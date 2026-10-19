--!strict
--[[
	PlayerStats
	Turns saved PlayerData into the numbers gameplay uses (scoop time, walk
	speed, cone size...). Server uses these to run the game; the client may use
	them to display stats. Pet and game-pass boosts get added here in later stages.
]]

local Shared = script.Parent.Parent
local Flavors = require(Shared.Data.Flavors)
local Formulas = require(script.Parent.Formulas)
local GameConfig = require(Shared.Data.GameConfig)
local GameData = require(Shared.Types.GameData)
local PlayerDataTypes = require(Shared.Types.PlayerData)
local Trucks = require(Shared.Data.Trucks)

type PlayerData = PlayerDataTypes.PlayerData

local PlayerStats = {}

local function level(data: PlayerData, statId: string): number
	return data.Truck.Upgrades[statId] or 1
end

function PlayerStats.truck(data: PlayerData): GameData.TruckDef
	return Trucks[math.clamp(data.Truck.Tier, 1, #Trucks)]
end

-- Seconds to scoop one scoop (the dispenser prompt's hold time).
function PlayerStats.scoopSeconds(data: PlayerData): number
	local base = Formulas.upgradeValue("ScoopSpeed", level(data, "ScoopSpeed"))
	return base / PlayerStats.truck(data).ScoopSpeedMultiplier
end

-- Scoops the cone can hold.
function PlayerStats.coneCapacity(data: PlayerData): number
	return Formulas.upgradeValue("Storage", level(data, "Storage"))
end

-- Customers that can be at the counter at once, capped by the neighborhood's spots.
function PlayerStats.servingCapacity(data: PlayerData, neighborhood: GameData.NeighborhoodDef): number
	local capacity = PlayerStats.truck(data).BaseServingCapacity
		+ Formulas.upgradeValue("ServingCapacity", level(data, "ServingCapacity"))
	return math.min(capacity, neighborhood.CustomerSpots)
end

function PlayerStats.walkSpeed(data: PlayerData): number
	return Formulas.upgradeValue("MoveSpeed", level(data, "MoveSpeed")) * PlayerStats.truck(data).MoveSpeedMultiplier
end

-- Extra tip fraction from the Tip Bonus upgrade (0.1 = +10%).
function PlayerStats.tipBonus(data: PlayerData): number
	return Formulas.upgradeValue("TipBonus", level(data, "TipBonus"))
end

-- The flavor the dispenser scoops and customers order. Stage 4 adds choosing between loadout slots.
function PlayerStats.activeFlavor(data: PlayerData): string
	local flavorId = data.Flavors.Loadout[1]
	if flavorId and Flavors[flavorId] and data.Flavors.Unlocked[flavorId] then
		return flavorId
	end
	return GameConfig.Starting.Flavor
end

-- Multiplier applied to every Coin the player earns.
function PlayerStats.coinMultiplier(data: PlayerData): number
	return Formulas.rebirthCoinMultiplier(data.Rebirths)
end

return PlayerStats
