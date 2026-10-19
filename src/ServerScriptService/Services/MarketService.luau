--!strict
--[[
	MarketService
	Robux purchases.
	  Game passes (Shared/Data/Products.GamePasses): ownership is checked with Roblox on
	  join and after a purchase, and stored in PlayerData.OwnedPasses so shared code
	  (PlayerStats, PetRules) and the UI can read it. Effects:
	    DoubleCoins   x2 Coins (PlayerStats.coinMultiplier)
	    AutoServe     serves a waiting customer every few seconds (CustomerService)
	    ExtraPetSlots +2 pet slots (PetRules.equipSlots)
	    VipTruck      golden truck paint (TruckService) + [VIP] chat tag (Player attribute "VIP")
	  Developer products (Gem packs): granted in ProcessReceipt; each PurchaseId is
	  remembered in PlayerData.Purchases.ReceiptIds so a receipt is never paid twice.
	Passes and products whose id is still 0 in Modules/Assets are skipped.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Modules.Assets)
local GameConfig = require(Shared.Data.GameConfig)
local Products = require(Shared.Data.Products)

local Notify = require(script.Parent.Parent.Modules.Notify)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local MarketService = {}

local function passIdFor(numericId: number): string?
	for id, pass in Products.GamePasses do
		if pass.PassId == numericId and not Assets.isPlaceholder(numericId) then
			return id
		end
	end
	return nil
end

local CHECK_RETRIES = 3

-- Asks Roblox (with retries) whether the player owns a pass. nil = Roblox didn't answer.
local function checkOwnership(player: Player, passId: number): boolean?
	for attempt = 1, CHECK_RETRIES do
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		if ok then
			return owns == true
		end
		task.wait(2 ^ attempt)
	end
	return nil
end

-- Asks Roblox which passes the player owns and stores the answer. If Roblox
-- never answers, the saved value is kept (it was confirmed when it was bought).
local function refreshPasses(player: Player)
	for id, pass in Products.GamePasses do
		if not Assets.isPlaceholder(pass.PassId) then
			local owns = checkOwnership(player, pass.PassId)
			if owns ~= nil and player.Parent then
				DataService.set(player, { "OwnedPasses", id }, if owns then true else nil)
			end
		end
	end
end

-- The "purchase finished" event can be faked by exploiters, so always confirm with Roblox.
local function onPassPurchased(player: Player, numericId: number, purchased: boolean)
	local id = passIdFor(numericId)
	if not purchased or id == nil then
		return
	end
	if checkOwnership(player, numericId) ~= true then
		warn(`[MarketService] {player.Name} reported buying pass {numericId}, but Roblox says no`)
		return
	end
	DataService.set(player, { "OwnedPasses", id }, true)
	Notify.send(player, `Thanks for buying {Products.GamePasses[id].DisplayName}!`, "Info")
	Notify.celebrate(player, "Purchase")
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.getData(player)
	if player == nil or data == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries later
	end
	local receiptId = tostring(receipt.PurchaseId)
	if table.find(data.Purchases.ReceiptIds, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already paid out
	end

	local product = nil
	for _, candidate in Products.DevProducts do
		if candidate.ProductId == receipt.ProductId and not Assets.isPlaceholder(candidate.ProductId) then
			product = candidate
		end
	end
	if product == nil then
		warn(`[MarketService] Unknown product {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	EconomyService.awardGems(player, product.Gems)
	-- Remember the receipt (keep the list short).
	DataService.update(player, { "Purchases", "ReceiptIds" }, function(list: { string })
		local updated = table.clone(list)
		table.insert(updated, receiptId)
		while #updated > GameConfig.Data.MaxReceiptHistory do
			table.remove(updated, 1)
		end
		return updated
	end)
	Notify.send(player, `+{product.Gems} Gems! Thank you!`, "Info")
	Notify.celebrate(player, "Purchase")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Everyone's client reads this for the chat tag (PlayerData only reaches its owner).
local function updateVipAttribute(player: Player)
	local data = DataService.getData(player)
	player:SetAttribute("VIP", if data and data.OwnedPasses.VipTruck then true else nil)
end

-- ===== Public API =====

function MarketService.ownsPass(player: Player, passId: string): boolean
	local data = DataService.getData(player)
	return data ~= nil and data.OwnedPasses[passId] == true
end

-- ===== Lifecycle =====

function MarketService.Init() end

function MarketService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPurchased)
	DataService.PlayerLoaded:Connect(function(player: Player)
		updateVipAttribute(player)
		task.spawn(refreshPasses, player)
	end)
	DataService.Changed:Connect(function(player: Player, path: { any })
		if #path == 0 or path[1] == "OwnedPasses" then
			updateVipAttribute(player)
		end
	end)
end

return MarketService
