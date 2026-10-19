--!strict
--[[
	Props
	Simple decorations built from Parts, in the chunky candy style.
	Every function takes a parent and a ground-level CFrame and returns the Model.
	All parts are anchored. Replace with real models later by putting your own
	builds in the areas instead (WorldBuilder only adds these if the area has none).
]]

local Props = {}

-- Anchored, smooth part with any properties.
function Props.part(parent: Instance, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Cylinders point along X, so this turns one upright.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

function Props.tree(parent: Instance, at: CFrame, leafColor: Color3?): Model
	local m = model(parent, "Tree")
	Props.part(m, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 2, 2),
		CFrame = at * CFrame.new(0, 4, 0) * UPRIGHT,
		Color = Color3.fromRGB(150, 100, 60),
	})
	Props.part(m, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 9, 9),
		CFrame = at * CFrame.new(0, 10, 0),
		Color = leafColor or Color3.fromRGB(110, 200, 110),
		CanCollide = false,
	})
	return m
end

function Props.bench(parent: Instance, at: CFrame): Model
	local m = model(parent, "Bench")
	local wood = Color3.fromRGB(200, 140, 90)
	Props.part(m, { Name = "Seat", Size = Vector3.new(7, 0.5, 2.4), CFrame = at * CFrame.new(0, 1.8, 0), Color = wood })
	Props.part(m, { Name = "Back", Size = Vector3.new(7, 2, 0.4), CFrame = at * CFrame.new(0, 3, 1), Color = wood })
	for _, x in { -3, 3 } do
		Props.part(m, {
			Name = "Leg",
			Size = Vector3.new(0.5, 1.8, 2),
			CFrame = at * CFrame.new(x, 0.9, 0),
			Color = Color3.fromRGB(90, 80, 90),
		})
	end
	return m
end

function Props.fountain(parent: Instance, at: CFrame): Model
	local m = model(parent, "Fountain")
	Props.part(m, {
		Name = "Basin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 18, 18),
		CFrame = at * CFrame.new(0, 1, 0) * UPRIGHT,
		Color = Color3.fromRGB(235, 230, 225),
	})
	Props.part(m, {
		Name = "Water",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 15, 15),
		CFrame = at * CFrame.new(0, 2, 0) * UPRIGHT,
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
	})
	Props.part(m, {
		Name = "Column",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 2, 2),
		CFrame = at * CFrame.new(0, 4, 0) * UPRIGHT,
		Color = Color3.fromRGB(235, 230, 225),
	})
	Props.part(m, {
		Name = "Top",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		CFrame = at * CFrame.new(0, 7.5, 0),
		Color = Color3.fromRGB(150, 215, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CanCollide = false,
	})
	return m
end

function Props.umbrella(parent: Instance, at: CFrame, color: Color3): Model
	local m = model(parent, "Umbrella")
	Props.part(m, {
		Name = "Pole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(9, 0.5, 0.5),
		CFrame = at * CFrame.new(0, 4.5, 0) * UPRIGHT,
		Color = Color3.fromRGB(240, 240, 240),
	})
	Props.part(m, {
		Name = "Canopy",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 10, 10),
		CFrame = at * CFrame.new(0, 9, 0) * UPRIGHT,
		Color = color,
		CanCollide = false,
	})
	Props.part(m, {
		Name = "Towel",
		Size = Vector3.new(4, 0.15, 7),
		CFrame = at * CFrame.new(3, 0.1, 2),
		Color = color:Lerp(Color3.new(1, 1, 1), 0.4),
		CanCollide = false,
	})
	return m
end

