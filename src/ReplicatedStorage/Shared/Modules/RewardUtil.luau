--!strict
--[[
	RewardUtil
	Display text for a Reward bundle (quests, daily login, achievements).
	  RewardUtil.describe({ Coins = 500, Gems = 10 }) -> "500 Coins + 10 Gems"
]]

local Shared = script.Parent.Parent
local Eggs = require(Shared.Data.Eggs)
local GameData = require(Shared.Types.GameData)
local NumberFormat = require(script.Parent.NumberFormat)

local RewardUtil = {}

function RewardUtil.describe(reward: GameData.Reward): string
	local parts = {}
	if reward.Coins then
		table.insert(parts, `{NumberFormat.short(reward.Coins)} Coins`)
	end
	if reward.Gems then
		table.insert(parts, `{NumberFormat.short(reward.Gems)} Gems`)
	end
	if reward.RebirthTokens then
		table.insert(parts, `{reward.RebirthTokens} Token{if reward.RebirthTokens == 1 then "" else "s"}`)
	end
	if reward.EggId and Eggs[reward.EggId] then
		table.insert(parts, Eggs[reward.EggId].DisplayName)
	end
	return table.concat(parts, " + ")
end

return RewardUtil
