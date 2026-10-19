--!strict
--[[
	TutorialController
	The first-time tutorial. Four steps, each with a tip box and a pointer:
	  1. Scoop ice cream      - glow + bouncing arrow on your truck's dispenser
	  2. Serve a customer     - glow + arrow on your waiting customer
	  3. Buy an upgrade       - pulsing arrow at the HUD Shop button
	  4. Open the Flavor Lab  - pulsing arrow at the HUD Flavors button
	Progress is saved through the TutorialProgress remote (PlayerData.Tutorial:
	Step = steps finished, Completed = done or skipped), so it continues after a
	rejoin. "Skip" ends it for good. Settings "Show tips" off hides it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local PlayerDataTypes = require(Shared.Types.PlayerData)
local Remotes = require(Shared.Modules.Remotes)

local UI = script.Parent.Parent.UI
local Cleaner = require(UI.Cleaner)
local HudLayout = require(UI.HudLayout)
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)
local WindowManager = require(UI.WindowManager)

local DataController = require(script.Parent.DataController)
local HudController = require(script.Parent.HudController)
local NotificationController = require(script.Parent.NotificationController)

type PlayerData = PlayerDataTypes.PlayerData

type Step = {
	Text: string,
	WorldTarget: (() -> Instance?)?, -- something in the world to point at
	HudButton: string?, -- or a HUD menu button
	isDone: (data: PlayerData) -> boolean,
}

local player = Players.LocalPlayer
local Colors = Theme.Colors

local CHECK_SECONDS = 0.5
local BOUNCE = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local function myTruck(): Model?
	local folder = Workspace:FindFirstChild("Trucks")
	local truck = folder and folder:FindFirstChild(`Truck_{player.UserId}`)
	return if truck and truck:IsA("Model") then truck else nil
end

local function myWaitingCustomer(): Instance?
	local folder = Workspace:FindFirstChild("Customers")
	if folder == nil then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:GetAttribute("OwnerUserId") == player.UserId and model:GetAttribute("State") == "Waiting" then
			return model
		end
	end
	return nil
end

local function upgradesBought(data: PlayerData): boolean
	if data.Truck.Tier > 1 then
		return true
	end
	for _, level in data.Truck.Upgrades do
		if level > 1 then
			return true
		end
	end
	return false
end

local STEPS: { Step } = {
	{
		Text = "Hold the button at your truck's dispenser to scoop ice cream!",
		WorldTarget = function()
			local truck = myTruck()
			return truck and truck:FindFirstChild("Dispenser", true)
		end,
		isDone = function(data)
			return ((player:GetAttribute("ConeScoops") :: number?) or 0) >= 1 or data.Stats.CustomersServed >= 1
		end,
	},
	{
		Text = "Give the cone to a waiting customer. Match their order for big tips!",
		WorldTarget = myWaitingCustomer,
		isDone = function(data)
			return data.Stats.CustomersServed >= 1
		end,
	},
	{
		Text = "Nice! Open the Shop and buy your first upgrade.",
		HudButton = "Shop",
		isDone = upgradesBought,
	},
	{
		Text = "Open the Flavor Lab to unlock new flavors.",
		HudButton = "Flavors",
		isDone = function()
			return WindowManager.isOpen("Flavors")
		end,
	},
}

local TutorialController = {}

local gui: ScreenGui
local tipFrame: Frame
local tipLabel: TextLabel
local pointer = Cleaner.new() -- the current arrow / highlight
local pointedAt: Instance? = nil
local sentStep = 0 -- highest step we've reported, so we don't spam the server
local finished = false

local function report(step: number, completed: boolean)
	if step <= sentStep and not completed then
		return
	end
	sentStep = math.max(sentStep, step)
	task.spawn(function()
		local remote = Remotes.func("TutorialProgress")
		pcall(remote.InvokeServer, remote, step, completed)
	end)
end

local function pointAtWorld(target: Instance)
	local highlight = pointer:add(Instance.new("Highlight"))
	highlight.FillColor = Colors.Coin
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.Adornee = target
	highlight.Parent = target

	local billboard = pointer:add(Instance.new("BillboardGui"))
	billboard.Adornee = target
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromScale(2.5, 2.5)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	local arrow = UILib.createLabel(billboard, { Text = "▼", TextColor3 = Colors.Coin })
	arrow.TextStrokeColor3 = Colors.Outline
	arrow.TextStrokeTransparency = 0
	billboard.Parent = player:WaitForChild("PlayerGui") -- not inside a ScreenGui, or it won't render
	local bounce =
		pointer:add(TweenService:Create(billboard, BOUNCE, { StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0) }))
	bounce:Play()
