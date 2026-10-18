--!strict
--[[
	HudController (Stage 2: basic HUD)
	  * top left: Coins and Gems counters with a count-up animation and "+X" pops
	  * bottom center: what's on your cone ("Cone 1/2")
	  * top center: short toast messages from the server (Notify remote)

	Stage 3 rebuilds this on top of UILib + Theme with the full glossy style
	and the right-side menu buttons. Colors here are temporary.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Modules.Assets)
local NumberFormat = require(Shared.Modules.NumberFormat)
local Remotes = require(Shared.Modules.Remotes)

local DataController = require(script.Parent.DataController)

local player = Players.LocalPlayer

local COLORS = {
	Panel = Color3.fromRGB(255, 250, 240),
	Outline = Color3.fromRGB(70, 45, 60),
	Text = Color3.fromRGB(70, 45, 60),
	Coin = Color3.fromRGB(255, 200, 60),
	Gem = Color3.fromRGB(120, 200, 255),
	Gain = Color3.fromRGB(90, 200, 90),
	Error = Color3.fromRGB(235, 80, 90),
}
local FONT = Enum.Font.FredokaOne
local COUNT_UP_TIME = 0.5
local TOAST_SECONDS = 2.5

local HudController = {}

local gui: ScreenGui

local function addCorner(parent: GuiObject, scale: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(scale, 0)
	corner.Parent = parent
end

local function addStroke(parent: GuiObject, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = COLORS.Outline
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

local function makeLabel(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextColor3 = COLORS.Text
	label.TextScaled = true
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

-- A currency row: round icon on the left, animated number on the right.
local function createCounter(parent: Instance, name: string, icon: string, color: Color3, order: number)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.LayoutOrder = order
	frame.Size = UDim2.fromScale(1, 0.46)
	frame.BackgroundColor3 = COLORS.Panel
	addCorner(frame, 0.5)
	addStroke(frame, 3)
	frame.Parent = parent

	local badge = Instance.new("ImageLabel")
	badge.Name = "Icon"
	badge.Size = UDim2.fromScale(1, 1.15)
	badge.Position = UDim2.fromScale(0, 0.5)
	badge.AnchorPoint = Vector2.new(0.25, 0.5)
	badge.BackgroundColor3 = color
	badge.BackgroundTransparency = if Assets.isPlaceholder(icon) then 0 else 1
	badge.Image = if Assets.isPlaceholder(icon) then "" else icon
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = badge
	addCorner(badge, 0.5)
	if Assets.isPlaceholder(icon) then
		addStroke(badge, 3)
	end
	badge.Parent = frame

	local amount = makeLabel(frame, {
		Name = "Amount",
		Size = UDim2.fromScale(0.68, 0.8),
		Position = UDim2.fromScale(0.27, 0.1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
	})

	-- Count-up: tween a NumberValue and show its value as it changes.
	local shown = Instance.new("NumberValue")
	shown.Parent = frame
	shown.Changed:Connect(function(value: number)
		amount.Text = NumberFormat.short(math.floor(value + 0.5))
	end)

	local current: number? = nil
	local tween: Tween? = nil
	return function(newValue: number)
		if current == nil then
			shown.Value = newValue
		else
			if tween then
				tween:Cancel()
			end
			tween =
				TweenService:Create(shown, TweenInfo.new(COUNT_UP_TIME, Enum.EasingStyle.Quad), { Value = newValue });
			(tween :: Tween):Play()

			local gained = newValue - (current :: number)
			if gained > 0 then
				local pop = makeLabel(frame, {
					Name = "Pop",
					Size = UDim2.fromScale(0.6, 0.7),
					Position = UDim2.fromScale(1.05, 0.15),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = COLORS.Gain,
					TextStrokeTransparency = 0.4,
					Text = "+" .. NumberFormat.short(gained),
				})
				local rise = TweenService:Create(pop, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
					Position = UDim2.fromScale(1.05, -0.6),
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				})
				rise.Completed:Connect(function()
					pop:Destroy()
				end)
				rise:Play()
			end
		end
		current = newValue
	end
end

local function createCurrencies()
	local holder = Instance.new("Frame")
	holder.Name = "Currencies"
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromScale(0.02, 0.02)
	holder.Size = UDim2.fromScale(0.18, 0.15)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(140, 80)
	sizeLimit.MaxSize = Vector2.new(240, 120)
	sizeLimit.Parent = holder
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.08, 0)
	layout.Parent = holder
	holder.Parent = gui

	local setCoins = createCounter(holder, "Coins", Assets.ICON_COIN, COLORS.Coin, 1)
	local setGems = createCounter(holder, "Gems", Assets.ICON_GEM, COLORS.Gem, 2)
	DataController.observe("Coins", setCoins)
	DataController.observe("Gems", setGems)
end

local function createConeDisplay()
	local frame = Instance.new("Frame")
	frame.Name = "Cone"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 0.97)
	frame.Size = UDim2.fromScale(0.2, 0.06)
	frame.BackgroundColor3 = COLORS.Panel
	addCorner(frame, 0.5)
	addStroke(frame, 3)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(150, 36)
	sizeLimit.MaxSize = Vector2.new(260, 54)
	sizeLimit.Parent = frame
	frame.Parent = gui

	local label = makeLabel(frame, {
		Size = UDim2.fromScale(0.9, 0.75),
		Position = UDim2.fromScale(0.05, 0.125),
		Text = "Cone 0/1",
	})

	local function update()
		local scoops = (player:GetAttribute("ConeScoops") :: number?) or 0
		local capacity = (player:GetAttribute("ConeCapacity") :: number?) or 1
		label.Text = `Cone {scoops}/{capacity}`
	end
	player:GetAttributeChangedSignal("ConeScoops"):Connect(update)
	player:GetAttributeChangedSignal("ConeCapacity"):Connect(update)
	update()
end

local function createToast()
	local label = makeLabel(gui, {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.5, 0.05),
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = COLORS.Outline,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",
	})
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(260, 26)
	sizeLimit.MaxSize = Vector2.new(640, 40)
	sizeLimit.Parent = label

	local fade: Tween? = nil
	Remotes.event("Notify").OnClientEvent:Connect(function(message: string, kind: string)
		if fade then
			fade:Cancel()
		end
		label.Text = message
		label.TextColor3 = if kind == "Error" then COLORS.Error else Color3.new(1, 1, 1)
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0
		fade = TweenService:Create(
			label,
			TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, TOAST_SECONDS),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		);
		(fade :: Tween):Play()
	end)
end

function HudController.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- stay clear of Roblox's top bar and notches
	gui.Parent = player:WaitForChild("PlayerGui")
end

function HudController.Start()
	createCurrencies()
	createConeDisplay()
	createToast()
end

return HudController
