--!strict
--[[
	RebirthRules
	Rebirth requirement and the Rebirth Token skill tree. The server validates
	with these and the UI displays with the same functions.
]]

local Shared = script.Parent.Parent
local Formulas = require(script.Parent.Formulas)
local GameConfig = require(Shared.Data.GameConfig)
local NumberFormat = require(script.Parent.NumberFormat)
local PlayerDataTypes = require(Shared.Types.PlayerData)
local RebirthSkills = require(Shared.Data.RebirthSkills)

type PlayerData = PlayerDataTypes.PlayerData

export type SkillState =
	"Maxed"
	| "Available" -- next level can be bought (may still be unaffordable)
	| "Locked" -- needs another skill first

export type SkillStatus = {
	State: SkillState,
	Level: number,
	MaxLevel: number,
	Cost: number?, -- Rebirth Tokens for the next level (nil when maxed)
	CanBuy: boolean,
}

-- What stays and what resets, for the Rebirth window.
local RebirthRules = {
	RESETS = { "Coins", "Truck tier", "Truck upgrades" },
	KEEPS = { "Flavors and toppings", "Neighborhoods", "Pets", "Gems", "Rebirth Tokens", "Cosmetics and settings" },
}

function RebirthRules.requirement(data: PlayerData): number
	return Formulas.rebirthRequirement(data.Rebirths)
end

function RebirthRules.canRebirth(data: PlayerData): boolean
	return data.Coins >= RebirthRules.requirement(data)
end

-- The current total effect of a skill (0 if not bought).
function RebirthRules.skillValue(data: PlayerData, skillId: string): number
	local skill = RebirthSkills[skillId]
	local level = data.Skills[skillId] or 0
	return if skill and level > 0 then skill.Values[math.min(level, skill.MaxLevel)] else 0
end

-- Coins you start with after a rebirth.
function RebirthRules.startingCoins(data: PlayerData): number
	return math.max(GameConfig.Starting.Coins, RebirthRules.skillValue(data, "StartingCoins"))
end

-- skillId must be a key of Shared/Data/RebirthSkills.
function RebirthRules.skillStatus(data: PlayerData, skillId: string): SkillStatus
	local skill = RebirthSkills[skillId]
	assert(skill, `Unknown skill {skillId}`)
	local level = data.Skills[skillId] or 0
	local state: SkillState
	if level >= skill.MaxLevel then
		state = "Maxed"
	elseif skill.Requires and (data.Skills[skill.Requires.SkillId] or 0) < skill.Requires.Level then
		state = "Locked"
	else
		state = "Available"
	end
	local cost = if state == "Maxed" then nil else skill.Costs[level + 1]
	return {
		State = state,
		Level = level,
		MaxLevel = skill.MaxLevel,
		Cost = cost,
		CanBuy = state == "Available" and cost ~= nil and data.RebirthTokens >= cost,
	}
end

-- How a skill's value reads in the UI: "+20% customers", "2.5K Coins"...
function RebirthRules.describeValue(skillId: string, value: number): string
	if skillId == "FasterCustomers" then
		return `+{math.floor(value * 100 + 0.5)}% customers`
	elseif skillId == "BiggerTips" then
		return `+{math.floor(value * 100 + 0.5)}% tips`
	elseif skillId == "StartingCoins" then
		return `{NumberFormat.short(value)} Coins`
	elseif skillId == "ExtraPetSlot" then
		return `+{value} pet slot{if value == 1 then "" else "s"}`
	elseif skillId == "RushHourDuration" then
		return `+{value}s Rush Hour`
	end
	return tostring(value)
end

function RebirthRules.hasSomethingToDo(data: PlayerData): boolean
	if RebirthRules.canRebirth(data) then
		return true
	end
	for skillId in RebirthSkills do
		if RebirthRules.skillStatus(data, skillId).CanBuy then
			return true
		end
	end
	return false
end

return RebirthRules
