--!strict
--[[
	RebirthController
	The Rebirth Machine window (HUD "Rebirth" button or the Hub counter).
	  * Rebirth tab: what resets / what you keep, progress toward the requirement,
	    your current and next Coin multiplier, and the Rebirth button (tap twice)
	  * Skills tab: the Rebirth Token skill tree - two roots, three branches, with
	    each skill's level, current -> next effect and Token cost
	Only displays RebirthRules results and sends requests; the server decides.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Modules.Formulas)
local GameConfig = require(Shared.Data.GameConfig)
local GameData = require(Shared.Types.GameData)
local NumberFormat = require(Shared.Modules.NumberFormat)
local RebirthRules = require(Shared.Modules.RebirthRules)
local RebirthSkills = require(Shared.Data.RebirthSkills)
local Remotes = require(Shared.Modules.Remotes)

local UI = script.Parent.Parent.UI
local Cleaner = require(UI.Cleaner)
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)
local WindowManager = require(UI.WindowManager)

local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

local player = Players.LocalPlayer
local Colors = Theme.Colors

local WINDOW_NAME = "Rebirth"
local TABS = { "Rebirth", "Skills" }
local CONFIRM_SECONDS = 3

-- Skill tree layout: where each card sits (fractions of the tab) and which card it hangs from.
local TREE: { [string]: Vector2 } = {
	FasterCustomers = Vector2.new(0.27, 0.2),
	StartingCoins = Vector2.new(0.73, 0.2),
	BiggerTips = Vector2.new(0.14, 0.7),
	RushHourDuration = Vector2.new(0.4, 0.7),
	ExtraPetSlot = Vector2.new(0.73, 0.7),
}
local CARD_SIZE = Vector2.new(0.24, 0.42)

local RebirthController = {}

local window: UILib.Window
local content = Cleaner.new()
local selectedTab = TABS[1]
local refresh: (() -> ())? = nil

local function request(remoteName: Remotes.FunctionName, ...: any)
	local args = table.pack(...)
	task.spawn(function()
		local remote = Remotes.func(remoteName)
		local ok, result = pcall(remote.InvokeServer, remote, table.unpack(args, 1, args.n))
		if ok and type(result) == "table" then
			NotificationController.toast(result.Message, if result.Ok then "Success" else "Error")
		else
			NotificationController.toast("Something went wrong. Try again!", "Error")
		end
	end)
end

-- ===== Rebirth tab =====

local function listPanel(parent: Instance, title: string, items: { string }, color: Color3, x: number)
	local panel = UILib.createFrame(parent, {
		Position = UDim2.fromScale(x, 0.18),
		Size = UDim2.fromScale(0.47, 0.42),
		BackgroundColor3 = Colors.CreamDark,
	})
	UILib.addCorner(panel, UDim.new(0.1, 0))
	UILib.addStroke(panel, Theme.Sizes.Outline, color)
	UILib.createLabel(panel, {
		Position = UDim2.fromScale(0.05, 0.03),
		Size = UDim2.fromScale(0.9, 0.18),
		Text = title,
		TextColor3 = color,
	})
	for index, item in items do
		UILib.createLabel(panel, {
			Position = UDim2.fromScale(0.08, 0.06 + index * 0.13),
			Size = UDim2.fromScale(0.84, 0.12),
			Text = `• {item}`,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
end

local function buildRebirthTab(holder: Frame): () -> ()
	local summary = UILib.createLabel(holder, {
		Size = UDim2.fromScale(1, 0.14),
	})
	listPanel(holder, "Resets", RebirthRules.RESETS, Colors.Cherry, 0)
	listPanel(holder, "You keep", RebirthRules.KEEPS, Colors.GreenDark, 0.53)

	local bar = UILib.createSpriteBar(holder, "BarFrame", Colors.Pink, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromScale(0.7, 0.16),
	})
	local barText = UILib.createLabel(holder, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.79),
		Size = UDim2.fromScale(0.8, 0.07),
	})
	local button = UILib.createButton(holder, {
		Text = "Rebirth",
		Style = "Pink",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(0.4, 0.12),
	})

	local armedUntil = 0
	content:add(UILib.onActivated(button, function()
		if os.clock() < armedUntil then
			armedUntil = 0
			request("Rebirth")
		else
			armedUntil = os.clock() + CONFIRM_SECONDS
			UILib.setButtonText(button, "Tap again to confirm!")
			task.delay(CONFIRM_SECONDS, function()
				if refresh then
					refresh()
				end
			end)
		end
	end))

	return function()
		local data = DataController.getData()
		if data == nil then
			return
		end
		local requirement = RebirthRules.requirement(data)
		local now = Formulas.rebirthCoinMultiplier(data.Rebirths)
		local nextMultiplier = Formulas.rebirthCoinMultiplier(data.Rebirths + 1)
		summary.Text = string.format(
			"Rebirths: %d  ·  Coins x%.2f  →  x%.2f  ·  +%d Token  ·  You have %d Tokens",
			data.Rebirths,
			now,
			nextMultiplier,
			GameConfig.Rebirth.TokensPerRebirth,
			data.RebirthTokens
		)
		bar.set(data.Coins / requirement, true)
		barText.Text = `{NumberFormat.short(data.Coins)} / {NumberFormat.short(requirement)} Coins`
		if os.clock() >= armedUntil then
			UILib.setButtonText(button, "Rebirth")
		end
		UILib.setButtonStyle(button, if RebirthRules.canRebirth(data) then "Pink" else "Disabled")
	end
end

-- ===== Skills tab =====

