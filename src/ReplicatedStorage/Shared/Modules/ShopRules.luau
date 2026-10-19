--!strict
--[[
	ShopRules
	What a player can buy in the Truck Garage and what it costs.
	The server uses these to VALIDATE purchases; the UI uses the same functions
	to show prices, locked states and notification dots, so they always agree.
]]

local Shared = script.Parent.Parent
local Formulas = require(script.Parent.Formulas)
local PlayerDataTypes = require(Shared.Types.PlayerData)
local Trucks = require(Shared.Data.Trucks)
local Upgrades = require(Shared.Data.Upgrades)

type PlayerData = PlayerDataTypes.PlayerData

export type UpgradeStatus = {
	Level: number,
	MaxLevel: number,
	Cost: number?, -- nil when maxed
	CanBuy: boolean, -- not maxed AND affordable
}

export type TruckState =
	"Owned" -- a lower tier you already passed
	| "Current" -- the truck you drive now
	| "Available" -- the next tier, requirements met (may still be unaffordable)
	| "NeedsRebirth" -- the next tier, but you need more rebirths
	| "NeedsPrevious" -- buy the tiers before it first

export type TruckStatus = {
	State: TruckState,
	Cost: number,
	CanBuy: boolean, -- Available AND affordable
}

local ShopRules = {}

-- statId must be a key of Shared/Data/Upgrades (errors otherwise).
function ShopRules.upgradeStatus(data: PlayerData, statId: string): UpgradeStatus
	local upgrade = Upgrades[statId]
	assert(upgrade, `Unknown upgrade {statId}`)
	local level = data.Truck.Upgrades[statId] or 1
	local cost = Formulas.upgradeCost(statId, level)
	return {
		Level = level,
		MaxLevel = upgrade.MaxLevel,
		Cost = cost,
		CanBuy = cost ~= nil and data.Coins >= cost,
	}
end

function ShopRules.truckStatus(data: PlayerData, tier: number): TruckStatus
	local truck = Trucks[tier]
	assert(truck, `Unknown truck tier {tier}`)
	local current = data.Truck.Tier
	local state: TruckState
	if tier < current then
		state = "Owned"
	elseif tier == current then
		state = "Current"
	elseif tier > current + 1 then
		state = "NeedsPrevious"
	elseif data.Rebirths < truck.RequiresRebirths then
		state = "NeedsRebirth"
	else
		state = "Available"
	end
	return {
		State = state,
		Cost = truck.Cost,
		CanBuy = state == "Available" and data.Coins >= truck.Cost,
	}
end

-- True if anything in the Truck Garage can be bought right now (for the HUD dot).
function ShopRules.hasAffordable(data: PlayerData): boolean
	for statId in Upgrades do
		if ShopRules.upgradeStatus(data, statId).CanBuy then
			return true
		end
	end
	local nextTier = data.Truck.Tier + 1
	return Trucks[nextTier] ~= nil and ShopRules.truckStatus(data, nextTier).CanBuy
end

return ShopRules
