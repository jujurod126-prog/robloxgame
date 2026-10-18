--!strict
--[[
	Robux shop: game passes and developer products.
	IDs come from Modules/Assets (all 0 until you create them in the Creator Dashboard).
]]

local Shared = script.Parent.Parent
local Assets = require(Shared.Modules.Assets)
local GameData = require(Shared.Types.GameData)
local TableUtil = require(Shared.Modules.TableUtil)

local GamePasses: { [string]: GameData.GamePassDef } = {
	DoubleCoins = {
		Id = "DoubleCoins",
		DisplayName = "2x Coins",
		Description = "Double every Coin you earn, forever.",
		PassId = Assets.GAMEPASS_2X_COINS,
	},
	AutoServe = {
		Id = "AutoServe",
		DisplayName = "Auto-Serve",
		Description = "Your truck serves waiting customers for you.",
		PassId = Assets.GAMEPASS_AUTO_SERVE,
	},
	ExtraPetSlots = {
		Id = "ExtraPetSlots",
		DisplayName = "+2 Pet Slots",
		Description = "Equip two more pets.",
		PassId = Assets.GAMEPASS_EXTRA_PET_SLOTS,
	},
	VipTruck = {
		Id = "VipTruck",
		DisplayName = "VIP Truck",
		Description = "An exclusive golden VIP truck skin and a VIP chat tag.",
		PassId = Assets.GAMEPASS_VIP_TRUCK,
	},
}

local DevProducts: { [string]: GameData.DevProductDef } = {
	GemsSmall = { Id = "GemsSmall", DisplayName = "Handful of Gems", ProductId = Assets.PRODUCT_GEMS_SMALL, Gems = 100 },
	GemsMedium = { Id = "GemsMedium", DisplayName = "Bag of Gems", ProductId = Assets.PRODUCT_GEMS_MEDIUM, Gems = 550 },
	GemsLarge = { Id = "GemsLarge", DisplayName = "Chest of Gems", ProductId = Assets.PRODUCT_GEMS_LARGE, Gems = 1200 },
}

return table.freeze({
	GamePasses = TableUtil.defineData("GamePasses", GamePasses),
	DevProducts = TableUtil.defineData("DevProducts", DevProducts),
})
