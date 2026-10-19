--!strict
--[[
	NotificationController
	Toast messages stacked at the top of the screen (newest on top, max 3).
	  NotificationController.toast("Upgraded!", "Success")
	Also shows the server's Notify messages.
	Stage 8 adds the Rush Hour banner and rare-customer alerts here.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
	gui.Parent = player:WaitForChild("PlayerGui")
end

function NotificationController.Start()
	Remotes.event("Notify").OnClientEvent:Connect(function(message: string, kind: string)
		NotificationController.toast(message, if kind == "Error" then "Error" else "Info")
	end)
end

return NotificationController
