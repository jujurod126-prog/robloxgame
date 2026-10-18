--!strict
--[[
	TruckService
	Gives every player their own truck on its own parking lot when their data
	loads, and removes it when they leave. Also applies truck stats to the
	character (walk speed) and moves the character behind the truck on spawn.

	Signals:
	  TruckService.TruckSpawned (player, truckModel)  -- also fires after a rebuild (tier change)
	  TruckService.TruckRemoved (player)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Data.Cosmetics)
local GameConfig = require(Shared.Data.GameConfig)
local PlayerDataTypes = require(Shared.Types.PlayerData)
local PlayerStats = require(Shared.Modules.PlayerStats)
local Signal = require(Shared.Modules.Signal)

local TruckBuilder = require(script.Parent.Parent.Modules.TruckBuilder)
local DataService = require(script.Parent.DataService)

type PlayerData = PlayerDataTypes.PlayerData

local DEFAULT_PAINT = Color3.fromRGB(250, 250, 245)
local DEFAULT_AWNING = Color3.fromRGB(255, 110, 140)
local GROUND_RAY_HEIGHT = 200

local TruckService = {}

TruckService.TruckSpawned = Signal.new()
TruckService.TruckRemoved = Signal.new()

local trucksFolder: Folder
local trucks: { [Player]: Model? } = {}
local lotOwners: { [number]: Player? } = {}
local playerLots: { [Player]: number? } = {}

-- Lot 1 at the origin, then +1, -1, +2, -2 ... spacings along X.
local function lotOffsetIndex(lot: number): number
	local step = math.floor(lot / 2)
	return if lot % 2 == 0 then step else -step
end

local function claimLot(player: Player): number?
	for lot = 1, GameConfig.Trucks.MaxLots do
		if lotOwners[lot] == nil then
			lotOwners[lot] = player
			playerLots[player] = lot
			return lot
		end
	end
	return nil
end

-- Finds the ground height under (x, z) so trucks sit on whatever map is there.
local function groundY(x: number, z: number, fallback: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { trucksFolder }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local customers = Workspace:FindFirstChild("Customers")
	if customers then
		table.insert(exclude, customers)
	end
	params.FilterDescendantsInstances = exclude
	local origin = Vector3.new(x, fallback + GROUND_RAY_HEIGHT, z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -GROUND_RAY_HEIGHT * 2, 0), params)
	return if result then result.Position.Y else fallback
end

local function lotPivot(lot: number): CFrame
	local origin = GameConfig.Trucks.LotOrigin
	local x = origin.X + lotOffsetIndex(lot) * GameConfig.Trucks.LotSpacing
	local y = groundY(x, origin.Z, origin.Y)
	return CFrame.new(x, y, origin.Z)
end

local function cosmeticColor(id: string, fallback: Color3): Color3
	local cosmetic = Cosmetics[id]
	return if cosmetic and cosmetic.Color then cosmetic.Color else fallback
end

local function buildTruck(player: Player, data: PlayerData, lot: number): Model
	local model = TruckBuilder.build(PlayerStats.truck(data), {
		Paint = cosmeticColor(data.Truck.Equipped.Paint, DEFAULT_PAINT),
		Awning = cosmeticColor(data.Truck.Equipped.Awning, DEFAULT_AWNING),
	}, lotPivot(lot))
	model.Name = `Truck_{player.UserId}`
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("OwnerName", player.DisplayName)
	model.Parent = trucksFolder
	return model
end

local function applyWalkSpeed(player: Player)
	local data = DataService.getData(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if data and humanoid then
		humanoid.WalkSpeed = PlayerStats.walkSpeed(data)
	end
end

-- Puts the character behind its truck, facing the customers.
local function moveCharacterToTruck(player: Player, character: Model)
	local truck = trucks[player]
	if truck == nil or truck.PrimaryPart == nil then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root == nil or character.Parent == nil then
		return
	end
	-- Let Roblox finish its own spawn positioning first, or it overrides ours.
	RunService.Heartbeat:Wait()
	local pivot = truck.PrimaryPart.CFrame
	local standZ = truck:GetAttribute("StandZ") :: number
	local position = (pivot * CFrame.new(0, 3, standZ)).Position
	character:PivotTo(CFrame.lookAt(position, position + pivot.LookVector))
end

local function onCharacterAdded(player: Player, character: Model)
	applyWalkSpeed(player)
	moveCharacterToTruck(player, character)
	applyWalkSpeed(player) -- again, in case the Humanoid appeared while we waited
end

local function spawnTruck(player: Player, data: PlayerData)
	local lot = claimLot(player)
	if lot == nil then
		warn(`[TruckService] No free truck lot for {player.Name}; raise GameConfig.Trucks.MaxLots`)
		return
	end
	trucks[player] = buildTruck(player, data, lot)
	TruckService.TruckSpawned:Fire(player, trucks[player])

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

-- Rebuilds the truck in place (after buying a new tier or cosmetic).
local function rebuildTruck(player: Player)
	local data = DataService.getData(player)
	local lot = playerLots[player]
	local old = trucks[player]
	if data == nil or lot == nil or old == nil then
		return
	end
	old:Destroy()
	trucks[player] = buildTruck(player, data, lot)
	TruckService.TruckSpawned:Fire(player, trucks[player])
end

local function onPlayerRemoving(player: Player)
	local truck = trucks[player]
	if truck then
		truck:Destroy()
		trucks[player] = nil
		TruckService.TruckRemoved:Fire(player)
	end
	local lot = playerLots[player]
	if lot then
		lotOwners[lot] = nil
		playerLots[player] = nil
	end
end

-- ===== Public API =====

function TruckService.getTruck(player: Player): Model?
	return trucks[player]
end

-- ===== Lifecycle =====

function TruckService.Init()
	trucksFolder = Instance.new("Folder")
	trucksFolder.Name = "Trucks"
	trucksFolder.Parent = Workspace
end

function TruckService.Start()
	DataService.PlayerLoaded:Connect(spawnTruck)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	DataService.Changed:Connect(function(player: Player, path: { any })
		if #path == 0 then
			rebuildTruck(player) -- whole data replaced (e.g. /wipe)
			applyWalkSpeed(player)
		elseif path[1] == "Truck" then
			if path[2] == "Tier" or path[2] == "Equipped" or path[2] == nil then
				rebuildTruck(player)
			end
			applyWalkSpeed(player)
		end
	end)
end

return TruckService
