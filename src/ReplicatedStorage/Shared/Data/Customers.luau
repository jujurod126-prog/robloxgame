--!strict
--[[
	Customer types
	CustomerService (Stage 2+) picks a type by SpawnWeight, multiplied by
	TimeOfDayWeights for the current time of day (and the neighborhood's
	RareCustomerMultiplier for Influencer / VIP). Types whose MinReputation is
	above the player's star rating never spawn.
]]

local Shared = script.Parent.Parent
local GameData = require(Shared.Types.GameData)
local TableUtil = require(Shared.Modules.TableUtil)

local Customers: { [string]: GameData.CustomerDef } = {
	Regular = {
		Id = "Regular",
		Order = 1,
		DisplayName = "Regular",
		SpawnWeight = 60,
		MinReputation = 0,
		PayMultiplier = 1,
		TipMultiplier = 1,
		PatienceSeconds = 30,
		ReputationBonus = 0,
		MaxScoops = 2,
		ToppingChance = 0.3,
		PreferredToppings = nil,
		MinFlavorRarity = nil,
		DemandsRarity = nil,
		TimeOfDayWeights = { Day = 1, Sunset = 1, Night = 1 },
		GivesCollectible = false,
		CameraFlash = false,
	},
	Kid = {
		Id = "Kid",
		Order = 2,
		DisplayName = "Kid",
		SpawnWeight = 22,
		MinReputation = 0,
		PayMultiplier = 0.7,
		TipMultiplier = 0.5,
		PatienceSeconds = 18,
		ReputationBonus = 0,
		MaxScoops = 1,
		ToppingChance = 0.8,
		PreferredToppings = { "Sprinkles" },
		MinFlavorRarity = nil,
		DemandsRarity = nil,
		TimeOfDayWeights = { Day = 1.6, Sunset = 0.8, Night = 0.3 },
		GivesCollectible = false,
		CameraFlash = false,
	},
	Tourist = {
		Id = "Tourist",
		Order = 3,
		DisplayName = "Tourist",
		SpawnWeight = 12,
		MinReputation = 3.5,
		PayMultiplier = 1.4,
		TipMultiplier = 2,
		PatienceSeconds = 45,
		ReputationBonus = 0.01,
		MaxScoops = 3,
		ToppingChance = 0.4,
		PreferredToppings = nil,
		MinFlavorRarity = nil,
		DemandsRarity = nil,
		TimeOfDayWeights = { Day = 0.8, Sunset = 2, Night = 1 },
		GivesCollectible = false,
		CameraFlash = false,
	},
	Influencer = {
		Id = "Influencer",
		Order = 4,
		DisplayName = "Influencer",
		SpawnWeight = 5,
		MinReputation = 4,
		PayMultiplier = 3,
		TipMultiplier = 1.5,
		PatienceSeconds = 30,
		ReputationBonus = 0.1,
		MaxScoops = 2,
		ToppingChance = 0.6,
		PreferredToppings = nil,
		MinFlavorRarity = "Rare",
		DemandsRarity = nil,
		TimeOfDayWeights = { Day = 1, Sunset = 1.3, Night = 0.8 },
		GivesCollectible = false,
		CameraFlash = true,
	},
	VIP = {
		Id = "VIP",
		Order = 5,
		DisplayName = "VIP Critic",
		SpawnWeight = 1,
		MinReputation = 4.5,
		PayMultiplier = 8,
		TipMultiplier = 3,
		PatienceSeconds = 60,
		ReputationBonus = 0.2,
		MaxScoops = 3,
		ToppingChance = 1,
		PreferredToppings = nil,
		MinFlavorRarity = nil,
		DemandsRarity = "Legendary", -- only spawns once the player owns a Legendary flavor
		TimeOfDayWeights = { Day = 1, Sunset = 1, Night = 1.5 },
		GivesCollectible = true,
		CameraFlash = true,
	},
}

return TableUtil.defineData("Customers", Customers)
