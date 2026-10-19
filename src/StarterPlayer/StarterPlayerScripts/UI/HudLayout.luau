--!strict
--[[
	HudLayout
	Where the fixed HUD pieces end on screen, so other UI can stack below them
	instead of overlapping on small phones. HudController reports the values;
	toasts, the event banner and the tutorial tip read them.

	Values are screen Y positions (the same space as GuiObject.AbsolutePosition):
	  "TopCenter" - bottom of the location badge (and the friend chip when shown)
	  "TopLeft"   - bottom of the Coins / Gems counters
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Modules.Signal)

export type Edge = "TopCenter" | "TopLeft"

local HudLayout = {}

-- Fires (edge, y) when an edge moves.
HudLayout.Changed = Signal.new()

local edges: { [Edge]: number } = { TopCenter = 0, TopLeft = 0 }

function HudLayout.set(edge: Edge, y: number)
	if edges[edge] ~= y then
		edges[edge] = y
		HudLayout.Changed:Fire(edge, y)
	end
end

function HudLayout.get(edge: Edge): number
	return edges[edge]
end

-- Calls callback() now and whenever any edge moves.
function HudLayout.watch(callback: () -> ())
	callback()
	return HudLayout.Changed:Connect(callback)
end

return HudLayout
