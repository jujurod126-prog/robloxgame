--!strict
--[[
	PlayerStats
	Turns saved PlayerData into the numbers gameplay uses (scoop time, walk
	speed, cone size...). Server uses these to run the game; the client may use
	them to display stats. Equipped pets boost Coins, walk speed, scoop speed and
	tips here; game-pass boosts get added in Stage 8.
]]

local Shared = script.Parent.Parent
local Flavors = require(Shared.Data.Flavors)
local Formulas = require(script.Parent.Formulas)
local GameConfig = require(Shared.Data.GameConfig)
local GameData = require(Shared.Types.GameData)
local PetRules = require(script.Parent.PetRules)
local RebirthRules = require(script.Parent.RebirthRules)
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
	local petBoost = PetRules.totalBoosts(data).ScoopSpeed
	return base / (PlayerStats.truck(data).ScoopSpeedMultiplier * (1 + petBoost))
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
	local petBoost = PetRules.totalBoosts(data).MoveSpeed
	return Formulas.upgradeValue("MoveSpeed", level(data, "MoveSpeed"))
		* PlayerStats.truck(data).MoveSpeedMultiplier
		* (1 + petBoost)
end

-- Extra tip fraction: Tip Bonus upgrade + pets + Bigger Tips skill (0.1 = +10%).
function PlayerStats.tipBonus(data: PlayerData): number
	return Formulas.upgradeValue("TipBonus", level(data, "TipBonus"))
		+ PetRules.totalBoosts(data).TipBonus
		+ RebirthRules.skillValue(data, "BiggerTips")
end

-- Number of flavor slots on the current truck.
function PlayerStats.flavorSlots(data: PlayerData): number
	return PlayerStats.truck(data).FlavorSlots
end

--[[
	The flavors loaded in the truck, in slot order: only unlocked, existing,
	non-duplicate flavors, at most flavorSlots of them, never empty.
	Use this instead of reading data.Flavors.Loadout directly.
]]
function PlayerStats.loadout(data: PlayerData): { string }
	local result: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, flavorId in data.Flavors.Loadout do
		if #result >= PlayerStats.flavorSlots(data) then
			break
		end
		if Flavors[flavorId] and data.Flavors.Unlocked[flavorId] and not seen[flavorId] then
			seen[flavorId] = true
			table.insert(result, flavorId)
		end
	end
	if #result == 0 then
		table.insert(result, GameConfig.Starting.Flavor)
	end
	return result
end

-- Multiplier applied to every Coin the player earns.
function PlayerStats.coinMultiplier(data: PlayerData): number
	return Formulas.rebirthCoinMultiplier(data.Rebirths) * (1 + PetRules.totalBoosts(data).CoinMultiplier)
end

return PlayerStats
