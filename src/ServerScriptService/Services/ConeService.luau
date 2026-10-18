--!strict
--[[
	ConeService
	The Cone tool and the scoops on it.

	  * gives every player a Cone tool each time their character spawns
	  * handles the truck dispenser's Scoop prompt, with server checks:
	    truck owner only, close enough, scoop cooldown, cone not full
	  * CustomerService calls takeScoops(player) when serving

	Cone contents are NOT saved (they reset on respawn). They're shown to the
	client through Player attributes:
	  ConeScoops (number), ConeCapacity (number), ConeFlavors ("Vanilla,Vanilla")
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Flavors = require(Shared.Data.Flavors)
local GameConfig = require(Shared.Data.GameConfig)
local PlayerStats = require(Shared.Modules.PlayerStats)

local ServerModules = script.Parent.Parent.Modules
local ConeTool = require(ServerModules.ConeTool)
local Notify = require(ServerModules.Notify)
local DataService = require(script.Parent.DataService)
local TruckService = require(script.Parent.TruckService)

-- Extra studs allowed beyond the prompt's range (movement between client and server).
local DISTANCE_SLACK = 4

type ConeState = {
	scoops: { string }, -- flavor ids, bottom to top
	lastScoopTime: number,
	tool: Tool?,
}

local ConeService = {}

local cones: { [Player]: ConeState } = {}

-- Pushes cone contents to the tool visuals and the player's attributes.
local function refresh(player: Player)
	local cone = cones[player]
	local data = DataService.getData(player)
	if cone == nil or data == nil then
		return
	end
	if cone.tool then
		local colors = {}
		for _, flavorId in cone.scoops do
			table.insert(colors, Flavors[flavorId].Color)
		end
		ConeTool.setScoops(cone.tool, colors)
	end
	player:SetAttribute("ConeScoops", #cone.scoops)
	player:SetAttribute("ConeCapacity", PlayerStats.coneCapacity(data))
	player:SetAttribute("ConeFlavors", table.concat(cone.scoops, ","))
end

local function giveCone(player: Player, character: Model)
	local cone = cones[player]
	if cone == nil then
		return
	end
	if cone.tool then
		cone.tool:Destroy()
	end
	table.clear(cone.scoops) -- a new life starts with an empty cone
	local tool = ConeTool.create()
	tool.Parent = player:FindFirstChildOfClass("Backpack") or character
	cone.tool = tool
	refresh(player)
end

local function equipCone(player: Player)
	local cone = cones[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if cone and cone.tool and humanoid and cone.tool.Parent ~= character then
		humanoid:EquipTool(cone.tool)
	end
end

local function tryScoop(player: Player, owner: Player, dispenser: BasePart)
	if player ~= owner then
		return -- only the truck's owner can scoop from it
	end
	local cone = cones[player]
	local data = DataService.getData(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if cone == nil or data == nil or root == nil then
		return
	end

	local maxDistance = GameConfig.Scooping.PromptDistance + DISTANCE_SLACK
	if (root.Position - dispenser.Position).Magnitude > maxDistance then
		return
	end

	local now = os.clock()
	if now - cone.lastScoopTime < PlayerStats.scoopSeconds(data) * GameConfig.Scooping.CooldownTolerance then
		return -- scooping faster than the hold time allows
	end

	if #cone.scoops >= PlayerStats.coneCapacity(data) then
		Notify.send(player, "Your cone is full! Serve a customer.", "Error")
		return
	end

	cone.lastScoopTime = now
	table.insert(cone.scoops, PlayerStats.activeFlavor(data))
	DataService.increment(player, { "Stats", "ScoopsMade" }, 1)
	equipCone(player)
	refresh(player)
end

-- Sets the dispenser prompt's hold time and label from the player's current stats.
local function configurePrompt(player: Player)
	local truck = TruckService.getTruck(player)
	local data = DataService.getData(player)
	local dispenser = truck and truck:FindFirstChild("Dispenser")
	local prompt = dispenser and dispenser:FindFirstChild("ScoopPrompt") :: ProximityPrompt?
	if prompt == nil or data == nil then
		return
	end
	local seconds = PlayerStats.scoopSeconds(data)
	prompt.HoldDuration = seconds
	prompt.ObjectText = Flavors[PlayerStats.activeFlavor(data)].DisplayName
	prompt:SetAttribute("ScoopSeconds", seconds) -- the client uses this for tap-to-scoop on mobile
end

local function onTruckSpawned(owner: Player, truck: Model)
	local dispenser = truck:FindFirstChild("Dispenser") :: BasePart?
	local prompt = dispenser and dispenser:FindFirstChild("ScoopPrompt") :: ProximityPrompt?
	if dispenser == nil or prompt == nil then
		return
	end
	configurePrompt(owner)
	prompt.Triggered:Connect(function(player: Player)
		tryScoop(player, owner, dispenser)
	end)
end

local function onPlayerLoaded(player: Player)
	cones[player] = { scoops = {}, lastScoopTime = 0, tool = nil }
	player.CharacterAdded:Connect(function(character)
		giveCone(player, character)
	end)
	if player.Character then
		giveCone(player, player.Character)
	end
end

-- ===== Public API =====

-- Removes and returns every scoop on the player's cone (bottom to top).
function ConeService.takeScoops(player: Player): { string }
	local cone = cones[player]
	if cone == nil then
		return {}
	end
	local scoops = table.clone(cone.scoops)
	table.clear(cone.scoops)
	refresh(player)
	return scoops
end

function ConeService.getScoopCount(player: Player): number
	local cone = cones[player]
	return if cone then #cone.scoops else 0
end

-- ===== Lifecycle =====

function ConeService.Init() end

function ConeService.Start()
	DataService.PlayerLoaded:Connect(onPlayerLoaded)
	TruckService.TruckSpawned:Connect(onTruckSpawned)
	Players.PlayerRemoving:Connect(function(player)
		cones[player] = nil
	end)

	DataService.Changed:Connect(function(player: Player, path: { any })
		if #path == 0 or path[1] == "Truck" or path[1] == "Flavors" then
			configurePrompt(player)
			refresh(player)
		end
	end)
end

return ConeService
