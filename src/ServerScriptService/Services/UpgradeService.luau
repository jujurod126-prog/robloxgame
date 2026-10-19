--!strict
--[[
	UpgradeService
	Handles Truck Garage purchases: stat upgrades and the next truck tier.

	Every request is checked on the server:
	  * rate limited (GameConfig.RateLimits.Purchase)
	  * argument type and value checked (only a known stat id / the NEXT tier)
	  * price and requirements from ShopRules (never from the client)
	  * Coins taken through EconomyService.trySpend (fails if unaffordable)
	TruckService, ConeService and CustomerService react to the data change
	(walk speed, scoop time, cone size, serving capacity, truck rebuild).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Data.GameConfig)
local NumberFormat = require(Shared.Modules.NumberFormat)
local Remotes = require(Shared.Modules.Remotes)
local ShopRules = require(Shared.Modules.ShopRules)
local Trucks = require(Shared.Data.Trucks)
local Upgrades = require(Shared.Data.Upgrades)

local Notify = require(script.Parent.Parent.Modules.Notify)
local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

type PurchaseResult = Remotes.PurchaseResult

local UpgradeService = {}

local limiter = RateLimiter.fromConfig(GameConfig.RateLimits.Purchase)

local function fail(message: string): PurchaseResult
	return { Ok = false, Message = message }
end

local function buyUpgrade(player: Player, statId: unknown): PurchaseResult
	if not limiter:check(player) then
		return fail("Slow down a little!")
	end
	if type(statId) ~= "string" or Upgrades[statId] == nil then
		return fail("That upgrade doesn't exist.")
	end
	local data = DataService.getData(player)
	if data == nil then
		return fail("Your data is still loading.")
	end

	local id = statId :: string -- checked against Upgrades above
	local status = ShopRules.upgradeStatus(data, id)
	if status.Cost == nil then
		return fail("Already at max level!")
	end
	if not EconomyService.trySpend(player, "Coins", status.Cost) then
		return fail(`You need {NumberFormat.commas(status.Cost - data.Coins)} more Coins.`)
	end

	local newLevel = status.Level + 1
	DataService.set(player, { "Truck", "Upgrades", id }, newLevel)
	return { Ok = true, Message = `{Upgrades[id].DisplayName} upgraded to level {newLevel}!` }
end

local function buyTruckTier(player: Player, tier: unknown): PurchaseResult
	if not limiter:check(player) then
		return fail("Slow down a little!")
	end
	if type(tier) ~= "number" or tier ~= math.floor(tier) or Trucks[tier] == nil then
		return fail("That truck doesn't exist.")
	end
	local data = DataService.getData(player)
	if data == nil then
		return fail("Your data is still loading.")
	end

	local truck = Trucks[tier :: number]
	local status = ShopRules.truckStatus(data, tier :: number)
	if status.State == "Owned" or status.State == "Current" then
		return fail("You already have this truck.")
	elseif status.State == "NeedsPrevious" then
		return fail("Buy the trucks before this one first.")
	elseif status.State == "NeedsRebirth" then
		return fail(`Needs {truck.RequiresRebirths} Rebirth(s).`)
	end
	if not EconomyService.trySpend(player, "Coins", status.Cost) then
		return fail(`You need {NumberFormat.commas(status.Cost - data.Coins)} more Coins.`)
	end

	DataService.set(player, { "Truck", "Tier" }, tier)
	Notify.celebrate(player, "Unlock")
	return { Ok = true, Message = `You got the {truck.DisplayName}!` }
end

function UpgradeService.Init() end

function UpgradeService.Start()
	Remotes.func("BuyUpgrade").OnServerInvoke = buyUpgrade
	Remotes.func("BuyTruckTier").OnServerInvoke = buyTruckTier
end

return UpgradeService
