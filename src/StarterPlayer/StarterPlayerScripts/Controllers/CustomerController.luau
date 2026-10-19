--!strict
--[[
	CustomerController
	Client-side visuals for customers (the server runs the customers):
	  * order bubble above YOUR waiting customers: name, flavor, scoop count,
	    topping and a draining patience bar (clock bar sprite)
	  * reaction emote when they leave: heart-eyes / happy / sad / angry
	  * hides other players' Serve prompts
	  * floating "+Coins" (and combo multiplier) above a customer who pays
	  * a camera flash when an Influencer reaches your counter
	Reads the customer model's attributes; see docs/UI_CONTRACT.md.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Modules.Assets)
local Customers = require(Shared.Data.Customers)
local Flavors = require(Shared.Data.Flavors)
local NumberFormat = require(Shared.Modules.NumberFormat)
local Remotes = require(Shared.Modules.Remotes)
local Toppings = require(Shared.Data.Toppings)

local UI = script.Parent.Parent.UI
local Cleaner = require(UI.Cleaner)
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)

local player = Players.LocalPlayer
local Colors = Theme.Colors

local EMOTE_SPRITES = {
	Love = "EmoteLove",
	Happy = "EmoteHappy",
	Sad = "EmoteSad",
	Angry = "EmoteAngry",
}
local EMOTE_SECONDS = 1.8

local CustomerController = {}

type Watch = {
	bubble: Cleaner.Cleaner, -- the order bubble and its tween
	all: Cleaner.Cleaner, -- connections and the emote, cleaned when the customer goes away
}

local watches: { [Model]: Watch } = {}
local playerGui: PlayerGui
local flashFrame: Frame

-- Quick white screen flash, like a phone camera.
local function cameraFlash()
	flashFrame.BackgroundTransparency = 0.35
	TweenService:Create(flashFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

local function isMine(model: Model): boolean
	return model:GetAttribute("OwnerUserId") == player.UserId
end

local function createBillboard(adornee: BasePart, size: UDim2, offset: Vector3): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = adornee
	billboard.Size = size
	billboard.StudsOffsetWorldSpace = offset
	billboard.MaxDistance = 80
	billboard.ResetOnSpawn = false
	billboard.Parent = playerGui
	return billboard
end

local function createBubble(model: Model, watch: Watch)
	local root = model.PrimaryPart
	local flavor = Flavors[model:GetAttribute("OrderFlavor") :: string]
	if root == nil or flavor == nil then
		return
	end
	local scoops = (model:GetAttribute("OrderScoops") :: number?) or 1
	local toppingId = model:GetAttribute("OrderTopping") :: string?
	local topping = if toppingId then Toppings[toppingId] else nil
	local total = (model:GetAttribute("PatienceTotal") :: number?) or 1
	local patienceEnd = (model:GetAttribute("PatienceEnd") :: number?) or 0

	local billboard = watch.bubble:add(createBillboard(root, UDim2.fromScale(6, 3.4), Vector3.new(0, 4.6, 0)))
	local outer, inner = UILib.createPanel(billboard, { Size = UDim2.fromScale(1, 1) })
	outer.Name = "OrderBubble"

	UILib.createLabel(inner, {
		Name = "CustomerName",
		Position = UDim2.fromScale(0.05, 0.02),
		Size = UDim2.fromScale(0.9, 0.22),
		Text = (model:GetAttribute("CustomerName") :: string?) or "Customer",
		TextColor3 = Colors.TextMuted,
	})

	-- Order row: [flavor] x2 [+ topping]
	local row = UILib.createFrame(inner, {
		Name = "Order",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.04, 0.24),
		Size = UDim2.fromScale(0.92, 0.42),
	})
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.03, 0)
	layout.Parent = row

	local flavorIcon = UILib.createIcon(row, flavor.Icon, flavor.Color, nil, {
		LayoutOrder = 1,
		Size = UDim2.fromScale(0.3, 1),
	})
	UILib.addAspect(flavorIcon, 1)
	UILib.createLabel(row, {
		LayoutOrder = 2,
		Size = UDim2.fromScale(0.26, 0.8),
		Text = `x{scoops}`,
	})
	if topping then
		UILib.createLabel(row, { LayoutOrder = 3, Size = UDim2.fromScale(0.1, 0.7), Text = "+" })
		local toppingIcon = UILib.createIcon(row, topping.Icon, topping.Color, nil, {
			LayoutOrder = 4,
			Size = UDim2.fromScale(0.3, 1),
		})
		UILib.addAspect(toppingIcon, 1)
	end

	-- Patience bar: drains from what's left to empty, green to red.
	local bar = UILib.createSpriteBar(inner, "PatienceBar", Colors.Green, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.98),
		Size = UDim2.fromScale(0.94, 0.32),
	})
	local now = Workspace:GetServerTimeNow()
	local fraction = math.clamp((patienceEnd - now) / total, 0, 1)
	bar.set(fraction)
	local fill = bar.Frame:FindFirstChild("Fill", true) :: Frame?
	if fill then
		fill.BackgroundColor3 = Colors.Cherry:Lerp(Colors.Green, fraction)
		local drain = TweenService:Create(
			fill,
			TweenInfo.new(math.max(patienceEnd - now, 0), Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Cherry }
		)
		drain:Play()
		watch.bubble:add(drain)
	end
