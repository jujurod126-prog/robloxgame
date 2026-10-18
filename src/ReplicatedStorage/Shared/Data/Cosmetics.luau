--!strict
--[[
	Truck cosmetics. Price 0 = owned by everyone from the start.
	Cosmetics are kept through Rebirth.
]]

local Shared = script.Parent.Parent
local Assets = require(Shared.Modules.Assets)
local GameData = require(Shared.Types.GameData)
local TableUtil = require(Shared.Modules.TableUtil)

local Cosmetics: { [string]: GameData.CosmeticDef } = {
	-- Paint
	PaintClassic = {
		Id = "PaintClassic",
		Order = 1,
		Kind = "Paint",
		DisplayName = "Classic White",
		Currency = "Coins",
		Price = 0,
		Color = Color3.fromRGB(250, 250, 245),
	},
	PaintBubblegum = {
		Id = "PaintBubblegum",
		Order = 2,
		Kind = "Paint",
		DisplayName = "Bubblegum Pink",
		Currency = "Coins",
		Price = 2000,
		Color = Color3.fromRGB(255, 160, 200),
	},
	PaintMint = {
		Id = "PaintMint",
		Order = 3,
		Kind = "Paint",
		DisplayName = "Mint Green",
		Currency = "Coins",
		Price = 2000,
		Color = Color3.fromRGB(160, 235, 200),
	},
	PaintSky = {
		Id = "PaintSky",
		Order = 4,
		Kind = "Paint",
		DisplayName = "Sky Blue",
		Currency = "Coins",
		Price = 2000,
		Color = Color3.fromRGB(150, 205, 255),
	},
	PaintGold = {
		Id = "PaintGold",
		Order = 5,
		Kind = "Paint",
		DisplayName = "Golden",
		Currency = "Gems",
		Price = 150,
		Color = Color3.fromRGB(255, 205, 60),
	},
	-- Awnings
	AwningStripes = {
		Id = "AwningStripes",
		Order = 10,
		Kind = "Awning",
		DisplayName = "Candy Stripes",
		Currency = "Coins",
		Price = 0,
		Color = Color3.fromRGB(255, 110, 140),
	},
	AwningLemon = {
		Id = "AwningLemon",
		Order = 11,
		Kind = "Awning",
		DisplayName = "Lemon",
		Currency = "Coins",
		Price = 1500,
		Color = Color3.fromRGB(255, 230, 100),
	},
	AwningGrape = {
		Id = "AwningGrape",
		Order = 12,
		Kind = "Awning",
		DisplayName = "Grape",
		Currency = "Gems",
		Price = 75,
		Color = Color3.fromRGB(170, 120, 230),
	},
	-- Flags
	FlagNone = {
		Id = "FlagNone",
		Order = 20,
		Kind = "Flag",
		DisplayName = "No Flag",
		Currency = "Coins",
		Price = 0,
		Color = nil,
	},
	FlagCone = {
		Id = "FlagCone",
		Order = 21,
		Kind = "Flag",
		DisplayName = "Cone Flag",
		Currency = "Coins",
		Price = 1000,
		Color = Color3.fromRGB(255, 200, 120),
	},
	FlagStar = {
		Id = "FlagStar",
		Order = 22,
		Kind = "Flag",
		DisplayName = "Star Flag",
		Currency = "Gems",
		Price = 50,
		Color = Color3.fromRGB(255, 225, 80),
	},
	-- Jingles (the default plays each neighborhood's own jingle)
	JingleNeighborhood = {
		Id = "JingleNeighborhood",
		Order = 30,
		Kind = "Jingle",
		DisplayName = "Local Tune",
		Currency = "Coins",
		Price = 0,
		Sound = nil,
	},
	JingleClassic = {
		Id = "JingleClassic",
		Order = 31,
		Kind = "Jingle",
		DisplayName = "Classic Chimes",
		Currency = "Coins",
		Price = 2500,
		Sound = Assets.JINGLE_SUNNY_SIDEWALK,
	},
}

return TableUtil.defineData("Cosmetics", Cosmetics)
