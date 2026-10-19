--!strict
--[[
	HudController
	The always-visible HUD, built with UILib + Theme:
	  * top left: Coins and Gems with count-up and floating "+X"
	  * top center: neighborhood name and 5-star Reputation
	  * right side: menu buttons (Shop, Pets, Flavors, Quests, Rebirth, Daily, Settings)
	    with red notification dots - HudController.setDot(name, visible)
	  (the bottom-center cone / combo strip is OrderBarController)
	Buttons open windows through WindowManager; windows not built yet say "Coming soon".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Modules.Assets)
local GameConfig = require(Shared.Data.GameConfig)
local Neighborhoods = require(Shared.Data.Neighborhoods)
local NumberFormat = require(Shared.Modules.NumberFormat)
local FlavorRules = require(Shared.Modules.FlavorRules)
local ShopRules = require(Shared.Modules.ShopRules)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)
local WindowManager = require(UI.WindowManager)

local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

local player = Players.LocalPlayer
local Colors = Theme.Colors

-- Right-side menu, top to bottom. Window = the WindowManager name it opens.
local MENU = {
	{ Window = "Shop", Text = "Shop", Style = "Primary" },
	{ Window = "Pets", Text = "Pets", Style = "Pink" },
	{ Window = "Flavors", Text = "Flavors", Style = "Blue" },
	{ Window = "Quests", Text = "Quests", Style = "Secondary" },
	{ Window = "Rebirth", Text = "Rebirth", Style = "Pink" },
	{ Window = "Daily", Text = "Daily", Style = "Primary" },
	{ Window = "Settings", Text = "Settings", Style = "Secondary" },
}

local HudController = {}

local gui: ScreenGui
local dots: { [string]: GuiObject } = {}

-- Shows or hides the red dot on a menu button (something claimable / affordable).
function HudController.setDot(window: string, visible: boolean)
	local dot = dots[window]
	if dot then
		dot.Visible = visible
	end
end

-- ===== Currencies =====

local function createCounter(parent: Instance, name: string, icon: string, color: Color3, order: number)
	local outer, inner = UILib.createPanel(parent, {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0.45),
	}, Theme.Sizes.CornerPill)

	local badge = UILib.createIcon(outer, icon, color, nil, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.02, 0.5),
		Size = UDim2.fromScale(1.3, 1.3),
		ZIndex = 2,
	})
	UILib.addAspect(badge, 1)

	local amount = UILib.createLabel(inner, {
		Name = "Amount",
		Position = UDim2.fromScale(0.24, 0.12),
		Size = UDim2.fromScale(0.72, 0.76),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Fonts.Number,
		Text = "0",
	})

	local shown = Instance.new("NumberValue")
	shown.Parent = outer
	shown.Changed:Connect(function(value: number)
		amount.Text = NumberFormat.short(math.floor(value + 0.5))
	end)

	local current: number? = nil
	local countUp: Tween? = nil
	return function(newValue: number)
		if current ~= nil and newValue ~= current then
			if countUp then
				countUp:Cancel()
			end
			countUp = TweenService:Create(shown, Theme.Motion.CountUp, { Value = newValue });
			(countUp :: Tween):Play()

			local gained = newValue - (current :: number)
			if gained > 0 then
				local pop = UILib.createLabel(outer, {
					Name = "Pop",
					Position = UDim2.fromScale(1.04, 0.1),
					Size = UDim2.fromScale(0.6, 0.8),
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = "+" .. NumberFormat.short(gained),
				})
				UILib.outlinedText(pop)
				pop.TextColor3 = Colors.Green
				local rise = TweenService:Create(pop, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
					Position = UDim2.fromScale(1.04, -0.7),
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				})
				rise.Completed:Connect(function()
					pop:Destroy()
				end)
				rise:Play()
			end
		else
			shown.Value = newValue
		end
		current = newValue
	end
end