end

-- Pops an emote above the customer's head for a moment.
local function showEmote(model: Model, watch: Watch, mood: string)
	local root = model.PrimaryPart
	local sprite = EMOTE_SPRITES[mood]
	if root == nil or sprite == nil then
		return
	end
	local billboard = watch.all:add(createBillboard(root, UDim2.fromScale(2.6, 2.6), Vector3.new(0, 4.4, 0)))
	local icon =
		UILib.createIcon(billboard, sprite, if mood == "Sad" or mood == "Angry" then Colors.Cherry else Colors.Pink)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = icon
	TweenService:Create(scale, Theme.Motion.Open, { Scale = 1 }):Play()
	task.delay(EMOTE_SECONDS, function()
		if billboard.Parent then
			local shrink = TweenService:Create(scale, Theme.Motion.Close, { Scale = 0 })
			shrink.Completed:Connect(function()
				billboard:Destroy()
			end)
			shrink:Play()
		end
	end)
end

local function hidePromptIfNotMine(model: Model, descendant: Instance)
	if descendant:IsA("ProximityPrompt") and not isMine(model) then
		descendant.Enabled = false
	end
end

local function onCustomerAdded(model: Instance)
	if not model:IsA("Model") or watches[model] then
		return
	end
	local watch: Watch = { bubble = Cleaner.new(), all = Cleaner.new() }
	watches[model] = watch

	local function refresh()
		watch.bubble:clean()
		if isMine(model) and model:GetAttribute("State") == "Waiting" then
			createBubble(model, watch)
			local def = Customers[model:GetAttribute("CustomerType") :: string]
			if def and def.CameraFlash then
				cameraFlash()
			end
		end
	end

	watch.all:add(model:GetAttributeChangedSignal("State"):Connect(refresh))
	watch.all:add(model:GetAttributeChangedSignal("Mood"):Connect(function()
		local mood = model:GetAttribute("Mood") :: string?
		if mood and isMine(model) then
			showEmote(model, watch, mood)
		end
	end))
	watch.all:add(model.DescendantAdded:Connect(function(descendant)
		hidePromptIfNotMine(model, descendant)
	end))
	for _, descendant in model:GetDescendants() do
		hidePromptIfNotMine(model, descendant)
	end
	refresh()
end

local function onCustomerRemoved(model: Instance)
	local watch = watches[model :: Model]
	if watch then
		watch.bubble:clean()
		watch.all:clean()
		watches[model :: Model] = nil
	end
end

-- Floating "+12" (and "x1.3" during a combo) above the customer who just paid.
local function showCoinPopup(position: Vector3, coins: number, correct: boolean, comboMultiplier: number?)
	local anchor = Instance.new("Part")
	anchor.Name = "CoinPopupAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = anchor
	billboard.Size = UDim2.fromScale(5, 1.6)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local combo = if comboMultiplier and comboMultiplier > 1 then string.format("  x%.1f", comboMultiplier) else ""
	local label = UILib.createLabel(billboard, {
		Text = `+{NumberFormat.short(coins)}{combo}`,
	})
	UILib.outlinedText(label)
	label.TextColor3 = if correct then Colors.Coin else Colors.Orange

	UILib.playSound(Assets.SFX_CASH_REGISTER)
	local rise = TweenService:Create(billboard, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
		StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
	})
	local fade = TweenService:Create(
		label,
		TweenInfo.new(0.6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.6),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	rise.Completed:Connect(function()
		anchor:Destroy()
	end)
	rise:Play()
	fade:Play()
end

function CustomerController.Init()
	playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui = UILib.createScreenGui("CameraFlash", Theme.Layers.Notification)
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None -- cover the whole screen
	flashFrame = UILib.createFrame(gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
	})
	gui.Parent = playerGui
end

function CustomerController.Start()
	local folder = Workspace:WaitForChild("Customers")
	folder.ChildAdded:Connect(onCustomerAdded)
	folder.ChildRemoved:Connect(onCustomerRemoved)
	for _, model in folder:GetChildren() do
		onCustomerAdded(model)
	end
	Remotes.event("OrderResult").OnClientEvent:Connect(showCoinPopup)
end

return CustomerController
