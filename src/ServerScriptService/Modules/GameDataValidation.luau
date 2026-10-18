--!strict
--[[
	GameDataValidation
	Runs once when the server starts and checks that the data modules point at
	each other correctly (e.g. every egg's PetId exists). A typo in a balance
	table fails loudly in Studio's Output instead of breaking mid-game.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = ReplicatedStorage.Shared.Data
local Customers = require(Data.Customers)
local DailyRewards = require(Data.DailyRewards)
local Eggs = require(Data.Eggs)
local Flavors = require(Data.Flavors)
local GameConfig = require(Data.GameConfig)
local Neighborhoods = require(Data.Neighborhoods)
local Pets = require(Data.Pets)
local Rarities = require(Data.Rarities)
local RebirthSkills = require(Data.RebirthSkills)
local Toppings = require(Data.Toppings)

local GameDataValidation = {}

function GameDataValidation.run()
	local problems: { string } = {}
	local function check(condition: any, message: string)
		if not condition then
			table.insert(problems, message)
		end
	end

	for id, flavor in Flavors do
		check(Rarities[flavor.Rarity], `Flavor {id}: unknown rarity {flavor.Rarity}`)
	end
	for id, pet in Pets do
		check(Rarities[pet.Rarity], `Pet {id}: unknown rarity {pet.Rarity}`)
	end
	for id, egg in Eggs do
		check(#egg.Odds > 0, `Egg {id}: has no odds`)
		for _, entry in egg.Odds do
			check(Pets[entry.PetId], `Egg {id}: unknown pet {entry.PetId}`)
			check(entry.Weight > 0, `Egg {id}: weight for {entry.PetId} must be > 0`)
		end
	end
	for id, customer in Customers do
		if customer.PreferredToppings then
			for _, toppingId in customer.PreferredToppings do
				check(Toppings[toppingId], `Customer {id}: unknown topping {toppingId}`)
			end
		end
		if customer.MinFlavorRarity then
			check(Rarities[customer.MinFlavorRarity], `Customer {id}: unknown rarity {customer.MinFlavorRarity}`)
		end
		if customer.DemandsRarity then
			check(Rarities[customer.DemandsRarity], `Customer {id}: unknown rarity {customer.DemandsRarity}`)
		end
	end
	for id, skill in RebirthSkills do
		if skill.Requires then
			check(RebirthSkills[skill.Requires.SkillId], `Skill {id}: requires unknown skill {skill.Requires.SkillId}`)
		end
	end
	for _, day in DailyRewards do
		if day.Reward.EggId then
			check(Eggs[day.Reward.EggId], `Daily reward day {day.Day}: unknown egg {day.Reward.EggId}`)
		end
	end
	check(Flavors[GameConfig.Starting.Flavor], `GameConfig.Starting.Flavor {GameConfig.Starting.Flavor} doesn't exist`)
	check(
		Neighborhoods[GameConfig.Starting.Neighborhood],
		`GameConfig.Starting.Neighborhood {GameConfig.Starting.Neighborhood} doesn't exist`
	)

	if #problems > 0 then
		error("[GameDataValidation] Fix these data problems:\n  " .. table.concat(problems, "\n  "))
	end
end

return GameDataValidation
