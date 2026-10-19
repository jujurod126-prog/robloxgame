--!strict
--[[
	Sprites
	Puts one sprite from the uploaded sprite sheets onto an ImageLabel/ImageButton.
	Sheet IDs live in Assets (SPRITE_SHEET_1..4); positions in SpriteRects (generated).

	if Sprites.apply(imageLabel, "PetPenguin") then ... end  -- false = not uploaded yet
	Sprites.aspectRatio("BarFrame")                           -- width / height, for UIAspectRatioConstraint
]]

local Assets = require(script.Parent.Assets)
local SpriteRects = require(script.Parent.SpriteRects)

local SHEETS: { string } = {
	Assets.SPRITE_SHEET_1,
	Assets.SPRITE_SHEET_2,
	Assets.SPRITE_SHEET_3,
	Assets.SPRITE_SHEET_4,
}

local Sprites = {}

function Sprites.exists(name: string): boolean
	return SpriteRects[name] ~= nil
end

--[[
	Shows sprite `name` on the label. Returns false (and leaves the label blank)
	if the sprite doesn't exist or its sheet hasn't been uploaded yet, so callers
	can show a fallback.
]]
function Sprites.apply(label: ImageLabel | ImageButton, name: string): boolean
	local image = label :: any -- both classes have the same image properties
	local rect = SpriteRects[name]
	local sheet = rect and SHEETS[rect[1]]
	if rect == nil or sheet == nil or Assets.isPlaceholder(sheet) then
		image.Image = ""
		return false
	end
	image.Image = sheet
	image.ImageRectOffset = Vector2.new(rect[2], rect[3])
	image.ImageRectSize = Vector2.new(rect[4], rect[5])
	return true
end

-- Width divided by height of the sprite (1 if unknown).
function Sprites.aspectRatio(name: string): number
	local rect = SpriteRects[name]
	return if rect then rect[4] / rect[5] else 1
end

return Sprites
