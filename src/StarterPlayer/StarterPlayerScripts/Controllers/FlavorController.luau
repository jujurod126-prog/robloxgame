--!strict
--[[
	FlavorController
	The Flavor Lab window (HUD "Flavors" button).
	  * Flavors tab: your truck's flavor slots on top (tap a slot to pick it), then a
	    grid of flavor cards with rarity frames: Unlock (price) / Equip / Equipped / Rebirth N
	  * Toppings tab: topping cards with their value bonus: Unlock (price) / Owned

	Only displays FlavorRules results and sends requests; the server decides.
	Everything built on open is cleaned up on close.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local FlavorRules = require(Shared.Modules.FlavorRules)
local Flavors = require(Shared.Data.Flavors)
local GameData = require(Shared.Types.GameData)
local NumberFormat = require(Shared.Modules.NumberFormat)
local PlayerStats = require(Shared.Modules.PlayerStats)
local Remotes = require(Shared.Modules.Remotes)
local TableUtil = require(Shared.Modules.TableUtil)
local Toppings = require(Shared.Data.Toppings)
local Trucks = require(Shared.Data.Trucks)

local UI = script.Parent.Parent.UI
local Cleaner = require(UI.Cleaner)
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)
local WindowManager = require(UI.WindowManager)

local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

local player = Players.LocalPlayer
local Colors = Theme.Colors

local WINDOW_NAME = "Flavors"
local TABS = { "Flavors", "Toppings" }
local GRID_COLUMNS = 4
local MAX_SLOTS = Trucks[#Trucks].FlavorSlots

local FlavorController = {}

local window: UILib.Window
local content = Cleaner.new()
local selectedTab = TABS[1]
local selectedSlot = 1
local updaters: { () -> () } = {}

local function refreshAll()
	for _, update in updaters do
		update()
	end
end

-- Sends a request; the button shows "..." until the server answers.
local function request(button: TextButton, remoteName: Remotes.FunctionName, ...: any)
	local args = table.pack(...)
	UILib.setButtonStyle(button, "Disabled")
	UILib.setButtonText(button, "...")
	task.spawn(function()
		local remote = Remotes.func(remoteName)
		local ok, result = pcall(remote.InvokeServer, remote, table.unpack(args, 1, args.n))
		if ok and type(result) == "table" then
			NotificationController.toast(result.Message, if result.Ok then "Success" else "Error")
		else
			NotificationController.toast("Something went wrong. Try again!", "Error")
		end
		refreshAll()
	end)
end

local function createCard(parent: Instance, order: number, strokeColor: Color3): Frame
	local card = UILib.createFrame(parent, { Name = "Card", LayoutOrder = order, BackgroundColor3 = Colors.CreamDark })
	UILib.addCorner(card, UDim.new(0.12, 0))
	UILib.addStroke(card, Theme.Sizes.Outline, strokeColor)
	return card
end

local function cardText(card: Frame, y: number, height: number, text: string, color: Color3?): TextLabel
	return UILib.createLabel(card, {
		Position = UDim2.fromScale(0.06, y),
		Size = UDim2.fromScale(0.88, height),
		Text = text,
		TextColor3 = color or Colors.Text,
	})
end

-- ===== Flavors tab =====

local function buildSlots(holder: Frame)
	local strip = UILib.createFrame(holder, {
		Name = "Slots",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.24),
	})
	UILib.createLabel(strip, {
		Size = UDim2.fromScale(1, 0.28),
		Text = "Truck slots - tap a slot, then Equip a flavor",
		TextColor3 = Colors.TextMuted,
	})
	local row = UILib.createFrame(strip, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.32),
		Size = UDim2.fromScale(1, 0.68),
	})
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.015, 0)
	layout.Parent = row

	for slot = 1, MAX_SLOTS do
		local button = UILib.createButton(row, {
			Name = `Slot{slot}`,
			Style = "Secondary",
			LayoutOrder = slot,
			Size = UDim2.fromScale(0.15, 1),
			OnClick = function()
				selectedSlot = slot
				refreshAll()
			end,
		})
		local swatch = UILib.createFrame(button, {
			Name = "Swatch",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.08, 0.5),
			Size = UDim2.fromScale(0.5, 0.62),
		})
		UILib.addAspect(swatch, 1)
		UILib.addCorner(swatch, Theme.Sizes.CornerPill)
		UILib.addStroke(swatch, Theme.Sizes.OutlineThin)
		local label = button:FindFirstChild("Label") :: TextLabel
		label.Position = UDim2.fromScale(0.62, 0.5)
		label.Size = UDim2.fromScale(0.62, 0.6)

		local function update()
			local data = DataController.getData()
			if data == nil then
				return
			end
			local slots = PlayerStats.flavorSlots(data)
			local flavorId = PlayerStats.loadout(data)[slot]
			if slot > slots then
				UILib.setButtonStyle(button, "Disabled")
				UILib.setButtonText(button, "")
				swatch.BackgroundColor3 = Colors.Grey
			else
				UILib.setButtonStyle(button, if slot == selectedSlot then "Pink" else "Secondary")
				UILib.setButtonText(button, if flavorId then Flavors[flavorId].DisplayName else "Empty")
				swatch.BackgroundColor3 = if flavorId then Flavors[flavorId].Color else Colors.Cream
			end
		end
		table.insert(updaters, update)
	end
end

