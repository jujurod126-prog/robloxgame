--!strict
--[[
	DataTemplate
	Default PlayerData for a brand-new player. ProfileStore also uses it to
	fill in any keys missing from older saves (Profile:Reconcile).
	Parts that depend on game data (upgrade levels, free cosmetics) are built
	from the data modules so adding a new upgrade needs no change here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Data.Cosmetics)
local GameConfig = require(Shared.Data.GameConfig)
local PlayerDataTypes = require(Shared.Types.PlayerData)
local TableUtil = require(Shared.Modules.TableUtil)
local Upgrades = require(Shared.Data.Upgrades)

local DataMigrations = require(script.Parent.DataMigrations)

type PlayerData = PlayerDataTypes.PlayerData

local upgradeLevels = {}
for id in Upgrades do
	upgradeLevels[id] = 1
end

-- Free cosmetics are owned by everyone; the first free one of each kind is equipped.
local ownedCosmetics: { [string]: boolean } = {}
local equipped: { [string]: string } = {}
for _, cosmetic in TableUtil.sortedByOrder(Cosmetics) do
	if cosmetic.Price == 0 then
		ownedCosmetics[cosmetic.Id] = true
		if equipped[cosmetic.Kind] == nil then
			equipped[cosmetic.Kind] = cosmetic.Id
		end
	end
end

local template: PlayerData = {
	DataVersion = DataMigrations.CURRENT_VERSION,

	Coins = GameConfig.Starting.Coins,
	Gems = GameConfig.Starting.Gems,
	RebirthTokens = 0,

	Rebirths = 0,
	Reputation = GameConfig.Reputation.Start,
	Truck = {
		Tier = 1,
		Upgrades = upgradeLevels :: any,
		Equipped = {
			Paint = equipped.Paint,
			Awning = equipped.Awning,
			Flag = equipped.Flag,
			Jingle = equipped.Jingle,
		},
	},
	OwnedCosmetics = ownedCosmetics,
	Flavors = {
		Unlocked = { [GameConfig.Starting.Flavor] = true },
		Loadout = { GameConfig.Starting.Flavor },
	},
	Toppings = {
		Unlocked = {},
	},
	Neighborhoods = {
		Unlocked = { Hub = true, [GameConfig.Starting.Neighborhood] = true },
		Current = GameConfig.Starting.Neighborhood,
	},
	Pets = {
		Inventory = {},
		Equipped = {},
	},
	Skills = {},

	Quests = {
		DayKey = 0,
		Active = {},
	},
	Daily = {
		Streak = 0,
		LastClaimTime = 0,
	},

	Achievements = {},
	Collectibles = {
		GoldenSprinkles = {},
		CriticTrophies = {},
	},
	Stats = {
		CustomersServed = 0,
		PerfectOrders = 0,
		ScoopsMade = 0,
		CoinsEarnedTotal = 0,
		HighestCombo = 0,
		EggsHatched = 0,
		GoldenSprinklesFound = 0,
		PlaySeconds = 0,
	},

	Settings = {
		MusicVolume = 0.5,
		SfxVolume = 0.7,
		ShowTips = true,
		ShowPopups = true,
	},
	Tutorial = {
		Completed = false,
		Step = 0,
	},

	Purchases = {
		ReceiptIds = {},
	},
}

for _, kind in { "Paint", "Awning", "Flag", "Jingle" } do
	assert(equipped[kind] ~= nil, `[DataTemplate] Cosmetics needs a free (Price 0) {kind}`)
end

return TableUtil.deepFreeze(template)
