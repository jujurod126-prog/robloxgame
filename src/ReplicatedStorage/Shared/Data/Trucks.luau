--!strict
--[[
	Trucks
	An ARRAY ordered by tier: Trucks[1] is the Pushcart. PlayerData.Truck.Tier
	is an index into this list. Buying the next tier keeps your stat upgrades.

	Serving capacity actually used = BaseServingCapacity + the Serving Capacity
	upgrade bonus, capped by the neighborhood's CustomerSpots.
]]

local Shared = script.Parent.Parent
local GameData = require(Shared.Types.GameData)
local TableUtil = require(Shared.Modules.TableUtil)

local Trucks: { GameData.TruckDef } = {
	{
		Id = "Pushcart",
		Tier = 1,
		DisplayName = "Pushcart",
		Description = "A humble street-corner cart. Everyone starts somewhere!",
		Cost = 0,
		RequiresRebirths = 0,
		FlavorSlots = 1,
		BaseServingCapacity = 1,
		ScoopSpeedMultiplier = 1,
		MoveSpeedMultiplier = 1,
		TipMultiplier = 1,
		AutoServeBurst = nil,
		Hovers = false,
		AutoCollectTips = false,
		Icon = "TruckPushcart",
	},
	{
		Id = "MiniVan",
		Tier = 2,
		DisplayName = "Mini Van",
		Description = "Two flavor slots and faster scooping.",
		Cost = 1500,
		RequiresRebirths = 0,
		FlavorSlots = 2,
		BaseServingCapacity = 1,
		ScoopSpeedMultiplier = 1.15,
		MoveSpeedMultiplier = 1,
		TipMultiplier = 1,
		AutoServeBurst = nil,
		Hovers = false,
		AutoCollectTips = false,
		Icon = "TruckMiniVan",
	},
	{
		Id = "ClassicTruck",
		Tier = 3,
		DisplayName = "Classic Truck",
		Description = "A real ice cream truck with a menu board and a little speed boost.",
		Cost = 20000,
		RequiresRebirths = 0,
		FlavorSlots = 3,
		BaseServingCapacity = 2,
		ScoopSpeedMultiplier = 1.2,
		MoveSpeedMultiplier = 1.05,
		TipMultiplier = 1,
		AutoServeBurst = nil,
		Hovers = false,
		AutoCollectTips = false,
		Icon = "TruckClassic",
	},
	{
		Id = "DeluxeTruck",
		Tier = 4,
		DisplayName = "Deluxe Truck",
		Description = "Four slots and an auto-serve burst every minute.",
		Cost = 200000,
		RequiresRebirths = 0,
		FlavorSlots = 4,
		BaseServingCapacity = 2,
		ScoopSpeedMultiplier = 1.3,
		MoveSpeedMultiplier = 1.1,
		TipMultiplier = 1.1,
		AutoServeBurst = { Duration = 5, Interval = 60 },
		Hovers = false,
		AutoCollectTips = false,
		Icon = "TruckDeluxe",
	},
	{
		Id = "RocketTruck",
		Tier = 5,
		DisplayName = "Rocket Truck",
		Description = "Five slots, blazing speed, and huge tips.",
		Cost = 1500000,
		RequiresRebirths = 0,
		FlavorSlots = 5,
		BaseServingCapacity = 3,
		ScoopSpeedMultiplier = 1.4,
		MoveSpeedMultiplier = 1.4,
		TipMultiplier = 1.5,
		AutoServeBurst = { Duration = 6, Interval = 60 },
		Hovers = false,
		AutoCollectTips = false,
		Icon = "TruckRocket",
	},
	{
		Id = "UfoTruck",
		Tier = 6,
		DisplayName = "UFO Truck",
		Description = "Rebirth reward. Six slots, hovers, and collects tips for you.",
		Cost = 6000000,
		RequiresRebirths = 1,
		FlavorSlots = 6,
		BaseServingCapacity = 4,
		ScoopSpeedMultiplier = 1.5,
		MoveSpeedMultiplier = 1.5,
		TipMultiplier = 1.75,
		AutoServeBurst = { Duration = 8, Interval = 60 },
		Hovers = true,
		AutoCollectTips = true,
		Icon = "TruckUfo",
	},
}

for tier, truck in Trucks do
	assert(truck.Tier == tier, `[Trucks] entry {tier} ({truck.Id}) has Tier {truck.Tier}`)
end

return TableUtil.deepFreeze(Trucks)
