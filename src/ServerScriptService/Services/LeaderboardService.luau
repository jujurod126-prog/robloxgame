--!strict
--[[
	LeaderboardService
	Global leaderboards: Most Coins (lifetime Coins earned) and Most Rebirths.
	Every GameConfig.Leaderboards.RefreshSeconds it saves online players' scores to
	OrderedDataStores, re-reads the top lists, and publishes them for the Hub wall as
	JSON StringValues in ReplicatedStorage.Leaderboards (MostCoins, MostRebirths):
	  [{ "Rank": 1, "Name": "...", "Value": 123 }, ...]
	Works only when DataStores are available (published place / API access);
	otherwise it quietly does nothing.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Data.GameConfig)
local PlayerDataTypes = require(Shared.Types.PlayerData)

local DataService = require(script.Parent.DataService)

type PlayerData = PlayerDataTypes.PlayerData

type Board = {
	name: string,
	store: OrderedDataStore?,
	score: (data: PlayerData) -> number,
	value: StringValue,
}

local LeaderboardService = {}

local boards: { Board } = {}
local nameCache: { [number]: string } = {}
local warned = false

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok and type(name) == "string" then name else "Player"
	nameCache[userId] = result
	return result
end

local function warnOnce(message: string)
	if not warned then
		warned = true
		warn(`[LeaderboardService] {message} (leaderboards stay empty until DataStores work)`)
	end
end

local function saveScores(player: Player)
	local data = DataService.getData(player)
	-- Studio test commands (/coins) would otherwise put fake scores on the real boards.
	if data == nil or RunService:IsStudio() then
		return
	end
	for _, board in boards do
		if board.store then
			local ok, err = pcall(
				(board.store :: OrderedDataStore).SetAsync,
				board.store,
				tostring(player.UserId),
				math.floor(board.score(data))
			)
			if not ok then
				warnOnce(tostring(err))
			end
		end
	end
end

local function readBoard(board: Board)
	if board.store == nil then
		return
	end
	local ok, pages =
		pcall((board.store :: OrderedDataStore).GetSortedAsync, board.store, false, GameConfig.Leaderboards.TopCount)
	if not ok then
		warnOnce(tostring(pages))
		return
	end
	local entries = {}
	for rank, entry in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(entries, { Rank = rank, Name = nameFor(userId), Value = entry.value })
		end
	end
	board.value.Value = HttpService:JSONEncode(entries)
end

local function refresh()
	for _, player in Players:GetPlayers() do
		saveScores(player)
	end
	for _, board in boards do
		readBoard(board)
	end
end

function LeaderboardService.Init()
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = ReplicatedStorage

	local function addBoard(name: string, storeName: string, score: (PlayerData) -> number)
		local value = Instance.new("StringValue")
		value.Name = name
		value.Value = "[]"
		value.Parent = folder
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, storeName)
		table.insert(boards, { name = name, store = if ok then store else nil, score = score, value = value })
	end
	addBoard("MostCoins", "LB_CoinsEarned", function(data)
		return data.Stats.CoinsEarnedTotal
	end)
	addBoard("MostRebirths", "LB_Rebirths", function(data)
		return data.Rebirths
	end)
end

function LeaderboardService.Start()
	Players.PlayerRemoving:Connect(function(player)
		task.spawn(saveScores, player)
	end)
	task.spawn(function()
		task.wait(10) -- let the first players load
		while true do
			refresh()
			task.wait(GameConfig.Leaderboards.RefreshSeconds)
		end
	end)
end

return LeaderboardService
