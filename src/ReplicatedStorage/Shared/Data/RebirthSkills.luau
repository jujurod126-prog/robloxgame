--!strict
--[[
	Rebirth skill tree (bought with Rebirth Tokens)
	Values[level] is the total effect at that level. Requires = another skill
	that must reach a level first (this is what makes it a tree).
]]

local Shared = script.Parent.Parent
local Assets = require(Shared.Modules.Assets)
local GameData = require(Shared.Types.GameData)
local TableUtil = require(Shared.Modules.TableUtil)

local RebirthSkills: { [string]: GameData.SkillDef } = {
	FasterCustomers = {
		Id = "FasterCustomers",
		Order = 1,
		DisplayName = "Faster Customers",
		Description = "Customers arrive more often.",
		MaxLevel = 5,
		Costs = { 1, 1, 2, 2, 3 },
		Values = { 0.1, 0.2, 0.3, 0.4, 0.5 }, -- +% spawn rate
		Requires = nil,
		Icon = Assets.ICON_SKILL_FASTER_CUSTOMERS,
	},
	StartingCoins = {
		Id = "StartingCoins",
		Order = 2,
		DisplayName = "Starting Coins",
		Description = "Start each rebirth with Coins in your pocket.",
		MaxLevel = 5,
		Costs = { 1, 1, 2, 2, 3 },
		Values = { 500, 2500, 10000, 50000, 250000 }, -- Coins
		Requires = nil,
		Icon = Assets.ICON_SKILL_STARTING_COINS,
	},
	BiggerTips = {
		Id = "BiggerTips",
		Order = 3,
		DisplayName = "Bigger Tips",
		Description = "Every tip is bigger.",
		MaxLevel = 5,
		Costs = { 1, 2, 2, 3, 3 },
		Values = { 0.1, 0.2, 0.3, 0.4, 0.5 }, -- +% tips
		Requires = { SkillId = "FasterCustomers", Level = 1 },
		Icon = Assets.ICON_SKILL_BIGGER_TIPS,
	},
	RushHourDuration = {
		Id = "RushHourDuration",
		Order = 4,
		DisplayName = "Longer Rush Hour",
		Description = "Rush Hour lasts longer.",
		MaxLevel = 5,
		Costs = { 1, 2, 2, 3, 3 },
		Values = { 10, 20, 30, 40, 50 }, -- extra seconds
		Requires = { SkillId = "FasterCustomers", Level = 2 },
		Icon = Assets.ICON_SKILL_RUSH_HOUR_DURATION,
	},
	ExtraPetSlot = {
		Id = "ExtraPetSlot",
		Order = 5,
		DisplayName = "Extra Pet Slot",
		Description = "Equip more pets at once.",
		MaxLevel = 2,
		Costs = { 3, 5 },
		Values = { 1, 2 }, -- extra equip slots
		Requires = { SkillId = "StartingCoins", Level = 2 },
		Icon = Assets.ICON_SKILL_EXTRA_PET_SLOT,
	},
}

for id, skill in RebirthSkills do
	assert(
		#skill.Costs == skill.MaxLevel and #skill.Values == skill.MaxLevel,
		`[RebirthSkills] {id} Costs/Values length`
	)
end

return TableUtil.defineData("RebirthSkills", RebirthSkills)
