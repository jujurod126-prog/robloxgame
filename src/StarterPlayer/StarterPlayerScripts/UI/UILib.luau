--!strict
--[[
	UILib
	Reusable builders for the game's chunky candy UI. Every screen is made from
	these, so the look stays consistent and comes from one place (Theme).

	Building blocks: createScreenGui, createFrame, createPanel, createLabel,
	createIcon, createButton, createProgressBar, createScrollingList,
	createScrollingGrid, createTabs, createWindow, createToast
	Decorators: addCorner, addStroke, addGradient, addPadding, addAspect,
	addSizeLimit, addTextLimit, addHoverEffect, addPressEffect
	Motion & sound: tweenIn, tweenOut, playClickSound

	Sizing is scale-based, kept sane on every screen with UIAspectRatioConstraint
	and UISizeConstraint. Buttons are at least Theme.Sizes.MinTapTarget.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Modules.Assets)
local Sprites = require(Shared.Modules.Sprites)

local Theme = require(script.Parent.Theme)

local Colors = Theme.Colors

local UILib = {}

export type ButtonStyle = "Primary" | "Secondary" | "Danger" | "Pink" | "Blue" | "Disabled"

local BUTTON_COLORS: { [ButtonStyle]: Color3 } = {
	Primary = Colors.Green,
	Secondary = Colors.Cream,
	Danger = Colors.Cherry,
	Pink = Colors.Pink,
	Blue = Colors.Blue,
	Disabled = Colors.Grey,
}

local function apply(instance: Instance, props: { [string]: any }?)
	if props then
		for key, value in props do
			(instance :: any)[key] = value
		end
	end
end

-- ===== Decorators =====

function UILib.addCorner(target: GuiObject, radius: UDim?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.Sizes.Corner
	corner.Parent = target
	return corner
end

function UILib.addStroke(target: GuiObject, thickness: number?, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or Theme.Sizes.Outline
	stroke.Color = color or Colors.Outline
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- outline the box, not the text
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = target
	return stroke
end

-- Glossy look: a white-to-transparent highlight from the top (rotation 90 = top to bottom).
function UILib.addGradient(target: GuiObject, colors: ColorSequence?, rotation: number?): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = colors or ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(225, 225, 225))
	gradient.Rotation = rotation or 90
	gradient.Parent = target
	return gradient
end

function UILib.addPadding(target: GuiObject, scale: number?): UIPadding
	local padding = Instance.new("UIPadding")
	local amount = UDim.new(scale or 0.04, 0)
	padding.PaddingTop = amount
	padding.PaddingBottom = amount
	padding.PaddingLeft = amount
	padding.PaddingRight = amount
	padding.Parent = target
	return padding
end

function UILib.addAspect(target: GuiObject, ratio: number): UIAspectRatioConstraint
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = ratio
	aspect.Parent = target
	return aspect
end

function UILib.addSizeLimit(target: GuiObject, minSize: Vector2?, maxSize: Vector2?): UISizeConstraint
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = minSize or Vector2.zero
	limit.MaxSize = maxSize or Vector2.new(math.huge, math.huge)
	limit.Parent = target
	return limit
end

function UILib.addTextLimit(label: TextLabel | TextButton, maxSize: number?, minSize: number?): UITextSizeConstraint
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize or Theme.Sizes.TextMax
	limit.MinTextSize = minSize or 8
	limit.Parent = label
	return limit
end

-- ===== Sound =====

local clickSound: Sound? = nil

function UILib.playClickSound()
	if Assets.isPlaceholder(Assets.SFX_BUTTON_CLICK) then
		return
	end
	if clickSound == nil then
		local sound = Instance.new("Sound")
		sound.Name = "UIClick"
		sound.SoundId = Assets.SFX_BUTTON_CLICK
		sound.Volume = 0.5
		sound.Parent = SoundService
		clickSound = sound
	end
	SoundService:PlayLocalSound(clickSound :: Sound)
end

local soundCache: { [string]: Sound? } = {}

-- Plays a UI/game sound locally (does nothing until the asset id is filled in).
function UILib.playSound(soundId: string, playbackSpeed: number?, volume: number?)
	if Assets.isPlaceholder(soundId) then
		return
	end
	local sound = soundCache[soundId]
	if sound == nil then
		local created = Instance.new("Sound")
		created.SoundId = soundId
		created.Parent = SoundService
		soundCache[soundId] = created
		sound = created
	end
	local playing = sound :: Sound
	playing.PlaybackSpeed = playbackSpeed or 1
	playing.Volume = volume or 0.6
	SoundService:PlayLocalSound(playing)
end

-- ===== Button effects =====

local function effectScale(button: GuiObject): UIScale
	local scale = button:FindFirstChild("EffectScale") :: UIScale?
	if scale == nil then
		local created = Instance.new("UIScale")
		created.Name = "EffectScale"
		created.Parent = button
		scale = created
	end
	return scale :: UIScale
end

local function tweenScale(button: GuiObject, value: number, info: TweenInfo)
	TweenService:Create(effectScale(button), info, { Scale = value }):Play()
end

-- Grows slightly while the mouse is over the button (purely cosmetic; nothing is hover-only).
function UILib.addHoverEffect(button: GuiButton)
	button.MouseEnter:Connect(function()
		if not button:GetAttribute("Disabled") then
			tweenScale(button, 1.05, Theme.Motion.Hover)
		end
	end)
	button.MouseLeave:Connect(function()
		tweenScale(button, 1, Theme.Motion.Hover)
	end)
end

-- Squishes on press, bounces back on release. Works for mouse and touch.
function UILib.addPressEffect(button: GuiButton)
	button.MouseButton1Down:Connect(function()
		if not button:GetAttribute("Disabled") then
			tweenScale(button, 0.93, Theme.Motion.Press)
		end
	end)
	button.MouseButton1Up:Connect(function()
		tweenScale(button, 1, Theme.Motion.Hover)
	end)
end

--[[
	Connects a click handler that plays the click sound and ignores clicks while
	the button is disabled (UILib.setButtonStyle(button, "Disabled")).
]]
function UILib.onActivated(button: GuiButton, handler: () -> ()): RBXScriptConnection
	return button.Activated:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		UILib.playClickSound()
		handler()
	end)
end

-- ===== Basic building blocks =====

function UILib.createScreenGui(name: string, layer: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- clear of the top bar and notches
	gui.DisplayOrder = layer
	return gui
end

function UILib.createFrame(parent: Instance?, props: { [string]: any }?): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Colors.Cream
	apply(frame, props)
	frame.Parent = parent
	return frame
end

function UILib.createLabel(parent: Instance?, props: { [string]: any }?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Theme.Fonts.Body
	label.TextColor3 = Colors.Text
	label.TextScaled = true
	label.TextWrapped = true
	label.Size = UDim2.fromScale(1, 1)
	apply(label, props)
	UILib.addTextLimit(label)
	label.Parent = parent
	return label
end

-- White text with a dark outline, for titles on colored backgrounds.
function UILib.outlinedText(label: TextLabel | TextButton)
	local text = label :: any -- both classes share these properties
	text.TextColor3 = Colors.TextLight
	text.TextStrokeColor3 = Colors.Outline
	text.TextStrokeTransparency = 0
end

--[[
	An icon from a sprite name ("PetPenguin") or an asset id. When the art isn't
	available yet it shows a colored circle with optional fallback text instead.
]]
function UILib.createIcon(
	parent: Instance?,
	icon: string?,
	fallbackColor: Color3?,
	fallbackText: string?,
	props: { [string]: any }?
): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.ScaleType = Enum.ScaleType.Fit
	image.Size = UDim2.fromScale(1, 1)
	apply(image, props)

	local shown = false
	if icon and Sprites.exists(icon) then
		shown = Sprites.apply(image, icon)
	elseif icon and not Assets.isPlaceholder(icon) then
		image.Image = icon
		shown = true
	end

	if not shown then
		local circle = UILib.createFrame(image, {
			Name = "Fallback",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.86, 0.86),
			BackgroundColor3 = fallbackColor or Colors.WaffleLight,
		})
		UILib.addAspect(circle, 1)
		UILib.addCorner(circle, Theme.Sizes.CornerPill)
		UILib.addStroke(circle, Theme.Sizes.Outline)
		UILib.addGradient(circle)
		if fallbackText then
			UILib.createLabel(circle, {
				Size = UDim2.fromScale(0.7, 0.7),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Text = fallbackText,
			})
		end
	end

	image.Parent = parent
	return image
end

--[[
	A waffle-bordered cream panel with a soft shadow, like the bars in the art.
	Returns (outer, inner): position/size the outer, put content in the inner.
	cornerRadius defaults to Theme.Sizes.Corner (use Theme.Sizes.CornerPill for pills).
]]
function UILib.createPanel(parent: Instance?, props: { [string]: any }?, cornerRadius: UDim?): (Frame, Frame)
	local outer = UILib.createFrame(parent, { Name = "Panel", BackgroundColor3 = Colors.Waffle })
	apply(outer, props)
	UILib.addCorner(outer, cornerRadius)
	UILib.addStroke(outer, Theme.Sizes.OutlineThick)
	UILib.addGradient(outer, ColorSequence.new(Colors.WaffleLight, Colors.Waffle))

	local inner = UILib.createFrame(outer, {
		Name = "Inner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -16, 1, -16), -- an 8px waffle border all round
		BackgroundColor3 = Colors.Cream,
	})
	UILib.addCorner(inner, cornerRadius)
	UILib.addStroke(inner, Theme.Sizes.OutlineThin, Colors.Waffle)
	return outer, inner
end

-- ===== Buttons =====

function UILib.setButtonStyle(button: GuiButton, style: ButtonStyle)
	button.BackgroundColor3 = BUTTON_COLORS[style]
	button:SetAttribute("Disabled", style == "Disabled")
	button.AutoButtonColor = false
	local label = button:FindFirstChild("Label") :: TextLabel?
	if label then
		if style == "Secondary" then
			label.TextColor3 = Colors.Text
			label.TextStrokeTransparency = 1
		else
			UILib.outlinedText(label)
		end
	end
end

function UILib.setButtonText(button: GuiButton, text: string)
	local label = button:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = text
	end
end

--[[
	A chunky glossy button with a text label, click sound, hover and press effects.
	props: Text, Style (ButtonStyle), OnClick, plus any TextButton property
	(Size, Position, AnchorPoint, LayoutOrder, Name...).
]]
function UILib.createButton(parent: Instance?, props: { [string]: any }): TextButton
	local button = Instance.new("TextButton")
	button.Name = props.Name or "Button"
	button.Text = ""
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Size = UDim2.fromScale(0.3, 0.12)
	for key, value in props do
		if key ~= "Text" and key ~= "Style" and key ~= "OnClick" and key ~= "Name" then
			(button :: any)[key] = value
		end
	end
	UILib.addCorner(button, Theme.Sizes.CornerPill)
	UILib.addStroke(button, Theme.Sizes.Outline)
	UILib.addGradient(button)
	UILib.addSizeLimit(button, Theme.Sizes.MinTapTarget)

	UILib.createLabel(button, {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.64),
		Text = props.Text or "",
	})

	UILib.setButtonStyle(button, props.Style or "Primary")
	UILib.addHoverEffect(button)
	UILib.addPressEffect(button)
	if props.OnClick then
		UILib.onActivated(button, props.OnClick)
	end
	button.Parent = parent
	return button
end

-- ===== Progress bar =====

export type ProgressBar = {
	Frame: Frame,
	set: (fraction: number, animate: boolean?) -> (),
}

-- A rounded bar with a glossy fill. set(0..1) updates it.
function UILib.createProgressBar(parent: Instance?, color: Color3?, props: { [string]: any }?): ProgressBar
	local back = UILib.createFrame(parent, { Name = "ProgressBar", BackgroundColor3 = Colors.CreamDark })
	apply(back, props)
	UILib.addCorner(back, Theme.Sizes.CornerPill)
	UILib.addStroke(back, Theme.Sizes.OutlineThin)

	local fill = UILib.createFrame(back, {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color or Colors.Green,
	})
	UILib.addCorner(fill, Theme.Sizes.CornerPill)
	UILib.addGradient(fill)

	local current: Tween? = nil
	return {
		Frame = back,
		set = function(fraction: number, animate: boolean?)
			local size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
			if current then
				current:Cancel()
			end
			if animate then
				current = TweenService:Create(fill, Theme.Motion.CountUp, { Size = size });
				(current :: Tween):Play()
			else
				fill.Size = size
			end
		end,
	}
end

--[[
	A progress bar drawn with one of the bar sprites (PatienceBar, ComboBar, BarFrame).
	Keeps the sprite's shape with an aspect constraint; falls back to a plain
	progress bar if the sprite sheet isn't uploaded.
]]
function UILib.createSpriteBar(
	parent: Instance?,
	spriteName: string,
	color: Color3?,
	props: { [string]: any }?
): ProgressBar
	local track = Theme.BarTracks[spriteName]
	local image = Instance.new("ImageLabel")
	image.Name = spriteName
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	image.Size = UDim2.fromScale(1, 1)
	apply(image, props)
	UILib.addAspect(image, Sprites.aspectRatio(spriteName))
	image.Parent = parent

	if track == nil or not Sprites.apply(image, spriteName) then
		local bar = UILib.createProgressBar(image, color, { Size = UDim2.fromScale(1, 0.4) })
		bar.Frame.AnchorPoint = Vector2.new(0, 0.5)
		bar.Frame.Position = UDim2.fromScale(0, 0.5)
		return { Frame = image :: any, set = bar.set }
	end

	-- Hide the painted fill with an empty track, then draw our own fill on top.
	local empty = UILib.createFrame(image, {
		Name = "Track",
		Position = UDim2.fromScale(track[1], track[2]),
		Size = UDim2.fromScale(track[3] - track[1], track[4] - track[2]),
		BackgroundColor3 = Colors.CreamDark,
	})
	UILib.addCorner(empty, Theme.Sizes.CornerPill)
	local fill = UILib.createFrame(empty, {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color or Colors.Green,
	})
	UILib.addCorner(fill, Theme.Sizes.CornerPill)
	UILib.addGradient(fill)

	local current: Tween? = nil
	return {
		Frame = image :: any,
		set = function(fraction: number, animate: boolean?)
			local size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
			if current then
				current:Cancel()
			end
			if animate then
				current = TweenService:Create(fill, Theme.Motion.CountUp, { Size = size });
				(current :: Tween):Play()
			else
				fill.Size = size
			end
		end,
	}
end

-- ===== Scrolling containers =====

local function createScroller(parent: Instance?, props: { [string]: any }?): ScrollingFrame
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Scroller"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollingDirection = Enum.ScrollingDirection.Y
	scroller.ScrollBarThickness = 8
	scroller.ScrollBarImageColor3 = Colors.Waffle
	scroller.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	apply(scroller, props)
	scroller.Parent = parent
	return scroller
end

--[[
	A vertical scrolling list. Rows keep the given width:height ratio (rowAspect)
	at any screen size: their height is recalculated from the list's width.
	Returns the ScrollingFrame; parent rows to it.
]]
function UILib.createScrollingList(parent: Instance?, rowAspect: number, props: { [string]: any }?): ScrollingFrame
	local scroller = createScroller(parent, props)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroller

	local function resizeRow(row: Instance)
		if row:IsA("GuiObject") then
			local width = scroller.AbsoluteSize.X - scroller.ScrollBarThickness - 4
			row.Size = UDim2.new(1, -(scroller.ScrollBarThickness + 4), 0, math.floor(width / rowAspect))
		end
	end
	scroller.ChildAdded:Connect(resizeRow)
	scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		for _, row in scroller:GetChildren() do
			resizeRow(row)
		end
	end)
	return scroller
