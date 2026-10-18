--!strict
--[[
	Flavors
	Unlocked in the Flavor Lab. To add a flavor: copy an entry, give it a new
	Id (same as its key), add an ICON_FLAVOR_* constant in Modules/Assets.

	UnlockCost = Coins to unlock, CoinValue = Coins per scoop before multipliers.
	Tags are matched against each neighborhood's PreferredFlavorTags.
]]

local Shared = script.Parent.Parent
local Assets = require(Shared.Modules.Assets)
local GameData = require(Shared.Types.GameData)
local TableUtil = require(Shared.Modules.TableUtil)

local Flavors: { [string]: GameData.FlavorDef } = {
	-- ===== Common =====
	Vanilla = {
		Id = "Vanilla",
		Order = 1,
		DisplayName = "Vanilla",
		Description = "The classic. Smooth, creamy, and always in demand.",
		Rarity = "Common",
		UnlockCost = 0,
		CoinValue = 10,
		RequiresRebirths = 0,
		Color = Color3.fromRGB(255, 244, 214),
		Icon = Assets.ICON_FLAVOR_VANILLA,
		Tags = { "Classic" },
	},
	Chocolate = {
		Id = "Chocolate",
		Order = 2,
		DisplayName = "Chocolate",
		Description = "Rich cocoa scoops everyone loves.",
		Rarity = "Common",
		UnlockCost = 150,
		CoinValue = 12,
		RequiresRebirths = 0,
		Color = Color3.fromRGB(123, 74, 46),
		Icon = Assets.ICON_FLAVOR_CHOCOLATE,
		Tags = { "Classic", "Chocolate" },
	},
	Strawberry = {
		Id = "Strawberry",
		Order = 3,
		DisplayName = "Strawberry",
		Description = "Sweet, pink, and bursting with berries.",
		Rarity = "Common",
		UnlockCost = 400,
		CoinValue = 14,
		RequiresRebirths = 0,
		Color = Color3.fromRGB(255, 153, 178),
		Icon = Assets.ICON_FLAVOR_STRAWBERRY,
		Tags = { "Fruity", "Cold" },
	},

	-- ===== Uncommon =====
	MintChip = {
		Id = "MintChip",
		Order = 4,
		DisplayName = "Mint Chip",
		Description = "Cool mint with crunchy chocolate chips.",
		Rarity = "Uncommon",
		UnlockCost = 1500,
		CoinValue = 20,
		RequiresRebirths = 0,
		Color = Color3.fromRGB(170, 240, 200),
		Icon = Assets.ICON_FLAVOR_MINT_CHIP,
		Tags = { "Cold", "Chocolate" },
	},
	CookiesAndCream = {
		Id = "CookiesAndCream",
		Order = 5,
		DisplayName = "Cookies and Cream",
		Description = "Vanilla packed with chunky cookie pieces.",
		Rarity = "Uncommon",
		UnlockCost = 4000,
		CoinValue = 24,
		RequiresRebirths = 0,
		Color = Color3.fromRGB(225, 222, 215),
		Icon = Assets.ICON_FLAVOR_COOKIES_AND_CREAM,
		Tags = { "Classic", "Chocolate" },
	},
	Mango = {
		Id = "Mango",
		Order = 6,
		DisplayName = "Mango",
		Description = "Tropical sunshine in a cone.",
		Rarity = "Uncommon",
		UnlockCost = 8000,
		CoinValue = 28,
		RequiresRebirths = 0,
		Color = Color3.fromRGB(255, 190, 60),
		Icon = Assets.ICON_FLAVOR_MANGO,
		Tags = { "Fruity", "Cold" },
	},

	-- ===== Rare =====
	Bubblegum = {
		Id = "Bubblegum",
		Order = 7,
		DisplayName = "Bubblegum",
		Description = "Bright blue and impossibly chewy-sweet.",
		Rarity = "Rare",
		UnlockCost = 30000,
		CoinValue = 44,
		RequiresRebirths = 0,
		Color = Color3.fromRGB(120, 200, 255),
		Icon = Assets.ICON_FLAVOR_BUBBLEGUM,
		Tags = { "Candy" },
	},
	BirthdayCake = {
		Id = "BirthdayCake",
		Order = 8,
		DisplayName = "Birthday Cake",
		Description = "Cake batter swirled with confetti sprinkles.",
		Rarity = "Rare",
		UnlockCost = 60000,
		CoinValue = 52,
		RequiresRebirths = 0,
		Color = Color3.fromRGB(255, 225, 240),
		Icon = Assets.ICON_FLAVOR_BIRTHDAY_CAKE,
		Tags = { "Candy", "Classic" },
	},
	Pistachio = {
		Id = "Pistachio",
		Order = 9,
		DisplayName = "Pistachio",
		Description = "Nutty, green, and fancy.",
		Rarity = "Rare",
		UnlockCost = 120000,
		CoinValue = 60,
		RequiresRebirths = 0,
		Color = Color3.fromRGB(180, 215, 130),
		Icon = Assets.ICON_FLAVOR_PISTACHIO,
		Tags = { "Nutty" },
	},

	-- ===== Epic =====
	RainbowSwirl = {
		Id = "RainbowSwirl",
		Order = 10,
		DisplayName = "Rainbow Swirl",
		Description = "Every color, every scoop.",
		Rarity = "Epic",
		UnlockCost = 400000,
		CoinValue = 100,
		RequiresRebirths = 0,
		Color = Color3.fromRGB(255, 140, 220),
		Icon = Assets.ICON_FLAVOR_RAINBOW_SWIRL,
		Tags = { "Candy", "Fruity" },
	},
	Galaxy = {
		Id = "Galaxy",
		Order = 11,
		DisplayName = "Galaxy",
		Description = "Sparkling cosmic blackberry. Out of this world.",
		Rarity = "Epic",
		UnlockCost = 900000,
		CoinValue = 120,
		RequiresRebirths = 0,
		Color = Color3.fromRGB(90, 60, 170),
		Icon = Assets.ICON_FLAVOR_GALAXY,
		Tags = { "Fruity", "Cold" },
	},
	CottonCandyCloud = {
		Id = "CottonCandyCloud",
		Order = 12,
		DisplayName = "Cotton Candy Cloud",
		Description = "Fluffy, light, and melts in your mouth.",
		Rarity = "Epic",
		UnlockCost = 1800000,
		CoinValue = 140,
		RequiresRebirths = 0,
		Color = Color3.fromRGB(200, 220, 255),
		Icon = Assets.ICON_FLAVOR_COTTON_CANDY_CLOUD,
		Tags = { "Candy" },
	},

	-- ===== Legendary =====
	GoldenSundae = {
		Id = "GoldenSundae",
		Order = 13,
		DisplayName = "Golden Sundae",
		Description = "Honey-gold cream fit for royalty.",
		Rarity = "Legendary",
		UnlockCost = 5000000,
		CoinValue = 300,
		RequiresRebirths = 1,
		Color = Color3.fromRGB(255, 205, 60),
		Icon = Assets.ICON_FLAVOR_GOLDEN_SUNDAE,
		Tags = { "Classic" },
	},
	DragonfruitDream = {
		Id = "DragonfruitDream",
		Order = 14,
		DisplayName = "Dragonfruit Dream",
		Description = "A legendary pink-and-speckled fruit swirl.",
		Rarity = "Legendary",
		UnlockCost = 12000000,
		CoinValue = 360,
		RequiresRebirths = 3,
		Color = Color3.fromRGB(255, 80, 160),
		Icon = Assets.ICON_FLAVOR_DRAGONFRUIT_DREAM,
		Tags = { "Fruity", "Cold" },
	},
}

return TableUtil.defineData("Flavors", Flavors)
