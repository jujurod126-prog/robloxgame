--!strict
--[[
	Pets
	Each pet boosts ONE stat by BoostAmount (0.10 = +10%). Golden pets (made
	by merging GameConfig.Pets.MergeCount copies) multiply that boost by
	GameConfig.Pets.GoldenBoostMultiplier. Boosts from equipped pets add together.
]]

local Shared = script.Parent.Parent
local Assets = require(Shared.Modules.Assets)
local GameData = require(Shared.Types.GameData)
local TableUtil = require(Shared.Modules.TableUtil)

local Pets: { [string]: GameData.PetDef } = {
	-- Common
	Penguin = {
		Id = "Penguin",
		Order = 1,
		DisplayName = "Penguin",
		Rarity = "Common",
		BoostStat = "CoinMultiplier",
		BoostAmount = 0.05,
		Icon = Assets.ICON_PET_PENGUIN,
	},
	Cow = {
		Id = "Cow",
		Order = 2,
		DisplayName = "Cow",
		Rarity = "Common",
		BoostStat = "MoveSpeed",
		BoostAmount = 0.05,
		Icon = Assets.ICON_PET_COW,
	},
	WafflePup = {
		Id = "WafflePup",
		Order = 3,
		DisplayName = "Waffle Pup",
		Rarity = "Common",
		BoostStat = "ScoopSpeed",
		BoostAmount = 0.05,
		Icon = Assets.ICON_PET_WAFFLE_PUP,
	},
	-- Uncommon
	PolarBear = {
		Id = "PolarBear",
		Order = 4,
		DisplayName = "Polar Bear",
		Rarity = "Uncommon",
		BoostStat = "CoinMultiplier",
		BoostAmount = 0.1,
		Icon = Assets.ICON_PET_POLAR_BEAR,
	},
	ConeCat = {
		Id = "ConeCat",
		Order = 5,
		DisplayName = "Cone Cat",
		Rarity = "Uncommon",
		BoostStat = "TipBonus",
		BoostAmount = 0.1,
		Icon = Assets.ICON_PET_CONE_CAT,
	},
	SundaeSeal = {
		Id = "SundaeSeal",
		Order = 6,
		DisplayName = "Sundae Seal",
		Rarity = "Uncommon",
		BoostStat = "ScoopSpeed",
		BoostAmount = 0.1,
		Icon = Assets.ICON_PET_SUNDAE_SEAL,
	},
	-- Rare
	CherryChick = {
		Id = "CherryChick",
		Order = 7,
		DisplayName = "Cherry Chick",
		Rarity = "Rare",
		BoostStat = "CoinMultiplier",
		BoostAmount = 0.2,
		Icon = Assets.ICON_PET_CHERRY_CHICK,
	},
	PopsicleParrot = {
		Id = "PopsicleParrot",
		Order = 8,
		DisplayName = "Popsicle Parrot",
		Rarity = "Rare",
		BoostStat = "MoveSpeed",
		BoostAmount = 0.15,
		Icon = Assets.ICON_PET_POPSICLE_PARROT,
	},
	-- Epic
	MarshmallowGhost = {
		Id = "MarshmallowGhost",
		Order = 9,
		DisplayName = "Marshmallow Ghost",
		Rarity = "Epic",
		BoostStat = "TipBonus",
		BoostAmount = 0.35,
		Icon = Assets.ICON_PET_MARSHMALLOW_GHOST,
	},
	GummyBear = {
		Id = "GummyBear",
		Order = 10,
		DisplayName = "Gummy Bear",
		Rarity = "Epic",
		BoostStat = "CoinMultiplier",
		BoostAmount = 0.4,
		Icon = Assets.ICON_PET_GUMMY_BEAR,
	},
	-- Legendary
	SprinkleDragon = {
		Id = "SprinkleDragon",
		Order = 11,
		DisplayName = "Sprinkle Dragon",
		Rarity = "Legendary",
		BoostStat = "CoinMultiplier",
		BoostAmount = 0.75,
		Icon = Assets.ICON_PET_SPRINKLE_DRAGON,
	},
	-- Mythic
	GalaxyUnicorn = {
		Id = "GalaxyUnicorn",
		Order = 12,
		DisplayName = "Galaxy Unicorn",
		Rarity = "Mythic",
		BoostStat = "CoinMultiplier",
		BoostAmount = 1.5,
		Icon = Assets.ICON_PET_GALAXY_UNICORN,
	},
}

return TableUtil.defineData("Pets", Pets)
