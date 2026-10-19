--!strict
--[[
	EconomyService
	The only place Coins and Gems are earned or spent.

	  EconomyService.awardCoins(player, baseAmount) -> Coins actually given
	      applies the player's Coin multipliers (rebirths now; pets, passes later)
	  EconomyService.trySpend(player, "Coins", 25) -> true if paid
	      checks the player can afford it first; never goes negative

	Amounts always come from server-side data (Formulas / data modules),
	never from a client request.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Data.GameConfig)
local GameData = require(Shared.Types.GameData)
local PlayerStats = require(Shared.Modules.PlayerStats)

local DataService = require(script.Parent.DataService)

local EconomyService = {}

local function isValidAmount(amount: number): boolean
	return type(amount) == "number" and amount == amount and amount >= 0 and amount ~= math.huge
end

--[[
	Gives Coins for gameplay (serving, quests...). baseAmount is before multipliers.
	Returns the Coins added (rounded, at least 1 if baseAmount > 0), or 0 if not loaded.
]]
function EconomyService.awardCoins(player: Player, baseAmount: number): number
	assert(isValidAmount(baseAmount), "awardCoins needs a finite, non-negative amount")
	local data = DataService.getData(player)
	if data == nil or baseAmount == 0 then
		return 0
	end
	local friendBonus = if player:GetAttribute("FriendBonus") then 1 + GameConfig.Social.FriendCoinBonus else 1
	local amount = math.max(1, math.floor(baseAmount * PlayerStats.coinMultiplier(data) * friendBonus + 0.5))
	DataService.increment(player, { "Coins" }, amount)
	DataService.increment(player, { "Stats", "CoinsEarnedTotal" }, amount)
	return amount
end

-- Gives a fixed number of Coins with no multipliers (quest / login rewards). Returns Coins added.
function EconomyService.grantCoins(player: Player, amount: number): number
	assert(isValidAmount(amount), "grantCoins needs a finite, non-negative amount")
	amount = math.floor(amount)
	if amount == 0 or DataService.increment(player, { "Coins" }, amount) == nil then
		return 0
	end
	return amount
end

-- Gives Gems (no multipliers). Returns the Gems added.
function EconomyService.awardGems(player: Player, amount: number): number
	assert(isValidAmount(amount), "awardGems needs a finite, non-negative amount")
	amount = math.floor(amount)
	if amount == 0 or DataService.increment(player, { "Gems" }, amount) == nil then
		return 0
	end
	return amount
end

function EconomyService.canAfford(player: Player, currency: GameData.CurrencyId, amount: number): boolean
	local data = DataService.getData(player)
	return data ~= nil and isValidAmount(amount) and (data :: any)[currency] >= amount
end

-- Takes `amount` of a currency if the player has enough. Returns true if paid.
function EconomyService.trySpend(player: Player, currency: GameData.CurrencyId, amount: number): boolean
	if not EconomyService.canAfford(player, currency, amount) then
		return false
	end
	return DataService.increment(player, { currency }, -math.floor(amount)) ~= nil
end

-- Sets the "FriendBonus" Player attribute for everyone with a friend in this server (+10% Coins).
local friendCache: { [Player]: { [number]: boolean } } = {}

local function areFriends(a: Player, b: Player): boolean
	local cache = friendCache[a]
	if cache == nil then
		cache = {}
		friendCache[a] = cache
	end
	local known = (cache :: any)[b.UserId]
	if known == nil then
		local ok, result = pcall(a.IsFriendsWithAsync, a, b.UserId)
		known = ok and result == true
		(cache :: any)[b.UserId] = known
	end
	return known
end

local function refreshFriendBonus()
	local players = Players:GetPlayers()
	for _, player in players do
		local hasFriend = false
		for _, other in players do
			if other ~= player and areFriends(player, other) then
				hasFriend = true
				break
			end
		end
		player:SetAttribute("FriendBonus", hasFriend)
	end
end

function EconomyService.Init() end

function EconomyService.Start()
	Players.PlayerAdded:Connect(function()
		task.spawn(refreshFriendBonus)
	end)
	Players.PlayerRemoving:Connect(function(player)
		friendCache[player] = nil
		task.defer(refreshFriendBonus)
	end)
end

return EconomyService
