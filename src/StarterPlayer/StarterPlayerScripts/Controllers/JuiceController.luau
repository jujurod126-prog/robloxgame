--!strict
--[[
	JuiceController
	Game-feel effects, all local:
	  * Celebrate remote (unlock, rebirth, golden pet, purchase): confetti burst,
	    a short camera shake and a sound
	  * OrderResult remote: a few coin icons fly from the customer to the HUD's
	    Coins counter (skipped when Settings.ShowPopups is off)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Modules.Assets)
local Remotes = require(Shared.Modules.Remotes)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)
local DataController = require(script.Parent.DataController)
local HudController = require(script.Parent.HudController)

local player = Players.LocalPlayer
local Colors = Theme.Colors

local CONFETTI_COLORS = { Colors.Pink, Colors.Blue, Colors.Green, Colors.Coin, Colors.Orange, Colors.Cherry }
local CONFETTI_PIECES: { [string]: number } = { Unlock = 40, Rebirth = 90, Golden = 60, Purchase = 50 }
local SHAKE: { [string]: number } = { Unlock = 0.25, Rebirth = 0.6, Golden = 0.35, Purchase = 0.25 }
local SHAKE_SECONDS = 0.4
local MAX_FLYING_COINS = 5

local JuiceController = {}

local gui: ScreenGui
local random = Random.new()
local shakeUntil = 0
local shakeStrength = 0

local function confetti(count: number)
	for _ = 1, count do
		local piece = UILib.createFrame(gui, {
			Name = "Confetti",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(random:NextNumber(0.05, 0.95), random:NextNumber(-0.2, -0.02)),
			Size = UDim2.fromScale(random:NextNumber(0.008, 0.016), random:NextNumber(0.014, 0.028)),
			BackgroundColor3 = CONFETTI_COLORS[random:NextInteger(1, #CONFETTI_COLORS)],
			Rotation = random:NextNumber(0, 360),
		})
		if not Assets.isPlaceholder(Assets.TEXTURE_CONFETTI) then
			local image = Instance.new("ImageLabel")
			image.BackgroundTransparency = 1
			image.Size = UDim2.fromScale(1, 1)
			image.Image = Assets.TEXTURE_CONFETTI
			image.ImageColor3 = piece.BackgroundColor3
			image.Parent = piece
			piece.BackgroundTransparency = 1
		end
		local fall = TweenService:Create(
			piece,
			TweenInfo.new(random:NextNumber(1.6, 2.6), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.fromScale(piece.Position.X.Scale + random:NextNumber(-0.15, 0.15), 1.1),
				Rotation = piece.Rotation + random:NextNumber(-540, 540),
			}
		)
		fall.Completed:Connect(function()
			piece:Destroy()
		end)
		task.delay(random:NextNumber(0, 0.4), function()
			fall:Play()
		end)
	end
end

local function shake(strength: number)
	shakeStrength = math.max(strength, if os.clock() < shakeUntil then shakeStrength else 0)
	shakeUntil = os.clock() + SHAKE_SECONDS
end

-- Runs after the camera scripts each frame and nudges the camera a little.
local function applyShake()
	local remaining = shakeUntil - os.clock()
	if remaining <= 0 then
		return
	end
	local amount = shakeStrength * (remaining / SHAKE_SECONDS)
	local camera = Workspace.CurrentCamera
	camera.CFrame *= CFrame.new(random:NextNumber(-amount, amount), random:NextNumber(-amount, amount), 0)
end

local function onCelebrate(kind: string)
	confetti(CONFETTI_PIECES[kind] or 40)
	shake(SHAKE[kind] or 0.25)
	UILib.playSound(Assets.SFX_UNLOCK)
	UILib.playSound(Assets.SFX_CONFETTI, 1, 0.5)
end

local function flyCoins(position: Vector3, coins: number)
	local data = DataController.getData()
	local target = HudController.getCoinTarget()
	if coins <= 0 or target == nil or (data and not data.Settings.ShowPopups) then
		return
	end
	local camera = Workspace.CurrentCamera
	-- WorldToScreenPoint and AbsolutePosition share one coordinate space;
	-- subtracting our gui's corner turns them into positions inside it.
	local screenPoint, onScreen = camera:WorldToScreenPoint(position)
	if not onScreen then
		return
	end
	local inset = gui.AbsolutePosition
	local start = Vector2.new(screenPoint.X, screenPoint.Y) - inset
	local goal = target.AbsolutePosition + target.AbsoluteSize / 2 - inset

	local count = math.clamp(math.ceil(math.log10(coins + 1)), 1, MAX_FLYING_COINS)
	for index = 1, count do
		local icon = UILib.createIcon(gui, Assets.ICON_COIN, Colors.Coin, nil, {
			Name = "FlyingCoin",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(start.X + random:NextNumber(-20, 20), start.Y + random:NextNumber(-20, 20)),
			Size = UDim2.fromOffset(28, 28),
		})
		local fly = TweenService:Create(
			icon,
			TweenInfo.new(0.55 + index * 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.fromOffset(goal.X, goal.Y), Size = UDim2.fromOffset(18, 18) }
		)
		fly.Completed:Connect(function()
			icon:Destroy()
		end)
		fly:Play()
	end
end

function JuiceController.Init()
	-- Same insets as the HUD, so HUD positions and ours line up.
	gui = UILib.createScreenGui("Juice", Theme.Layers.Notification)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function JuiceController.Start()
	Remotes.event("Celebrate").OnClientEvent:Connect(onCelebrate)
	Remotes.event("OrderResult").OnClientEvent:Connect(function(position: Vector3, coins: number)
		flyCoins(position, coins)
	end)
	RunService:BindToRenderStep("JuiceShake", Enum.RenderPriority.Camera.Value + 1, applyShake)
end

return JuiceController
