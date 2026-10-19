--!strict
--[[
	Truck stat upgrades (levels 1 - 10)
	Cost to buy the NEXT level comes from Modules/Formulas.upgradeCost:
	    BaseCost * CostGrowth ^ (currentLevel - 1)
	Values[level] is the stat at that level. Keep Values the same length as MaxLevel.
	docs/BALANCE.md shows time-to-afford for these numbers; update it when tuning.
]]

local Shared = script.Parent.Parent
local GameData = require(Shared.Types.GameData)
local TableUtil = require(Shared.Modules.TableUtil)

local Upgrades: { [string]: GameData.UpgradeDef } = {
	ScoopSpeed = {
		Id = "ScoopSpeed",
		Order = 1,
		DisplayName = "Scoop Speed",
		Description = "Seconds to scoop one scoop. Lower is faster.",
		MaxLevel = 10,
		BaseCost = 25,
		CostGrowth = 1.6,
		Values = { 1.0, 0.9, 0.8, 0.72, 0.65, 0.58, 0.52, 0.47, 0.42, 0.38 },
		ValueFormat = "Seconds",
		Icon = "UpgradeScoopSpeed",
	},
	MoveSpeed = {
		Id = "MoveSpeed",
		Order = 2,
		DisplayName = "Move Speed",
		Description = "How fast you walk and drive.",
		MaxLevel = 10,
		BaseCost = 40,
		CostGrowth = 1.55,
		Values = { 16, 17, 18, 19, 20, 21, 22, 23, 24, 26 }, -- Humanoid.WalkSpeed
		ValueFormat = "Number",
		Icon = "UpgradeMoveSpeed",
	},
	Storage = {
		Id = "Storage",
		Order = 3,
		DisplayName = "Storage",
		Description = "Scoops your cone can hold at once.",
		MaxLevel = 10,
		BaseCost = 60,
		CostGrowth = 1.7,
		Values = { 1, 2, 2, 3, 3, 4, 4, 5, 5, 6 },
		ValueFormat = "Number",
		Icon = "UpgradeStorage",
	},
	TipBonus = {
		Id = "TipBonus",
		Order = 4,
		DisplayName = "Tip Bonus",
		Description = "Extra tips from happy customers.",
		MaxLevel = 10,
		BaseCost = 100,
		CostGrowth = 1.5,
		Values = { 0, 0.05, 0.1, 0.15, 0.2, 0.27, 0.34, 0.42, 0.5, 0.6 },
		ValueFormat = "Percent",
		Icon = "UpgradeTipBonus",
	},
	ServingCapacity = {
		Id = "ServingCapacity",
		Order = 5,
		DisplayName = "Serving Capacity",
		Description = "Extra customers you can serve at the same time.",
		MaxLevel = 10,
		BaseCost = 150,
		CostGrowth = 1.8,
		Values = { 0, 1, 1, 2, 2, 3, 3, 4, 4, 5 }, -- added to the truck's BaseServingCapacity
		ValueFormat = "Bonus",
		Icon = "UpgradeServingCapacity",
	},
}

for id, upgrade in Upgrades do
	assert(#upgrade.Values == upgrade.MaxLevel, `[Upgrades] {id} needs {upgrade.MaxLevel} Values`)
end

return TableUtil.defineData("Upgrades", Upgrades)
