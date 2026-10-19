--!strict
--[[
	QuestService
	Daily quests, the 7-day login reward and achievements.

	Daily quests:
	  * each UTC day a player gets GameConfig.Quests.PerDay quests from Shared/Data/Quests
	    (random quests, random difficulty), re-rolled when the day changes
	  * progress comes from what already happens in the game: the Stats counters
	    (customers served, scoops, perfect orders, Coins earned) and the "Combo"
	    Player attribute (best combo today) - no other service has to call in
	  * ClaimQuest(index) pays the reward once
	Daily login: ClaimDaily() every ClaimCooldownHours; missing StreakExpireHours resets
	the streak; day 7 is the big one, then it loops.
	Achievements: reaching a target awards the Roblox badge (if its id is set) and a
	toast; ClaimAchievement(id) pays the reward once.
]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Achievements = require(Shared.Data.Achievements)
local Assets = require(Shared.Modules.Assets)
local DailyRewards = require(Shared.Data.DailyRewards)
local GameConfig = require(Shared.Data.GameConfig)
local GameData = require(Shared.Types.GameData)
local PetRules = require(Shared.Modules.PetRules)
local QuestRules = require(Shared.Modules.QuestRules)
local Quests = require(Shared.Data.Quests)
local Remotes = require(Shared.Modules.Remotes)
local RewardUtil = require(Shared.Modules.RewardUtil)
local TableUtil = require(Shared.Modules.TableUtil)

local ServerModules = script.Parent.Parent.Modules
local Notify = require(ServerModules.Notify)
local RateLimiter = require(ServerModules.RateLimiter)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PetService = require(script.Parent.PetService)

type PurchaseResult = Remotes.PurchaseResult
type HatchResult = Remotes.HatchResult

local DAY_CHECK_SECONDS = 60

-- Quest Stat name -> the PlayerData.Stats counter it follows.
local COUNT_SOURCES: { [string]: string } = {
	CustomersServed = "CustomersServed",
	ScoopsMade = "ScoopsMade",
	PerfectOrders = "PerfectOrders",
	CoinsEarned = "CoinsEarnedTotal",
}

local QuestService = {}

local limiter = RateLimiter.fromConfig(GameConfig.RateLimits.Purchase)
local random = Random.new()
local lastStats: { [Player]: { [string]: number } } = {}
local announced: { [Player]: { [string]: boolean } } = {} -- achievements already toasted this session

-- ===== Rewards =====

-- Pays a reward bundle. Returns the hatched pet if it included an egg.
local function grantReward(player: Player, reward: GameData.Reward): Remotes.HatchedPet?
	if reward.Coins then
		EconomyService.grantCoins(player, reward.Coins)
	end
	if reward.Gems then
		EconomyService.awardGems(player, reward.Gems)
	end
	if reward.RebirthTokens then
		DataService.increment(player, { "RebirthTokens" }, reward.RebirthTokens)
	end
	if reward.EggId then
		local pet = PetService.grantEgg(player, reward.EggId)
		if pet == nil then
			Notify.send(player, "Your pet inventory is full, so the egg couldn't hatch. Make room next time!", "Error")
		end
		return pet
	end
	return nil
end

-- ===== Daily quests =====

local function rollQuests(player: Player, dayKey: number)
	local pool = {}
	for _, quest in TableUtil.sortedByOrder(Quests) do
		table.insert(pool, quest)
	end
	local active = {}
	for _ = 1, math.min(GameConfig.Quests.PerDay, #pool) do
		local quest = table.remove(pool, random:NextInteger(1, #pool)) :: GameData.QuestDef
		table.insert(active, {
			QuestId = quest.Id,
			Tier = random:NextInteger(1, #quest.Targets),
			Progress = 0,
			Claimed = false,
		})
	end
	DataService.set(player, { "Quests" }, { DayKey = dayKey, Active = active })
end

local function ensureToday(player: Player)
	local data = DataService.getData(player)
	local today = QuestRules.dayKey(os.time())
	if data and data.Quests.DayKey ~= today then
		rollQuests(player, today)
	end
end

-- Adds to (Count) or raises (Peak) every active quest that follows `stat`.
local function progress(player: Player, stat: string, amount: number)
	ensureToday(player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	for index, quest in data.Quests.Active do
		local def = Quests[quest.QuestId]
		if def and def.Stat == stat and not quest.Claimed then
			local target = QuestRules.target(quest)
			local value = if def.Kind == "Peak" then math.max(quest.Progress, amount) else quest.Progress + amount
			value = math.min(value, target)
			if value ~= quest.Progress then
				DataService.set(player, { "Quests", "Active", index, "Progress" }, value)
				if value >= target then
					Notify.send(player, `Quest complete: {QuestRules.description(quest)}! Claim it in Quests.`, "Info")
				end
			end
		end
	end
end

local function claimQuest(player: Player, index: unknown): PurchaseResult
	if not limiter:check(player) then
		return { Ok = false, Message = "Slow down a little!" }
	end
	ensureToday(player)
	local data = DataService.getData(player)
	if data == nil then
		return { Ok = false, Message = "Your data is still loading." }
	end
	if type(index) ~= "number" or data.Quests.Active[index :: number] == nil then
		return { Ok = false, Message = "That quest doesn't exist." }
	end
	local quest = data.Quests.Active[index :: number]
	if quest.Claimed then
		return { Ok = false, Message = "Already claimed." }
	end
	if not QuestRules.isComplete(quest) then
		return { Ok = false, Message = "Finish the quest first!" }
	end
	DataService.set(player, { "Quests", "Active", index :: number, "Claimed" }, true)
	local reward = QuestRules.reward(quest)
	grantReward(player, reward)
	return { Ok = true, Message = `Claimed {RewardUtil.describe(reward)}!` }
end

-- ===== Daily login reward =====

local function claimDaily(player: Player): HatchResult
	if not limiter:check(player) then
		return { Ok = false, Message = "Slow down a little!" }
	end
	local data = DataService.getData(player)
	if data == nil then
		return { Ok = false, Message = "Your data is still loading." }
	end
	local now = os.time()
	local status = QuestRules.dailyStatus(data, now)
	if not status.CanClaim then
		return { Ok = false, Message = "Come back later for your next reward!" }
	end
	local reward = DailyRewards[status.Day].Reward
	-- Refuse before claiming, so a full pet inventory can't swallow the day's egg.
	if reward.EggId and PetRules.inventoryCount(data) >= GameConfig.Pets.MaxInventory then
		return { Ok = false, Message = "Your pet inventory is full! Delete or merge a pet, then claim." }
	end
	local streak = (if status.StreakResets then 0 else data.Daily.Streak) + 1
	DataService.set(player, { "Daily" }, { Streak = streak, LastClaimTime = now })
	local pet = grantReward(player, reward)
	return {
		Ok = true,
		Message = `Day {status.Day} reward: {RewardUtil.describe(reward)}!`,
		Pets = if pet then { pet } else nil,
	}
end

-- ===== Achievements =====

local function awardBadge(player: Player, badgeId: number)
	if Assets.isPlaceholder(badgeId) then
		return
	end
	task.spawn(function()
		local ok, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)
		if not ok then
			warn(`[QuestService] Couldn't award badge {badgeId}: {err}`)
		end
	end)
end

-- Awards badges and toasts for newly reached achievements. quiet = no toasts (on join).
local function checkAchievements(player: Player, quiet: boolean)
	local data = DataService.getData(player)
	local seen = announced[player]
	if data == nil or seen == nil then
		return
	end
	for id, def in Achievements do
		if not seen[id] and QuestRules.achievementReached(data, id) then
			seen[id] = true
			awardBadge(player, def.BadgeId)
			if not quiet and not data.Achievements[id] then
				Notify.send(player, `Achievement unlocked: {def.DisplayName}! Claim it in Quests.`, "Info")
			end
		end
	end
end

local function claimAchievement(player: Player, achievementId: unknown): PurchaseResult
	if not limiter:check(player) then
		return { Ok = false, Message = "Slow down a little!" }
	end
	if type(achievementId) ~= "string" or Achievements[achievementId] == nil then
		return { Ok = false, Message = "That achievement doesn't exist." }
	end
	local data = DataService.getData(player)
	if data == nil then
		return { Ok = false, Message = "Your data is still loading." }
	end
	local id = achievementId :: string
	if data.Achievements[id] then
		return { Ok = false, Message = "Already claimed." }
	end
	if not QuestRules.achievementReached(data, id) then
		return { Ok = false, Message = "Not reached yet!" }
	end
	DataService.set(player, { "Achievements", id }, true)
	local reward = Achievements[id].Reward
	grantReward(player, reward)
	return { Ok = true, Message = `Claimed {RewardUtil.describe(reward)}!` }
end

-- ===== Tracking =====

local function snapshotStats(player: Player)
	local data = DataService.getData(player)
	if data then
		lastStats[player] = table.clone(data.Stats :: any)
	end
end

local function onDataChanged(player: Player, path: { any }, value: any)
	if #path == 0 then
		snapshotStats(player)
		announced[player] = {}
		checkAchievements(player, true)
		return
	end
	if path[1] == "Stats" and type(path[2]) == "string" and type(value) == "number" then
		local stats = lastStats[player]
		if stats then
			local key = path[2] :: string
			local delta = value - (stats[key] or value)
			stats[key] = value
			if delta > 0 then
				for questStat, source in COUNT_SOURCES do
					if source == key then
						progress(player, questStat, delta)
					end
				end
			end
		end
		checkAchievements(player, false)
	elseif path[1] == "Rebirths" then
		checkAchievements(player, false)
	end
end

local function onPlayerLoaded(player: Player)
	ensureToday(player)
	snapshotStats(player)
	announced[player] = {}
	checkAchievements(player, true)
	player:GetAttributeChangedSignal("Combo"):Connect(function()
		local combo = player:GetAttribute("Combo") :: number?
		if combo and combo > 0 then
			progress(player, "Combo", combo)
		end
	end)
end

function QuestService.Init() end

function QuestService.Start()
	Remotes.func("ClaimQuest").OnServerInvoke = claimQuest
	Remotes.func("ClaimDaily").OnServerInvoke = claimDaily
	Remotes.func("ClaimAchievement").OnServerInvoke = claimAchievement

	DataService.PlayerLoaded:Connect(onPlayerLoaded)
	DataService.Changed:Connect(onDataChanged)
	Players.PlayerRemoving:Connect(function(player)
		lastStats[player] = nil
		announced[player] = nil
	end)

	-- Re-roll quests for everyone online when the UTC day changes.
	task.spawn(function()
		while true do
			task.wait(DAY_CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				ensureToday(player)
			end
		end
	end)
end

return QuestService