local function buildFlavorCard(grid: Instance, flavor: GameData.FlavorDef)
	local rarityColor = Theme.Rarity[flavor.Rarity]
	local card = createCard(grid, flavor.Order, rarityColor)

	-- Rarity badge frame with the flavor's icon (or a scoop-colored circle) in the middle.
	local frame = UILib.createIcon(card, `Rarity{flavor.Rarity}`, rarityColor, nil, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.03),
		Size = UDim2.fromScale(0.62, 0.4),
	})
	UILib.addAspect(frame, 1)
	local icon = UILib.createIcon(frame, flavor.Icon, flavor.Color, nil, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.5, 0.5),
		ZIndex = 2,
	})
	UILib.addAspect(icon, 1)

	cardText(card, 0.44, 0.13, flavor.DisplayName)
	cardText(card, 0.57, 0.09, flavor.Rarity, rarityColor)
	cardText(card, 0.66, 0.09, `{flavor.CoinValue} per scoop`, Colors.TextMuted)
	local button = UILib.createButton(card, {
		Name = "Action",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.96),
		Size = UDim2.fromScale(0.86, 0.16),
	})

	local flavorId = flavor.Id
	local action: (() -> ())? = nil
	local function update()
		local data = DataController.getData()
		if data == nil then
			return
		end
		local status = FlavorRules.flavorStatus(data, flavorId)
		action = nil
		if status.State == "Equipped" then
			UILib.setButtonText(button, "Equipped")
			UILib.setButtonStyle(button, "Blue")
			button:SetAttribute("Disabled", true)
		elseif status.State == "Owned" then
			UILib.setButtonText(button, `Equip in {selectedSlot}`)
			UILib.setButtonStyle(button, "Pink")
			action = function()
				request(button, "EquipFlavor", flavorId, selectedSlot)
			end
		elseif status.State == "NeedsRebirth" then
			UILib.setButtonText(button, `Rebirth {flavor.RequiresRebirths}`)
			UILib.setButtonStyle(button, "Disabled")
		else
			UILib.setButtonText(button, NumberFormat.short(status.Cost))
			UILib.setButtonStyle(button, if status.CanBuy then "Primary" else "Disabled")
			action = function()
				request(button, "UnlockFlavor", flavorId)
			end
		end
	end
	content:add(UILib.onActivated(button, function()
		if action then
			action()
		end
	end))
	table.insert(updaters, update)
end

local function buildFlavorsTab(holder: Frame)
	buildSlots(holder)
	local grid = UILib.createScrollingGrid(holder, GRID_COLUMNS, 0.72, {
		Position = UDim2.fromScale(0, 0.27),
		Size = UDim2.fromScale(1, 0.73),
	})
	for _, flavor in TableUtil.sortedByOrder(Flavors) do
		buildFlavorCard(grid, flavor)
	end
end

-- ===== Toppings tab =====

local function buildToppingCard(grid: Instance, topping: GameData.ToppingDef)
	local card = createCard(grid, topping.Order, Colors.Outline)
	local icon = UILib.createIcon(card, topping.Icon, topping.Color, nil, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromScale(0.6, 0.42),
	})
	UILib.addAspect(icon, 1)
	cardText(card, 0.48, 0.14, topping.DisplayName)
	cardText(card, 0.63, 0.11, `x{topping.ValueMultiplier} value`, Colors.GreenDark)
	local button = UILib.createButton(card, {
		Name = "Action",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.96),
		Size = UDim2.fromScale(0.86, 0.17),
	})

	local toppingId = topping.Id
	local function update()
		local data = DataController.getData()
		if data == nil then
			return
		end
		local status = FlavorRules.toppingStatus(data, toppingId)
		if status.State == "Owned" then
			UILib.setButtonText(button, "Owned")
			UILib.setButtonStyle(button, "Blue")
			button:SetAttribute("Disabled", true)
		else
			UILib.setButtonText(button, NumberFormat.short(status.Cost))
			UILib.setButtonStyle(button, if status.CanBuy then "Primary" else "Disabled")
		end
	end
	content:add(UILib.onActivated(button, function()
		request(button, "UnlockTopping", toppingId)
	end))
	table.insert(updaters, update)
end

local function buildToppingsTab(holder: Frame)
	UILib.createLabel(holder, {
		Size = UDim2.fromScale(1, 0.08),
		Text = "Unlocked toppings appear under your cone. Tap one at your truck to add it.",
		TextColor3 = Colors.TextMuted,
	})
	local grid = UILib.createScrollingGrid(holder, GRID_COLUMNS, 0.8, {
		Position = UDim2.fromScale(0, 0.1),
		Size = UDim2.fromScale(1, 0.9),
	})
	for _, topping in TableUtil.sortedByOrder(Toppings) do
		buildToppingCard(grid, topping)
	end
end

-- ===== Window =====

local function buildTab(tabName: string, holder: Frame)
	holder:ClearAllChildren()
	table.clear(updaters)
	if tabName == "Flavors" then
		buildFlavorsTab(holder)
	else
		buildToppingsTab(holder)
	end
	refreshAll()
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
			#path == 0
			or key == "Coins"
			or key == "Flavors"
			or key == "Toppings"
			or key == "Truck"
			or key == "Rebirths"
		then
			refreshAll()
		end
	end))
	content:add(function()
		table.clear(updaters)
	end)
end

local function close()
	UILib.tweenOut(window.Root, function()
		content:clean()
	end)
end

function FlavorController.Init() end

function FlavorController.Start()
	local gui = UILib.createScreenGui("FlavorGui", Theme.Layers.Window)
	window = UILib.createWindow(gui, { Title = "Flavor Lab" })
	UILib.onActivated(window.CloseButton, function()
		WindowManager.close(WINDOW_NAME)
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	WindowManager.register(WINDOW_NAME, open, close)
end

return FlavorController
