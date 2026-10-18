--!strict
--[[
	DataService
	Loads, saves and replicates PlayerData. The ONLY place that writes saved data.

	Saving (via ProfileStore, vendored in ServerScriptService/Packages):
	  * session locking: a profile can only be open on one server at a time
	  * autosave every GameConfig.Data.AutosaveSeconds
	  * saves + releases on PlayerRemoving, and on server shutdown (ProfileStore binds BindToClose)
	  * failed DataStore calls are retried by ProfileStore; errors are logged below
	  * DataVersion + DataMigrations upgrade old saves before use

	Replication (one method, used everywhere - see docs/UI_CONTRACT.md):
	  * client calls GetSnapshot once -> { Seq, Data }
	  * every change after that is sent as DataPatch(seq, path, value)
	  * path {} means "replace everything" (used by resets)

	Other services: READ with DataService.getData(player), WRITE only through
	set / update / increment so the change is replicated and Changed fires.
	Never edit the table returned by getData directly.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Data.GameConfig)
local PlayerDataTypes = require(Shared.Types.PlayerData)
local Remotes = require(Shared.Modules.Remotes)
local Signal = require(Shared.Modules.Signal)
local TableUtil = require(Shared.Modules.TableUtil)

local ProfileStore = require(ServerScriptService.Packages.ProfileStore)
local ServerModules = ServerScriptService.Modules
local DataMigrations = require(ServerModules.DataMigrations)
local DataTemplate = require(ServerModules.DataTemplate)
local RateLimiter = require(ServerModules.RateLimiter)

type PlayerData = PlayerDataTypes.PlayerData
export type PathKey = string | number
export type Path = { PathKey }

local LOAD_WAIT_TIMEOUT = 30 -- seconds GetSnapshot waits for a profile to finish loading
local KICK_LOAD_FAILED = "We couldn't load your ice cream empire. Please rejoin in a moment!"
local KICK_SESSION_ENDED = "Your data was opened on another server. Please rejoin."
local KICK_DATA_TOO_NEW = "This server is out of date. Please rejoin to get the latest version."

local DataService = {}

-- Fires (player, data) once a player's profile has loaded and is safe to use.
DataService.PlayerLoaded = Signal.new()
-- Fires (player, path, newValue) after every change made through this service.
DataService.Changed = Signal.new()

local store: any = nil
local profiles: { [Player]: any } = {}
local syncSeq: { [Player]: number } = {}

local function pathToString(path: Path): string
	local parts = {}
	for _, key in path do
		table.insert(parts, tostring(key))
	end
	return table.concat(parts, ".")
end

-- Sends one change to the owning client, tagged with a sequence number so
-- the client can drop patches that are older than its snapshot.
local function replicate(player: Player, path: Path, value: any)
	local seq = (syncSeq[player] or 0) + 1
	syncSeq[player] = seq
	Remotes.event("DataPatch"):FireClient(player, seq, path, value)
end

local function getActiveProfile(player: Player): any?
	local profile = profiles[player]
	if profile and profile:IsActive() then
		return profile
	end
	return nil
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(GameConfig.Data.KeyPrefix .. player.UserId, {
		-- Stop retrying if the player leaves while we're still waiting.
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Loading failed (DataStore down, or the player left while loading).
		if player.Parent == Players then
			player:Kick(KICK_LOAD_FAILED)
		end
		return
	end

	profile:AddUserId(player.UserId) -- GDPR: links the save to the user for erasure requests

	local ok, result = pcall(DataMigrations.run, profile.Data)
	if not ok or result ~= "Ok" then
		warn(`[DataService] Migration failed for {player.Name}: {if ok then result else tostring(result)}`)
		profile:EndSession()
		if player.Parent == Players then
			player:Kick(if result == "TooNew" then KICK_DATA_TOO_NEW else KICK_LOAD_FAILED)
		end
		return
	end
	profile:Reconcile() -- fill in keys added to DataTemplate since this save was made

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		syncSeq[player] = nil
		if player.Parent == Players then
			player:Kick(KICK_SESSION_ENDED)
		end
	end)

	if player.Parent ~= Players then
		-- Left during loading: release the session right away.
		profile:EndSession()
		return
	end

	profiles[player] = profile
	syncSeq[player] = 0

	if RunService:IsStudio() then
		print(
			`[DataService] Loaded {player.Name} (data v{profile.Data.DataVersion}, store "{GameConfig.Data.StoreName}"):`
				.. ` {profile.Data.Coins} Coins, {profile.Data.Gems} Gems, session #{profile.SessionLoadCount}`
		)
	end

	DataService.PlayerLoaded:Fire(player, profile.Data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		-- Saves one last time and releases the session lock.
		profile:EndSession()
	end
end

-- Client -> Server: returns { Seq, Data } once the player's data is ready, or nil.
local snapshotLimiter = RateLimiter.fromConfig(GameConfig.RateLimits.GetSnapshot)
local function onGetSnapshot(player: Player): { Seq: number, Data: PlayerData }?
	if not snapshotLimiter:check(player) then
		return nil
	end
	local data = DataService.waitForData(player, LOAD_WAIT_TIMEOUT)
	if data == nil then
		return nil
	end
	return { Seq = syncSeq[player], Data = data }
end

-- ===== Public API =====

--[[
	Returns the player's live data table, or nil if not loaded yet.
	READ ONLY: change data with set / update / increment instead.
]]
function DataService.getData(player: Player): PlayerData?
	local profile = getActiveProfile(player)
	return if profile then profile.Data else nil
end

-- Yields until the player's data is loaded. Returns nil on timeout or if they leave.
function DataService.waitForData(player: Player, timeout: number?): PlayerData?
	local deadline = os.clock() + (timeout or LOAD_WAIT_TIMEOUT)
	while player.Parent == Players and os.clock() < deadline do
		local data = DataService.getData(player)
		if data then
			return data
		end
		task.wait(0.1)
	end
	return DataService.getData(player)
end

function DataService.isLoaded(player: Player): boolean
	return getActiveProfile(player) ~= nil
end

--[[
	Changes one value. updater gets the current value and returns the new one.
	Returns the new value, or nil if the player's data isn't loaded.

	DataService.update(player, { "Truck", "Upgrades", "ScoopSpeed" }, function(level)
		return level + 1
	end)
]]
function DataService.update(player: Player, path: Path, updater: (any) -> any): any
	assert(#path > 0, "DataService.update needs a non-empty path")
	local profile = getActiveProfile(player)
	if profile == nil then
		return nil
	end

	local parent = profile.Data
	for index = 1, #path - 1 do
		parent = parent[path[index]]
		assert(type(parent) == "table", `[DataService] invalid path {pathToString(path)}`)
	end
	local key = path[#path]

	local newValue = updater(parent[key])
	parent[key] = newValue

	replicate(player, path, newValue)
	DataService.Changed:Fire(player, path, newValue)
	return newValue
end

-- Sets one value. Returns the value, or nil if the player's data isn't loaded.
function DataService.set(player: Player, path: Path, value: any): any
	return DataService.update(player, path, function()
		return value
	end)
end

--[[
	Adds delta to a number (use a negative delta to subtract).
	Does NOT check affordability - EconomyService (Stage 2) wraps this with
	server-side checks for spending. Returns the new number, or nil if not loaded.
]]
function DataService.increment(player: Player, path: Path, delta: number): number?
	assert(type(delta) == "number" and delta == delta and math.abs(delta) ~= math.huge, "delta must be a finite number")
	return DataService.update(player, path, function(current)
		assert(type(current) == "number", `[DataService] {pathToString(path)} is not a number`)
		return current + delta
	end)
end

--[[
	Wipes the player's data back to the template (Studio testing / support only).
	Sends a full replacement to the client (path = {}).
]]
function DataService.resetData(player: Player)
	local profile = getActiveProfile(player)
	if profile == nil then
		return
	end
	table.clear(profile.Data)
	for key, value in TableUtil.deepCopy(DataTemplate) :: any do
		profile.Data[key] = value
	end
	replicate(player, {}, profile.Data)
	DataService.Changed:Fire(player, {}, profile.Data)
end

-- ===== Lifecycle =====

function DataService.Init()
	ProfileStore.SetConstant("AUTO_SAVE_PERIOD", GameConfig.Data.AutosaveSeconds)

	local liveStore = ProfileStore.New(GameConfig.Data.StoreName, DataTemplate)
	local useMock = RunService:IsStudio() and GameConfig.Data.ForceMockInStudio
	store = if useMock then liveStore.Mock else liveStore
	if useMock then
		print("[DataService] GameConfig.Data.ForceMockInStudio is on: nothing will be saved")
	end

	ProfileStore.OnError:Connect(function(message, storeName, profileKey)
		warn(`[DataService] ProfileStore error ({storeName}/{profileKey}): {message}`)
	end)
	ProfileStore.OnCriticalToggle:Connect(function(isCritical)
		warn(`[DataService] DataStore critical state: {isCritical}`)
	end)
end

function DataService.Start()
	Remotes.func("GetSnapshot").OnServerInvoke = onGetSnapshot

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- Players who joined before this ran (common in Studio play-tests).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return DataService
