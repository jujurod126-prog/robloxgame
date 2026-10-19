--!strict
--[[
	PetController
	The Pet Parlor window (HUD "Pets" button or the Pet Parlor counter in the Hub).
	  * Eggs tab: each egg with its price, drop odds per pet, and Buy 1 / Buy 3
	    (plays the hatch animation with what the server rolled)
	  * My Pets tab: grid of your pets (equipped first) and a details panel to
	    Equip / Unequip, Lock, Delete (tap twice) and Merge 5 into a Golden pet

	Only displays PetRules results and sends requests; the server decides.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Eggs = require(Shared.Data.Eggs)
local Formulas = require(Shared.Modules.Formulas)
local GameConfig = require(Shared.Data.GameConfig)
local GameData = require(Shared.Types.GameData)
local NumberFormat = require(Shared.Modules.NumberFormat)
local PetRules = require(Shared.Modules.PetRules)
local Pets = require(Shared.Data.Pets)
local Rarities = require(Shared.Data.Rarities)
local Remotes = require(Shared.Modules.Remotes)
local TableUtil = require(Shared.Modules.TableUtil)

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

local WINDOW_NAME = "Pets"
local TABS = { "Eggs", "My Pets" }
local DELETE_CONFIRM_SECONDS = 3

local PetController = {}

local window: UILib.Window
local content = Cleaner.new()
local selectedTab = TABS[1]
local selectedPet: string? = nil
local hatching = false
local refreshTab: (() -> ())? = nil

local function invoke(remoteName: Remotes.FunctionName, ...: any): any
	local remote = Remotes.func(remoteName)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if ok and type(result) == "table" then
		return result
	end
	return { Ok = false, Message = "Something went wrong. Try again!" }
end

local function pill(parent: Instance, text: string, color: Color3, props: { [string]: any })
	local frame = UILib.createFrame(parent, { BackgroundColor3 = color, ZIndex = 3 })
	for key, value in props do
		(frame :: any)[key] = value
	end
	UILib.addCorner(frame, Theme.Sizes.CornerPill)
	UILib.addStroke(frame, Theme.Sizes.OutlineThin)
	local label = UILib.createLabel(frame, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.8),
		Text = text,
		ZIndex = 4,
	})
	UILib.outlinedText(label)
end

-- A pet portrait: rarity frame with the pet inside (works without art too).
local function petPortrait(parent: Instance, petId: string, props: { [string]: any }): ImageLabel
	local def = Pets[petId]
	local rarityColor = Theme.Rarity[def.Rarity]
	local frame = UILib.createIcon(parent, `Rarity{def.Rarity}`, rarityColor, nil, props)
	UILib.addAspect(frame, 1)
	local icon = UILib.createIcon(frame, def.Icon, rarityColor, def.DisplayName:sub(1, 1), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.62, 0.62),
		ZIndex = 2,
	})
	UILib.addAspect(icon, 1)
	return frame
end

-- ===== Eggs tab =====

