--!strict
--[[
	GameConfig
	Global tuning knobs that aren't tied to one flavor/pet/truck.
	Readable by both server and client; only the server acts on them.
]]

local Shared = script.Parent.Parent
local TableUtil = require(Shared.Modules.TableUtil)

local GameConfig = {
	Data = {
		StoreName = "PlayerData", -- changing this starts everyone fresh!
		KeyPrefix = "Player_",
		AutosaveSeconds = 60,
		-- true = Studio sessions never touch real saves (uses ProfileStore's mock store).
		-- Leave false to test real saving in Studio (needs API access enabled).
		ForceMockInStudio = false,
		MaxReceiptHistory = 50,
	},

	Starting = {
		Coins = 0,
		Gems = 0,
		Flavor = "Vanilla",
		Neighborhood = "SunnySidewalk",
	},

	Trucks = {
		-- Each player's truck parks on its own lot. Lot 1 is at LotOrigin, then
		-- alternating right/left: +1, -1, +2, -2 ... times LotSpacing along X.
		LotOrigin = Vector3.new(0, 0, 60),
		LotSpacing = 45,
		MaxLots = 12,
		-- Trucks face -Z: customers line up on that side, the player stands behind (+Z).
		CounterGap = 3.5, -- studs between the truck's front face and the customer line
		StandGap = 3, -- studs behind the truck where the player appears
	},

	Scooping = {
		PromptDistance = 10, -- how close you must be to the dispenser
		-- Server accepts a scoop after this fraction of the scoop time (allows for lag).
		CooldownTolerance = 0.85,
	},

	CustomerFlow = {
		ArriveDelayMin = 0.5, -- seconds before a new customer arrives at a free spot
		ArriveDelayMax = 1.5,
		WalkSpeed = 12, -- studs per second
		SpawnDistance = 24, -- how far in front of the truck customers appear
		SpotSpacing = 5.5, -- studs between counter spots
		ServeDistance = 16, -- server-side max distance between player and customer
		PromptDistance = 14,
	},

	Combo = {
		StartsAt = 5, -- correct orders in a row before the multiplier kicks in
		StepMultiplier = 0.1, -- x1.1 at 5, x1.2 at 6, ...
		MaxMultiplier = 2,
	},

	Orders = {
		MaxTipFraction = 0.5, -- tip at full patience = 50% of the order's value
		WrongOrderPayFraction = 0.4,
		-- Served with at least this much patience left = heart-eyes ("Love") reaction.
		DelightedPatience = 0.7,
	},

	Reputation = {
		Start = 3,
		Min = 1,
		Max = 5,
		CorrectOrder = 0.02,
		WrongOrder = -0.03,
		CustomerLeft = -0.1,
	},

	Rebirth = {
		BaseRequirement = 2500000, -- Coins needed for the first rebirth (= Candy Kingdom unlock)
		RequirementGrowth = 1.5, -- each later rebirth needs this much more
		CoinMultiplierPerRebirth = 0.25, -- +25% permanent Coins per rebirth
		TokensPerRebirth = 1,
	},

	Pets = {
		BaseEquipSlots = 3,
		MaxInventory = 100,
		MergeCount = 5,
		GoldenBoostMultiplier = 2.5,
	},

	Quests = {
		PerDay = 3,
	},

	Daily = {
		ClaimCooldownHours = 20, -- can claim again this long after the last claim
		StreakExpireHours = 48, -- miss this window and the streak resets to day 1
	},

	RushHour = {
		IntervalMinSeconds = 480,
		IntervalMaxSeconds = 600,
		DurationSeconds = 60,
		SpawnRateMultiplier = 2,
		GemBonus = 5,
	},

	World = {
		DayNightCycleSeconds = 1200, -- one full in-game day
		Weather = {
			Rain = { Chance = 0.15, DurationSeconds = 120, CustomerSpeedMultiplier = 0.7 },
			Heatwave = { Chance = 0.1, DurationSeconds = 90, DemandMultiplier = 2 },
		},
	},

	Social = {
		FriendCoinBonus = 0.1, -- +10% Coins while a friend is in the server
	},

	Collectibles = {
		GoldenSprinkleGems = 25,
	},

	-- Max calls per player per window for each remote, enforced by the server RateLimiter.
	RateLimits = {
		Default = { Calls = 10, WindowSeconds = 1 },
		GetSnapshot = { Calls = 3, WindowSeconds = 10 },
		Purchase = { Calls = 6, WindowSeconds = 1 },
		Action = { Calls = 12, WindowSeconds = 1 }, -- SelectFlavor, AddTopping
	},
}

return TableUtil.deepFreeze(GameConfig)
