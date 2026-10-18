--!strict
--[[
	Eggs (Pet Parlor)
	Odds are relative weights; the UI shows Weight / total as a percentage
	(Modules/Formulas.eggOddsPercent). Weights don't have to add up to 100.
]]

local Shared = script.Parent.Parent
local Assets = require(Shared.Modules.Assets)
local GameData = require(Shared.Types.GameData)
local TableUtil = require(Shared.Modules.TableUtil)

local Eggs: { [string]: GameData.EggDef } = {
	Basic = {
		Id = "Basic",
		Order = 1,
		DisplayName = "Basic Egg",
		Currency = "Coins",
		Price = 750,
		EventOnly = false,
		Odds = {
			{ PetId = "Penguin", Weight = 35 },
			{ PetId = "Cow", Weight = 30 },
			{ PetId = "WafflePup", Weight = 20 },
			{ PetId = "PolarBear", Weight = 8 },
			{ PetId = "ConeCat", Weight = 5 },
			{ PetId = "CherryChick", Weight = 2 },
		},
		Icon = Assets.ICON_EGG_BASIC,
	},
	Rainbow = {
		Id = "Rainbow",
		Order = 2,
		DisplayName = "Rainbow Egg",
		Currency = "Gems",
		Price = 100,
		EventOnly = false,
		Odds = {
			{ PetId = "PolarBear", Weight = 30 },
			{ PetId = "ConeCat", Weight = 25 },
			{ PetId = "SundaeSeal", Weight = 20 },
			{ PetId = "CherryChick", Weight = 12 },
			{ PetId = "PopsicleParrot", Weight = 8 },
			{ PetId = "MarshmallowGhost", Weight = 4 },
			{ PetId = "GummyBear", Weight = 1 },
		},
		Icon = Assets.ICON_EGG_RAINBOW,
	},
	Legendary = {
		Id = "Legendary",
		Order = 3,
		DisplayName = "Legendary Egg",
		Currency = "Gems",
		Price = 500,
		EventOnly = false, -- set true to make it event-only
		Odds = {
			{ PetId = "CherryChick", Weight = 30 },
			{ PetId = "PopsicleParrot", Weight = 25 },
			{ PetId = "MarshmallowGhost", Weight = 22 },
			{ PetId = "GummyBear", Weight = 15 },
			{ PetId = "SprinkleDragon", Weight = 7 },
			{ PetId = "GalaxyUnicorn", Weight = 1 },
		},
		Icon = Assets.ICON_EGG_LEGENDARY,
	},
}

return TableUtil.defineData("Eggs", Eggs)
