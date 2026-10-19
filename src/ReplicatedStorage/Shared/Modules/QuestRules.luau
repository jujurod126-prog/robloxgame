--!strict
--[[
	QuestRules
	Daily quests, the 7-day login reward and achievements: what's claimable and
	when things refresh. Server and UI share these. Times are os.time() seconds
	(clients should pass Workspace:GetServerTimeNow()).
]]

local Shared = script.Parent.Parent
local Achievements = require(Shared.Data.Achievements)
local DailyRewards = require(Shared.Data.DailyRewards)
local GameConfig = require(Shared.Data.GameConfig)
local GameData = require(Shared.Types.GameData)
local PlayerDataTypes = require(Shared.Types.PlayerData)
local Quests = require(Shared.Data.Quests)

type PlayerData = PlayerDataTypes.PlayerData
type DailyQuestState = PlayerDataTypes.DailyQuestState

local DAY = 86400
local HOUR = 3600

local QuestRules = {}

-- ===== Daily quests =====

-- Which UTC day a time falls on; quests re-roll when this changes.
function QuestRules.dayKey(now: number): number
	return now // DAY
end

function QuestRules.secondsUntilReset(now: number): number
	return (QuestRules.dayKey(now) + 1) * DAY - now
end

function QuestRules.target(quest: DailyQuestState): number
	local def = Quests[quest.QuestId]
	return if def then def.Targets[quest.Tier] else 1
end

function QuestRules.description(quest: DailyQuestState): string
	local def = Quests[quest.QuestId]
	if def == nil then
		return "?"
	end
	local text = def.DescriptionTemplate:gsub("{target}", tostring(QuestRules.target(quest)))
	return text
end

local NO_REWARD: GameData.Reward = {}

function QuestRules.reward(quest: DailyQuestState): GameData.Reward
	local def = Quests[quest.QuestId]
	return if def then def.Rewards[quest.Tier] else NO_REWARD
end

function QuestRules.isComplete(quest: DailyQuestState): boolean
	return quest.Progress >= QuestRules.target(quest)
end

function QuestRules.isClaimable(quest: DailyQuestState): boolean
	return not quest.Claimed and QuestRules.isComplete(quest)
end

-- ===== Daily login reward =====

export type DailyStatus = {
	CanClaim: boolean,
	Day: number, -- 1..7, the day the next claim gives
	SecondsUntilClaim: number,
	StreakResets: boolean, -- the streak was missed and starts over at day 1
}

function QuestRules.dailyStatus(data: PlayerData, now: number): DailyStatus
	local last = data.Daily.LastClaimTime
	local elapsed = now - last
	local resets = last > 0 and elapsed > GameConfig.Daily.StreakExpireHours * HOUR
	local streak = if resets then 0 else data.Daily.Streak
	local cooldown = GameConfig.Daily.ClaimCooldownHours * HOUR
	local waiting = if last == 0 then 0 else math.max(0, cooldown - elapsed)
	return {
		CanClaim = waiting <= 0,
		Day = (streak % #DailyRewards) + 1,
		SecondsUntilClaim = waiting,
		StreakResets = resets,
	}
end

-- ===== Achievements =====

-- Current value of the stat an achievement tracks.
function QuestRules.achievementProgress(data: PlayerData, achievementId: string): number
	local def = Achievements[achievementId]
	if def == nil then
		return 0
	end
	if def.Stat == "Rebirths" then
		return data.Rebirths
	end
	return (data.Stats :: any)[def.Stat] or 0
end

function QuestRules.achievementReached(data: PlayerData, achievementId: string): boolean
	local def = Achievements[achievementId]
	return def ~= nil and QuestRules.achievementProgress(data, achievementId) >= def.Target
end

function QuestRules.achievementClaimable(data: PlayerData, achievementId: string): boolean
	return QuestRules.achievementReached(data, achievementId) and not data.Achievements[achievementId]
end

-- ===== HUD dots =====

function QuestRules.anyQuestClaimable(data: PlayerData, now: number): boolean
	if data.Quests.DayKey == QuestRules.dayKey(now) then
		for _, quest in data.Quests.Active do
			if QuestRules.isClaimable(quest) then
				return true
			end
		end
	end
	for achievementId in Achievements do
		if QuestRules.achievementClaimable(data, achievementId) then
			return true
		end
	end
	return false
end

return QuestRules
