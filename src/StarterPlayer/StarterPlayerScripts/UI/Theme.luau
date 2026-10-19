--!strict
--[[
	Theme
	Every color, font and size the UI uses, matched to the art sheets
	(waffle borders, cream fill, frosting, cherries, thick dark outlines).
	Change values here to restyle the whole game. Asset IDs live in
	Shared/Modules/Assets and are re-exported as Theme.Assets.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Modules.Assets)

local Theme = {}

Theme.Assets = Assets

Theme.Colors = {
	Outline = Color3.fromRGB(75, 40, 45), -- the thick dark brown outline on every sprite
	Text = Color3.fromRGB(75, 40, 45),
	TextLight = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(140, 110, 105),

	Cream = Color3.fromRGB(255, 246, 228), -- panel fill
	CreamDark = Color3.fromRGB(242, 226, 200), -- inset areas, rows
	Waffle = Color3.fromRGB(232, 162, 82), -- borders
	WaffleLight = Color3.fromRGB(248, 200, 128),
	Frosting = Color3.fromRGB(255, 250, 242),
	FrostingPink = Color3.fromRGB(255, 176, 205),
	FrostingBlue = Color3.fromRGB(176, 222, 248),
	Cherry = Color3.fromRGB(226, 40, 52),

	Green = Color3.fromRGB(104, 206, 88), -- buy / confirm / progress
	GreenDark = Color3.fromRGB(64, 160, 60),
	Pink = Color3.fromRGB(255, 122, 172),
	Orange = Color3.fromRGB(255, 186, 60),
	Blue = Color3.fromRGB(96, 178, 255),
	Grey = Color3.fromRGB(186, 178, 176), -- disabled
	Coin = Color3.fromRGB(255, 200, 52),
	Gem = Color3.fromRGB(110, 200, 255),

	Shadow = Color3.fromRGB(60, 30, 40),
	Overlay = Color3.fromRGB(40, 20, 30),
}

-- Rarity colors for frames, borders and text (Mythic also gets a rainbow gradient).
Theme.Rarity = {
	Common = Color3.fromRGB(170, 170, 180),
	Uncommon = Color3.fromRGB(96, 200, 90),
	Rare = Color3.fromRGB(70, 160, 255),
	Epic = Color3.fromRGB(165, 95, 235),
	Legendary = Color3.fromRGB(255, 195, 40),
	Mythic = Color3.fromRGB(255, 110, 200),
}

Theme.MythicGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 110)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(130, 230, 140)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(120, 190, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 140, 255)),
})

Theme.Fonts = {
	Title = Enum.Font.FredokaOne,
	Body = Enum.Font.FredokaOne,
	Number = Enum.Font.FredokaOne,
}

Theme.Sizes = {
	OutlineThick = 4, -- windows, big buttons
	Outline = 3, -- cards, small buttons
	OutlineThin = 2,
	Corner = UDim.new(0.18, 0), -- rounded corners as a fraction of the shorter side
	CornerPill = UDim.new(0.5, 0),
	MinTapTarget = Vector2.new(44, 44),
	TextMax = 32, -- largest auto-scaled text, px
	TextMaxSmall = 20,
}

Theme.Motion = {
	Open = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Close = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	Hover = TweenInfo.new(0.1, Enum.EasingStyle.Quad),
	Press = TweenInfo.new(0.06, Enum.EasingStyle.Quad),
	CountUp = TweenInfo.new(0.5, Enum.EasingStyle.Quad),
}

--[[
	Inner track of each bar sprite, as fractions of the sprite (X0, Y0, X1, Y1).
	UILib.createSpriteBar covers the painted fill with an empty track and draws
	a live fill inside this rectangle. Measured from assets/sprites/parts.
]]
Theme.BarTracks = {
	PatienceBar = { 0.36, 0.605, 0.93, 0.85 },
	ComboBar = { 0.235, 0.61, 0.925, 0.885 },
	BarFrame = { 0.09, 0.53, 0.925, 0.86 },
}

-- ScreenGui DisplayOrder per layer: higher draws on top.
Theme.Layers = {
	Hud = 0,
	Window = 10,
	Notification = 20,
}

return Theme
