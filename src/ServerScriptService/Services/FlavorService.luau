--!strict
--[[
	FlavorService
	Flavor Lab purchases and the truck's flavor loadout.
	  UnlockFlavor(flavorId)        buy a flavor (auto-loads it if a truck slot is free)
	  EquipFlavor(flavorId, slot)   put an unlocked flavor in a truck slot
	  UnlockTopping(toppingId)      buy a topping

	Server checks on every request: rate limit, argument types, ids exist,
	FlavorRules (rebirth locks, already owned), affordability via EconomyService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local FlavorRules = require(Shared.Modules.FlavorRules)
local Flavors = require(Shared.Data.Flavors)
local GameConfig = require(Shared.Data.GameConfig)
local NumberFormat = require(Shared.Modules.NumberFormat)
local PlayerStats = require(Shared.Modules.PlayerStats)
local Remotes = require(Shared.Modules.Remotes)
local Toppings = require(Shared.Data.Toppings)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

type PurchaseResult = Remotes.PurchaseResult

local FlavorService = {}

local limiter = RateLimiter.fromConfig(GameConfig.RateLimits.Purchase)

local function fail(message: string): PurchaseResult
	return { Ok = false, Message = message }
end

local function unlockFlavor(player: Player, flavorId: unknown): PurchaseResult
	if not limiter:check(player) then
		return fail("Slow down a little!")
	end
	if type(flavorId) ~= "string" or Flavors[flavorId] == nil then
		return fail("That flavor doesn't exist.")
	end
	local data = DataService.getData(player)
	if data == nil then
		return fail("Your data is still loading.")
	end
	local id = flavorId :: string
	local flavor = Flavors[id]
	local status = FlavorRules.flavorStatus(data, id)
	if status.State == "Owned" or status.State == "Equipped" then
		return fail("You already have this flavor.")
	elseif status.State == "NeedsRebirth" then
		return fail(`Needs {flavor.RequiresRebirths} Rebirth(s).`)
	end
	if not EconomyService.trySpend(player, "Coins", status.Cost) then
		return fail(`You need {NumberFormat.commas(status.Cost - data.Coins)} more Coins.`)
	end

	DataService.set(player, { "Flavors", "Unlocked", id }, true)
	-- Load it straight into the truck if there's a free slot.
	local loadout = PlayerStats.loadout(data)
	if #loadout < PlayerStats.flavorSlots(data) then
		table.insert(loadout, id)
		DataService.set(player, { "Flavors", "Loadout" }, loadout)
		return { Ok = true, Message = `{flavor.DisplayName} unlocked and loaded into your truck!` }
	end
	return { Ok = true, Message = `{flavor.DisplayName} unlocked!` }
end

local function equipFlavor(player: Player, flavorId: unknown, slot: unknown): PurchaseResult
	if not limiter:check(player) then
		return fail("Slow down a little!")
	end
	if type(flavorId) ~= "string" or Flavors[flavorId] == nil then
		return fail("That flavor doesn't exist.")
	end
	if type(slot) ~= "number" or slot ~= math.floor(slot) then
		return fail("Pick a truck slot first.")
	end
	local data = DataService.getData(player)
	if data == nil then
		return fail("Your data is still loading.")
	end
	local id = flavorId :: string
	local slots = PlayerStats.flavorSlots(data)
	if (slot :: number) < 1 or (slot :: number) > slots then
		return fail(`Your truck only has {slots} flavor slot(s).`)
	end
	if not data.Flavors.Unlocked[id] then
		return fail("Unlock this flavor first.")
	end

	local loadout = PlayerStats.loadout(data)
	local existing = table.find(loadout, id)
	-- No gaps: a new flavor can go one past the end, a moved one only within the list.
	local target = math.min(slot :: number, if existing then #loadout else #loadout + 1)
	if existing == target then
		return { Ok = true, Message = "Already in that slot." }
	end
	if existing then
		-- Moving within the truck: swap the two slots.
		loadout[existing], loadout[target] = loadout[target], id
	else
		loadout[target] = id
	end
	DataService.set(player, { "Flavors", "Loadout" }, loadout)
	return { Ok = true, Message = `{Flavors[id].DisplayName} loaded into slot {target}.` }
end

local function unlockTopping(player: Player, toppingId: unknown): PurchaseResult
	if not limiter:check(player) then
		return fail("Slow down a little!")
	end
	if type(toppingId) ~= "string" or Toppings[toppingId] == nil then
		return fail("That topping doesn't exist.")
	end
	local data = DataService.getData(player)
	if data == nil then
		return fail("Your data is still loading.")
	end
	local id = toppingId :: string
	local status = FlavorRules.toppingStatus(data, id)
	if status.State == "Owned" then
		return fail("You already have this topping.")
	end
	if not EconomyService.trySpend(player, "Coins", status.Cost) then
		return fail(`You need {NumberFormat.commas(status.Cost - data.Coins)} more Coins.`)
	end
	DataService.set(player, { "Toppings", "Unlocked", id }, true)
	return { Ok = true, Message = `{Toppings[id].DisplayName} unlocked! Tap it below to add it to a cone.` }
end

function FlavorService.Init() end

function FlavorService.Start()
	Remotes.func("UnlockFlavor").OnServerInvoke = unlockFlavor
	Remotes.func("EquipFlavor").OnServerInvoke = equipFlavor
	Remotes.func("UnlockTopping").OnServerInvoke = unlockTopping
end

return FlavorService
