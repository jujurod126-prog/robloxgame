--!strict
--[[
	WorldBuilder
	Builds the playable world from Shared/Data/WorldLayout when the server starts:
	  * an island per area (Hub + 5 neighborhoods) with a road for the truck lots
	  * decorations per neighborhood (park, beach, carnival, snow, candy)
	  * Hub: Truck Garage, Flavor Lab, Pet Parlor, Rebirth Machine, leaderboard wall,
	    and a row of gates - one per neighborhood - each with a teleport pad behind it
	  * a "To Hub" teleport pad in every neighborhood

	Tagging conventions other scripts rely on (keep these if you build your own map):
	  Part "TravelPad"       attribute TravelTo = area id ("Hub" or a neighborhood)
	  Model "Gate_<id>"      attribute NeighborhoodId; contains Part "Barrier" with
	                         ProximityPrompt "UnlockPrompt"
	  Part with SignText     the client shows a floating sign (attributes SignText, SignHeight)
	  Part with OpensWindow  has a ProximityPrompt; the client opens that window

	If Workspace already has a Folder named "World" (your own build), it's used as-is.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Neighborhoods = require(Shared.Data.Neighborhoods)
local TableUtil = require(Shared.Modules.TableUtil)
local WorldLayout = require(Shared.Data.WorldLayout)

local Props = require(script.Parent.Props)

local WorldBuilder = {}

local ROAD_COLOR = Color3.fromRGB(110, 105, 120)
local PAD_COLOR = Color3.fromRGB(120, 230, 255)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local random = Random.new(1234) -- fixed seed: the same world every time

-- ===== Shared pieces =====

local function buildGround(folder: Folder, areaId: string)
	local layout = WorldLayout[areaId]
	local center = layout.Center
	Props.part(folder, {
		Name = "Ground",
		Size = Vector3.new(layout.Size.X, 4, layout.Size.Y),
		-- Top sits a hair above y = 0 so it never flickers against a Baseplate.
		CFrame = CFrame.new(center + Vector3.new(0, -1.95, 0)),
		Color = layout.GroundColor,
		Material = layout.GroundMaterial,
	})
	-- Frosting-style rim around the island edge.
	Props.part(folder, {
		Name = "Rim",
		Size = Vector3.new(layout.Size.X + 6, 3, layout.Size.Y + 6),
		CFrame = CFrame.new(center + Vector3.new(0, -3, 0)),
		Color = Color3.fromRGB(255, 250, 240),
	})
	if not Neighborhoods[areaId].IsHub then
		Props.part(folder, {
			Name = "Road",
			Size = Vector3.new(layout.Size.X - 20, 0.2, 26),
			CFrame = CFrame.new(center + Vector3.new(0, 0.05, layout.LotRowZ)),
			Color = ROAD_COLOR,
		})
	end
end

local function buildPad(folder: Instance, position: Vector3, travelTo: string, label: string): Part
	local pad = Props.part(folder, {
		Name = "TravelPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 12, 12),
		CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * UPRIGHT,
		Color = PAD_COLOR,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CanCollide = false,
	})
	pad:SetAttribute("TravelTo", travelTo)
	pad:SetAttribute("SignText", label)
	pad:SetAttribute("SignHeight", 5)
	return pad
end

-- ===== Hub =====

local function buildHubBuilding(folder: Folder, at: CFrame, name: string, color: Color3, window: string, action: string)
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = folder
	Props.part(
		model,
		{ Name = "Walls", Size = Vector3.new(34, 18, 22), CFrame = at * CFrame.new(0, 9, 0), Color = color }
	)
	Props.part(model, {
		Name = "Roof",
		Size = Vector3.new(38, 2, 26),
		CFrame = at * CFrame.new(0, 19, 0),
		Color = Color3.fromRGB(255, 250, 240),
	})
	Props.part(model, {
		Name = "Awning",
		Size = Vector3.new(26, 1, 6),
		CFrame = at * CFrame.new(0, 12, -13) * CFrame.Angles(math.rad(-15), 0, 0),
		Color = Color3.fromRGB(255, 130, 160),
	})
	local counter = Props.part(model, {
		Name = "Counter",
		Size = Vector3.new(14, 4, 4),
		CFrame = at * CFrame.new(0, 2, -13),
		Color = Color3.fromRGB(255, 240, 220),
	})
	counter:SetAttribute("OpensWindow", window)
	counter:SetAttribute("SignText", name)
	counter:SetAttribute("SignHeight", 20)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WindowPrompt"
	prompt.ActionText = action
	prompt.ObjectText = name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
end

local function buildGate(folder: Folder, at: CFrame, neighborhood: any)
	local model = Instance.new("Model")
	model.Name = `Gate_{neighborhood.Id}`
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- clients get the whole gate at once
	model:SetAttribute("NeighborhoodId", neighborhood.Id)
	model.Parent = folder
	local color = WorldLayout[neighborhood.Id].GroundColor
	for _, x in { -9, 9 } do
		Props.part(model, {
			Name = "Pillar",
			Size = Vector3.new(4, 20, 4),
			CFrame = at * CFrame.new(x, 10, 0),
			Color = Color3.fromRGB(255, 250, 240),
		})
		Props.part(model, {
			Name = "Cherry",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 4, 4),
			CFrame = at * CFrame.new(x, 22, 0),
			Color = Color3.fromRGB(226, 40, 52),
		})
	end
	local arch = Props.part(
		model,
		{ Name = "Arch", Size = Vector3.new(24, 4, 5), CFrame = at * CFrame.new(0, 19, 0), Color = color }
	)
	arch:SetAttribute("SignText", neighborhood.DisplayName)
	arch:SetAttribute("SignHeight", 6)
	local barrier = Props.part(model, {
		Name = "Barrier",
		Size = Vector3.new(14, 17, 1),
		CFrame = at * CFrame.new(0, 8.5, 0),
		Color = color,
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UnlockPrompt"
	prompt.ActionText = "Unlock"
	prompt.ObjectText = neighborhood.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = barrier
	-- The teleport pad sits just past the gate.
	buildPad(model, (at * CFrame.new(0, 0, -16)).Position, neighborhood.Id, `To {neighborhood.DisplayName}`)
end

local function buildHub(folder: Folder)
	local center = WorldLayout.Hub.Center
	local base = CFrame.new(center)

	-- Buildings are turned around so their counters face the spawn point (+Z).
	local facingSpawn = CFrame.Angles(0, math.pi, 0)
	buildHubBuilding(
		folder,
		base * CFrame.new(-110, 0, 20) * facingSpawn,
		"Truck Garage",
		Color3.fromRGB(150, 205, 255),
		"Shop",
		"Shop"
	)
	buildHubBuilding(
		folder,
		base * CFrame.new(-40, 0, 20) * facingSpawn,
		"Flavor Lab",
		Color3.fromRGB(255, 190, 220),
		"Flavors",
		"Open"
	)
	buildHubBuilding(
		folder,
		base * CFrame.new(40, 0, 20) * facingSpawn,
		"Pet Parlor",
		Color3.fromRGB(190, 240, 180),
		"Pets",
		"Open"
	)
	buildHubBuilding(
		folder,
		base * CFrame.new(110, 0, 20) * facingSpawn,
		"Rebirth Machine",
		Color3.fromRGB(210, 180, 255),
		"Rebirth",
		"Open"
	)

	local wall = Props.part(folder, {
		Name = "LeaderboardWall",
		Size = Vector3.new(60, 24, 2),
		CFrame = base * CFrame.new(0, 12, 130),
		Color = Color3.fromRGB(255, 240, 220),
	})
	wall:SetAttribute("SignText", "Leaderboards")
	wall:SetAttribute("SignHeight", 15)

	-- Gate row along the far side of the plaza, in unlock order.
	local list = {}
	for _, neighborhood in TableUtil.sortedByOrder(Neighborhoods) do
		if not neighborhood.IsHub then
			table.insert(list, neighborhood)
		end
	end
	for index, neighborhood in list do
		local x = (index - (#list + 1) / 2) * 56
		buildGate(folder, base * CFrame.new(x, 0, -80), neighborhood)
	end

	Props.fountain(folder, base * CFrame.new(0, 0, -20))
	for _, x in { -150, 150 } do
		for _, z in { -110, 100 } do
			Props.tree(folder, base * CFrame.new(x, 0, z))
		end
	end
end

-- ===== Neighborhood decorations =====
-- Props stay out of the truck/customer band (local Z 10 to 95) and off the Hub pad.

local function scatter(count: number, minX: number, maxX: number, minZ: number, maxZ: number): { CFrame }
	local result = {}
	for _ = 1, count do
		local x = random:NextNumber(minX, maxX)
		local z = random:NextNumber(minZ, maxZ)
		table.insert(result, CFrame.new(x, 0, z) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0))
	end
	return result
end

local DECORATORS: { [string]: (folder: Folder, base: CFrame) -> () } = {
	SunnySidewalk = function(folder, base)
		Props.fountain(folder, base * CFrame.new(0, 0, -60))
		for _, x in { -40, -20, 20, 40 } do
			Props.bench(folder, base * CFrame.new(x, 0, -40) * CFrame.Angles(0, math.pi, 0))
		end
		for _, at in scatter(12, -190, 190, -190, -80) do
			Props.tree(folder, base * at)
		end
		for _, at in scatter(6, -190, 190, 110, 190) do
			if math.abs(at.Position.X) > 20 then
				Props.tree(folder, base * at)
			end
		end
	end,
	BeachBoardwalk = function(folder, base)
		Props.part(folder, {
			Name = "Sea",
			Size = Vector3.new(420, 0.4, 90),
			CFrame = base * CFrame.new(0, 0.1, -165),
			Color = Color3.fromRGB(90, 190, 240),
			Material = Enum.Material.Glass,
			Transparency = 0.2,
		})
		Props.lifeguardTower(folder, base * CFrame.new(-90, 0, -100))
		local colors = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 220, 90) }
		for index, at in scatter(10, -180, 180, -110, -30) do
			Props.umbrella(folder, base * at, colors[index % #colors + 1])
		end
	end,
	CarnivalSquare = function(folder, base)
		Props.ferrisWheel(folder, base * CFrame.new(0, 0, -120))
		for _, x in { -120, -60, 60, 120 } do
			Props.balloonStand(folder, base * CFrame.new(x, 0, -50))
		end
		for _, x in { -150, -50, 50 } do
			Props.stringLights(
				folder,
				(base * CFrame.new(x, 0, 0)).Position,
				(base * CFrame.new(x + 100, 0, 0)).Position,
				14
			)
		end
	end,
	SnowyVillage = function(folder, base)
		Props.pond(folder, base * CFrame.new(0, 0, -100), 40, Color3.fromRGB(190, 230, 255), Enum.Material.Ice)
		local colors = { Color3.fromRGB(190, 110, 80), Color3.fromRGB(170, 90, 70), Color3.fromRGB(210, 140, 100) }
		for index, x in { -140, -80, 80, 140 } do
			Props.cabin(
				folder,
				base * CFrame.new(x, 0, -60) * CFrame.Angles(0, math.pi, 0),
				colors[index % #colors + 1]
			)
		end
		for _, at in scatter(16, -190, 190, -190, -130) do
			Props.pineTree(folder, base * at)
		end
	end,
	CandyKingdom = function(folder, base)
		Props.part(folder, {
			Name = "ChocolateRiver",
			Size = Vector3.new(420, 0.4, 30),
			CFrame = base * CFrame.new(0, 0.1, -130),
			Color = Color3.fromRGB(110, 60, 35),
		})
		local colors = {
			Color3.fromRGB(255, 90, 140),
			Color3.fromRGB(110, 190, 255),
			Color3.fromRGB(255, 200, 70),
			Color3.fromRGB(170, 110, 255),
		}
		for index, at in scatter(8, -180, 180, -100, -30) do
			Props.lollipop(folder, base * at, colors[index % #colors + 1], random:NextNumber(10, 18))
		end
		for index, at in scatter(10, -190, 190, -190, -150) do
			Props.gumdrop(folder, base * at, colors[index % #colors + 1], random:NextNumber(10, 22))
		end
	end,
}

-- ===== Entry point =====

-- Builds (or finds) the world. Returns the World folder.
function WorldBuilder.build(): Folder
	local existing = Workspace:FindFirstChild("World")
	if existing and existing:IsA("Folder") then
		return existing
	end

	local world = Instance.new("Folder")
	world.Name = "World"
	for areaId, layout in WorldLayout do
		local folder = Instance.new("Folder")
		folder.Name = areaId
		folder.Parent = world
		buildGround(folder, areaId)
		if areaId == "Hub" then
			buildHub(folder)
		else
			local decorate = DECORATORS[areaId]
			if decorate then
				decorate(folder, CFrame.new(layout.Center))
			end
			if layout.HubPad then
				buildPad(folder, layout.Center + layout.HubPad, "Hub", "To Scoop Central")
			end
		end
	end
	world.Parent = Workspace
	return world
end

return WorldBuilder