local function buildEggRow(list: Instance, egg: GameData.EggDef)
	local row = UILib.createFrame(list, { Name = "Egg", LayoutOrder = egg.Order, BackgroundColor3 = Colors.CreamDark })
	UILib.addCorner(row, UDim.new(0.15, 0))
	UILib.addStroke(row, Theme.Sizes.Outline)

	local icon = UILib.createIcon(row, egg.Icon, Colors.Cream, nil, {
		Position = UDim2.fromScale(0.015, 0.06),
		Size = UDim2.fromScale(0.2, 0.88),
	})
	UILib.addAspect(icon, 0.85)

	UILib.createLabel(row, {
		Position = UDim2.fromScale(0.2, 0.04),
		Size = UDim2.fromScale(0.42, 0.24),
		Text = egg.DisplayName,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	UILib.createLabel(row, {
		Position = UDim2.fromScale(0.2, 0.28),
		Size = UDim2.fromScale(0.42, 0.16),
		Text = `{NumberFormat.short(egg.Price)} {egg.Currency} each`,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if egg.Currency == "Gems" then Colors.Blue else Colors.Orange,
	})

	-- Odds: every pet this egg can give, with its chance.
	local odds = UILib.createFrame(row, {
		Name = "Odds",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.2, 0.48),
		Size = UDim2.fromScale(0.52, 0.48),
	})
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = odds
	for index, entry in Formulas.eggOddsPercent(egg) do
		local cell = UILib.createFrame(odds, {
			LayoutOrder = index,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.13, 1),
		})
		petPortrait(cell, entry.PetId, { Size = UDim2.fromScale(1, 0.7) })
		local percent = if entry.Percent >= 1
			then string.format("%d%%", math.floor(entry.Percent + 0.5))
			else string.format("%.1f%%", entry.Percent)
		UILib.createLabel(cell, {
			Position = UDim2.fromScale(0, 0.7),
			Size = UDim2.fromScale(1, 0.3),
			Text = percent,
			TextColor3 = Theme.Rarity[Pets[entry.PetId].Rarity],
			TextStrokeColor3 = Colors.Outline,
			TextStrokeTransparency = 0.4,
		})
	end

	local buttons = {}
	for index, count in { 1, 3 } do
		local button = UILib.createButton(row, {
			Name = `Buy{count}`,
			Text = `Buy {count}`,
			Position = UDim2.fromScale(0.75, 0.08 + (index - 1) * 0.46),
			Size = UDim2.fromScale(0.23, 0.38),
		})
		buttons[count] = button
		content:add(UILib.onActivated(button, function()
			if hatching then
				return
			end
			hatching = true
			UILib.setButtonText(button, "...")
			task.spawn(function()
				local result = invoke("HatchEgg", egg.Id, count)
				if result.Ok and result.Pets then
					HatchAnimation.play(egg.Id, result.Pets)
				else
					NotificationController.toast(result.Message, "Error")
				end
				hatching = false
				if refreshTab then
					refreshTab()
				end
			end)
		end))
	end

	return function()
		local data = DataController.getData()
		if data == nil then
			return
		end
		for count, button in buttons do
			local status = PetRules.eggStatus(data, egg.Id, count)
			UILib.setButtonText(button, if egg.EventOnly then "Event" else `Buy {count}`)
			UILib.setButtonStyle(button, if status.CanBuy and not hatching then "Primary" else "Disabled")
		end
	end
end

local function buildEggsTab(holder: Frame): () -> ()
	local list = UILib.createScrollingList(holder, 3.4)
	local updaters = {}
	for _, egg in TableUtil.sortedByOrder(Eggs) do
		table.insert(updaters, buildEggRow(list, egg))
	end
	return function()
		for _, update in updaters do
			update()
		end
	end
end

-- ===== My Pets tab =====

local function sortedPets(data: any): { string }
	local equipped = PetRules.equipped(data)
	local list = {}
	for petGuid in data.Pets.Inventory do
		table.insert(list, petGuid)
	end
	table.sort(list, function(a, b)
		local petA, petB = data.Pets.Inventory[a], data.Pets.Inventory[b]
		local eqA, eqB = table.find(equipped, a) ~= nil, table.find(equipped, b) ~= nil
		if eqA ~= eqB then
			return eqA
		end
		local rarityA = Rarities[Pets[petA.PetId].Rarity].Order
		local rarityB = Rarities[Pets[petB.PetId].Rarity].Order
		if rarityA ~= rarityB then
			return rarityA > rarityB
		end
		if petA.Variant ~= petB.Variant then
			return petA.Variant == "Golden"
		end
		if petA.PetId ~= petB.PetId then
			return petA.PetId < petB.PetId
		end
		return a < b
	end)
	return list
end

