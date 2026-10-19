--!strict
--[[
	NeighborhoodService
	Where each player is, and getting around:
	  * builds the world at startup (WorldBuilder)
	  * on join: you appear in the neighborhood you were last in, with your truck there
	  * teleport pads: Hub <-> neighborhoods (server checks you've unlocked the area)
	  * gates in the Hub: "Unlock" prompt buys the neighborhood (in order, rebirth locks)
	  * respawning puts you back in your area (behind your truck, or at the Hub spawn)

	The current area is the Player attribute "Neighborhood" ("Hub" or a neighborhood id).
	Signal: NeighborhoodService.AreaChanged (player, areaId)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Data.GameConfig)
local NeighborhoodRules = require(Shared.Modules.NeighborhoodRules)
local Neighborhoods = require(Shared.Data.Neighborhoods)
local NumberFormat = require(Shared.Modules.NumberFormat)
local Signal = require(Shared.Modules.Signal)
local WorldLayout = require(Shared.Data.WorldLayout)

local ServerModules = script.Parent.Parent.Modules
local Notify = require(ServerModules.Notify)
local WorldBuilder = require(ServerModules.World.WorldBuilder)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local TruckService = require(script.Parent.TruckService)

local HUB = "Hub"

local NeighborhoodService = {}

NeighborhoodService.AreaChanged = Signal.new()

local world: Folder
local areas: { [Player]: string } = {}
local lastPadUse: { [Player]: number } = {}

-- Where a new session starts: the last neighborhood they were in, if they can still enter it.
local function startingArea(player: Player): string
	local data = DataService.getData(player)
	local saved = data and data.Neighborhoods.Current
	if data and saved and saved ~= HUB and Neighborhoods[saved] and NeighborhoodRules.canEnter(data, saved) then
		return saved
	end
	return GameConfig.Starting.Neighborhood
end

local function hubSpawn(): CFrame
	local layout = WorldLayout[HUB]
	local position = layout.Center + layout.Spawn
	return CFrame.lookAt(position, position + Vector3.new(0, 0, -1)) -- facing the gates
end

-- Where the player appears in an area (the truck stand position is close to this).
local function arrivalPoint(area: string): Vector3
	if area == HUB then
		return hubSpawn().Position
	end
	return WorldLayout[area].Center + WorldLayout[area].Spawn
end

-- Puts the character where they belong for their current area.
local function placeCharacter(player: Player, character: Model)
	local area = areas[player]
	if area then
		-- Load the destination on the client first (StreamingEnabled), so they don't fall.
		pcall(player.RequestStreamAroundAsync, player, arrivalPoint(area))
	end
	if area == HUB then
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and character.Parent then
			character:PivotTo(hubSpawn())
		end
	else
		TruckService.moveCharacterToTruck(player, character)
	end
end

local function setArea(player: Player, area: string)
	areas[player] = area
	player:SetAttribute("Neighborhood", area)
	if area ~= HUB then
		DataService.set(player, { "Neighborhoods", "Current" }, area)
	end
	NeighborhoodService.AreaChanged:Fire(player, area)
end

--[[
	Moves the player to an area (truck follows into neighborhoods). Checks access.
	Returns true on success; tells the player why on failure.
]]
function NeighborhoodService.travel(player: Player, area: string): boolean
	local data = DataService.getData(player)
	local neighborhood = Neighborhoods[area]
	if data == nil or neighborhood == nil then
		return false
	end
	if not NeighborhoodRules.canEnter(data, area) then
		local status = NeighborhoodRules.status(data, area)
		if status.State == "NeedsRebirth" then
			Notify.send(player, `{neighborhood.DisplayName} needs {neighborhood.RequiresRebirths} Rebirth(s).`, "Error")
		else
			Notify.send(player, `Unlock {neighborhood.DisplayName} at its gate in Scoop Central first!`, "Error")
		end
		return false
	end
	if area ~= HUB and not TruckService.placeTruck(player, area) then
		Notify.send(player, "No parking space there right now. Try again soon!", "Error")
		return false
	end

	setArea(player, area) -- placeCharacter streams the destination in before moving them
	if player.Character then
		task.spawn(placeCharacter, player, player.Character)
	end
	return true
end

function NeighborhoodService.getArea(player: Player): string?
	return areas[player]
end

-- ===== Gates and pads =====

local function unlock(player: Player, neighborhoodId: string)
	local data = DataService.getData(player)
	local neighborhood = Neighborhoods[neighborhoodId]
	if data == nil or neighborhood == nil then
		return
	end
	local status = NeighborhoodRules.status(data, neighborhoodId)
	if status.State == "Unlocked" then
		return
	elseif status.State == "NeedsRebirth" then
		Notify.send(player, `{neighborhood.DisplayName} needs {neighborhood.RequiresRebirths} Rebirth(s).`, "Error")
		return
	elseif status.State == "NeedsPrevious" then
		local previous = NeighborhoodRules.previous(neighborhoodId)
		local name = if previous then Neighborhoods[previous].DisplayName else "the one before"
		Notify.send(player, `Unlock {name} first!`, "Error")
		return
	end
	if not EconomyService.trySpend(player, "Coins", status.Cost) then
		Notify.send(player, `You need {NumberFormat.commas(status.Cost - data.Coins)} more Coins.`, "Error")
		return
	end
	DataService.set(player, { "Neighborhoods", "Unlocked", neighborhoodId }, true)
	Notify.send(player, `{neighborhood.DisplayName} unlocked! Step on the pad to go there.`, "Info")
	Notify.celebrate(player, "Unlock")
end

local function playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	if character and character:FindFirstChildOfClass("Humanoid") then
		return Players:GetPlayerFromCharacter(character)
	end
	return nil
end

local function connectPad(pad: BasePart)
	pad.Touched:Connect(function(hit: BasePart)
		local player = playerFromHit(hit)
		local target = pad:GetAttribute("TravelTo") :: string?
		if player == nil or target == nil or areas[player] == target then
			return
		end
		local now = os.clock()
		if now - (lastPadUse[player] or 0) < GameConfig.Travel.PadCooldown then
			return
		end
		lastPadUse[player] = now
		NeighborhoodService.travel(player, target)
	end)
end

local function connectWorld()
	for _, descendant in world:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == "TravelPad" then
			connectPad(descendant)
		elseif descendant:IsA("Model") and descendant:GetAttribute("NeighborhoodId") then
			local id = descendant:GetAttribute("NeighborhoodId") :: string
			local barrier = descendant:FindFirstChild("Barrier")
			local prompt = barrier and barrier:FindFirstChild("UnlockPrompt") :: ProximityPrompt?
			if prompt then
				prompt.Triggered:Connect(function(player: Player)
					unlock(player, id)
				end)
			end
		end
	end
end

-- ===== Lifecycle =====

local function onPlayerLoaded(player: Player)
	local area = startingArea(player)
	TruckService.placeTruck(player, area)
	setArea(player, area)
	player.CharacterAdded:Connect(function(character)
		placeCharacter(player, character)
	end)
	if player.Character then
		task.spawn(placeCharacter, player, player.Character)
	end
end

function NeighborhoodService.Init()
	world = WorldBuilder.build()
end

function NeighborhoodService.Start()
	connectWorld()
	DataService.PlayerLoaded:Connect(onPlayerLoaded)
	Players.PlayerRemoving:Connect(function(player)
		areas[player] = nil
		lastPadUse[player] = nil
	end)

	-- After a data reset the player may be somewhere they no longer have access to.
	DataService.Changed:Connect(function(player: Player, path: { any })
		local data = DataService.getData(player)
		local area = areas[player]
		if #path == 0 and data and area and not NeighborhoodRules.canEnter(data, area) then
			NeighborhoodService.travel(player, GameConfig.Starting.Neighborhood)
		end
	end)
end

return NeighborhoodService
