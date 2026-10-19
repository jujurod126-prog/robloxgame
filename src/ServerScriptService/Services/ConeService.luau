--!strict
--[[
	ConeService
	The Cone tool and what's on it.

	  * gives every player a Cone tool each time their character spawns
	  * SelectFlavor(slot): which loaded flavor the dispenser scoops
	  * the truck dispenser's Scoop prompt, with server checks:
	    truck owner only, close enough, scoop cooldown, cone not full
	  * AddTopping(toppingId): one topping per cone, unlocked, near the truck, cone not empty
	  * CustomerService calls takeCone(player) when serving

	Cone contents are NOT saved (they reset on respawn). The client sees them through
	Player attributes: ConeScoops, ConeCapacity, ConeFlavors ("Vanilla,Chocolate"),
	ConeTopping (topping id or nil), ActiveSlot, ActiveFlavor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Flavors = require(Shared.Data.Flavors)
local GameConfig = require(Shared.Data.GameConfig)
local PlayerStats = require(Shared.Modules.PlayerStats)
local Remotes = require(Shared.Modules.Remotes)
local Toppings = require(Shared.Data.Toppings)

local ServerModules = script.Parent.Parent.Modules
local ConeTool = require(ServerModules.ConeTool)
local Notify = require(ServerModules.Notify)
local RateLimiter = require(ServerModules.RateLimiter)
local DataService = require(script.Parent.DataService)
local TruckService = require(script.Parent.TruckService)

type PurchaseResult = Remotes.PurchaseResult

-- Extra studs allowed beyond the prompt's range (movement between client and server).
local DISTANCE_SLACK = 4

type ConeState = {
	scoops: { string }, -- flavor ids, bottom to top
	topping: string?,
	activeSlot: number, -- loadout slot the dispenser scoops from
	lastScoopTime: number,
	tool: Tool?,
}

export type ConeContents = { Scoops: { string }, Topping: string? }

local ConeService = {}

local cones: { [Player]: ConeState } = {}
local actionLimiter = RateLimiter.fromConfig(GameConfig.RateLimits.Action)

-- The flavor id in the player's active slot (falls back to slot 1 if the loadout shrank).
local function activeFlavor(player: Player): string?
	local cone = cones[player]
	local data = DataService.getData(player)
	if cone == nil or data == nil then
		return nil
	end
	local loadout = PlayerStats.loadout(data)
	if cone.activeSlot > #loadout then
		cone.activeSlot = 1
	end
	return loadout[cone.activeSlot]
end

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
		ConeTool.setScoops(cone.tool, colors, if cone.topping then Toppings[cone.topping].Color else nil)
	end
	player:SetAttribute("ConeScoops", #cone.scoops)
	player:SetAttribute("ConeCapacity", PlayerStats.coneCapacity(data))
	player:SetAttribute("ConeFlavors", table.concat(cone.scoops, ","))
	player:SetAttribute("ConeTopping", cone.topping)
	player:SetAttribute("ActiveFlavor", activeFlavor(player))
	player:SetAttribute("ActiveSlot", cone.activeSlot)
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
	cone.topping = nil
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

-- True if the player's character is within reach of their own truck's dispenser.
local function nearDispenser(player: Player): boolean
	local truck = TruckService.getTruck(player)
	local dispenser = truck and truck:FindFirstChild("Dispenser") :: BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if dispenser == nil or root == nil then
		return false
	end
	return (root.Position - dispenser.Position).Magnitude <= GameConfig.Scooping.PromptDistance + DISTANCE_SLACK
end

local function tryScoop(player: Player, owner: Player)
	if player ~= owner then
		return -- only the truck's owner can scoop from it
	end
	local cone = cones[player]
	local data = DataService.getData(player)
	local flavorId = activeFlavor(player)
	if cone == nil or data == nil or flavorId == nil or not nearDispenser(player) then
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
	if cone.topping then
		Notify.send(player, "The topping goes on last! Serve this cone first.", "Error")
		return
	end

	cone.lastScoopTime = now
	table.insert(cone.scoops, flavorId)
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
	local flavorId = activeFlavor(player)
	if prompt == nil or data == nil then
		return
	end
	local seconds = PlayerStats.scoopSeconds(data)
	prompt.HoldDuration = seconds
	prompt.ObjectText = if flavorId then Flavors[flavorId].DisplayName else ""
	prompt:SetAttribute("ScoopSeconds", seconds) -- the client uses this for tap-to-scoop on mobile
end

local function onSelectFlavor(player: Player, slot: unknown)
	local cone = cones[player]
	local data = DataService.getData(player)
	if not actionLimiter:check(player) or cone == nil or data == nil then
		return
	end
	if type(slot) ~= "number" or slot ~= math.floor(slot) then
		return
	end
	if (slot :: number) < 1 or (slot :: number) > #PlayerStats.loadout(data) then
		return
	end
	cone.activeSlot = slot :: number
	configurePrompt(player)
	refresh(player)
end

local function onAddTopping(player: Player, toppingId: unknown): PurchaseResult
	local cone = cones[player]
	local data = DataService.getData(player)
	if not actionLimiter:check(player) then
		return { Ok = false, Message = "Slow down a little!" }
	end
	if cone == nil or data == nil then
		return { Ok = false, Message = "Your data is still loading." }
	end
	if type(toppingId) ~= "string" or Toppings[toppingId] == nil then
		return { Ok = false, Message = "That topping doesn't exist." }
	end
	local id = toppingId :: string
	if not data.Toppings.Unlocked[id] then
		return { Ok = false, Message = "Unlock that topping in the Flavor Lab first." }
	end
	if not nearDispenser(player) then
		return { Ok = false, Message = "Go to your truck to add toppings." }
	end
	if #cone.scoops == 0 then
		return { Ok = false, Message = "Scoop some ice cream first!" }
	end
	if cone.topping then
		return { Ok = false, Message = "This cone already has a topping." }
	end
	cone.topping = id
	equipCone(player)
	refresh(player)
	return { Ok = true, Message = `Added {Toppings[id].DisplayName}!` }
end

local function onTruckSpawned(owner: Player, truck: Model)
	local dispenser = truck:FindFirstChild("Dispenser") :: BasePart?
	local prompt = dispenser and dispenser:FindFirstChild("ScoopPrompt") :: ProximityPrompt?
	if dispenser == nil or prompt == nil then
		return
	end
	configurePrompt(owner)
	prompt.Triggered:Connect(function(player: Player)
		tryScoop(player, owner)
	end)
end

local function onPlayerLoaded(player: Player)
	cones[player] = { scoops = {}, topping = nil, activeSlot = 1, lastScoopTime = 0, tool = nil }
	player.CharacterAdded:Connect(function(character)
		giveCone(player, character)
	end)
	if player.Character then
		giveCone(player, player.Character)
	end
	configurePrompt(player)
end

-- ===== Public API =====

-- Removes and returns everything on the player's cone.
function ConeService.takeCone(player: Player): ConeContents
	local cone = cones[player]
	if cone == nil then
		return { Scoops = {}, Topping = nil }
	end
	local contents = { Scoops = table.clone(cone.scoops), Topping = cone.topping }
	table.clear(cone.scoops)
	cone.topping = nil
	refresh(player)
	return contents
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
	Remotes.event("SelectFlavor").OnServerEvent:Connect(onSelectFlavor)
	Remotes.func("AddTopping").OnServerInvoke = onAddTopping
	Players.PlayerRemoving:Connect(function(player)
		cones[player] = nil
	end)

	DataService.Changed:Connect(function(player: Player, path: { any })
		if #path == 0 or path[1] == "Truck" or path[1] == "Flavors" or path[1] == "Pets" then
			configurePrompt(player)
			refresh(player)
		end
	end)
end

return ConeService