local function buildMyPetsTab(holder: Frame): () -> ()
	local header = UILib.createLabel(holder, {
		Size = UDim2.fromScale(0.62, 0.09),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local grid = UILib.createScrollingGrid(holder, 4, 0.85, {
		Position = UDim2.fromScale(0, 0.11),
		Size = UDim2.fromScale(0.62, 0.89),
	})

	-- Details panel for the selected pet.
	local panel = UILib.createFrame(holder, {
		Name = "Details",
		Position = UDim2.fromScale(0.645, 0),
		Size = UDim2.fromScale(0.355, 1),
		BackgroundColor3 = Colors.CreamDark,
	})
	UILib.addCorner(panel, UDim.new(0.08, 0))
	UILib.addStroke(panel, Theme.Sizes.Outline)
	local detailContent = UILib.createFrame(panel, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })

	local deleteArmedUntil = 0

	-- Action buttons go in a scrolling list with fixed 44 px rows, so on small
	-- phones they never overlap (an overlapped Lock button could hit Delete).
	local function actionList(parent: Instance): ScrollingFrame
		local list = Instance.new("ScrollingFrame")
		list.Name = "Actions"
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.Position = UDim2.fromScale(0, 0.54)
		list.Size = UDim2.fromScale(1, 0.46)
		list.CanvasSize = UDim2.new()
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.ScrollBarThickness = 6
		list.ScrollBarImageColor3 = Colors.Waffle
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Padding = UDim.new(0, 6)
		layout.Parent = list
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 4)
		padding.PaddingBottom = UDim.new(0, 4)
		padding.Parent = list
		list.Parent = parent
		return list
	end

	local function actionButton(
		parent: Instance,
		order: number,
		text: string,
		style: UILib.ButtonStyle,
		onClick: () -> ()
	): TextButton
		return UILib.createButton(parent, {
			Text = text,
			Style = style,
			LayoutOrder = order,
			Size = UDim2.new(0.86, 0, 0, 44),
			OnClick = onClick,
		})
	end

	-- One request at a time, so a double tap can't merge (or delete) twice.
	local requestBusy = false
	local function request(remoteName: Remotes.FunctionName, ...: any)
		if requestBusy then
			return
		end
		requestBusy = true
		local args = table.pack(...)
		task.spawn(function()
			local result = invoke(remoteName, table.unpack(args, 1, args.n))
			requestBusy = false
			NotificationController.toast(result.Message, if result.Ok then "Success" else "Error")
		end)
	end

	local function renderDetails(data: any)
		detailContent:ClearAllChildren()
		local pet = selectedPet and data.Pets.Inventory[selectedPet]
		if pet == nil then
			selectedPet = nil
			UILib.createLabel(detailContent, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.86, 0.2),
				Text = "Tap a pet to see it here",
				TextColor3 = Colors.TextMuted,
			})
			return
		end
		local petGuid = selectedPet :: string
		local def = Pets[pet.PetId]
		local equipped = table.find(PetRules.equipped(data), petGuid) ~= nil
		local golden = pet.Variant == "Golden"

		petPortrait(detailContent, pet.PetId, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.02),
			Size = UDim2.fromScale(0.6, 0.3),
		})
		UILib.createLabel(detailContent, {
			Position = UDim2.fromScale(0.05, 0.33),
			Size = UDim2.fromScale(0.9, 0.08),
			Text = (if golden then "Golden " else "") .. def.DisplayName,
			TextColor3 = if golden then Colors.Orange else Colors.Text,
		})
		UILib.createLabel(detailContent, {
			Position = UDim2.fromScale(0.05, 0.41),
			Size = UDim2.fromScale(0.9, 0.06),
			Text = Rarities[def.Rarity].DisplayName,
			TextColor3 = Theme.Rarity[def.Rarity],
		})
		UILib.createLabel(detailContent, {
			Position = UDim2.fromScale(0.05, 0.47),
			Size = UDim2.fromScale(0.9, 0.06),
			Text = PetRules.boostLabel(pet),
			TextColor3 = Colors.GreenDark,
		})

		local actions = actionList(detailContent)
		actionButton(
			actions,
			1,
			if equipped then "Unequip" else "Equip",
			if equipped then "Secondary" else "Primary",
			function()
				request(if equipped then "UnequipPet" else "EquipPet", petGuid)
			end
		)
		actionButton(actions, 2, if pet.Locked then "Unlock" else "Lock", "Blue", function()
			request("SetPetLocked", petGuid, not pet.Locked)
		end)
		actionButton(actions, 3, "Delete", if pet.Locked then "Disabled" else "Danger", function()
			if os.clock() < deleteArmedUntil then
				deleteArmedUntil = 0
				request("DeletePet", petGuid)
			else
				deleteArmedUntil = os.clock() + DELETE_CONFIRM_SECONDS
				NotificationController.toast("Tap Delete again to confirm.", "Info")
			end
		end)

		local copies = #PetRules.mergeCandidates(data, pet.PetId)
		local needed = GameConfig.Pets.MergeCount
		local canMerge = not golden and copies >= needed
		actionButton(
			actions,
			4,
			if golden then "Already Golden" else `Merge {math.min(copies, needed)}/{needed} → Golden`,
			if canMerge then "Pink" else "Disabled",
			function()
				request("MergePets", pet.PetId)
			end
		)
	end

	local function renderGrid()
		local data = DataController.getData()
		if data == nil then
			return
		end
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local equipped = PetRules.equipped(data)
		header.Text =
			`Equipped {#equipped}/{PetRules.equipSlots(data)}   ·   Pets {PetRules.inventoryCount(data)}/{GameConfig.Pets.MaxInventory}`

		for order, petGuid in sortedPets(data) do
			local pet = data.Pets.Inventory[petGuid]
			local def = Pets[pet.PetId]
			local card = Instance.new("TextButton")
			card.Name = "Pet"
			card.Text = ""
			card.AutoButtonColor = false
			card.LayoutOrder = order
			card.BackgroundColor3 = if petGuid == selectedPet then Colors.FrostingPink else Colors.Cream
			UILib.addCorner(card, UDim.new(0.15, 0))
			UILib.addStroke(
				card,
				if pet.Variant == "Golden" then 4 else Theme.Sizes.Outline,
				if pet.Variant == "Golden" then Colors.Coin else Theme.Rarity[def.Rarity]
			)
			card.Parent = grid
			petPortrait(card, pet.PetId, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.04),
				Size = UDim2.fromScale(0.78, 0.66),
			})
			UILib.createLabel(card, {
				Position = UDim2.fromScale(0.05, 0.72),
				Size = UDim2.fromScale(0.9, 0.2),
				Text = def.DisplayName,
			})
			if table.find(equipped, petGuid) then
				pill(
					card,
					"ON",
					Colors.Green,
					{ Position = UDim2.fromScale(0.02, 0.02), Size = UDim2.fromScale(0.36, 0.16) }
				)
			end
			if pet.Variant == "Golden" then
				pill(
					card,
					"GOLD",
					Colors.Coin,
					{ Position = UDim2.fromScale(0.6, 0.02), Size = UDim2.fromScale(0.38, 0.16) }
				)
			end
			if pet.Locked then
				pill(
					card,
					"LOCK",
					Colors.Grey,
					{ Position = UDim2.fromScale(0.6, 0.58), Size = UDim2.fromScale(0.38, 0.14) }
				)
			end
			UILib.addPressEffect(card)
			content:add(UILib.onActivated(card, function()
				selectedPet = petGuid
				deleteArmedUntil = 0
				renderGrid()
			end))
		end
		renderDetails(data)
	end

	return renderGrid
