--!strict
--[[
	SettingsController
	The Settings window (HUD "Settings" button):
	  Music / Sound effects volume sliders (drag with mouse or finger)
	  Show tips (the tutorial arrows) and Coin popups toggles
	Changes preview instantly and are saved through the UpdateSettings remote
	when you let go of a slider or flip a toggle. The server clamps everything.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local UI = script.Parent.Parent.UI
local Cleaner = require(UI.Cleaner)
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)
local WindowManager = require(UI.WindowManager)

local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

local player = Players.LocalPlayer
local Colors = Theme.Colors

local WINDOW_NAME = "Settings"
local ROW_HEIGHT = 0.2

local SettingsController = {}

local window: UILib.Window
local content = Cleaner.new()

local function save(changes: { [string]: any })
	task.spawn(function()
		local remote = Remotes.func("UpdateSettings")
		local ok, result = pcall(remote.InvokeServer, remote, changes)
		if not ok or type(result) ~= "table" or not result.Ok then
			NotificationController.toast("Couldn't save settings. Try again!", "Error")
		end
	end)
end

local function createRow(order: number, text: string): Frame
	local row = content:add(UILib.createFrame(window.Body, {
		Name = text,
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, ROW_HEIGHT),
	}))
	UILib.createLabel(row, {
		Size = UDim2.fromScale(0.36, 0.6),
		Position = UDim2.fromScale(0, 0.2),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
	})
	return row
end

-- A 0..1 slider. onPreview runs while dragging, onCommit once on release.
local function createSlider(
	order: number,
	text: string,
	value: number,
	onPreview: (number) -> (),
	onCommit: (number) -> ()
)
	local row = createRow(order, text)
	local track = UILib.createFrame(row, {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.4, 0.5),
		Size = UDim2.fromScale(0.46, 0.3),
		BackgroundColor3 = Colors.CreamDark,
		Active = true,
	})
	UILib.addCorner(track, Theme.Sizes.CornerPill)
	UILib.addStroke(track, Theme.Sizes.Outline)
	local fill = UILib.createFrame(track, {
		Name = "Fill",
		Size = UDim2.fromScale(value, 1),
		BackgroundColor3 = Colors.Pink,
	})
	UILib.addCorner(fill, Theme.Sizes.CornerPill)
	local knob = UILib.createFrame(track, {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(value, 0.5),
		Size = UDim2.fromScale(2.2, 2.2), -- relative to the track height (aspect below)
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = Colors.Cream,
		ZIndex = 2,
	})
	UILib.addCorner(knob, Theme.Sizes.CornerPill)
	UILib.addStroke(knob, Theme.Sizes.Outline)
	UILib.addSizeLimit(knob, Theme.Sizes.MinTapTarget) -- easy to grab on phones
	local percent = UILib.createLabel(row, {
		Position = UDim2.fromScale(0.89, 0.2),
		Size = UDim2.fromScale(0.11, 0.6),
	})

	local current = value
	local function show(newValue: number)
		current = newValue
		fill.Size = UDim2.fromScale(newValue, 1)
		knob.Position = UDim2.fromScale(newValue, 0.5)
		percent.Text = `{math.floor(newValue * 100 + 0.5)}%`
	end
	show(value)

	local dragging: InputObject? = nil
	local function setFromX(x: number)
		local fraction = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		show(fraction)
		onPreview(fraction)
	end
	local function startDrag(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = input
			setFromX(input.Position.X)
		end
	end
	content:add(track.InputBegan:Connect(startDrag))
	content:add(knob.InputBegan:Connect(startDrag))
	content:add(UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging == nil then
			return
		end
		local kind = input.UserInputType
		-- Mouse: any mouse movement. Touch: only the finger that started the drag.
		if
			(kind == Enum.UserInputType.MouseMovement and dragging.UserInputType == Enum.UserInputType.MouseButton1)
			or input == dragging
		then
			setFromX(input.Position.X)
		end
	end))
	content:add(UserInputService.InputEnded:Connect(function(input: InputObject)
		if dragging and (input == dragging or input.UserInputType == dragging.UserInputType) then
			dragging = nil
			onCommit(current)
		end
	end))
end

local function createToggle(order: number, text: string, value: boolean, onChange: (boolean) -> ())
	local row = createRow(order, text)
	local state = value
	local button = UILib.createButton(row, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.4, 0.5),
		Size = UDim2.fromScale(0.22, 0.75),
	})
	local function show()
		UILib.setButtonText(button, if state then "ON" else "OFF")
		UILib.setButtonStyle(button, if state then "Primary" else "Secondary")
	end
	show()
	content:add(UILib.onActivated(button, function()
		state = not state
		show()
		onChange(state)
	end))
end

local function open()
	content:clean()
	UILib.tweenIn(window.Root)
	local data = DataController.getData()
	if data == nil then
		return
	end
	local settings = data.Settings

	local layout = content:add(Instance.new("UIListLayout"))
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.04, 0)
	layout.Parent = window.Body

	createSlider(1, "Music", settings.MusicVolume, function(volume)
		UILib.soundGroup("Music").Volume = volume
	end, function(volume)
		save({ MusicVolume = volume })
	end)
	createSlider(2, "Sound effects", settings.SfxVolume, function(volume)
		UILib.soundGroup("SFX").Volume = volume
	end, function(volume)
		save({ SfxVolume = volume })
	end)
	createToggle(3, "Show tips", settings.ShowTips, function(on)
		save({ ShowTips = on })
	end)
	createToggle(4, "Coin popups", settings.ShowPopups, function(on)
		save({ ShowPopups = on })
	end)
end

local function close()
	UILib.tweenOut(window.Root, function()
		content:clean()
	end)
end

function SettingsController.Init() end

function SettingsController.Start()
	local gui = UILib.createScreenGui("SettingsGui", Theme.Layers.Window)
	window = UILib.createWindow(gui, { Title = "Settings", AspectRatio = 1.5, MaxSize = Vector2.new(640, 430) })
	UILib.onActivated(window.CloseButton, function()
		WindowManager.close(WINDOW_NAME)
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	WindowManager.register(WINDOW_NAME, open, close)
end

return SettingsController
