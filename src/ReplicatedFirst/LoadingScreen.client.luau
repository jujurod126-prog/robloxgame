--!strict
--[[
	LoadingScreen
	Runs before anything else on the client (ReplicatedFirst). Replaces Roblox's
	default loading screen with a candy one, then fades out once the game has
	loaded AND your save data has arrived (DataController sets the local Player
	attribute "DataReady"). Gives up waiting after MAX_WAIT_SECONDS.

	Self-contained on purpose: UILib / Theme may not have replicated yet.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local MAX_WAIT_SECONDS = 30
local PINK = Color3.fromRGB(255, 170, 205)
local CREAM = Color3.fromRGB(255, 246, 228)
local OUTLINE = Color3.fromRGB(90, 50, 40)
local FONT = Enum.Font.FredokaOne
local TIPS = {
	"Match the customer's order exactly for big tips!",
	"Correct orders in a row build your combo multiplier.",
	"Pets give boosts - golden pets are 2.5x stronger.",
	"Rush Hour brings twice the customers and bonus Gems!",
	"Rebirth to earn permanent Coin multipliers.",
}

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = 100
gui.ResetOnSpawn = false

local background = Instance.new("CanvasGroup")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = PINK
background.Active = true -- block taps to the HUD underneath while loading
background.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(Color3.fromRGB(255, 200, 225), Color3.fromRGB(170, 215, 255))
gradient.Rotation = 90
gradient.Parent = background

local function label(text: string, position: UDim2, size: UDim2, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.Position = position
	item.Size = size
	item.Font = FONT
	item.Text = text
	item.TextColor3 = color
	item.TextStrokeColor3 = OUTLINE
	item.TextStrokeTransparency = 0
	item.TextScaled = true
	item.Parent = background
	return item
end

label("Ice Cream Truck Simulator", UDim2.fromScale(0.5, 0.36), UDim2.fromScale(0.8, 0.14), CREAM)
local status = label("Loading...", UDim2.fromScale(0.5, 0.56), UDim2.fromScale(0.5, 0.06), CREAM)
local tip = label(TIPS[math.random(1, #TIPS)], UDim2.fromScale(0.5, 0.8), UDim2.fromScale(0.7, 0.05), CREAM)
tip.TextStrokeTransparency = 0.4

-- A bouncing three-scoop cone made of circles.
local cone = Instance.new("Frame")
cone.AnchorPoint = Vector2.new(0.5, 0.5)
cone.Position = UDim2.fromScale(0.5, 0.67)
cone.Size = UDim2.fromScale(0.08, 0.08)
cone.SizeConstraint = Enum.SizeConstraint.RelativeYY
cone.BackgroundTransparency = 1
cone.Parent = background
for index, color in { Color3.fromRGB(255, 240, 200), Color3.fromRGB(255, 150, 190), Color3.fromRGB(150, 90, 60) } do
	local scoop = Instance.new("Frame")
	scoop.AnchorPoint = Vector2.new(0.5, 0.5)
	scoop.Position = UDim2.fromScale(0.5 + (index - 2) * 0.55, 0.5)
	scoop.Size = UDim2.fromScale(0.5, 0.5)
	scoop.BackgroundColor3 = color
	scoop.Parent = cone
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = scoop
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = 3
	stroke.Parent = scoop
	TweenService:Create(
		scoop,
		TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, index * 0.13),
		{ Position = UDim2.fromScale(scoop.Position.X.Scale, 0.1) }
	):Play()
end

gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local started = os.clock()
local function timedOut(): boolean
	return os.clock() - started > MAX_WAIT_SECONDS
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end
status.Text = "Loading your truck..."
while not player:GetAttribute("DataReady") and not timedOut() do
	task.wait(0.1)
end

status.Text = "Let's scoop!"
task.wait(0.3)
local fade = TweenService:Create(background, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { GroupTransparency = 1 })
fade.Completed:Connect(function()
	gui:Destroy()
end)
fade:Play()