end

-- A scrolling grid with `columns` cells per row, each cellAspect (width:height).
function UILib.createScrollingGrid(
	parent: Instance?,
	columns: number,
	cellAspect: number,
	props: { [string]: any }?
): ScrollingFrame
	local scroller = createScroller(parent, props)
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.Parent = scroller

	local function resize()
		local width = scroller.AbsoluteSize.X - scroller.ScrollBarThickness - 4
		local cellWidth = math.floor((width - (columns - 1) * 8) / columns)
		grid.CellSize = UDim2.fromOffset(cellWidth, math.floor(cellWidth / cellAspect))
	end
	scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	return scroller
end

-- ===== Tabs =====

export type Tabs = {
	Frame: Frame,
	select: (name: string) -> (),
}

-- A row of tab buttons. onSelect(name) runs when a tab is picked (and for the first tab).
function UILib.createTabs(parent: Instance?, names: { string }, onSelect: (name: string) -> ()): Tabs
	local bar = UILib.createFrame(parent, { Name = "Tabs", BackgroundTransparency = 1 })
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.02, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	local buttons: { [string]: TextButton } = {}
	local selected: string? = nil

	local function selectTab(name: string)
		if selected == name then
			return
		end
		selected = name
		for tabName, button in buttons do
			UILib.setButtonStyle(button, if tabName == name then "Pink" else "Secondary")
		end
		onSelect(name)
	end

	for index, name in names do
		buttons[name] = UILib.createButton(bar, {
			Name = name,
			Text = name,
			Style = "Secondary",
			LayoutOrder = index,
			Size = UDim2.fromScale(math.min(0.3, 0.9 / #names), 1),
			OnClick = function()
				selectTab(name)
			end,
		})
	end

	return { Frame = bar, select = selectTab }
end

-- ===== Windows =====

export type Window = {
	Root: CanvasGroup, -- the whole window (fades as a group)
	Body: Frame, -- put content here
	CloseButton: TextButton,
	setTitle: (title: string) -> (),
}

-- Sprinkle colors for the frosting strip on window titles.
local SPRINKLE_COLORS = {
	Color3.fromRGB(255, 110, 170),
	Color3.fromRGB(110, 190, 255),
	Color3.fromRGB(255, 210, 80),
	Color3.fromRGB(130, 220, 120),
	Color3.fromRGB(190, 140, 255),
}

--[[
	A big centered window: waffle panel, frosted title banner with a cherry,
	and a close button. Hidden until UILib.tweenIn(window.Root).
	props: Title, AspectRatio (default 1.45), MaxSize (Vector2)
]]
function UILib.createWindow(gui: ScreenGui, props: { [string]: any }): Window
	local root = Instance.new("CanvasGroup")
	root.Name = (props.Title or "Window") .. "Window"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.52)
	root.Size = UDim2.fromScale(0.7, 0.8)
	root.Visible = false
	UILib.addAspect(root, props.AspectRatio or 1.45)
	UILib.addSizeLimit(root, Vector2.new(320, 220), props.MaxSize or Vector2.new(920, 640))
	local openScale = Instance.new("UIScale")
	openScale.Name = "OpenScale"
	openScale.Parent = root

	-- Inset by a few pixels: a CanvasGroup clips anything (like outlines) drawn past its edges.
	local _, inner = UILib.createPanel(root, {
		Position = UDim2.new(0, 6, 0.08, 0),
		Size = UDim2.new(1, -12, 0.92, -6),
	})

	-- Frosted title banner across the top edge, with a cherry and sprinkles.
	local banner = UILib.createFrame(root, {
		Name = "TitleBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromScale(0.44, 0.14),
		BackgroundColor3 = Colors.FrostingPink,
		ZIndex = 3,
	})
	UILib.addCorner(banner, Theme.Sizes.CornerPill)
	UILib.addStroke(banner, Theme.Sizes.OutlineThick)
	UILib.addGradient(banner)
	for index = 1, 7 do
		local sprinkle = UILib.createFrame(banner, {
			Name = "Sprinkle",
			Size = UDim2.fromScale(0.045, 0.12),
			Position = UDim2.fromScale(0.08 + index * 0.11, if index % 2 == 0 then 0.1 else 0.78),
			Rotation = (index * 47) % 90 - 45,
			BackgroundColor3 = SPRINKLE_COLORS[(index - 1) % #SPRINKLE_COLORS + 1],
			ZIndex = 3,
		})
		UILib.addCorner(sprinkle, Theme.Sizes.CornerPill)
	end
	local title = UILib.createLabel(banner, {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.62),
		Text = props.Title or "",
		Font = Theme.Fonts.Title,
		ZIndex = 4,
	})
	UILib.outlinedText(title)

	local cherry = UILib.createIcon(root, "NotificationDot", Colors.Cherry, nil, {
		Name = "Cherry",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.29, 0.03),
		Size = UDim2.fromScale(0.06, 0.06),
		ZIndex = 5,
	})
	UILib.addAspect(cherry, 1)

	local close = UILib.createButton(root, {
		Name = "Close",
		Text = "X",
		Style = "Danger",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.985, 0.03),
		Size = UDim2.fromScale(0.08, 0.12),
		ZIndex = 5,
	})
	UILib.addAspect(close, 1)

	local body = UILib.createFrame(inner, { Name = "Body", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local bodyPadding = UILib.addPadding(body, 0.03)
	bodyPadding.PaddingTop = UDim.new(0.09, 0) -- room under the title banner

	root.Parent = gui
	return {
		Root = root,
		Body = body,
		CloseButton = close,
		setTitle = function(text: string)
			title.Text = text
		end,
	}
end

-- Pop-in: scale up with a little overshoot while fading in.
function UILib.tweenIn(root: CanvasGroup)
	local scale = root:FindFirstChild("OpenScale") :: UIScale?
	root.Visible = true
	root.GroupTransparency = 1
	if scale then
		scale.Scale = 0.85
		TweenService:Create(scale, Theme.Motion.Open, { Scale = 1 }):Play()
	end
	TweenService:Create(root, Theme.Motion.Open, { GroupTransparency = 0 }):Play()
end

-- Shrink and fade out, then hide. onDone runs once it's hidden.
function UILib.tweenOut(root: CanvasGroup, onDone: (() -> ())?)
	local scale = root:FindFirstChild("OpenScale") :: UIScale?
	if scale then
		TweenService:Create(scale, Theme.Motion.Close, { Scale = 0.9 }):Play()
	end
	local fade = TweenService:Create(root, Theme.Motion.Close, { GroupTransparency = 1 })
	fade.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			root.Visible = false
			if onDone then
				onDone()
			end
		end
	end)
	fade:Play()
end

-- ===== Toasts =====

export type ToastKind = "Info" | "Success" | "Error"

local TOAST_COLORS: { [ToastKind]: Color3 } = {
	Info = Colors.Cream,
	Success = Colors.Green,
	Error = Colors.Cherry,
}

--[[
	A small pill message. Returns a transparent CanvasGroup (fade it with
	GroupTransparency) holding the pill; the caller sizes and stacks it.
]]
function UILib.createToast(parent: Instance?, text: string, kind: ToastKind?): CanvasGroup
	local toast = Instance.new("CanvasGroup")
	toast.Name = "Toast"
	toast.BackgroundTransparency = 1
	toast.Size = UDim2.fromScale(1, 0.3)

	local pill = UILib.createFrame(toast, {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -10, 1, -10), -- room for the outline inside the CanvasGroup
		BackgroundColor3 = TOAST_COLORS[(kind or "Info") :: ToastKind],
	})
	UILib.addCorner(pill, Theme.Sizes.CornerPill)
	UILib.addStroke(pill, Theme.Sizes.Outline)
	UILib.addGradient(pill)
	local label = UILib.createLabel(pill, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.62),
		Text = text,
	})
	if kind == "Success" or kind == "Error" then
		UILib.outlinedText(label)
	end
	toast.Parent = parent
	return toast
end

return UILib
