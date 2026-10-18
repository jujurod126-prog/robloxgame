--!strict
--[[
	DataMigrations
	Upgrades old saves to the current PlayerData shape.

	When you change PlayerData in a way Reconcile can't handle on its own
	(renaming/moving/removing a key, changing a value's meaning):
	  1. bump CURRENT_VERSION
	  2. add MIGRATIONS[oldVersion] = function(data) ... end that edits data in place
	New keys with defaults do NOT need a migration - Reconcile fills them in.
]]

local DataMigrations = {}

DataMigrations.CURRENT_VERSION = 1

-- MIGRATIONS[n] upgrades a version-n save to version n + 1.
local MIGRATIONS: { [number]: (data: { [string]: any }) -> () } = {
	-- Example for the future:
	-- [1] = function(data)
	--     data.Gems = data.Diamonds or 0
	--     data.Diamonds = nil
	-- end,
}

export type MigrationResult = "Ok" | "TooNew"

--[[
	Runs every needed migration in order. Returns "TooNew" if the save was
	written by a newer version of the game (the player should rejoin a newer
	server instead of us overwriting their progress with an older shape).
]]
function DataMigrations.run(data: { [string]: any }): MigrationResult
	-- Saves from before versioning existed are treated as version 1.
	local version = if type(data.DataVersion) == "number" then data.DataVersion else 1

	if version > DataMigrations.CURRENT_VERSION then
		return "TooNew"
	end

	while version < DataMigrations.CURRENT_VERSION do
		local migrate = MIGRATIONS[version]
		assert(migrate, `Missing migration from data version {version}`)
		migrate(data)
		version += 1
	end

	data.DataVersion = version
	return "Ok"
end

return DataMigrations
