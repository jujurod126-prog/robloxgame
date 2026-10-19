--!strict
--[[
	NotificationController
	Toast messages stacked at the top of the screen (newest on top, max 3).
	  NotificationController.toast("Upgraded!", "Success")
	Also shows the server's Notify messages (errors play the error sound).

	Event banner (EventBanner remote, or NotificationController.banner(text, seconds)):
	a big ribbon under the HUD's location badge. Rush Hour banners count down to
	this player's own end time (Player attribute RushHourEnds).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Modules.Assets)
local NumberFormat = require(ReplicatedStorage.Shared.Modules.NumberFormat)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)

local player = Players.LocalPlayer

local MAX_TOASTS = 3
local SHOW_SECONDS = 2.6

local NotificationController = {}

local stack: Frame
local order = 0
local bannerFrame: Frame
local bannerLabel: TextLabel
local bannerToken = 0

function NotificationController.toast(text: string, kind: UILib.ToastKind?)
	-- Drop the oldest if the stack is full.
	local toasts = {}
	for _, child in stack:GetChildren() do
		if child:IsA("CanvasGroup") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = 1, #toasts - MAX_TOASTS + 1 do
		toasts[index]:Destroy()
	end

	order -= 1 -- newest first in the list layout
	local toast = UILib.createToast(stack, text, kind)
	toast.LayoutOrder = order
	toast.GroupTransparency = 1
	toast.Size = UDim2.fromScale(1, 1 / MAX_TOASTS - 0.04)

	TweenService:Create(toast, Theme.Motion.Open, { GroupTransparency = 0 }):Play()
	task.delay(SHOW_SECONDS, function()
		if toast.Parent == nil then
			return
		end
		local fade = TweenService:Create(toast, Theme.Motion.Close, { GroupTransparency = 1 })
		fade.Completed:Connect(function()
			toast:Destroy()
		end)
		fade:Play()
	end)
end

-- Shows the event banner for `seconds`. countdownTo (server time) adds a "0:42" timer.
function NotificationController.banner(text: string, seconds: number, countdownTo: number?)
	bannerToken += 1
	local token = bannerToken
	local endsAt = countdownTo or (Workspace:GetServerTimeNow() + seconds)
	bannerFrame.Visible = true
	bannerFrame.Size = UDim2.fromScale(0, 0.07)
	TweenService:Create(bannerFrame, Theme.Motion.Open, { Size = UDim2.fromScale(0.46, 0.07) }):Play()
	task.spawn(function()
		while token == bannerToken do
			local left = endsAt - Workspace:GetServerTimeNow()
			if left <= 0 then
				break
			end
			bannerLabel.Text = if countdownTo then `{text}  {NumberFormat.duration(math.ceil(left))}` else text
			task.wait(0.25)
		end
		if token == bannerToken then
			local close = TweenService:Create(bannerFrame, Theme.Motion.Close, { Size = UDim2.fromScale(0, 0.07) })
			close.Completed:Connect(function()
				if token == bannerToken then
					bannerFrame.Visible = false
				end
			end)
			close:Play()
		end
	end)
end

local function createBanner(gui: ScreenGui)
	local outer, inner = UILib.createPanel(gui, {
		Name = "EventBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.165),
		Size = UDim2.fromScale(0.46, 0.07),
		Visible = false,
		ClipsDescendants = true,
	}, Theme.Sizes.CornerPill)
	UILib.addSizeLimit(outer, Vector2.new(0, 40), Vector2.new(620, 64))
	inner.BackgroundColor3 = Theme.Colors.Pink
	bannerLabel = UILib.createLabel(inner, {
		Name = "Text",
		Position = UDim2.fromScale(0.04, 0.1),
		Size = UDim2.fromScale(0.92, 0.8),
	})
	UILib.outlinedText(bannerLabel)
	bannerFrame = outer
end

function NotificationController.Init()
	local gui = UILib.createScreenGui("Notifications", Theme.Layers.Notification)
	stack = UILib.createFrame(gui, {
		Name = "Stack",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.11),
		Size = UDim2.fromScale(0.42, 0.2),
		BackgroundTransparency = 1,
	})
	UILib.addSizeLimit(stack, Vector2.new(260, 100), Vector2.new(560, 170))
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.03, 0)
	layout.Parent = stack
	createBanner(gui)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function NotificationController.Start()
	Remotes.event("Notify").OnClientEvent:Connect(function(message: string, kind: string)
		if kind == "Error" then
			UILib.playSound(Assets.SFX_ERROR, 1, 0.5)
		end
		NotificationController.toast(message, if kind == "Error" then "Error" else "Info")
	end)
	Remotes.event("EventBanner").OnClientEvent:Connect(function(text: string, seconds: number, kind: string)
		local ends = player:GetAttribute("RushHourEnds") :: number?
		if kind == "RushHour" then
			-- RushHourEnds is set right after the banner is sent; give it a moment.
			task.wait(0.5)
			ends = player:GetAttribute("RushHourEnds") :: number?
		end
		local countdown = if kind == "RushHour" and ends and ends > Workspace:GetServerTimeNow() then ends else nil
		NotificationController.banner(text, seconds, countdown)
	end)
end

return NotificationController
