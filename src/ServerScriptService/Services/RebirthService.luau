--!strict
--[[
	RebirthService
	Rebirth and the Rebirth Token skill tree.

	Rebirth():
	  needs Coins >= RebirthRules.requirement (2.5M, then x1.5 each time)
	  RESETS Coins (to the Starting Coins skill value), truck tier and stat upgrades
	  KEEPS flavors, toppings, neighborhoods, pets, Gems, Tokens, cosmetics, settings
	  GIVES +1 Rebirth (permanent +25% Coins each) and Rebirth Token(s)
	BuySkill(skillId): spend Tokens on the next level (prerequisites checked)

	Skill effects live where they apply: Faster Customers (CustomerService), Bigger Tips
	(PlayerStats), Starting Coins (here), Extra Pet Slot (PetRules), Rush Hour (Stage 8).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Modules.Formulas)
local GameConfig = require(Shared.Data.GameConfig)
local NumberFormat = require(Shared.Modules.NumberFormat)
local RebirthRules = require(Shared.Modules.RebirthRules)
local RebirthSkills = require(Shared.Data.RebirthSkills)
local Remotes = require(Shared.Modules.Remotes)
local Upgrades = require(Shared.Data.Upgrades)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

type PurchaseResult = Remotes.PurchaseResult

local RebirthService = {}

local limiter = RateLimiter.fromConfig(GameConfig.RateLimits.Purchase)

local function fail(message: string): PurchaseResult
	return { Ok = false, Message = message }
end

local function rebirth(player: Player): PurchaseResult
	if not limiter:check(player) then
		return fail("Slow down a little!")
	end
	local data = DataService.getData(player)
	if data == nil then
		return fail("Your data is still loading.")
	end
	local requirement = RebirthRules.requirement(data)
	if data.Coins < requirement then
		return fail(`You need {NumberFormat.short(requirement - data.Coins)} more Coins to rebirth.`)
	end

	local newRebirths = data.Rebirths + 1
	local freshUpgrades = {}
	for upgradeId in Upgrades do
		freshUpgrades[upgradeId] = 1
	end

	-- Resets
	DataService.set(player, { "Coins" }, RebirthRules.startingCoins(data))
	DataService.set(player, { "Truck", "Upgrades" }, freshUpgrades)
	DataService.set(player, { "Truck", "Tier" }, 1)
	-- Rewards
	DataService.set(player, { "Rebirths" }, newRebirths)
	DataService.increment(player, { "RebirthTokens" }, GameConfig.Rebirth.TokensPerRebirth)

	local multiplier = Formulas.rebirthCoinMultiplier(newRebirths)
	return {
		Ok = true,
		Message = `Rebirth {newRebirths}! Coins are now x{string.format("%.2f", multiplier)} forever.`,
	}
end

local function buySkill(player: Player, skillId: unknown): PurchaseResult
	if not limiter:check(player) then
		return fail("Slow down a little!")
	end
	if type(skillId) ~= "string" or RebirthSkills[skillId] == nil then
		return fail("That skill doesn't exist.")
	end
	local data = DataService.getData(player)
	if data == nil then
		return fail("Your data is still loading.")
	end
	local id = skillId :: string
	local skill = RebirthSkills[id]
	local status = RebirthRules.skillStatus(data, id)
	if status.State == "Maxed" then
		return fail("Already maxed!")
	elseif status.State == "Locked" then
		local required = skill.Requires :: { SkillId: string, Level: number }
		return fail(`Needs {RebirthSkills[required.SkillId].DisplayName} level {required.Level} first.`)
	end
	local cost = status.Cost :: number
	if not EconomyService.trySpend(player, "RebirthTokens", cost) then
		return fail(`You need {cost} Rebirth Token{if cost == 1 then "" else "s"}.`)
	end
	DataService.set(player, { "Skills", id }, status.Level + 1)
	return { Ok = true, Message = `{skill.DisplayName} is now level {status.Level + 1}!` }
end

function RebirthService.Init() end

function RebirthService.Start()
	Remotes.func("Rebirth").OnServerInvoke = rebirth
	Remotes.func("BuySkill").OnServerInvoke = buySkill
end

return RebirthService
