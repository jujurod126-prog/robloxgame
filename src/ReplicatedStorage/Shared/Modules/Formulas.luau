--!strict
--[[
	Formulas
	Every balance calculation lives here so server and UI always agree.
	The server uses these to charge and reward; the client only to display.
]]

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Data.GameConfig)
local GameData = require(Shared.Types.GameData)
local Upgrades = require(Shared.Data.Upgrades)

local Formulas = {}

--[[
	Coins to buy the next level of a stat upgrade.
	currentLevel is the level the player has now (1 = never upgraded).
	Returns nil when the stat is already maxed.
]]
function Formulas.upgradeCost(statId: string, currentLevel: number): number?
	local upgrade = Upgrades[statId]
	assert(upgrade, `Unknown upgrade {statId}`)
	if currentLevel >= upgrade.MaxLevel then
		return nil
	end
	return math.floor(upgrade.BaseCost * upgrade.CostGrowth ^ (currentLevel - 1) + 0.5)
end

-- The stat's value at a level (clamped to 1..MaxLevel).
function Formulas.upgradeValue(statId: string, level: number): number
	local upgrade = Upgrades[statId]
	assert(upgrade, `Unknown upgrade {statId}`)
	return upgrade.Values[math.clamp(level, 1, upgrade.MaxLevel)]
end

export type OrderPayoutInput = {
	ScoopValue: number, -- sum of CoinValue for every scoop in the order
	Customer: GameData.CustomerDef,
	Neighborhood: GameData.NeighborhoodDef,
	Truck: GameData.TruckDef,
	TipBonus: number, -- from the Tip Bonus upgrade (0.1 = +10%)
	PatienceFraction: number, -- 1 = served instantly, 0 = at the last second
	Correct: boolean,
}

--[[
	Coins for one served order, BEFORE the player's global multipliers
	(rebirths, pets, passes - applied by EconomyService.awardCoins).
	Returns base, tip. Wrong orders pay a fraction of base and no tip.
]]
function Formulas.orderPayout(input: OrderPayoutInput): (number, number)
	local base = input.ScoopValue * input.Customer.PayMultiplier * input.Neighborhood.PayMultiplier
	if not input.Correct then
		return base * GameConfig.Orders.WrongOrderPayFraction, 0
	end
	local tip = base
		* GameConfig.Orders.MaxTipFraction
		* math.clamp(input.PatienceFraction, 0, 1)
		* input.Customer.TipMultiplier
		* input.Truck.TipMultiplier
		* input.Neighborhood.TipMultiplier
		* (1 + input.TipBonus)
	return base, tip
end

-- Coin multiplier from the combo meter. streak = correct orders in a row.
function Formulas.comboMultiplier(streak: number): number
	local config = GameConfig.Combo
	if streak < config.StartsAt then
		return 1
	end
	local steps = streak - config.StartsAt + 1
	return math.min(1 + steps * config.StepMultiplier, config.MaxMultiplier)
end

-- Coins needed to rebirth when the player has already rebirthed `rebirths` times.
function Formulas.rebirthRequirement(rebirths: number): number
	local config = GameConfig.Rebirth
	return math.floor(config.BaseRequirement * config.RequirementGrowth ^ rebirths + 0.5)
end

-- Permanent Coin multiplier from rebirths (1 rebirth = x1.25 by default).
function Formulas.rebirthCoinMultiplier(rebirths: number): number
	return 1 + rebirths * GameConfig.Rebirth.CoinMultiplierPerRebirth
end

-- Egg odds as percentages for the UI, in the same order as the egg's Odds list.
function Formulas.eggOddsPercent(egg: GameData.EggDef): { { PetId: string, Percent: number } }
	local total = 0
	for _, entry in egg.Odds do
		total += entry.Weight
	end
	local result = {}
	for _, entry in egg.Odds do
		table.insert(result, { PetId = entry.PetId, Percent = entry.Weight / total * 100 })
	end
	return result
end

return Formulas
