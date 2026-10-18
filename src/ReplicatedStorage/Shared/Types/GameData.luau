--!strict
--[[
	GameData types
	Shapes of the balance tables in Shared/Data. Data modules annotate their
	entries with these so typos and missing fields show up in the type checker.
]]

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type CurrencyId = "Coins" | "Gems" | "RebirthTokens"

export type UpgradeStatId = "MoveSpeed" | "ScoopSpeed" | "ServingCapacity" | "Storage" | "TipBonus"

export type PetBoostStat = "CoinMultiplier" | "MoveSpeed" | "ScoopSpeed" | "TipBonus"

export type TimeOfDay = "Day" | "Sunset" | "Night"

-- A bundle of things given to the player (quests, daily rewards, achievements...).
export type Reward = {
	Coins: number?,
	Gems: number?,
	RebirthTokens: number?,
	EggId: string?, -- a free hatch of this egg
}

export type RarityDef = {
	Id: RarityId,
	Order: number,
	DisplayName: string,
}

export type FlavorDef = {
	Id: string,
	Order: number,
	DisplayName: string,
	Description: string,
	Rarity: RarityId,
	UnlockCost: number, -- Coins to unlock in the Flavor Lab (0 = owned from the start)
	CoinValue: number, -- Coins earned per scoop before multipliers
	RequiresRebirths: number,
	Color: Color3, -- scoop color in the world and on cards
	Icon: string,
	Tags: { string }, -- e.g. "Fruity", "Cold"; neighborhoods prefer certain tags
}

export type ToppingDef = {
	Id: string,
	Order: number,
	DisplayName: string,
	UnlockCost: number,
	ValueMultiplier: number, -- multiplies the order's value when included
	Color: Color3,
	Icon: string,
	Tags: { string }, -- e.g. "Warm"
}

export type TruckDef = {
	Id: string,
	Tier: number, -- 1..6, also the sort order
	DisplayName: string,
	Description: string,
	Cost: number, -- Coins
	RequiresRebirths: number,
	FlavorSlots: number,
	BaseServingCapacity: number, -- customers served at once before upgrades
	ScoopSpeedMultiplier: number, -- higher = faster scooping
	MoveSpeedMultiplier: number,
	TipMultiplier: number,
	AutoServeBurst: { Duration: number, Interval: number }?, -- seconds
	Hovers: boolean,
	AutoCollectTips: boolean,
	Icon: string,
}

export type UpgradeDef = {
	Id: UpgradeStatId,
	Order: number,
	DisplayName: string,
	Description: string,
	MaxLevel: number,
	BaseCost: number, -- cost to go from level 1 to level 2
	CostGrowth: number, -- each next level costs this much more (1.4 - 1.8)
	Values: { number }, -- Values[level] = the stat at that level
	ValueFormat: "Number" | "Seconds" | "Percent",
	Icon: string,
}

export type LightingDef = {
	ClockTime: number,
	Ambient: Color3,
	AtmosphereColor: Color3,
	AtmosphereDecay: Color3,
	AtmosphereDensity: number,
	AtmosphereHaze: number,
	TintColor: Color3, -- ColorCorrectionEffect
	Saturation: number,
	Contrast: number,
	Brightness: number,
}

export type NeighborhoodDef = {
	Id: string,
	Order: number,
	DisplayName: string,
	Description: string,
	IsHub: boolean,
	UnlockCost: number, -- Coins (0 = free)
	RequiresRebirths: number,
	CustomerSpots: number,
	PayMultiplier: number,
	TipMultiplier: number,
	PreferredFlavorTags: { string },
	PreferredToppingTags: { string },
	PreferenceBonus: number, -- extra multiplier when an order matches the area's taste
	ToppingPayBonus: number, -- extra multiplier on orders that include toppings
	RareCustomerMultiplier: number, -- scales spawn weight of Influencer/VIP customers
	Music: string,
	Jingle: string,
	Lighting: LightingDef,
}

export type CustomerDef = {
	Id: string,
	Order: number,
	DisplayName: string,
	SpawnWeight: number,
	MinReputation: number, -- stars needed before this type can appear
	PayMultiplier: number,
	TipMultiplier: number,
	PatienceSeconds: number,
	ReputationBonus: number, -- added on a correct order
	MaxScoops: number,
	ToppingChance: number, -- 0..1 chance the order includes a topping
	PreferredToppings: { string }?, -- picked first when ordering a topping
	MinFlavorRarity: RarityId?, -- only orders flavors of this rarity or better
	DemandsRarity: RarityId?, -- VIP/Critic: must be this exact rarity
	TimeOfDayWeights: { [TimeOfDay]: number },
	GivesCollectible: boolean,
	CameraFlash: boolean,
}

export type PetDef = {
	Id: string,
	Order: number,
	DisplayName: string,
	Rarity: RarityId,
	BoostStat: PetBoostStat,
	BoostAmount: number, -- 0.10 = +10%
	Icon: string,
}

export type EggOdds = { PetId: string, Weight: number }

export type EggDef = {
	Id: string,
	Order: number,
	DisplayName: string,
	Currency: CurrencyId,
	Price: number,
	EventOnly: boolean,
	Odds: { EggOdds },
	Icon: string,
}

export type SkillDef = {
	Id: string,
	Order: number,
	DisplayName: string,
	Description: string,
	MaxLevel: number,
	Costs: { number }, -- Rebirth Tokens for level 1, 2, ...
	Values: { number }, -- Values[level]; level 0 means "not bought" and has no effect
	Requires: { SkillId: string, Level: number }?,
	Icon: string,
}

export type QuestKind = "Count" | "Peak" -- Count: add up during the day; Peak: best single value

export type QuestDef = {
	Id: string,
	Order: number,
	DescriptionTemplate: string, -- "{target}" is replaced with the target number
	Kind: QuestKind,
	Stat: string, -- the gameplay stat that advances this quest
	Targets: { number }, -- one is picked per day (easy / medium / hard)
	Rewards: { Reward }, -- Rewards[i] matches Targets[i]
}

export type AchievementDef = {
	Id: string,
	Order: number,
	DisplayName: string,
	Description: string,
	Stat: string, -- lifetime stat from PlayerData.Stats (or "Rebirths")
	Target: number,
	Reward: Reward,
	BadgeId: number,
}

export type DailyRewardDef = {
	Day: number,
	Reward: Reward,
}

export type CosmeticKind = "Paint" | "Awning" | "Flag" | "Jingle"

export type CosmeticDef = {
	Id: string,
	Order: number,
	Kind: CosmeticKind,
	DisplayName: string,
	Currency: CurrencyId,
	Price: number, -- 0 = owned from the start
	Color: Color3?, -- Paint / Awning / Flag tint
	Sound: string?, -- Jingle
}

export type GamePassDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	PassId: number,
}

export type DevProductDef = {
	Id: string,
	DisplayName: string,
	ProductId: number,
	Gems: number,
}

return {}
