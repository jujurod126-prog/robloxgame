--!strict
--[[
	7-day login calendar. Day 7 is the big one; after it the streak loops to day 1.
	Claim timing rules are in GameConfig.Daily.
]]

local Shared = script.Parent.Parent
local GameData = require(Shared.Types.GameData)
local TableUtil = require(Shared.Modules.TableUtil)

local DailyRewards: { GameData.DailyRewardDef } = {
	{ Day = 1, Reward = { Coins = 100 } },
	{ Day = 2, Reward = { Gems = 5 } },
	{ Day = 3, Reward = { Coins = 500 } },
	{ Day = 4, Reward = { Gems = 10 } },
	{ Day = 5, Reward = { Coins = 1500 } },
	{ Day = 6, Reward = { Gems = 20 } },
	{ Day = 7, Reward = { Gems = 50, EggId = "Rainbow" } },
}

return TableUtil.deepFreeze(DailyRewards)
