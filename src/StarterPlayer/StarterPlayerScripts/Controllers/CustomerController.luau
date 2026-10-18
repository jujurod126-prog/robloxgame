--!strict
--[[
	CustomerController
	Client-side visuals for customers (the server runs the customers):
	  * order bubble above YOUR waiting customers: name, flavor, scoops, patience bar
	  * hides other players' Serve prompts
	  * floating "+Coins" above a customer when they pay (OrderResult remote)
	Reads the customer model's attributes; see docs/UI_CONTRACT.md.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Flavors = require(Shared.Data.Flavors)
local NumberFormat = require(Shared.Modules.NumberFormat)
local Remotes = require(Shared.Modules.Remotes)

local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne
local OUTLINE = Color3.fromRGB(70, 45, 60)
local PANEL = Color3.fromRGB(255, 250, 240)
local PATIENCE_FULL = Color3.fromRGB(110, 210, 110)
local PATIENCE_EMPTY = Color3.fromRGB(235, 80, 90)

local CustomerController = {}

type Watch = {
	bubble: BillboardGui?,
	tweens: { Tween },
	connections: { RBXScriptConnection },
}

local watches: { [Model]: Watch } = {}

local function addCorner(parent: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = parent
end

local function addStroke(parent: GuiObject, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = OUTLINE
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

local function clearBubble(watch: Watch)
	for _, tween in watch.tweens do
		tween:Cancel()
	end
	table.clear(watch.tweens)
	if watch.bubble then
		watch.bubble:Destroy()
		watch.bubble = nil
	end
end

local function createBubble(model: Model, watch: Watch)
	local root = model.PrimaryPart
	local flavor = Flavors[model:GetAttribute("OrderFlavor") :: string]
	if root == nil or flavor == nil then
		return
	end
	local scoops = (model:GetAttribute("OrderScoops") :: number?) or 1
	local total = (model:GetAttribute("PatienceTotal") :: number?) or 1
	local patienceEnd = (model:GetAttribute("PatienceEnd") :: number?) or 0

	local bubble = Instance.new("BillboardGui")
	bubble.Name = "OrderBubble"
	bubble.Adornee = root
	bubble.Size = UDim2.fromScale(5, 2.6)
	bubble.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
	bubble.MaxDistance = 80
	bubble.ResetOnSpawn = false

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = PANEL
	addCorner(panel)
	addStroke(panel, 3)
	panel.Parent = bubble

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(0.9, 0.28)
	nameLabel.Position = UDim2.fromScale(0.05, 0.04)
	nameLabel.Font = FONT
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = OUTLINE
	nameLabel.Text = (model:GetAttribute("CustomerName") :: string?) or "Customer"
	nameLabel.Parent = panel

	-- Flavor "icon": a scoop-colored circle (swap for flavor.Icon once real icons exist).
	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.fromScale(0.26, 0.36)
	swatch.Position = UDim2.fromScale(0.06, 0.34)
	swatch.BackgroundColor3 = flavor.Color
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = swatch
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = swatch
	addStroke(swatch, 2)
	swatch.Parent = panel

	local orderLabel = Instance.new("TextLabel")
	orderLabel.BackgroundTransparency = 1
	orderLabel.Size = UDim2.fromScale(0.62, 0.36)
	orderLabel.Position = UDim2.fromScale(0.34, 0.34)
	orderLabel.Font = FONT
	orderLabel.TextScaled = true
	orderLabel.TextXAlignment = Enum.TextXAlignment.Left
	orderLabel.TextColor3 = OUTLINE
	orderLabel.Text = `{scoops}x {flavor.DisplayName}`
	orderLabel.Parent = panel

	local barBack = Instance.new("Frame")
	barBack.Size = UDim2.fromScale(0.88, 0.14)
	barBack.Position = UDim2.fromScale(0.06, 0.78)
	barBack.BackgroundColor3 = Color3.fromRGB(230, 220, 215)
	addCorner(barBack)
	barBack.Parent = panel

	local fraction = math.clamp((patienceEnd - Workspace:GetServerTimeNow()) / total, 0, 1)
	local remaining = math.max(patienceEnd - Workspace:GetServerTimeNow(), 0)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(fraction, 1)
	fill.BackgroundColor3 = PATIENCE_EMPTY:Lerp(PATIENCE_FULL, fraction)
	addCorner(fill)
	fill.Parent = barBack

	local drain = TweenService:Create(
		fill,
		TweenInfo.new(remaining, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = PATIENCE_EMPTY }
	)
	drain:Play()
	table.insert(watch.tweens, drain)

	bubble.Parent = player:WaitForChild("PlayerGui")
	watch.bubble = bubble
end

local function hidePromptIfNotMine(model: Model, descendant: Instance)
	if descendant:IsA("ProximityPrompt") and model:GetAttribute("OwnerUserId") ~= player.UserId then
		descendant.Enabled = false
	end
end

local function onCustomerAdded(model: Instance)
	if not model:IsA("Model") or watches[model] then
		return
	end
	local watch: Watch = { bubble = nil, tweens = {}, connections = {} }
	watches[model] = watch

	local function refresh()
		clearBubble(watch)
		local isMine = model:GetAttribute("OwnerUserId") == player.UserId
		if isMine and model:GetAttribute("State") == "Waiting" then
			createBubble(model, watch)
		end
	end

	table.insert(watch.connections, model:GetAttributeChangedSignal("State"):Connect(refresh))
	table.insert(
		watch.connections,
		model.DescendantAdded:Connect(function(descendant)
			hidePromptIfNotMine(model, descendant)
		end)
	)
	for _, descendant in model:GetDescendants() do
		hidePromptIfNotMine(model, descendant)
	end
	refresh()
end

local function onCustomerRemoved(model: Instance)
	local watch = watches[model :: Model]
	if watch == nil then
		return
	end
	clearBubble(watch)
	for _, connection in watch.connections do
		connection:Disconnect()
	end
	watches[model :: Model] = nil
end

-- Floating "+12" above the customer who just paid.
local function showCoinPopup(position: Vector3, coins: number, correct: boolean)
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
	billboard.Size = UDim2.fromScale(4, 1.5)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = if correct then Color3.fromRGB(255, 215, 70) else Color3.fromRGB(255, 160, 90)
	label.TextStrokeColor3 = OUTLINE
	label.TextStrokeTransparency = 0
	label.Text = `+{NumberFormat.short(coins)}`
	label.Parent = billboard

	local rise = TweenService:Create(billboard, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
		StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
	})
	local fade = TweenService:Create(
		label,
		TweenInfo.new(0.6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.6),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	rise.Completed:Connect(function()
		anchor:Destroy()
	end)
	rise:Play()
	fade:Play()
end

function CustomerController.Init() end

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
