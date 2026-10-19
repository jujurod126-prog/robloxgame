--!strict
--[[
	StoreController
	The Robux Store window (HUD "Store" button):
	  Passes tab - every game pass in Shared/Data/Products: Owned, or a Buy button
	  Gems tab   - Gem packs (developer products)
	Buying only opens Roblox's purchase prompt. MarketService on the server checks
	ownership / processes receipts and changes data; this window just shows it.
	Prices come from Roblox (GetProductInfo). Items whose id is still a placeholder
	in Modules/Assets show "Coming soon".
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Modules.Assets)
local NumberFormat = require(Shared.Modules.NumberFormat)
local Products = require(Shared.Data.Products)

local UI = script.Parent.Parent.UI
local Cleaner = require(UI.Cleaner)
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)
local WindowManager = require(UI.WindowManager)

local DataController = require(script.Parent.DataController)

local player = Players.LocalPlayer
local Colors = Theme.Colors

local WINDOW_NAME = "Store"
local TABS = { "Passes", "Gems" }
local PASS_ORDER = { "DoubleCoins", "AutoServe", "ExtraPetSlots", "VipTruck" }
local GEM_ORDER = { "GemsSmall", "GemsMedium", "GemsLarge" }

local StoreController = {}

local window: UILib.Window
local content = Cleaner.new()
local selectedTab = TABS[1]
local updaters: { () -> () } = {}
local prices: { [number]: number? } = {} -- asset id -> Robux price (cached)

-- Fetches a price from Roblox once, then calls onPrice (can yield, so run in a thread).
local function fetchPrice(id: number, infoType: Enum.InfoType, onPrice: (number) -> ())
	local cached = prices[id]
	if cached then
		onPrice(cached)
		return
	end
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			prices[id] = info.PriceInRobux
			onPrice(info.PriceInRobux)
		end
	end)
end

local function createCard(
	parent: Instance,
	order: number,
	title: string,
	description: string,
	icon: string?,
	color: Color3
): (Frame, TextButton)
	local card = UILib.createFrame(parent, {
		Name = title,
		LayoutOrder = order,
		BackgroundColor3 = Colors.CreamDark,
	})
	UILib.addCorner(card, UDim.new(0.12, 0))
	UILib.addStroke(card, Theme.Sizes.Outline)

	local image = UILib.createIcon(card, icon, color, nil, {
		Position = UDim2.fromScale(0.04, 0.08),
		Size = UDim2.fromScale(0.3, 0.55),
	})
	UILib.addAspect(image, 1)
	UILib.createLabel(card, {
		Position = UDim2.fromScale(0.38, 0.06),
		Size = UDim2.fromScale(0.58, 0.24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
	})
	UILib.createLabel(card, {
		Position = UDim2.fromScale(0.38, 0.32),
		Size = UDim2.fromScale(0.58, 0.3),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Colors.TextMuted,
		Text = description,
	})
	local button = UILib.createButton(card, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.94),
		Size = UDim2.fromScale(0.6, 0.26),
	})
	return card, button
end

local function buildPasses(grid: ScrollingFrame)
	for index, id in PASS_ORDER do
		local pass = Products.GamePasses[id]
		if pass == nil then
			continue
		end
		local placeholder = Assets.isPlaceholder(pass.PassId)
		local _, button = createCard(grid, index, pass.DisplayName, pass.Description, nil, Colors.Blue)
		local priceText = "Buy"
		if not placeholder then
			fetchPrice(pass.PassId, Enum.InfoType.GamePass, function(price)
				priceText = `R$ {NumberFormat.commas(price)}`
				for _, update in updaters do
					update()
				end
			end)
		end
		table.insert(updaters, function()
			local data = DataController.getData()
			if data and data.OwnedPasses[id] then
				UILib.setButtonText(button, "Owned")
				UILib.setButtonStyle(button, "Disabled")
			elseif placeholder then
				UILib.setButtonText(button, "Coming soon")
				UILib.setButtonStyle(button, "Disabled")
			else
				UILib.setButtonText(button, priceText)
				UILib.setButtonStyle(button, "Primary")
			end
		end)
		UILib.onActivated(button, function()
			local data = DataController.getData()
			if placeholder or (data and data.OwnedPasses[id]) then
				return
			end
			MarketplaceService:PromptGamePassPurchase(player, pass.PassId)
		end)
	end
end

local function buildGems(grid: ScrollingFrame)
	for index, id in GEM_ORDER do
		local product = Products.DevProducts[id]
		if product == nil then
			continue
		end
		local placeholder = Assets.isPlaceholder(product.ProductId)
		local _, button = createCard(
			grid,
			index,
			product.DisplayName,
			`{NumberFormat.commas(product.Gems)} Gems`,
			Assets.ICON_GEM,
			Colors.Gem
		)
		UILib.setButtonText(button, if placeholder then "Coming soon" else "Buy")
		UILib.setButtonStyle(button, if placeholder then "Disabled" else "Primary")
		if not placeholder then
			fetchPrice(product.ProductId, Enum.InfoType.Product, function(price)
				if button.Parent then
					UILib.setButtonText(button, `R$ {NumberFormat.commas(price)}`)
				end
			end)
		end
		UILib.onActivated(button, function()
			if not placeholder then
				MarketplaceService:PromptProductPurchase(player, product.ProductId)
			end
		end)
	end
end

local function buildTab(tabName: string, holder: Frame)
	holder:ClearAllChildren()
	table.clear(updaters)
	local grid = UILib.createScrollingGrid(holder, 2, 1.7)
	if tabName == "Passes" then
		buildPasses(grid)
	else
		buildGems(grid)
	end
	for _, update in updaters do
		update()
	end
end

local function open()
	content:clean()
	UILib.tweenIn(window.Root)
	local body = window.Body
	local holder = content:add(UILib.createFrame(body, {
		Name = "TabContent",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, Theme.Sizes.TabBar + 8), -- below the tab buttons
		Size = UDim2.new(1, 0, 1, -(Theme.Sizes.TabBar + 8)),
	}))
	local tabs = UILib.createTabs(body, TABS, function(name)
		selectedTab = name
		buildTab(name, holder)
	end)
	tabs.Frame.Size = UDim2.new(1, 0, 0, Theme.Sizes.TabBar)
	content:add(tabs.Frame)
	tabs.select(selectedTab)

	content:add(DataController.Changed:Connect(function(path: { any })
		if #path == 0 or path[1] == "OwnedPasses" then
			for _, update in updaters do
				update()
			end
		end
	end))
end

local function close()
	UILib.tweenOut(window.Root, function()
		content:clean()
		table.clear(updaters)
	end)
end

function StoreController.Init() end

function StoreController.Start()
	local gui = UILib.createScreenGui("StoreGui", Theme.Layers.Window)
	window = UILib.createWindow(gui, { Title = "Store" })
	UILib.onActivated(window.CloseButton, function()
		WindowManager.close(WINDOW_NAME)
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	WindowManager.register(WINDOW_NAME, open, close)
end

return StoreController