end

local function pointAtButton(button: GuiObject)
	local arrow = pointer:add(UILib.createLabel(gui, {
		Name = "TutorialArrow",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(56, 56),
		Text = "▶",
		TextColor3 = Colors.Coin,
		ZIndex = 5,
	}))
	arrow.TextStrokeColor3 = Colors.Outline
	arrow.TextStrokeTransparency = 0
	local function place(offset: number)
		local inset = gui.AbsolutePosition
		local x = button.AbsolutePosition.X - inset.X - offset
		local y = button.AbsolutePosition.Y - inset.Y + button.AbsoluteSize.Y / 2
		return UDim2.fromOffset(x, y)
	end
	arrow.Position = place(4)
	local bounce = pointer:add(TweenService:Create(arrow, BOUNCE, { Position = place(20) }))
	bounce:Play()
	-- Re-place if the screen resizes (rotating a phone).
	pointer:add(button:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		bounce:Cancel()
		arrow.Position = place(4)
		bounce = pointer:add(TweenService:Create(arrow, BOUNCE, { Position = place(20) }))
		bounce:Play()
	end))
end

local function clearPointer()
	pointer:clean()
	pointedAt = nil
end

local function finish(skipped: boolean)
	if finished then
		return
	end
	finished = true
	report(#STEPS, true)
	clearPointer()
	tipFrame.Visible = false
	if not skipped then
		NotificationController.toast("Tutorial done! Serve customers to earn Coins and grow your empire!", "Success")
	end
end

-- Runs a few times a second: works out the current step and updates the tip.
local function check()
	local data = DataController.getData()
	if finished or data == nil or data.Tutorial.Completed then
		clearPointer()
		tipFrame.Visible = false
		return false
	end
	local stepIndex = math.max(data.Tutorial.Step, sentStep) + 1
	local step = STEPS[stepIndex]
	if step == nil then
		finish(false)
		return false
	end
	if step.isDone(data) then
		if stepIndex == #STEPS then
			finish(false)
			return false
		end
		report(stepIndex, false)
		clearPointer()
		return true
	end

	if not data.Settings.ShowTips then
		clearPointer()
		tipFrame.Visible = false
		return true
	end
	tipFrame.Visible = true
	tipLabel.Text = `({stepIndex}/{#STEPS}) {step.Text}`

	local target: Instance? = nil
	if step.WorldTarget then
		target = step.WorldTarget()
	elseif step.HudButton then
		target = HudController.getMenuButton(step.HudButton)
	end
	if target ~= pointedAt or (target and target.Parent == nil) then
		clearPointer()
		if target and target.Parent then
			if target:IsA("GuiObject") then
				pointAtButton(target)
			else
				pointAtWorld(target)
			end
			pointedAt = target
		end
	end
	return true
end

local function createTip()
	local outer, inner = UILib.createPanel(gui, {
		Name = "TutorialTip",
		-- Left side, under the Coins / Gems counters (clear of the order bar on phones).
		Position = UDim2.fromScale(0.035, 0.22),
		Size = UDim2.fromScale(0.32, 0.13),
		Visible = false,
	})
	UILib.addSizeLimit(outer, Vector2.new(250, 64), Vector2.new(460, 110))
	tipLabel = UILib.createLabel(inner, {
		Name = "Text",
		Position = UDim2.fromScale(0.03, 0.08),
		Size = UDim2.fromScale(0.72, 0.84),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local skip = UILib.createButton(inner, {
		Name = "Skip",
		Text = "Skip",
		Style = "Secondary",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.98, 0.5),
		Size = UDim2.fromScale(0.2, 0.8),
	})
	UILib.onActivated(skip, function()
		finish(true)
	end)
	tipFrame = outer
	-- Just under the Coins / Gems counters, whatever size they are.
	HudLayout.watch(function()
		outer.Position = UDim2.new(0.035, 0, 0, HudLayout.get("TopLeft") - gui.AbsolutePosition.Y + 8)
	end)
end

function TutorialController.Init()
	gui = UILib.createScreenGui("Tutorial", Theme.Layers.Notification)
	createTip()
	gui.Parent = player:WaitForChild("PlayerGui")
end

function TutorialController.Start()
	task.spawn(function()
		DataController.waitForData()
		while check() do
			task.wait(CHECK_SECONDS)
		end
	end)
end

return TutorialController
