--!strict
--[[
	OrderBarController
	The bottom-center HUD strip for serving:
	  * combo meter (flame bar sprite) - fills toward the max multiplier, shows x1.3 etc.
	  * flavor chips: your truck's loaded flavors; tap one to scoop that flavor (SelectFlavor)
	  * cone: scoops / capacity and the topping on it
	  * topping chips: your unlocked toppings; tap one at your truck to add it (AddTopping)
	Reads Player attributes from ConeService/CustomerService (ConeScoops, ConeCapacity,
	ConeTopping, ActiveSlot, Combo) and the replicated PlayerData.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Modules.Assets)
local Flavors = require(Shared.Data.Flavors)
local Formulas = require(Shared.Modules.Formulas)
local GameConfig = require(Shared.Data.GameConfig)
local PlayerStats = require(Shared.Modules.PlayerStats)
local Remotes = require(Shared.Modules.Remotes)
local TableUtil = require(Shared.Modules.TableUtil)
local Toppings = require(Shared.Data.Toppings)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)

local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

local player = Players.LocalPlayer
local Colors = Theme.Colors

-- Combo count where the multiplier reaches its cap (the meter is full there).
local COMBO_FULL = GameConfig.Combo.StartsAt
	- 1
	+ math.ceil((GameConfig.Combo.MaxMultiplier - 1) / GameConfig.Combo.StepMultiplier)

local OrderBarController = {}

local gui: ScreenGui
local chipRow: Frame
local coneLabel: TextLabel
local coneTopping: ImageLabel?
local conePill: Frame

local function clearChips(prefix: string)
	for _, child in chipRow:GetChildren() do
		if child.Name:sub(1, #prefix) == prefix then
			child:Destroy()
		end
	end
end

local function createChip(name: string, order: number, icon: string?, color: Color3, onClick: () -> ()): TextButton
	local chip = UILib.createButton(chipRow, {
		Name = name,
		Style = "Secondary",
		LayoutOrder = order,
		Size = UDim2.fromScale(0.1, 0.9),
		OnClick = onClick,
	})
	UILib.addAspect(chip, 1)
	local image = UILib.createIcon(chip, icon, color, nil, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.78, 0.78),
	})
	UILib.addAspect(image, 1)
	return chip
end

-- Flavor chips: left of the cone, in slot order. The active slot is pink.
local function rebuildFlavorChips()
	clearChips("Flavor")
	local data = DataController.getData()
	if data == nil then
		return
	end
	local loadout = PlayerStats.loadout(data)
	if #loadout <= 1 then
		return -- nothing to choose between
	end
	local activeSlot = (player:GetAttribute("ActiveSlot") :: number?) or 1
	for slot, flavorId in loadout do
		local flavor = Flavors[flavorId]
		local chip = createChip(`Flavor{slot}`, slot, flavor.Icon, flavor.Color, function()
			Remotes.event("SelectFlavor"):FireServer(slot)
		end)
		if slot == activeSlot then
			UILib.setButtonStyle(chip, "Pink")
		end
	end
end

-- Topping chips: right of the cone, one per unlocked topping.
local function rebuildToppingChips()
	clearChips("Topping")
	local data = DataController.getData()
	if data == nil then
		return
	end
	for _, topping in TableUtil.sortedByOrder(Toppings) do
		if data.Toppings.Unlocked[topping.Id] then
			local toppingId = topping.Id
			createChip(`Topping{toppingId}`, 100 + topping.Order, topping.Icon, topping.Color, function()
				task.spawn(function()
					local remote = Remotes.func("AddTopping")
					local ok, result = pcall(remote.InvokeServer, remote, toppingId)
					if ok and type(result) == "table" and not result.Ok then
						NotificationController.toast(result.Message, "Error")
					end
				end)
			end)
		end
	end
end

local function updateCone()
	local scoops = (player:GetAttribute("ConeScoops") :: number?) or 0
	local capacity = (player:GetAttribute("ConeCapacity") :: number?) or 1
	coneLabel.Text = `Cone {scoops}/{capacity}`

	if coneTopping then
		coneTopping:Destroy()
		coneTopping = nil
	end
	local toppingId = player:GetAttribute("ConeTopping") :: string?
	local topping = toppingId and Toppings[toppingId]
	if topping then
		local icon = UILib.createIcon(conePill, topping.Icon, topping.Color, nil, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.98, 0.5),
			Size = UDim2.fromScale(0.3, 0.9),
		})
		UILib.addAspect(icon, 1)
		coneTopping = icon
	end
end

local function createCone()
	local outer, inner = UILib.createPanel(chipRow, {
		Name = "Cone",
		LayoutOrder = 50,
		Size = UDim2.fromScale(0.28, 0.9),
	}, Theme.Sizes.CornerPill)
	UILib.addAspect(outer, 2.6)
	conePill = outer
	coneLabel = UILib.createLabel(inner, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.08, 0.5),
		Size = UDim2.fromScale(0.62, 0.7),
	})
	for _, name in { "ConeScoops", "ConeCapacity", "ConeTopping" } do
		player:GetAttributeChangedSignal(name):Connect(updateCone)
	end
	updateCone()
end

local function createComboMeter(container: Frame)
	local bar = UILib.createSpriteBar(container, "ComboBar", Colors.Orange, {
		Name = "Combo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.5, 0.42),
	})
	local label = UILib.createLabel(bar.Frame, {
		Name = "ComboText",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.58, 0.74),
		Size = UDim2.fromScale(0.6, 0.3),
		ZIndex = 3,
	})
	UILib.outlinedText(label)
	local scale = Instance.new("UIScale")
	scale.Parent = bar.Frame

	local lastCombo = 0
	local function update()
		local combo = (player:GetAttribute("Combo") :: number?) or 0
		bar.set(combo / COMBO_FULL, true)
		local multiplier = Formulas.comboMultiplier(combo)
		label.Text = if multiplier > 1
			then string.format("x%.1f COMBO!", multiplier)
			else `Combo {combo}/{GameConfig.Combo.StartsAt}`
		bar.Frame.Visible = combo > 0
		if combo > lastCombo then
			-- Rising pitch and a little bounce on every combo step.
			UILib.playSound(Assets.SFX_COMBO, 1 + math.min(combo, 20) * 0.04)
			scale.Scale = 1.12
			TweenService:Create(scale, Theme.Motion.Open, { Scale = 1 }):Play()
		end
		lastCombo = combo
	end
	player:GetAttributeChangedSignal("Combo"):Connect(update)
	update()
end

function OrderBarController.Init()
	gui = UILib.createScreenGui("OrderBar", Theme.Layers.Hud)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function OrderBarController.Start()
	local container = UILib.createFrame(gui, {
		Name = "Container",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.985),
		Size = UDim2.fromScale(0.56, 0.2),
	})
	UILib.addSizeLimit(container, Vector2.new(320, 110), Vector2.new(760, 190))

	createComboMeter(container)

	chipRow = UILib.createFrame(container, {
		Name = "Chips",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.46),
		Size = UDim2.fromScale(1, 0.54),
	})
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.012, 0)
	layout.Parent = chipRow

	createCone()

	DataController.waitForData()
	rebuildFlavorChips()
	rebuildToppingChips()
	player:GetAttributeChangedSignal("ActiveSlot"):Connect(rebuildFlavorChips)
	DataController.Changed:Connect(function(path: { any })
		local key = path[1]
		if #path == 0 or key == "Flavors" or key == "Truck" then
			rebuildFlavorChips()
		end
		if #path == 0 or key == "Toppings" then
			rebuildToppingChips()
		end
	end)
end

return OrderBarController
