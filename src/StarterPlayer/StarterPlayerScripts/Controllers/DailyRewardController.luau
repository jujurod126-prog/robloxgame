--!strict
--[[
	DailyRewardController
	The Daily Reward window (HUD "Daily" button): a 7-day calendar with the
	streak, today's reward highlighted, a Claim button and a countdown to the
	next claim. Day 7's egg plays the hatch animation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Modules.Assets)
local DailyRewards = require(Shared.Data.DailyRewards)
local Eggs = require(Shared.Data.Eggs)
local NumberFormat = require(Shared.Modules.NumberFormat)
local QuestRules = require(Shared.Modules.QuestRules)
local Remotes = require(Shared.Modules.Remotes)
local RewardUtil = require(Shared.Modules.RewardUtil)

local UI = script.Parent.Parent.UI
local Cleaner = require(UI.Cleaner)
local HatchAnimation = require(UI.HatchAnimation)
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)
local WindowManager = require(UI.WindowManager)

local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

local player = Players.LocalPlayer
local Colors = Theme.Colors

local WINDOW_NAME = "Daily"

local DailyRewardController = {}

local window: UILib.Window
local content = Cleaner.new()

local function rewardIcon(reward: any): (string?, Color3)
	if reward.EggId and Eggs[reward.EggId] then
		return Eggs[reward.EggId].Icon, Colors.Pink
	elseif reward.Gems then
		return Assets.ICON_GEM, Colors.Gem
	end
	return Assets.ICON_COIN, Colors.Coin
end

local function open()
	content:clean()
	UILib.tweenIn(window.Root)
	local body = window.Body

	local streakLabel = content:add(UILib.createLabel(body, {
		Size = UDim2.fromScale(1, 0.1),
	}))

	-- 7 day cards in a row (day 7 is bigger and pink).
	local row = content:add(UILib.createFrame(body, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.14),
		Size = UDim2.fromScale(1, 0.5),
	}))
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.012, 0)
	layout.Parent = row

	local cards = {}
	for _, entry in DailyRewards do
		local big = entry.Day == #DailyRewards
		local card = UILib.createFrame(row, {
			Name = `Day{entry.Day}`,
			LayoutOrder = entry.Day,
			Size = UDim2.fromScale(if big then 0.18 else 0.125, if big then 1 else 0.86),
			BackgroundColor3 = if big then Colors.FrostingPink else Colors.CreamDark,
		})
		UILib.addCorner(card, UDim.new(0.15, 0))
		local stroke = UILib.addStroke(card, Theme.Sizes.Outline)
		UILib.createLabel(card, {
			Position = UDim2.fromScale(0.05, 0.03),
			Size = UDim2.fromScale(0.9, 0.16),
			Text = `Day {entry.Day}`,
		})
		local iconId, color = rewardIcon(entry.Reward)
		local icon = UILib.createIcon(card, iconId, color, nil, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.22),
			Size = UDim2.fromScale(0.7, 0.4),
		})
		UILib.addAspect(icon, 1)
		UILib.createLabel(card, {
			Position = UDim2.fromScale(0.05, 0.66),
			Size = UDim2.fromScale(0.9, 0.3),
			Text = RewardUtil.describe(entry.Reward),
		})
		local check = UILib.createLabel(card, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromScale(0.8, 0.3),
			Text = "CLAIMED",
			TextColor3 = Colors.GreenDark,
			Rotation = -12,
			Visible = false,
			ZIndex = 3,
		})
		cards[entry.Day] = { card = card, stroke = stroke, check = check }
	end

	local status = content:add(UILib.createLabel(body, {
		Position = UDim2.fromScale(0, 0.68),
		Size = UDim2.fromScale(1, 0.1),
		TextColor3 = Colors.TextMuted,
	}))
	local button = content:add(UILib.createButton(body, {
		Text = "Claim",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.98),
		Size = UDim2.fromScale(0.36, 0.15),
	}))

	local busy = false
	local function update()
		local data = DataController.getData()
		if data == nil then
			return
		end
		local daily = QuestRules.dailyStatus(data, Workspace:GetServerTimeNow())
		local streak = if daily.StreakResets then 0 else data.Daily.Streak
		streakLabel.Text = `Streak: {streak} day{if streak == 1 then "" else "s"} in a row`
			.. (if daily.StreakResets then " (missed a day - starting over!)" else "")
		-- Days already claimed in the current 7-day loop.
		local claimedInLoop = if daily.CanClaim then daily.Day - 1 else ((streak - 1) % #DailyRewards) + 1
		for day, info in cards do
			info.check.Visible = day <= claimedInLoop
			info.stroke.Color = if daily.CanClaim and day == daily.Day then Colors.Green else Colors.Outline
			info.stroke.Thickness = if daily.CanClaim and day == daily.Day then 5 else Theme.Sizes.Outline
		end
		if daily.CanClaim then
			status.Text = `Day {daily.Day} is ready!`
			UILib.setButtonText(button, "Claim")
			UILib.setButtonStyle(button, if busy then "Disabled" else "Primary")
		else
			status.Text = `Next reward in {NumberFormat.duration(daily.SecondsUntilClaim)}`
			UILib.setButtonText(button, "Come back later")
			UILib.setButtonStyle(button, "Disabled")
		end
	end

	content:add(UILib.onActivated(button, function()
		if busy then
			return
		end
		busy = true
		update()
		local data = DataController.getData()
		local day = if data then QuestRules.dailyStatus(data, Workspace:GetServerTimeNow()).Day else 1
		local eggId = DailyRewards[day].Reward.EggId
		task.spawn(function()
			local remote = Remotes.func("ClaimDaily")
			local ok, result = pcall(remote.InvokeServer, remote)
			if ok and type(result) == "table" then
				NotificationController.toast(result.Message, if result.Ok then "Success" else "Error")
				if result.Ok and result.Pets and eggId then
					HatchAnimation.play(eggId, result.Pets)
				end
			else
				NotificationController.toast("Something went wrong. Try again!", "Error")
			end
			busy = false
			update()
		end)
	end))

	content:add(DataController.Changed:Connect(function(path: { any })
		if #path == 0 or path[1] == "Daily" then
			update()
		end
	end))
	-- Keep the countdown ticking while open.
	local alive = true
	content:add(function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			update()
			task.wait(1)
		end
	end)
end

local function close()
	UILib.tweenOut(window.Root, function()
		content:clean()
	end)
end

function DailyRewardController.Init() end

function DailyRewardController.Start()
	local gui = UILib.createScreenGui("DailyGui", Theme.Layers.Window)
	window = UILib.createWindow(gui, { Title = "Daily Rewards", AspectRatio = 1.8 })
	UILib.onActivated(window.CloseButton, function()
		WindowManager.close(WINDOW_NAME)
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	WindowManager.register(WINDOW_NAME, open, close)
end

return DailyRewardController
