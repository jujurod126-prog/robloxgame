--!strict
--[[
	DataController
	The client's read-only copy of PlayerData, kept in sync with the server.

	How syncing works (see docs/UI_CONTRACT.md):
	  1. Listen for DataPatch(seq, path, value) and buffer anything that arrives early.
	  2. Ask for GetSnapshot() -> { Seq, Data }.
	  3. Apply buffered patches with seq > snapshot Seq, in order; drop older ones.

	UI code:
	  local data = DataController.waitForData()
	  DataController.Changed:Connect(function(path, value) ... end)
	  DataController.observe("Coins", function(coins) ... end) -- runs now and on every change
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local PlayerDataTypes = require(Shared.Types.PlayerData)
local Remotes = require(Shared.Modules.Remotes)
local Signal = require(Shared.Modules.Signal)

type PlayerData = PlayerDataTypes.PlayerData
type Path = { string | number }
type Patch = { seq: number, path: Path, value: any }

local SNAPSHOT_RETRY_SECONDS = 2

local DataController = {}

-- Fires (data) once, when the first snapshot arrives.
DataController.Ready = Signal.new()
-- Fires (path, value) after every applied change. path {} = everything was replaced.
DataController.Changed = Signal.new()

local data: PlayerData? = nil
local lastSeq = -1
local pending: { Patch } = {}

local function applyPatch(patch: Patch)
	if patch.seq <= lastSeq then
		return -- already included in the snapshot
	end
	lastSeq = patch.seq

	if #patch.path == 0 then
		data = patch.value
	else
		local parent: any = data
		for index = 1, #patch.path - 1 do
			parent = parent[patch.path[index]]
		end
		parent[patch.path[#patch.path]] = patch.value
	end
	DataController.Changed:Fire(patch.path, patch.value)
end

local function requestSnapshot()
	local getSnapshot = Remotes.func("GetSnapshot")
	while true do
		local ok, snapshot = pcall(getSnapshot.InvokeServer, getSnapshot)
		if ok and snapshot then
			data = snapshot.Data
			lastSeq = snapshot.Seq

			table.sort(pending, function(a, b)
				return a.seq < b.seq
			end)
			for _, patch in pending do
				applyPatch(patch)
			end
			table.clear(pending)

			if RunService:IsStudio() then
				print(`[DataController] Data received: {(data :: PlayerData).Coins} Coins, seq {lastSeq}`)
			end
			-- The loading screen (ReplicatedFirst) waits for this. Local only.
			Players.LocalPlayer:SetAttribute("DataReady", true)
			DataController.Ready:Fire(data)
			return
		end
		task.wait(SNAPSHOT_RETRY_SECONDS)
	end
end

-- The current data, or nil before the first snapshot. Treat it as READ ONLY.
function DataController.getData(): PlayerData?
	return data
end

-- Yields until the first snapshot has arrived.
function DataController.waitForData(): PlayerData
	if data then
		return data
	end
	return DataController.Ready:Wait()
end

--[[
	Calls callback(value) right away (once data is ready) and again whenever the
	top-level key changes or is replaced. Returns the Changed connection.
]]
function DataController.observe(key: string, callback: (value: any) -> ())
	task.spawn(function()
		callback((DataController.waitForData() :: any)[key])
	end)
	return DataController.Changed:Connect(function(path: Path)
		if #path == 0 or path[1] == key then
			callback((data :: any)[key])
		end
	end)
end

function DataController.Init() end

function DataController.Start()
	Remotes.event("DataPatch").OnClientEvent:Connect(function(seq: number, path: Path, value: any)
		local patch = { seq = seq, path = path, value = value }
		if data == nil then
			table.insert(pending, patch)
		else
			applyPatch(patch)
		end
	end)
	task.spawn(requestSnapshot)
end

return DataController
