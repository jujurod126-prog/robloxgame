--!strict
--[[
	HatchAnimation
	The full-screen egg hatch: the egg shakes harder and harder, cracks with a
	flash, then the pet pops out in its rarity frame with spinning rays.
	Hatching 3 eggs plays them side by side.

	HatchAnimation.play(eggId, pets) yields until the player taps or it times out.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Modules.Assets)
local Eggs = require(Shared.Data.Eggs)
local Pets = require(Shared.Data.Pets)
local Rarities = require(Shared.Data.Rarities)

local Theme = require(script.Parent.Theme)
local UILib = require(script.Parent.UILib)

local player = Players.LocalPlayer
local Colors = Theme.Colors

local SHOW_SECONDS = 4 -- auto-close after the reveal if the player doesn't tap
local HATCH_LAYER = Theme.Layers.Window + 5 -- above windows, below toasts

local HatchAnimation = {}

export type HatchedPet = { PetId: string, Variant: string }

local function tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local created = TweenService:Create(instance, info, goal)
	created:Play()
	return created
end

-- Shakes the egg in growing bursts, then cracks it open with a flash.
local function shakeAndCrack(egg: GuiObject, scale: UIScale, flash: Frame)
	for burst = 1, 3 do
		local angle = 8 + burst * 6
		for _ = 1, 3 do
			tween(egg, TweenInfo.new(0.06), { Rotation = angle }).Completed:Wait()
			tween(egg, TweenInfo.new(0.06), { Rotation = -angle }).Completed:Wait()
		end
		egg.Rotation = 0
		task.wait(0.15)
	end
	UILib.playSound(Assets.SFX_EGG_CRACK)
	tween(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Scale = 1.35 }).Completed:Wait()
	flash.BackgroundTransparency = 0
	tween(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	egg.Visible = false
end

local function buildSlot(parent: Instance, order: number, eggId: string, pet: HatchedPet)
	local def = Pets[pet.PetId]
	local rarityColor = Theme.Rarity[def.Rarity]

	local slot = UILib.createFrame(parent, {
		Name = "Slot",
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.28, 1),
	})

	-- Spinning rays behind the reveal, tinted by rarity.
	local rays = UILib.createFrame(slot, {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(1.1, 1.1),
		BackgroundColor3 = rarityColor,
		BackgroundTransparency = 1,
	})
	UILib.addAspect(rays, 1)
	UILib.addCorner(rays, Theme.Sizes.CornerPill)
	local rayGradient = Instance.new("UIGradient")
	rayGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.6, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	rayGradient.Parent = rays
	if def.Rarity == "Mythic" then
		rayGradient.Color = Theme.MythicGradient
	end

	local egg = UILib.createIcon(slot, Eggs[eggId].Icon, Colors.Cream, nil, {
		Name = "Egg",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.7, 0.7),
	})
	UILib.addAspect(egg, 1)
	local eggScale = Instance.new("UIScale")
	eggScale.Parent = egg

	local reveal = UILib.createIcon(slot, `Rarity{def.Rarity}`, rarityColor, nil, {
		Name = "Reveal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.75, 0.75),
		Visible = false,
	})
	UILib.addAspect(reveal, 1)
	local petIcon = UILib.createIcon(reveal, def.Icon, rarityColor, def.DisplayName:sub(1, 1), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.62, 0.62),
		ZIndex = 2,
	})
	UILib.addAspect(petIcon, 1)
	local revealScale = Instance.new("UIScale")
	revealScale.Scale = 0
	revealScale.Parent = reveal

	local name = UILib.createLabel(slot, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.fromScale(1, 0.1),
		Text = def.DisplayName,
		TextTransparency = 1,
	})
	UILib.outlinedText(name)
	name.TextStrokeTransparency = 1
	local rarity = UILib.createLabel(slot, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.9),
		Size = UDim2.fromScale(1, 0.08),
		Text = Rarities[def.Rarity].DisplayName,
		TextColor3 = rarityColor,
		TextTransparency = 1,
		TextStrokeColor3 = Colors.Outline,
		TextStrokeTransparency = 1,
	})

	return function(flash: Frame)
		shakeAndCrack(egg, eggScale, flash)
		reveal.Visible = true
		tween(revealScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		tween(rays, TweenInfo.new(0.3), { BackgroundTransparency = 0 })
		tween(rays, TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
		for _, label in { name, rarity } do
			tween(label, TweenInfo.new(0.3), { TextTransparency = 0, TextStrokeTransparency = 0 })
		end
	end
end

--[[
	Plays the hatch for one or more pets from `eggId`. Yields until it closes
	(the player taps, or SHOW_SECONDS after the reveal).
]]
function HatchAnimation.play(eggId: string, pets: { HatchedPet })
	local gui = UILib.createScreenGui("HatchOverlay", HATCH_LAYER)
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None

	-- Whatever goes wrong inside, the overlay must never stay stuck on screen.
	local ok, err = pcall(function()
		local root = Instance.new("CanvasGroup")
		root.Size = UDim2.fromScale(1, 1)
		root.BackgroundColor3 = Colors.Overlay
		root.BackgroundTransparency = 0.35
		root.GroupTransparency = 1
		root.Parent = gui

		local row = UILib.createFrame(root, {
			Name = "Row",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.6),
			BackgroundTransparency = 1,
		})
		UILib.addSizeLimit(row, nil, Vector2.new(1000, 520))
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0.03, 0)
		layout.Parent = row

		local flash = UILib.createFrame(root, {
			Name = "Flash",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			ZIndex = 10,
		})
		local hint = UILib.createLabel(root, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.95),
			Size = UDim2.fromScale(0.5, 0.05),
			Text = "Tap to continue",
			Visible = false,
		})
		UILib.outlinedText(hint)

		local reveals = {}
		for index, pet in pets do
			table.insert(reveals, buildSlot(row, index, eggId, pet))
		end

		gui.Parent = player:WaitForChild("PlayerGui")
		tween(root, TweenInfo.new(0.25), { GroupTransparency = 0 }).Completed:Wait()

		-- All eggs hatch together; wait for the slowest.
		local remaining = #reveals
		for _, reveal in reveals do
			task.spawn(function()
				local revealOk, revealErr = pcall(function()
					reveal(flash)
				end)
				if not revealOk then
					warn(`[HatchAnimation] {revealErr}`)
				end
				remaining -= 1
			end)
		end
		local revealDeadline = os.clock() + 15
		while remaining > 0 and os.clock() < revealDeadline do
			task.wait(0.05)
		end
		UILib.playSound(Assets.SFX_HATCH_FANFARE)

		-- Close on tap or after a few seconds.
		hint.Visible = true
		local closed = false
		local catcher = Instance.new("TextButton")
		catcher.Text = ""
		catcher.BackgroundTransparency = 1
		catcher.Size = UDim2.fromScale(1, 1)
		catcher.ZIndex = 20
		catcher.Parent = root
		catcher.Activated:Connect(function()
			closed = true
		end)
		local deadline = os.clock() + SHOW_SECONDS
		while not closed and os.clock() < deadline do
			task.wait(0.05)
		end

		tween(root, TweenInfo.new(0.2), { GroupTransparency = 1 }).Completed:Wait()
	end)
	if not ok then
		warn(`[HatchAnimation] {err}`)
	end
	gui:Destroy()
end

return HatchAnimation