end

-- ===== Window =====

local function buildTab(tabName: string, holder: Frame)
	holder:ClearAllChildren()
	refreshTab = if tabName == "Eggs" then buildEggsTab(holder) else buildMyPetsTab(holder);
	(refreshTab :: () -> ())()
end

local function open()
	content:clean()
	UILib.tweenIn(window.Root)
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

	content:add(DataController.Changed:Connect(function(path: { any })
		-- Eggs care about money and inventory space; My Pets only about pets.
		local key = path[1]
		local relevant = if selectedTab == "Eggs"
			then key == "Coins" or key == "Gems" or key == "Pets"
			else key == "Pets" or key == "Skills"
		if refreshTab and (#path == 0 or relevant) then
			refreshTab()
		end
	end))
	content:add(function()
		refreshTab = nil
	end)
end

local function close()
	UILib.tweenOut(window.Root, function()
		content:clean()
	end)
end

function PetController.Init() end

function PetController.Start()
	local gui = UILib.createScreenGui("PetGui", Theme.Layers.Window)
	window = UILib.createWindow(gui, { Title = "Pet Parlor" })
	UILib.onActivated(window.CloseButton, function()
		WindowManager.close(WINDOW_NAME)
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	WindowManager.register(WINDOW_NAME, open, close)
end

return PetController
