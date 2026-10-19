--!strict
--[[
	TruckService
	Every player has one truck, parked on a lot in the neighborhood they're
	working in. NeighborhoodService decides where (placeTruck); this service
	builds, moves, rebuilds (tier/cosmetic/VIP pass change) and removes it, and applies
	truck stats to the character (walk speed).

	Signals:
	  TruckService.TruckSpawned (player, truckModel)  -- after placing in a new area or a rebuild
	  TruckService.TruckRemoved (player)
	The truck model has attribute Neighborhood = the area it's parked in.
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
local WorldLayout = require(Shared.Data.WorldLayout)

local TruckBuilder = require(script.Parent.Parent.Modules.TruckBuilder)
local DataService = require(script.Parent.DataService)

type PlayerData = PlayerDataTypes.PlayerData

local DEFAULT_PAINT = Color3.fromRGB(250, 250, 245)
local DEFAULT_AWNING = Color3.fromRGB(255, 110, 140)
local VIP_PAINT = Color3.fromRGB(255, 200, 60) -- VIP Truck game pass: golden paint
local GROUND_RAY_HEIGHT = 200

type Parking = { area: string, lot: number }

local TruckService = {}

TruckService.TruckSpawned = Signal.new()
TruckService.TruckRemoved = Signal.new()

local trucksFolder: Folder
local trucks: { [Player]: Model? } = {}
local parking: { [Player]: Parking? } = {}
local lotOwners: { [string]: { [number]: Player? } } = {} -- area -> lot -> player

-- Lot 1 in the middle of the row, then +1, -1, +2, -2 ... spacings along X.
local function lotOffsetIndex(lot: number): number
	local step = math.floor(lot / 2)
	return if lot % 2 == 0 then step else -step
end

local function freeLot(player: Player)
	local spot = parking[player]
	if spot then
		local owners = lotOwners[spot.area]
		if owners then
			owners[spot.lot] = nil
		end
		parking[player] = nil
	end
end

local function claimLot(player: Player, area: string): number?
	local owners: { [number]: Player? } = lotOwners[area] or {}
	lotOwners[area] = owners
	for lot = 1, GameConfig.Trucks.MaxLots do
		if owners[lot] == nil then
			owners[lot] = player
			parking[player] = { area = area, lot = lot }
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

local function lotPivot(area: string, lot: number): CFrame
	local layout = WorldLayout[area]
	local x = layout.Center.X + lotOffsetIndex(lot) * GameConfig.Trucks.LotSpacing
	local z = layout.Center.Z + layout.LotRowZ
	return CFrame.new(x, groundY(x, z, layout.Center.Y), z)
end

local function cosmeticColor(id: string, fallback: Color3): Color3
	local cosmetic = Cosmetics[id]
	return if cosmetic and cosmetic.Color then cosmetic.Color else fallback
end

local function buildTruck(player: Player, data: PlayerData, spot: Parking): Model
	-- VIP pass owners get gold paint unless they picked a bought paint cosmetic.
	local paintId = data.Truck.Equipped.Paint
	local paint = cosmeticColor(paintId, DEFAULT_PAINT)
	local paintCosmetic = Cosmetics[paintId]
	if data.OwnedPasses.VipTruck and (paintCosmetic == nil or paintCosmetic.Price == 0) then
		paint = VIP_PAINT
	end
	local model = TruckBuilder.build(PlayerStats.truck(data), {
		Paint = paint,
		Awning = cosmeticColor(data.Truck.Equipped.Awning, DEFAULT_AWNING),
	}, lotPivot(spot.area, spot.lot))
	model.Name = `Truck_{player.UserId}`
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("OwnerName", player.DisplayName)
	model:SetAttribute("Neighborhood", spot.area)
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

-- Rebuilds the truck on the same lot (after buying a new tier or cosmetic).
local function rebuildTruck(player: Player)
	local data = DataService.getData(player)
	local spot = parking[player]
	local old = trucks[player]
	if data == nil or spot == nil or old == nil then
		return
	end
	old:Destroy()
	trucks[player] = buildTruck(player, data, spot)
	TruckService.TruckSpawned:Fire(player, trucks[player])
	-- A bigger truck could overlap the player, so put them behind the new one.
	if player.Character then
		task.spawn(TruckService.moveCharacterToTruck, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local truck = trucks[player]
	if truck then
		truck:Destroy()
		trucks[player] = nil
		TruckService.TruckRemoved:Fire(player)
	end
	freeLot(player)
end

-- ===== Public API =====

function TruckService.getTruck(player: Player): Model?
	return trucks[player]
end

-- The area the player's truck is parked in, or nil if they have no truck yet.
function TruckService.getTruckArea(player: Player): string?
	local spot = parking[player]
	return if spot then spot.area else nil
end

--[[
	Parks the player's truck in `area` (a neighborhood id), building it if needed.
	Does nothing if it's already there. Returns true if the truck is in that area.
]]
function TruckService.placeTruck(player: Player, area: string): boolean
	local data = DataService.getData(player)
	if data == nil or WorldLayout[area] == nil then
		return false
	end
	local spot = parking[player]
	if spot and spot.area == area and trucks[player] then
		return true
	end
	freeLot(player)
	if claimLot(player, area) == nil then
		warn(`[TruckService] No free truck lot in {area}; raise GameConfig.Trucks.MaxLots`)
		return false
	end
	local old = trucks[player]
	if old then
		old:Destroy()
	end
	trucks[player] = buildTruck(player, data, parking[player] :: Parking)
	TruckService.TruckSpawned:Fire(player, trucks[player])
	return true
end

-- Puts the character behind their truck, facing the customers. Yields briefly.
function TruckService.moveCharacterToTruck(player: Player, character: Model)
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
	local pivot = (truck.PrimaryPart :: BasePart).CFrame
	local standZ = truck:GetAttribute("StandZ") :: number
	local position = (pivot * CFrame.new(0, 3, standZ)).Position
	character:PivotTo(CFrame.lookAt(position, position + pivot.LookVector))
end

-- ===== Lifecycle =====

function TruckService.Init()
	trucksFolder = Instance.new("Folder")
	trucksFolder.Name = "Trucks"
	trucksFolder.Parent = Workspace
end

function TruckService.Start()
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	DataService.PlayerLoaded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			applyWalkSpeed(player)
		end)
		applyWalkSpeed(player)
	end)

	DataService.Changed:Connect(function(player: Player, path: { any })
		if #path == 0 then
			rebuildTruck(player) -- whole data replaced (e.g. /wipe)
			applyWalkSpeed(player)
		elseif path[1] == "Truck" then
			if path[2] == "Tier" or path[2] == "Equipped" or path[2] == nil then
				rebuildTruck(player)
			end
			applyWalkSpeed(player)
		elseif path[1] == "OwnedPasses" and path[2] == "VipTruck" then
			rebuildTruck(player)
		elseif path[1] == "Pets" or path[1] == "Skills" then
			applyWalkSpeed(player) -- pet speed boosts
		end
	end)
end

return TruckService
