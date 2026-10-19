--!strict
--[[
	ShopController
	The Truck Garage window (opened from the HUD "Shop" button).
	  * Upgrades tab: the 5 truck stats - level, current -> next value, price, Buy / MAX
	  * Trucks tab: the 6 tiers - Current / Owned / Buy / Locked (needs previous tier or rebirths)

	The window only DISPLAYS prices from ShopRules and sends requests
	(BuyUpgrade(statId), BuyTruckTier(tier)); the server decides and charges.
	All data connections are made on open and cleaned up on close.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameData = require(Shared.Types.GameData)
local NumberFormat = require(Shared.Modules.NumberFormat)
local Remotes = require(Shared.Modules.Remotes)
local ShopRules = require(Shared.Modules.ShopRules)
local TableUtil = require(Shared.Modules.TableUtil)
local Trucks = require(Shared.Data.Trucks)
local Upgrades = require(Shared.Data.Upgrades)

local UI = script.Parent.Parent.UI
local Cleaner = require(UI.Cleaner)
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)
local WindowManager = require(UI.WindowManager)

local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

local player = Players.LocalPlayer
local Colors = Theme.Colors

local WINDOW_NAME = "Shop"
local TABS = { "Upgrades", "Trucks" }
local ROW_ASPECT = 4.4 -- row width : height

local ShopController = {}

local window: UILib.Window
local content = Cleaner.new() -- everything built for the current open/tab
local selectedTab = TABS[1]
local rowUpdaters: { () -> () } = {}

local function formatValue(upgrade: GameData.UpgradeDef, value: number): string
	if upgrade.ValueFormat == "Seconds" then
		return string.format("%.2fs", value)
	elseif upgrade.ValueFormat == "Percent" then
		return `+{math.floor(value * 100 + 0.5)}%`
	elseif upgrade.ValueFormat == "Bonus" then
		return `+{value}`
	end
	return tostring(value)
end

-- Sends a purchase request; the button shows "..." until the server answers.
local function purchase(button: TextButton, remoteName: Remotes.FunctionName, argument: any)
	UILib.setBusy(button, true)
	task.spawn(function()
		local remote = Remotes.func(remoteName)
		local ok, result = pcall(remote.InvokeServer, remote, argument)
		if ok and type(result) == "table" then
			NotificationController.toast(result.Message, if result.Ok then "Success" else "Error")
		else
			NotificationController.toast("Something went wrong. Try again!", "Error")
		end
		UILib.setBusy(button, false)
		for _, update in rowUpdaters do
			update() -- restore buttons even if the data didn't change
		end
	end)
end

local function createRow(parent: Instance, order: number): Frame
	local row = UILib.createFrame(parent, {
		Name = "Row",
		LayoutOrder = order,
		BackgroundColor3 = Colors.CreamDark,
	})
	UILib.addCorner(row, UDim.new(0.2, 0))
	UILib.addStroke(row, Theme.Sizes.Outline)
	return row
end

local function addText(row: Frame, props: { [string]: any }): TextLabel
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return UILib.createLabel(row, props)
end

-- ===== Upgrades tab =====

local function buildUpgradeRow(list: Instance, upgrade: GameData.UpgradeDef)
	local row = createRow(list, upgrade.Order)
	local icon = UILib.createIcon(row, upgrade.Icon, Colors.WaffleLight, upgrade.DisplayName:sub(1, 1), {
		Position = UDim2.fromScale(0.02, 0.08),
		Size = UDim2.fromScale(0.18, 0.84),
	})
	UILib.addAspect(icon, 1)

	addText(row, {
		Position = UDim2.fromScale(0.2, 0.06),
		Size = UDim2.fromScale(0.5, 0.32),
		Text = upgrade.DisplayName,
	})
	addText(row, {
		Position = UDim2.fromScale(0.2, 0.38),
		Size = UDim2.fromScale(0.5, 0.22),
		Text = upgrade.Description,
		TextColor3 = Colors.TextMuted,
	})
	local bar = UILib.createProgressBar(row, Colors.Green, {
		Position = UDim2.fromScale(0.2, 0.68),
		Size = UDim2.fromScale(0.3, 0.17),
	})
	local levelText = addText(row, {
		Position = UDim2.fromScale(0.52, 0.63),
		Size = UDim2.fromScale(0.19, 0.27),
	})
	local valueText = addText(row, {
		Position = UDim2.fromScale(0.72, 0.06),
		Size = UDim2.fromScale(0.26, 0.32),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local button = UILib.createButton(row, {
		Name = "Buy",
		Position = UDim2.fromScale(0.72, 0.44),
		Size = UDim2.fromScale(0.26, 0.46),
	})

	local statId = upgrade.Id
	local function update()
		local data = DataController.getData()
		if data == nil then
			return
		end
		local status = ShopRules.upgradeStatus(data, statId)
		bar.set(status.Level / status.MaxLevel, true)
		levelText.Text = `Lv {status.Level}/{status.MaxLevel}`
		local now = formatValue(upgrade, upgrade.Values[status.Level])
		if status.Cost then
			valueText.Text = `{now} → {formatValue(upgrade, upgrade.Values[status.Level + 1])}`
			UILib.setButtonText(button, NumberFormat.short(status.Cost))
			UILib.setButtonStyle(button, if status.CanBuy then "Primary" else "Disabled")
		else
			valueText.Text = now
			UILib.setButtonText(button, "MAX")
			UILib.setButtonStyle(button, "Disabled")
		end
	end
	content:add(UILib.onActivated(button, function()
		purchase(button, "BuyUpgrade", statId)
	end))
	table.insert(rowUpdaters, update)
	update()
end

-- ===== Trucks tab =====

local function truckStats(truck: GameData.TruckDef): string
	local parts = {
		`{truck.FlavorSlots} flavor slot{if truck.FlavorSlots == 1 then "" else "s"}`,
		`serves {truck.BaseServingCapacity}`,
	}
	if truck.ScoopSpeedMultiplier > 1 then
		table.insert(parts, `scoop x{truck.ScoopSpeedMultiplier}`)
	end
	if truck.TipMultiplier > 1 then
		table.insert(parts, `tips x{truck.TipMultiplier}`)
	end
	return table.concat(parts, " · ")
end

local function buildTruckRow(list: Instance, truck: GameData.TruckDef)
	local row = createRow(list, truck.Tier)
	UILib.createIcon(row, truck.Icon, Colors.WaffleLight, tostring(truck.Tier), {
		Position = UDim2.fromScale(0.015, 0.06),
		Size = UDim2.fromScale(0.22, 0.88),
	})
	addText(row, {
		Position = UDim2.fromScale(0.25, 0.06),
		Size = UDim2.fromScale(0.46, 0.32),
		Text = truck.DisplayName,
	})
	addText(row, {
		Position = UDim2.fromScale(0.25, 0.38),
		Size = UDim2.fromScale(0.46, 0.26),
		Text = truck.Description,
		TextColor3 = Colors.TextMuted,
	})
	addText(row, {
		Position = UDim2.fromScale(0.25, 0.66),
		Size = UDim2.fromScale(0.46, 0.24),
		Text = truckStats(truck),
	})
	local button = UILib.createButton(row, {
		Name = "Buy",
		Position = UDim2.fromScale(0.72, 0.27),
		Size = UDim2.fromScale(0.26, 0.46),
	})

	local tier = truck.Tier
	local function update()
		local data = DataController.getData()
		if data == nil then
			return
		end
		local status = ShopRules.truckStatus(data, tier)
		if status.State == "Current" then
			UILib.setButtonText(button, "Driving")
			UILib.setButtonStyle(button, "Blue")
			button:SetAttribute("Disabled", true)
		elseif status.State == "Owned" then
			UILib.setButtonText(button, "Owned")
			UILib.setButtonStyle(button, "Disabled")
		elseif status.State == "NeedsRebirth" then
			UILib.setButtonText(button, `Rebirth {truck.RequiresRebirths}`)
			UILib.setButtonStyle(button, "Disabled")
		elseif status.State == "NeedsPrevious" then
			UILib.setButtonText(button, `Locked`)
			UILib.setButtonStyle(button, "Disabled")
		else
			UILib.setButtonText(button, NumberFormat.short(status.Cost))
			UILib.setButtonStyle(button, if status.CanBuy then "Primary" else "Disabled")
		end
	end
	content:add(UILib.onActivated(button, function()
		purchase(button, "BuyTruckTier", tier)
	end))
	table.insert(rowUpdaters, update)
	update()
end

-- ===== Window =====

local function buildTab(tabName: string, holder: Frame)
	holder:ClearAllChildren()
	table.clear(rowUpdaters)
	local list = UILib.createScrollingList(holder, ROW_ASPECT)
	if tabName == "Upgrades" then
		for _, upgrade in TableUtil.sortedByOrder(Upgrades) do
			buildUpgradeRow(list, upgrade)
		end
	else
		for _, truck in Trucks do
			buildTruckRow(list, truck)
		end
	end
end

local function open()
	content:clean() -- leftovers from a close that was interrupted
	UILib.tweenIn(window.Root) -- visible first, so rows can measure their width
	local body = window.Body

	local holder = content:add(UILib.createFrame(body, {
		Name = "TabContent",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, Theme.Sizes.TabBar + 8), -- below the tab buttons
		Size = UDim2.new(1, 0, 1, -(Theme.Sizes.TabBar + 8)),
	}))
	local tabs = UILib.createTabs(body, TABS, function(name)
		selectedTab = name
		buildTab(name, holder)
	end)
	tabs.Frame.Size = UDim2.new(1, 0, 0, Theme.Sizes.TabBar)
	content:add(tabs.Frame)
	tabs.select(selectedTab)

	-- Refresh prices and buttons whenever Coins, the truck or rebirths change.
	content:add(DataController.Changed:Connect(function(path: { any })
		if #path == 0 or path[1] == "Coins" or path[1] == "Truck" or path[1] == "Rebirths" then
			for _, update in rowUpdaters do
				update()
			end
		end
	end))
	content:add(function()
		table.clear(rowUpdaters)
	end)
end

local function close()
	UILib.tweenOut(window.Root, function()
		content:clean()
	end)
end

function ShopController.Init() end

function ShopController.Start()
	local gui = UILib.createScreenGui("ShopGui", Theme.Layers.Window)
	window = UILib.createWindow(gui, { Title = "Truck Garage" })
	UILib.onActivated(window.CloseButton, function()
		WindowManager.close(WINDOW_NAME)
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	WindowManager.register(WINDOW_NAME, open, close)
end

return ShopController
