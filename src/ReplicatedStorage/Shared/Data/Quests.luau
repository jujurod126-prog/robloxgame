--!strict
--[[
	Daily quest pool
	Every UTC day each player gets GameConfig.Quests.PerDay quests picked from
	this pool, each with one difficulty tier rolled (Targets[i] -> Rewards[i]).
	Stat names are the events QuestService listens for:
	  Count quests add up during the day, Peak quests track the best value.
]]

local Shared = script.Parent.Parent
local GameData = require(Shared.Types.GameData)
local TableUtil = require(Shared.Modules.TableUtil)

local Quests: { [string]: GameData.QuestDef } = {
	ServeCustomers = {
		Id = "ServeCustomers",
		Order = 1,
		DescriptionTemplate = "Serve {target} customers",
		Kind = "Count",
		Stat = "CustomersServed",
		Targets = { 15, 30, 60 },
		Rewards = { { Coins = 150, Gems = 5 }, { Coins = 500, Gems = 10 }, { Coins = 1500, Gems = 20 } },
	},
	ReachCombo = {
		Id = "ReachCombo",
		Order = 2,
		DescriptionTemplate = "Reach a combo of {target}",
		Kind = "Peak",
		Stat = "Combo",
		Targets = { 5, 10, 20 },
		Rewards = { { Gems = 5 }, { Gems = 10 }, { Gems = 25 } },
	},
	ScoopScoops = {
		Id = "ScoopScoops",
		Order = 3,
		DescriptionTemplate = "Scoop {target} scoops of ice cream",
		Kind = "Count",
		Stat = "ScoopsMade",
		Targets = { 30, 60, 120 },
		Rewards = { { Coins = 200 }, { Coins = 600, Gems = 5 }, { Coins = 2000, Gems = 15 } },
	},
	PerfectOrders = {
		Id = "PerfectOrders",
		Order = 4,
		DescriptionTemplate = "Serve {target} perfect orders",
		Kind = "Count",
		Stat = "PerfectOrders",
		Targets = { 10, 25, 50 },
		Rewards = { { Coins = 200, Gems = 5 }, { Coins = 750, Gems = 10 }, { Coins = 2500, Gems = 20 } },
	},
	EarnCoins = {
		Id = "EarnCoins",
		Order = 5,
		DescriptionTemplate = "Earn {target} Coins",
		Kind = "Count",
		Stat = "CoinsEarned",
		Targets = { 500, 2500, 10000 },
		Rewards = { { Gems = 5 }, { Gems = 10 }, { Gems = 20 } },
	},
}

for id, quest in Quests do
	assert(#quest.Targets == #quest.Rewards, `[Quests] {id} needs one reward per target`)
end

return TableUtil.defineData("Quests", Quests)
