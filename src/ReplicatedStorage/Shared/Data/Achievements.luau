--!strict
--[[
	Achievements
	Unlocked when a lifetime stat (PlayerData.Stats.<Stat>, or "Rebirths")
	reaches Target. Each awards a Roblox badge (BadgeId from Modules/Assets).
]]

local Shared = script.Parent.Parent
local Assets = require(Shared.Modules.Assets)
local GameData = require(Shared.Types.GameData)
local TableUtil = require(Shared.Modules.TableUtil)

local Achievements: { [string]: GameData.AchievementDef } = {
	FirstCustomer = {
		Id = "FirstCustomer",
		Order = 1,
		DisplayName = "Open for Business",
		Description = "Serve your first customer.",
		Stat = "CustomersServed",
		Target = 1,
		Reward = { Gems = 5 },
		BadgeId = Assets.BADGE_FIRST_CUSTOMER,
	},
	Served100 = {
		Id = "Served100",
		Order = 2,
		DisplayName = "Neighborhood Favorite",
		Description = "Serve 100 customers.",
		Stat = "CustomersServed",
		Target = 100,
		Reward = { Gems = 15 },
		BadgeId = Assets.BADGE_SERVED_100,
	},
	Served1000 = {
		Id = "Served1000",
		Order = 3,
		DisplayName = "Town Legend",
		Description = "Serve 1,000 customers.",
		Stat = "CustomersServed",
		Target = 1000,
		Reward = { Gems = 50 },
		BadgeId = Assets.BADGE_SERVED_1000,
	},
	Combo25 = {
		Id = "Combo25",
		Order = 4,
		DisplayName = "On a Roll",
		Description = "Reach a 25 combo.",
		Stat = "HighestCombo",
		Target = 25,
		Reward = { Gems = 25 },
		BadgeId = Assets.BADGE_COMBO_25,
	},
	FirstRebirth = {
		Id = "FirstRebirth",
		Order = 5,
		DisplayName = "Born Again Sweet",
		Description = "Rebirth for the first time.",
		Stat = "Rebirths",
		Target = 1,
		Reward = { Gems = 50 },
		BadgeId = Assets.BADGE_FIRST_REBIRTH,
	},
	Hatch10 = {
		Id = "Hatch10",
		Order = 6,
		DisplayName = "Egg Enthusiast",
		Description = "Hatch 10 eggs.",
		Stat = "EggsHatched",
		Target = 10,
		Reward = { Gems = 15 },
		BadgeId = Assets.BADGE_HATCH_10,
	},
	Millionaire = {
		Id = "Millionaire",
		Order = 7,
		DisplayName = "Ice Cream Millionaire",
		Description = "Earn 1,000,000 Coins in total.",
		Stat = "CoinsEarnedTotal",
		Target = 1000000,
		Reward = { Gems = 75 },
		BadgeId = Assets.BADGE_MILLIONAIRE,
	},
	GoldenHunter = {
		Id = "GoldenHunter",
		Order = 8,
		DisplayName = "Golden Hunter",
		Description = "Find 10 golden sprinkles.",
		Stat = "GoldenSprinklesFound",
		Target = 10,
		Reward = { Gems = 40 },
		BadgeId = Assets.BADGE_GOLDEN_HUNTER,
	},
}

return TableUtil.defineData("Achievements", Achievements)