local function createCurrencies()
	local holder = UILib.createFrame(gui, {
		Name = "Currencies",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.035, 0.03),
		Size = UDim2.fromScale(0.19, 0.16),
	})
	UILib.addSizeLimit(holder, Vector2.new(150, 84), Vector2.new(260, 130))
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.1, 0)
	layout.Parent = holder

	DataController.observe("Coins", createCounter(holder, "Coins", Assets.ICON_COIN, Colors.Coin, 1))
	DataController.observe("Gems", createCounter(holder, "Gems", Assets.ICON_GEM, Colors.Gem, 2))
end

-- ===== Neighborhood + Reputation =====

local function starText(rating: number): string
	local full = math.clamp(math.floor(rating + 0.5), 0, 5)
	return string.rep("★", full) .. string.rep("☆", 5 - full)
end

local function createLocationBadge()
	local outer, inner = UILib.createPanel(gui, {
		Name = "Location",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.015),
		Size = UDim2.fromScale(0.24, 0.09),
	})
	UILib.addSizeLimit(outer, Vector2.new(170, 48), Vector2.new(300, 74))

	local name = UILib.createLabel(inner, {
		Name = "Neighborhood",
		Position = UDim2.fromScale(0.05, 0.04),
		Size = UDim2.fromScale(0.9, 0.5),
	})
	local stars = UILib.createLabel(inner, {
		Name = "Stars",
		Position = UDim2.fromScale(0.1, 0.52),
		Size = UDim2.fromScale(0.8, 0.44),
		TextColor3 = Colors.Coin,
		TextStrokeColor3 = Colors.Outline,
		TextStrokeTransparency = 0,
	})

	-- Stage 5 sets the "Neighborhood" player attribute when you travel.
	local function updateName()
		local id = (player:GetAttribute("Neighborhood") :: string?) or GameConfig.Starting.Neighborhood
		local neighborhood = Neighborhoods[id]
		name.Text = if neighborhood then neighborhood.DisplayName else id
	end
	player:GetAttributeChangedSignal("Neighborhood"):Connect(updateName)
	updateName()

	DataController.observe("Reputation", function(rating: number)
		stars.Text = starText(rating or 0)
	end)
end

-- ===== Menu buttons =====

local function createMenu()
	local column = UILib.createFrame(gui, {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.985, 0.47),
		Size = UDim2.fromScale(0.075, 0.66),
	})
	UILib.addSizeLimit(column, Vector2.new(52, 330), Vector2.new(86, 640))
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.015, 0)
	layout.Parent = column

	for index, entry in MENU do
		local button = UILib.createButton(column, {
			Name = entry.Window,
			Text = entry.Text,
			Style = entry.Style,
			LayoutOrder = index,
			Size = UDim2.fromScale(1, 0.13),
			OnClick = function()
				if WindowManager.isRegistered(entry.Window) then
					WindowManager.toggle(entry.Window)
				else
					NotificationController.toast(`{entry.Text} is coming in a later update!`, "Info")
				end
			end,
		})
		UILib.addAspect(button, 1)
		local corner = button:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0.3, 0)
		end

		local dot = UILib.createIcon(button, "NotificationDot", Colors.Cherry, nil, {
			Name = "Dot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.9, 0.1),
			Size = UDim2.fromScale(0.34, 0.34),
			Visible = false,
			ZIndex = 3,
		})
		UILib.addAspect(dot, 1)
		dots[entry.Window] = dot
	end
end

-- ===== Dots =====

local function watchDots()
	local function update()
		local data = DataController.getData()
		HudController.setDot("Shop", data ~= nil and ShopRules.hasAffordable(data))
		HudController.setDot("Flavors", data ~= nil and FlavorRules.hasAffordable(data))
	end
	DataController.Changed:Connect(function(path: { any })
		local key = path[1]
		if
			#path == 0
			or key == "Coins"
			or key == "Truck"
			or key == "Rebirths"
			or key == "Flavors"
			or key == "Toppings"
		then
			update()
		end
	end)
	DataController.waitForData()
	update()
end

function HudController.Init()
	gui = UILib.createScreenGui("Hud", Theme.Layers.Hud)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function HudController.Start()
	createCurrencies()
	createLocationBadge()
	createMenu()
	task.spawn(watchDots)
end

return HudController
