--!strict
--[[
	PlayerData type
	The saved profile for one player. The server owns it; clients receive a
	read-only copy (see docs/UI_CONTRACT.md for how it is synced).

	Saving rules (ProfileStore / DataStore):
	  * no Instances, Color3s, Vector3s or functions - plain values only
	  * dictionaries use string keys, arrays have no gaps, never mix the two

	When you change this shape, also update:
	  1. ServerScriptService/Modules/DataTemplate.luau (default values)
	  2. ServerScriptService/Modules/DataMigrations.luau (bump the version, add a migration)
]]

export type PetVariant = "Normal" | "Golden"

export type PetInstance = {
	PetId: string, -- key into Shared/Data/Pets
	Variant: PetVariant,
	Locked: boolean, -- locked pets can't be deleted or merged by accident
}

export type DailyQuestState = {
	QuestId: string, -- key into Shared/Data/Quests
	Tier: number, -- which of the quest's Targets/Rewards was rolled (1 = easy)
	Progress: number,
	Claimed: boolean,
}

export type PlayerData = {
	DataVersion: number,

	-- Currencies
	Coins: number,
	Gems: number,
	RebirthTokens: number,

	-- Progression
	Rebirths: number,
	Reputation: number, -- star rating, GameConfig.Reputation.Min .. Max
	Truck: {
		Tier: number, -- index into Shared/Data/Trucks by Tier
		Upgrades: { [string]: number }, -- upgrade id (Shared/Data/Upgrades) -> level, starts at 1
		Equipped: { -- equipped cosmetic id per kind
			Paint: string,
			Awning: string,
			Flag: string,
			Jingle: string,
		},
	},
	OwnedCosmetics: { [string]: boolean },
	Flavors: {
		Unlocked: { [string]: boolean },
		Loadout: { string }, -- flavor ids in the truck's slots, in slot order
	},
	Toppings: {
		Unlocked: { [string]: boolean },
	},
	Neighborhoods: {
		Unlocked: { [string]: boolean },
		Current: string, -- where the player was last (Hub or a neighborhood id); they come back here
	},
	Pets: {
		Inventory: { [string]: PetInstance }, -- key = unique pet GUID
		Equipped: { string }, -- pet GUIDs
	},
	Skills: { [string]: number }, -- Rebirth skill id -> level

	-- Dailies
	Quests: {
		DayKey: number, -- which UTC day the Active list was rolled for
		Active: { DailyQuestState },
	},
	Daily: {
		Streak: number, -- 0..7, the next claim gives day (Streak % 7) + 1
		LastClaimTime: number, -- os.time() of the last claim, 0 = never
	},

	-- Collections & lifetime stats
	Achievements: { [string]: boolean }, -- achievement id -> reward claimed
	Collectibles: {
		GoldenSprinkles: { [string]: boolean }, -- sprinkle id found in the world
		CriticTrophies: { [string]: boolean },
	},
	Stats: {
		CustomersServed: number,
		PerfectOrders: number,
		ScoopsMade: number,
		CoinsEarnedTotal: number,
		HighestCombo: number,
		EggsHatched: number,
		GoldenSprinklesFound: number,
		PlaySeconds: number,
	},

	-- Player preferences
	Settings: {
		MusicVolume: number, -- 0..1
		SfxVolume: number, -- 0..1
		ShowTips: boolean,
		ShowPopups: boolean,
	},
	Tutorial: {
		Completed: boolean,
		Step: number,
	},

	-- Robux purchase bookkeeping (stops a developer product being granted twice)
	Purchases: {
		ReceiptIds: { string }, -- most recent processed PurchaseIds, capped in MarketService
	},
}

return {}