function Props.lifeguardTower(parent: Instance, at: CFrame): Model
	local m = model(parent, "LifeguardTower")
	local wood = Color3.fromRGB(230, 200, 150)
	for _, x in { -3, 3 } do
		for _, z in { -3, 3 } do
			Props.part(
				m,
				{ Name = "Leg", Size = Vector3.new(0.8, 10, 0.8), CFrame = at * CFrame.new(x, 5, z), Color = wood }
			)
		end
	end
	Props.part(m, {
		Name = "Cabin",
		Size = Vector3.new(8, 5, 8),
		CFrame = at * CFrame.new(0, 12.5, 0),
		Color = Color3.fromRGB(255, 120, 110),
	})
	Props.part(m, {
		Name = "Roof",
		Size = Vector3.new(10, 1, 10),
		CFrame = at * CFrame.new(0, 15.5, 0),
		Color = Color3.fromRGB(255, 255, 255),
	})
	return m
end

function Props.ferrisWheel(parent: Instance, at: CFrame): Model
	local m = model(parent, "FerrisWheel")
	local radius, cars = 22, 10
	local hub = at * CFrame.new(0, radius + 6, 0)
	for _, x in { -3, 3 } do
		Props.part(m, {
			Name = "Support",
			Size = Vector3.new(1.5, radius + 8, 2),
			CFrame = at * CFrame.new(x, (radius + 8) / 2, 0),
			Color = Color3.fromRGB(240, 240, 250),
		})
	end
	Props.part(m, {
		Name = "Hub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(7, 4, 4),
		CFrame = hub,
		Color = Color3.fromRGB(255, 200, 80),
	})
	local colors = {
		Color3.fromRGB(255, 130, 170),
		Color3.fromRGB(120, 200, 255),
		Color3.fromRGB(255, 220, 90),
		Color3.fromRGB(150, 230, 140),
	}
	for index = 1, cars do
		local angle = (index / cars) * math.pi * 2
		local spoke = hub * CFrame.Angles(angle, 0, 0)
		Props.part(m, {
			Name = "Spoke",
			Size = Vector3.new(0.6, radius, 0.6),
			CFrame = spoke * CFrame.new(0, radius / 2, 0),
			Color = Color3.fromRGB(240, 240, 250),
			CanCollide = false,
		})
		local carPosition = (spoke * CFrame.new(0, radius, 0)).Position
		Props.part(m, {
			Name = "Car",
			Size = Vector3.new(5, 3.5, 4),
			CFrame = CFrame.new(carPosition) * (at - at.Position) * CFrame.new(0, -2, 0),
			Color = colors[(index - 1) % #colors + 1],
			CanCollide = false,
		})
	end
	return m
end

function Props.balloonStand(parent: Instance, at: CFrame): Model
	local m = model(parent, "BalloonStand")
	Props.part(m, {
		Name = "Cart",
		Size = Vector3.new(5, 3, 3),
		CFrame = at * CFrame.new(0, 1.5, 0),
		Color = Color3.fromRGB(255, 240, 220),
	})
	local colors = {
		Color3.fromRGB(255, 90, 120),
		Color3.fromRGB(90, 170, 255),
		Color3.fromRGB(255, 210, 60),
		Color3.fromRGB(160, 110, 255),
		Color3.fromRGB(110, 220, 140),
	}
	for index, color in colors do
		local offset = Vector3.new((index - 3) * 1.4, 9 + (index % 2) * 1.5, (index % 3 - 1) * 1)
		Props.part(m, {
			Name = "Balloon",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.4, 2.4, 2.4),
			CFrame = at * CFrame.new(offset),
			Color = color,
			CanCollide = false,
		})
		Props.part(m, {
			Name = "String",
			Size = Vector3.new(0.1, offset.Y - 3, 0.1),
			CFrame = at * CFrame.new(offset.X / 2, (offset.Y + 3) / 2, offset.Z / 2),
			Color = Color3.fromRGB(80, 80, 80),
			CanCollide = false,
		})
	end
	return m
end

