--!strict
--[[
	FlavorRules
	What a player can unlock in the Flavor Lab and what it costs. Like ShopRules:
	the server validates with these and the UI displays with the same functions.
]]

local Shared = script.Parent.Parent
local Flavors = require(Shared.Data.Flavors)
local PlayerDataTypes = require(Shared.Types.PlayerData)
local PlayerStats = require(script.Parent.PlayerStats)
local Toppings = require(Shared.Data.Toppings)

type PlayerData = PlayerDataTypes.PlayerData

export type FlavorState =
	"Equipped" -- unlocked and loaded in a truck slot
	| "Owned" -- unlocked, not in a slot
	| "Available" -- can be unlocked (may still be unaffordable)
	| "NeedsRebirth" -- needs more rebirths first

export type Status = {
	State: FlavorState,
	Cost: number,
	CanBuy: boolean, -- Available AND affordable
}

local FlavorRules = {}

-- flavorId must be a key of Shared/Data/Flavors.
function FlavorRules.flavorStatus(data: PlayerData, flavorId: string): Status
	local flavor = Flavors[flavorId]
	assert(flavor, `Unknown flavor {flavorId}`)
	local state: FlavorState
	if data.Flavors.Unlocked[flavorId] then
		state = if table.find(PlayerStats.loadout(data), flavorId) then "Equipped" else "Owned"
	elseif data.Rebirths < flavor.RequiresRebirths then
		state = "NeedsRebirth"
	else
		state = "Available"
	end
	return {
		State = state,
		Cost = flavor.UnlockCost,
		CanBuy = state == "Available" and data.Coins >= flavor.UnlockCost,
	}
end

-- toppingId must be a key of Shared/Data/Toppings. Toppings have no rebirth locks.
function FlavorRules.toppingStatus(data: PlayerData, toppingId: string): Status
	local topping = Toppings[toppingId]
	assert(topping, `Unknown topping {toppingId}`)
	local owned = data.Toppings.Unlocked[toppingId] == true
	return {
		State = if owned then "Owned" else "Available",
		Cost = topping.UnlockCost,
		CanBuy = not owned and data.Coins >= topping.UnlockCost,
	}
end

-- True if any flavor or topping can be unlocked right now (for the HUD dot).
function FlavorRules.hasAffordable(data: PlayerData): boolean
	for flavorId in Flavors do
		if FlavorRules.flavorStatus(data, flavorId).CanBuy then
			return true
		end
	end
	for toppingId in Toppings do
		if FlavorRules.toppingStatus(data, toppingId).CanBuy then
			return true
		end
	end
	return false
end

return FlavorRules
