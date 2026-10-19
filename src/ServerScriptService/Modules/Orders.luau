--!strict
--[[
	Orders
	Creating customer orders and checking served cones against them.

	An order is one flavor, a number of scoops, and optionally one topping:
	  * flavors come from the player's truck loadout (what they can actually make),
	    weighted toward the neighborhood's favorite tags and the customer's rarity taste
	  * toppings come from the player's unlocked toppings (customer favorites first)
	  * scoops never exceed the player's cone capacity
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Flavors = require(Shared.Data.Flavors)
local GameData = require(Shared.Types.GameData)
local PlayerDataTypes = require(Shared.Types.PlayerData)
local PlayerStats = require(Shared.Modules.PlayerStats)
local Rarities = require(Shared.Data.Rarities)
local Toppings = require(Shared.Data.Toppings)

type PlayerData = PlayerDataTypes.PlayerData

export type Order = { FlavorId: string, Scoops: number, ToppingId: string? }
export type Cone = { Scoops: { string }, Topping: string? }

local PREFERRED_WEIGHT = 2 -- favorite tags are this many times more likely

local Orders = {}

local random = Random.new()

local function hasAnyTag(tags: { string }, wanted: { string }): boolean
	for _, tag in tags do
		if table.find(wanted, tag) then
			return true
		end
	end
	return false
end

local function pickWeighted<T>(options: { T }, weightOf: (T) -> number): T
	local total = 0
	for _, option in options do
		total += weightOf(option)
	end
	local roll = random:NextNumber() * total
	for _, option in options do
		roll -= weightOf(option)
		if roll <= 0 then
			return option
		end
	end
	return options[#options]
end

local function pickFlavor(data: PlayerData, customer: GameData.CustomerDef, area: GameData.NeighborhoodDef): string
	local options = PlayerStats.loadout(data)
	if customer.DemandsRarity then
		-- VIP Critics only accept one rarity (CustomerPicker makes sure the truck has one).
		local demanded = {}
		for _, flavorId in options do
			if Flavors[flavorId].Rarity == customer.DemandsRarity then
				table.insert(demanded, flavorId)
			end
		end
		if #demanded > 0 then
			options = demanded
		end
	elseif customer.MinFlavorRarity then
		local minOrder = Rarities[customer.MinFlavorRarity].Order
		local fancy = {}
		for _, flavorId in options do
			if Rarities[Flavors[flavorId].Rarity].Order >= minOrder then
				table.insert(fancy, flavorId)
			end
		end
		if #fancy > 0 then
			options = fancy
		end
	end
	return pickWeighted(options, function(flavorId: string)
		return if hasAnyTag(Flavors[flavorId].Tags, area.PreferredFlavorTags) then PREFERRED_WEIGHT else 1
	end)
end

local function pickTopping(data: PlayerData, customer: GameData.CustomerDef, area: GameData.NeighborhoodDef): string?
	if random:NextNumber() >= customer.ToppingChance then
		return nil
	end
	local owned: { string } = {}
	for toppingId in Toppings do
		if data.Toppings.Unlocked[toppingId] then
			table.insert(owned, toppingId)
		end
	end
	if #owned == 0 then
		return nil
	end
	table.sort(owned) -- deterministic order before the weighted pick
	if customer.PreferredToppings then
		local favorites = {}
		for _, toppingId in customer.PreferredToppings do
			if table.find(owned, toppingId) then
				table.insert(favorites, toppingId)
			end
		end
		if #favorites > 0 then
			return favorites[random:NextInteger(1, #favorites)]
		end
	end
	return pickWeighted(owned, function(toppingId: string)
		return if hasAnyTag(Toppings[toppingId].Tags, area.PreferredToppingTags) then PREFERRED_WEIGHT else 1
	end)
end

function Orders.create(data: PlayerData, customer: GameData.CustomerDef, area: GameData.NeighborhoodDef): Order
	local maxScoops = math.min(customer.MaxScoops, PlayerStats.coneCapacity(data))
	return {
		FlavorId = pickFlavor(data, customer, area),
		Scoops = random:NextInteger(1, maxScoops),
		ToppingId = pickTopping(data, customer, area),
	}
end

-- Exact match: same scoop count, every scoop the ordered flavor, and the same topping (or none).
function Orders.isCorrect(order: Order, cone: Cone): boolean
	if #cone.Scoops ~= order.Scoops or cone.Topping ~= order.ToppingId then
		return false
	end
	for _, flavorId in cone.Scoops do
		if flavorId ~= order.FlavorId then
			return false
		end
	end
	return true
end

-- True if the order matches what the neighborhood likes (flavor or topping tags).
function Orders.matchesPreference(order: Order, area: GameData.NeighborhoodDef): boolean
	if hasAnyTag(Flavors[order.FlavorId].Tags, area.PreferredFlavorTags) then
		return true
	end
	return order.ToppingId ~= nil and hasAnyTag(Toppings[order.ToppingId].Tags, area.PreferredToppingTags)
end

return Orders
