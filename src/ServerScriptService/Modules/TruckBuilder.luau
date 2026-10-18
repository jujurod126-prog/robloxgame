--!strict
--[[
	TruckBuilder
	Builds a truck Model out of plain Parts (no assets needed yet).

	Named parts, so cosmetics and later art can be swapped by script:
	  Root (PrimaryPart, invisible, anchored, at ground level)
	  Body, Awning, Window, MenuBoard, Speakers, Dispenser (+ Wheel / Pole decoration)
	Everything is welded to Root, so moving Root moves the whole truck.

	The truck faces -Z: customers stand in front, the player stands behind.
	Attributes set on the model for other scripts:
	  CounterZ  local Z where customers line up
	  StandZ    local Z where the player stands
	  Width     body width in studs
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Data.GameConfig)
local GameData = require(Shared.Types.GameData)

local TruckBuilder = {}

-- Bigger tiers are a bit bigger. Real models per tier can replace this later.
local SCALE_PER_TIER = 0.15
local MENU_BOARD_MIN_TIER = 3
local WHEEL_COLOR = Color3.fromRGB(60, 50, 60)
local POLE_COLOR = Color3.fromRGB(240, 240, 240)
local METAL_COLOR = Color3.fromRGB(200, 205, 215)

export type Colors = {
	Paint: Color3,
	Awning: Color3,
}

local function makePart(model: Model, root: BasePart, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	for key, value in props do
		(part :: any)[key] = value
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- Builds the truck at `pivot` (a ground-level CFrame). The caller parents it.
function TruckBuilder.build(truck: GameData.TruckDef, colors: Colors, pivot: CFrame): Model
	local scale = 1 + (truck.Tier - 1) * SCALE_PER_TIER
	local width, height, depth = 6 * scale, 3 * scale, 4 * scale
	local wheelHeight = 1
	local poleHeight = 3.2 * scale
	local bodyTop = wheelHeight + height

	local model = Instance.new("Model")
	model.Name = truck.Id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- clients get the whole truck at once

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CFrame = pivot
	root.Parent = model
	model.PrimaryPart = root

	local function at(x: number, y: number, z: number): CFrame
		return pivot * CFrame.new(x, y, z)
	end

	makePart(model, root, {
		Name = "Body",
		Size = Vector3.new(width, height, depth),
		CFrame = at(0, wheelHeight + height / 2, 0),
		Color = colors.Paint,
		CanCollide = true,
	})

	for _, side in { -1, 1 } do
		makePart(model, root, {
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder, -- cylinders point along X
			Size = Vector3.new(0.5, 2, 2),
			CFrame = at(side * (width / 2 + 0.25), wheelHeight, 0),
			Color = WHEEL_COLOR,
		})
	end

	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		makePart(model, root, {
			Name = "Pole",
			Size = Vector3.new(0.25, poleHeight, 0.25),
			CFrame = at(corner[1] * (width / 2 - 0.2), bodyTop + poleHeight / 2, corner[2] * (depth / 2 - 0.2)),
			Color = POLE_COLOR,
		})
	end

	local awningY = bodyTop + poleHeight + 0.2
	makePart(model, root, {
		Name = "Awning",
		Size = Vector3.new(width + 1, 0.4, depth + 1),
		CFrame = at(0, awningY, 0),
		Color = colors.Awning,
	})

	makePart(model, root, {
		Name = "Window",
		Size = Vector3.new(width * 0.8, 1.6 * scale, 0.15),
		CFrame = at(0, bodyTop + 1 * scale, -depth / 2 + 0.1),
		Color = Color3.fromRGB(200, 235, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.7,
	})

	makePart(model, root, {
		Name = "MenuBoard",
		Size = Vector3.new(width * 0.5, height * 0.6, 0.15),
		CFrame = at(0, wheelHeight + height / 2, -depth / 2 - 0.08),
		Color = Color3.fromRGB(255, 250, 235),
		Transparency = if truck.Tier >= MENU_BOARD_MIN_TIER then 0 else 1,
	})

	makePart(model, root, {
		Name = "Speakers",
		Size = Vector3.new(1, 0.8, 0.8),
		CFrame = at(0, awningY + 0.6, 0),
		Color = METAL_COLOR,
	})

	local dispenser = makePart(model, root, {
		Name = "Dispenser",
		Size = Vector3.new(1.6, 1.6, 1.2) * scale,
		CFrame = at(0, bodyTop + 0.8 * scale, depth / 4),
		Color = METAL_COLOR,
		Material = Enum.Material.Metal,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ScoopPrompt"
	prompt.ActionText = "Scoop"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = GameConfig.Scooping.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = dispenser

	model:SetAttribute("CounterZ", -(depth / 2 + GameConfig.Trucks.CounterGap))
	model:SetAttribute("StandZ", depth / 2 + GameConfig.Trucks.StandGap)
	model:SetAttribute("Width", width)
	model:SetAttribute("Tier", truck.Tier)

	return model
end

return TruckBuilder