-- A string of glowing bulbs between two points (high posts at each end).
function Props.stringLights(parent: Instance, from: Vector3, to: Vector3, height: number): Model
	local m = model(parent, "StringLights")
	local colors = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 150, 200), Color3.fromRGB(150, 220, 255) }
	for _, base in { from, to } do
		Props.part(m, {
			Name = "Post",
			Size = Vector3.new(0.8, height, 0.8),
			CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)),
			Color = Color3.fromRGB(240, 240, 250),
		})
	end
	local bulbs = 12
	for index = 1, bulbs - 1 do
		local alpha = index / bulbs
		local sag = math.sin(alpha * math.pi) * 3
		local position = from:Lerp(to, alpha) + Vector3.new(0, height - sag, 0)
		Props.part(m, {
			Name = "Bulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(position),
			Color = colors[index % #colors + 1],
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	return m
end

function Props.cabin(parent: Instance, at: CFrame, color: Color3): Model
	local m = model(parent, "Cabin")
	Props.part(m, {
		Name = "Walls",
		Size = Vector3.new(16, 10, 12),
		CFrame = at * CFrame.new(0, 5, 0),
		Color = color,
		Material = Enum.Material.WoodPlanks,
	})
	for _, side in { -1, 1 } do
		Props.part(m, {
			Name = "Roof",
			Size = Vector3.new(18, 1, 8.5),
			CFrame = at * CFrame.new(0, 12.5, side * 3.2) * CFrame.Angles(math.rad(-side * 35), 0, 0),
			Color = Color3.fromRGB(250, 250, 255),
		})
	end
	Props.part(m, {
		Name = "Door",
		Size = Vector3.new(3, 6, 0.4),
		CFrame = at * CFrame.new(0, 3, -6.1),
		Color = Color3.fromRGB(120, 70, 40),
	})
	Props.part(m, {
		Name = "Window",
		Size = Vector3.new(3, 3, 0.3),
		CFrame = at * CFrame.new(5, 6, -6.1),
		Color = Color3.fromRGB(255, 220, 140),
		Material = Enum.Material.Neon,
	})
	return m
end

function Props.pineTree(parent: Instance, at: CFrame): Model
	local m = model(parent, "PineTree")
	Props.part(m, {
		Name = "Trunk",
		Size = Vector3.new(1.6, 4, 1.6),
		CFrame = at * CFrame.new(0, 2, 0),
		Color = Color3.fromRGB(120, 80, 50),
	})
	for index, size in { 10, 7.5, 5 } do
		Props.part(m, {
			Name = "Needles",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size * 0.8, size),
			CFrame = at * CFrame.new(0, 3 + index * 3, 0),
			Color = Color3.fromRGB(80, 150, 110),
			CanCollide = false,
		})
		Props.part(m, {
			Name = "Snow",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size * 0.7, size * 0.35, size * 0.7),
			CFrame = at * CFrame.new(0, 3.3 + index * 3 + size * 0.25, 0),
			Color = Color3.fromRGB(250, 250, 255),
			CanCollide = false,
		})
	end
	return m
end

function Props.pond(parent: Instance, at: CFrame, radius: number, color: Color3, material: Enum.Material): Part
	return Props.part(parent, {
		Name = "Pond",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = at * CFrame.new(0, 0.1, 0) * UPRIGHT,
		Color = color,
		Material = material,
	})
end

function Props.lollipop(parent: Instance, at: CFrame, color: Color3, height: number): Model
	local m = model(parent, "Lollipop")
	Props.part(m, {
		Name = "Stick",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.2, 1.2),
		CFrame = at * CFrame.new(0, height / 2, 0) * UPRIGHT,
		Color = Color3.fromRGB(255, 255, 255),
	})
	Props.part(m, {
		Name = "Candy",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, height * 0.6, height * 0.6),
		CFrame = at * CFrame.new(0, height + height * 0.25, 0),
		Color = color,
		CanCollide = false,
	})
	Props.part(m, {
		Name = "Swirl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.2, height * 0.35, height * 0.35),
		CFrame = at * CFrame.new(0, height + height * 0.25, 0),
		Color = Color3.fromRGB(255, 255, 255),
		CanCollide = false,
	})
	return m
end

function Props.gumdrop(parent: Instance, at: CFrame, color: Color3, size: number): Part
	return Props.part(parent, {
		Name = "Gumdrop",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		CFrame = at * CFrame.new(0, size * 0.15, 0),
		Color = color,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
	})
end

return Props