local function connector(parent: Instance, from: Vector2, to: Vector2)
	-- A thick line between two card centers (drawn under the cards).
	local holder = parent :: GuiObject
	local function draw()
		local size = holder.AbsoluteSize
		local a = Vector2.new(from.X * size.X, from.Y * size.Y)
		local b = Vector2.new(to.X * size.X, to.Y * size.Y)
		local line = holder:FindFirstChild(`Line{from}{to}`) :: Frame?
		if line == nil then
			local created = UILib.createFrame(holder, {
				Name = `Line{from}{to}`,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Colors.Waffle,
				ZIndex = 0,
			})
			line = created
		end
		local frame = line :: Frame
		frame.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
		frame.Size = UDim2.fromOffset((b - a).Magnitude, 6)
		frame.Rotation = math.deg(math.atan2(b.Y - a.Y, b.X - a.X))
	end
	content:add(holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(draw))
	draw()
end

local function buildSkillCard(parent: Instance, skill: GameData.SkillDef): () -> ()
	local position = TREE[skill.Id] or Vector2.new(0.5, 0.5)
	local card = UILib.createFrame(parent, {
		Name = skill.Id,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(position.X, position.Y),
		Size = UDim2.fromScale(CARD_SIZE.X, CARD_SIZE.Y),
		BackgroundColor3 = Colors.CreamDark,
		ZIndex = 2,
	})
	UILib.addCorner(card, UDim.new(0.12, 0))
	UILib.addStroke(card, Theme.Sizes.Outline)

	local icon = UILib.createIcon(card, skill.Icon, Colors.FrostingBlue, skill.DisplayName:sub(1, 1), {
		Position = UDim2.fromScale(0.04, 0.05),
		Size = UDim2.fromScale(0.3, 0.3),
		ZIndex = 3,
	})
	UILib.addAspect(icon, 1)
	UILib.createLabel(card, {
		Position = UDim2.fromScale(0.36, 0.05),
		Size = UDim2.fromScale(0.6, 0.18),
		Text = skill.DisplayName,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	local levelText = UILib.createLabel(card, {
		Position = UDim2.fromScale(0.36, 0.23),
		Size = UDim2.fromScale(0.6, 0.12),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.TextMuted,
		ZIndex = 3,
	})
	local effectText = UILib.createLabel(card, {
		Position = UDim2.fromScale(0.05, 0.4),
		Size = UDim2.fromScale(0.9, 0.24),
		TextColor3 = Colors.GreenDark,
		ZIndex = 3,
	})
	local button = UILib.createButton(card, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromScale(0.85, 0.24),
		ZIndex = 3,
	})
	content:add(UILib.onActivated(button, function()
		request("BuySkill", skill.Id)
	end))

	return function()
		local data = DataController.getData()
		if data == nil then
			return
		end
		local status = RebirthRules.skillStatus(data, skill.Id)
		levelText.Text = `Lv {status.Level}/{status.MaxLevel}`
		local current = RebirthRules.describeValue(skill.Id, RebirthRules.skillValue(data, skill.Id))
		if status.State == "Maxed" then
			effectText.Text = current
			UILib.setButtonText(button, "MAX")
			UILib.setButtonStyle(button, "Disabled")
		elseif status.State == "Locked" then
			local required = skill.Requires :: { SkillId: string, Level: number }
			effectText.Text = `Needs {RebirthSkills[required.SkillId].DisplayName} Lv {required.Level}`
			UILib.setButtonText(button, "Locked")
			UILib.setButtonStyle(button, "Disabled")
		else
			local nextValue = RebirthRules.describeValue(skill.Id, skill.Values[status.Level + 1])
			effectText.Text = if status.Level == 0 then nextValue else `{current} → {nextValue}`
			local cost = status.Cost :: number
			UILib.setButtonText(button, `{cost} Token{if cost == 1 then "" else "s"}`)
			UILib.setButtonStyle(button, if status.CanBuy then "Primary" else "Disabled")
		end
	end
end

local function buildSkillsTab(holder: Frame): () -> ()
	local tokens = UILib.createLabel(holder, { Size = UDim2.fromScale(1, 0.08) })
	local tree = UILib.createFrame(holder, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.08),
		Size = UDim2.fromScale(1, 0.92),
	})
	for id, skill in RebirthSkills do
		if skill.Requires and TREE[id] and TREE[skill.Requires.SkillId] then
			connector(tree, TREE[skill.Requires.SkillId], TREE[id])
		end
	end
	local updaters = {}
	for _, skill in RebirthSkills do
		table.insert(updaters, buildSkillCard(tree, skill))
	end
	return function()
		local data = DataController.getData()
		if data then
			tokens.Text = `Rebirth Tokens: {data.RebirthTokens}   (earn 1 per rebirth)`
		end
		for _, update in updaters do
			update()
		end
	end
end

-- ===== Window =====

local function buildTab(tabName: string, holder: Frame)
	holder:ClearAllChildren()
	refresh = if tabName == "Rebirth" then buildRebirthTab(holder) else buildSkillsTab(holder);
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
			refresh and (#path == 0 or key == "Coins" or key == "Rebirths" or key == "RebirthTokens" or key == "Skills")
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

function RebirthController.Init() end

function RebirthController.Start()
	local gui = UILib.createScreenGui("RebirthGui", Theme.Layers.Window)
	window = UILib.createWindow(gui, { Title = "Rebirth Machine" })
	UILib.onActivated(window.CloseButton, function()
		WindowManager.close(WINDOW_NAME)
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	WindowManager.register(WINDOW_NAME, open, close)
end

return RebirthController
