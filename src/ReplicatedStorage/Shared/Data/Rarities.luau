--!strict
--[[
	Rarities
	Shared by flavors, pets and eggs. Colors for each rarity live in the Theme
	module (Stage 3) so the UI can be restyled in one place.
]]

local Shared = script.Parent.Parent
local GameData = require(Shared.Types.GameData)
local TableUtil = require(Shared.Modules.TableUtil)

local Rarities: { [string]: GameData.RarityDef } = {
	Common = { Id = "Common", Order = 1, DisplayName = "Common" },
	Uncommon = { Id = "Uncommon", Order = 2, DisplayName = "Uncommon" },
	Rare = { Id = "Rare", Order = 3, DisplayName = "Rare" },
	Epic = { Id = "Epic", Order = 4, DisplayName = "Epic" },
	Legendary = { Id = "Legendary", Order = 5, DisplayName = "Legendary" },
	Mythic = { Id = "Mythic", Order = 6, DisplayName = "Mythic" },
}

return TableUtil.defineData("Rarities", Rarities)
