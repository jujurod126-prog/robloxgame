--!strict
--[[
	CustomerPicker
	Chooses which type of customer walks up next, for one player in one neighborhood.

	A type can appear only if:
	  * the player's Reputation is at least its MinReputation (stars unlock better customers)
	  * the truck can make what it wants (Influencers need a Rare+ flavor loaded,
	    VIP Critics need a flavor of the exact DemandsRarity loaded)
	Its chance is SpawnWeight x the time-of-day weight x the neighborhood's
	RareCustomerMultiplier (for Influencers and VIPs).
	Time of day comes from the Workspace attribute "TimeOfDay" (set in Stage 8, "Day" until then).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Customers = require(Shared.Data.Customers)
local Flavors = require(Shared.Data.Flavors)
local GameData = require(Shared.Types.GameData)
local PlayerDataTypes = require(Shared.Types.PlayerData)
local PlayerStats = require(Shared.Modules.PlayerStats)
local Rarities = require(Shared.Data.Rarities)
local TableUtil = require(Shared.Modules.TableUtil)

type PlayerData = PlayerDataTypes.PlayerData

local CustomerPicker = {}

local random = Random.new()

-- Influencers and VIPs: rarer, and boosted in fancier neighborhoods.
function CustomerPicker.isRare(customer: GameData.CustomerDef): boolean
	return customer.DemandsRarity ~= nil or customer.MinFlavorRarity ~= nil
end

local function truckCanServe(data: PlayerData, customer: GameData.CustomerDef): boolean
	if customer.DemandsRarity == nil and customer.MinFlavorRarity == nil then
		return true
	end
	for _, flavorId in PlayerStats.loadout(data) do
		local rarity = Flavors[flavorId].Rarity
		if customer.DemandsRarity and rarity == customer.DemandsRarity then
			return true
		end
		if customer.MinFlavorRarity and Rarities[rarity].Order >= Rarities[customer.MinFlavorRarity].Order then
			return true
		end
	end
	return false
end

function CustomerPicker.pick(data: PlayerData, area: GameData.NeighborhoodDef): GameData.CustomerDef
	local timeOfDay = (Workspace:GetAttribute("TimeOfDay") :: string?) or "Day"
	local options: { GameData.CustomerDef } = {}
	local weights: { number } = {}
	local total = 0
	for _, customer in TableUtil.sortedByOrder(Customers) do
		if data.Reputation >= customer.MinReputation and truckCanServe(data, customer) then
			local weight = customer.SpawnWeight * ((customer.TimeOfDayWeights :: any)[timeOfDay] or 1)
			if CustomerPicker.isRare(customer) then
				weight *= area.RareCustomerMultiplier
			end
			table.insert(options, customer)
			table.insert(weights, weight)
			total += weight
		end
	end
	local roll = random:NextNumber() * total
	for index, customer in options do
		roll -= weights[index]
		if roll <= 0 then
			return customer
		end
	end
	return Customers.Regular
end

return CustomerPicker
