--!strict
--[[
	QuestController
	The Quests window (HUD "Quests" button).
	  * Daily tab: today's 3 quests with progress bars, rewards and Claim buttons,
	    plus a countdown to the next refresh
	  * Achievements tab: every achievement with progress, reward and Claim
	The daily login calendar is DailyRewardController.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Achievements = require(Shared.Data.Achievements)
local GameData = require(Shared.Types.GameData)
local NumberFormat = require(Shared.Modules.NumberFormat)
local QuestRules = require(Shared.Modules.QuestRules)
local Remotes = require(Shared.Modules.Remotes)
local RewardUtil = require(Shared.Modules.RewardUtil)
local TableUtil = require(Shared.Modules.TableUtil)

local UI = script.Parent.Parent.UI
local Cleaner = require(UI.Cleaner)
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)
local WindowManager = require(UI.WindowManager)

local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

local player = Players.LocalPlayer
local Colors = Theme.Colors

local WINDOW_NAME = "Quests"
local TABS = { "Daily", "Achievements" }

local QuestController = {}

local window: UILib.Window
local content = Cleaner.new()
local selectedTab = TABS[1]
local refresh: (() -> ())? = nil

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function claim(button: TextButton, remoteName: Remotes.FunctionName, argument: any)
	UILib.setButtonStyle(button, "Disabled")
	UILib.setButtonText(button, "...")
	task.spawn(function()
		local remote = Remotes.func(remoteName)
		local ok, result = pcall(remote.InvokeServer, remote, argument)
		if ok and type(result) == "table" then
			NotificationController.toast(result.Message, if result.Ok then "Success" else "Error")
		else
			NotificationController.toast("Something went wrong. Try again!", "Error")
		end
		if refresh then
			refresh()
		end
	end)
end

-- A row: title, reward line, progress bar with "x / y", and a claim button.
local function createRow(list: Instance, order: number)
	local row = UILib.createFrame(list, { Name = "Row", LayoutOrder = order, BackgroundColor3 = Colors.CreamDark })
	UILib.addCorner(row, UDim.new(0.2, 0))
	UILib.addStroke(row, Theme.Sizes.Outline)
	local title = UILib.createLabel(row, {
		Position = UDim2.fromScale(0.03, 0.06),
		Size = UDim2.fromScale(0.66, 0.3),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local reward = UILib.createLabel(row, {
		Position = UDim2.fromScale(0.03, 0.36),
		Size = UDim2.fromScale(0.66, 0.22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.GreenDark,
	})
	local bar = UILib.createProgressBar(row, Colors.Green, {
		Position = UDim2.fromScale(0.03, 0.66),
		Size = UDim2.fromScale(0.5, 0.2),
	})
	local amount = UILib.createLabel(row, {
		Position = UDim2.fromScale(0.55, 0.62),
		Size = UDim2.fromScale(0.15, 0.28),
	})
	local button = UILib.createButton(row, {
		Text = "Claim",
		Position = UDim2.fromScale(0.73, 0.25),
		Size = UDim2.fromScale(0.25, 0.5),
	})
	return title, reward, bar, amount, button
end

local function setClaimButton(button: TextButton, claimed: boolean, ready: boolean)
	if claimed then
		UILib.setButtonText(button, "Claimed")
		UILib.setButtonStyle(button, "Disabled")
	elseif ready then
		UILib.setButtonText(button, "Claim")
		UILib.setButtonStyle(button, "Primary")
	else
		UILib.setButtonText(button, "In progress")
		UILib.setButtonStyle(button, "Disabled")
	end
end

-- ===== Daily tab =====

local function buildDailyTab(holder: Frame): () -> ()
	local timer = UILib.createLabel(holder, {
		Size = UDim2.fromScale(1, 0.1),
		TextColor3 = Colors.TextMuted,
	})
	local list = UILib.createScrollingList(holder, 4.6, {
		Position = UDim2.fromScale(0, 0.12),
		Size = UDim2.fromScale(1, 0.88),
	})
	local rows = {}
	for index = 1, 3 do
		local title, reward, bar, amount, button = createRow(list, index)
		rows[index] = { title = title, reward = reward, bar = bar, amount = amount, button = button }
		content:add(UILib.onActivated(button, function()
			claim(button, "ClaimQuest", index)
		end))
	end

	-- Countdown to the daily refresh, updated once a second while the window is open.
	local alive = true
	content:add(function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			timer.Text = `New quests in {NumberFormat.duration(QuestRules.secondsUntilReset(serverNow()))}`
			task.wait(1)
		end
	end)

	return function()
		local data = DataController.getData()
		if data == nil then
			return
		end
		local current = data.Quests.DayKey == QuestRules.dayKey(serverNow())
		for index, row in rows do
			local quest = if current then data.Quests.Active[index] else nil
			local frame = row.button.Parent :: GuiObject
			frame.Visible = quest ~= nil
			if quest then
				local target = QuestRules.target(quest)
				row.title.Text = QuestRules.description(quest)
				row.reward.Text = RewardUtil.describe(QuestRules.reward(quest))
				row.bar.set(quest.Progress / target, true)
				row.amount.Text = `{NumberFormat.short(quest.Progress)}/{NumberFormat.short(target)}`
				setClaimButton(row.button, quest.Claimed, QuestRules.isComplete(quest))
			end
		end
	end
end

-- ===== Achievements tab =====

local function buildAchievementsTab(holder: Frame): () -> ()
	local list = UILib.createScrollingList(holder, 4.6)
	local updaters = {}
	for _, achievement: GameData.AchievementDef in TableUtil.sortedByOrder(Achievements) do
		local title, reward, bar, amount, button = createRow(list, achievement.Order)
		title.Text = `{achievement.DisplayName} - {achievement.Description}`
		reward.Text = RewardUtil.describe(achievement.Reward)
		content:add(UILib.onActivated(button, function()
			claim(button, "ClaimAchievement", achievement.Id)
		end))
		table.insert(updaters, function(data: any)
			local value = QuestRules.achievementProgress(data, achievement.Id)
			bar.set(value / achievement.Target, true)
			amount.Text =
				`{NumberFormat.short(math.min(value, achievement.Target))}/{NumberFormat.short(achievement.Target)}`
			setClaimButton(button, data.Achievements[achievement.Id] == true, value >= achievement.Target)
		end)
	end
	return function()
		local data = DataController.getData()
		if data then
			for _, update in updaters do
				update(data)
			end
		end
	end
end

-- ===== Window =====

local function buildTab(tabName: string, holder: Frame)
	holder:ClearAllChildren()
	refresh = if tabName == "Daily" then buildDailyTab(holder) else buildAchievementsTab(holder);
	(refresh :: () -> ())()
end

local function open()
	content:clean()
	UILib.tweenIn(window.Root)
	local body = window.Body
	local holder = content:add(UILib.createFrame(body, {
		Name = "TabContent",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.16),
		Size = UDim2.fromScale(1, 0.84),
	}))
	local tabs = UILib.createTabs(body, TABS, function(name)
		selectedTab = name
		buildTab(name, holder)
	end)
	tabs.Frame.Size = UDim2.fromScale(1, 0.12)
	content:add(tabs.Frame)
	tabs.select(selectedTab)

	content:add(DataController.Changed:Connect(function(path: { any })
		local key = path[1]
		if
			refresh and (#path == 0 or key == "Quests" or key == "Achievements" or key == "Stats" or key == "Rebirths")
		then
			refresh()
		end
	end))
	content:add(function()
		refresh = nil
	end)
end

local function close()
	UILib.tweenOut(window.Root, function()
		content:clean()
	end)
end

function QuestController.Init() end

function QuestController.Start()
	local gui = UILib.createScreenGui("QuestGui", Theme.Layers.Window)
	window = UILib.createWindow(gui, { Title = "Quests" })
	UILib.onActivated(window.CloseButton, function()
		WindowManager.close(WINDOW_NAME)
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	WindowManager.register(WINDOW_NAME, open, close)
end

return QuestController
