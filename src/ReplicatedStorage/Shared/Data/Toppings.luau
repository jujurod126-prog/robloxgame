--!strict
--[[
	Toppings
	Each topping on an order multiplies its value by ValueMultiplier.
	Hot Fudge is not in the original list; it was added because Snowy Village
	customers want warm toppings.
]]

local Shared = script.Parent.Parent
local GameData = require(Shared.Types.GameData)
local TableUtil = require(Shared.Modules.TableUtil)

local Toppings: { [string]: GameData.ToppingDef } = {
	Sprinkles = {
		Id = "Sprinkles",
		Order = 1,
		DisplayName = "Sprinkles",
		UnlockCost = 100,
		ValueMultiplier = 1.1,
		Color = Color3.fromRGB(255, 120, 180),
		Icon = "ToppingSprinkles",
		Tags = { "Sweet" },
	},
	ChocolateSyrup = {
		Id = "ChocolateSyrup",
		Order = 2,
		DisplayName = "Chocolate Syrup",
		UnlockCost = 600,
		ValueMultiplier = 1.2,
		Color = Color3.fromRGB(90, 50, 30),
		Icon = "ToppingChocolateSyrup",
		Tags = { "Sweet", "Chocolate" },
	},
	Cherry = {
		Id = "Cherry",
		Order = 3,
		DisplayName = "Cherry",
		UnlockCost = 3000,
		ValueMultiplier = 1.3,
		Color = Color3.fromRGB(220, 30, 50),
		Icon = "ToppingCherry",
		Tags = { "Fruity" },
	},
	WhippedCream = {
		Id = "WhippedCream",
		Order = 4,
		DisplayName = "Whipped Cream",
		UnlockCost = 15000,
		ValueMultiplier = 1.4,
		Color = Color3.fromRGB(255, 255, 250),
		Icon = "ToppingWhippedCream",
		Tags = { "Sweet" },
	},
	CrushedCookies = {
		Id = "CrushedCookies",
		Order = 5,
		DisplayName = "Crushed Cookies",
		UnlockCost = 60000,
		ValueMultiplier = 1.5,
		Color = Color3.fromRGB(60, 45, 40),
		Icon = "ToppingCrushedCookies",
		Tags = { "Chocolate" },
	},
	HotFudge = {
		Id = "HotFudge",
		Order = 6,
		DisplayName = "Hot Fudge",
		UnlockCost = 250000,
		ValueMultiplier = 1.6,
		Color = Color3.fromRGB(70, 35, 20),
		Icon = "ToppingChocolateSyrup", -- no Hot Fudge art yet
		Tags = { "Warm", "Chocolate" },
	},
	GoldFlakes = {
		Id = "GoldFlakes",
		Order = 7,
		DisplayName = "Gold Flakes",
		UnlockCost = 1500000,
		ValueMultiplier = 2,
		Color = Color3.fromRGB(255, 215, 70),
		Icon = "ToppingGoldFlakes",
		Tags = { "Fancy" },
	},
}

return TableUtil.defineData("Toppings", Toppings)
