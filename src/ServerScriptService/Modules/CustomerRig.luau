--!strict
--[[
	CustomerRig
	Builds simple blocky customer NPCs out of Parts and keeps a pool of them,
	so customers are reused instead of created and destroyed every time.

	A rig is a Model whose PrimaryPart "Root" is anchored. Customers move by
	tweening Root's CFrame (no physics or Humanoid needed), and all body parts
	are welded to Root so they follow.

	Want real characters later? Put a Model named "CustomerRig" in
	ServerStorage with an anchored PrimaryPart and welded, unanchored parts;
	it will be cloned instead of the blocky rig.
]]

local ServerStorage = game:GetService("ServerStorage")

local CustomerRig = {}

-- Height of Root's center above the ground. Use this when placing a rig.
CustomerRig.ROOT_HEIGHT = 2.2

local SKIN_TONES = {
	Color3.fromRGB(255, 220, 185),
	Color3.fromRGB(240, 195, 150),
	Color3.fromRGB(200, 150, 110),
	Color3.fromRGB(150, 100, 70),
	Color3.fromRGB(100, 65, 45),
}

local OUTFIT_COLORS = {
	Color3.fromRGB(255, 150, 170),
	Color3.fromRGB(150, 200, 255),
	Color3.fromRGB(170, 230, 170),
	Color3.fromRGB(255, 210, 120),
	Color3.fromRGB(200, 160, 240),
	Color3.fromRGB(255, 170, 120),
	Color3.fromRGB(120, 210, 210),
	Color3.fromRGB(245, 245, 245),
	Color3.fromRGB(90, 110, 160),
}

local random = Random.new()
local pool: { Model } = {}

local function pick<T>(list: { T }): T
	return list[random:NextInteger(1, #list)]
end

local function addPart(model: Model, root: BasePart, name: string, size: Vector3, offset: CFrame, shape: Enum.PartType?)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Shape = shape or Enum.PartType.Block
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- Offsets are relative to Root (which sits ROOT_HEIGHT above the ground).
-- The rig faces -Z, like every Roblox model's LookVector.
local function buildBlockyRig(): Model
	local model = Instance.new("Model")
	model.Name = "Customer"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- clients get the whole rig at once

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.Parent = model
	model.PrimaryPart = root

	addPart(model, root, "Legs", Vector3.new(1.6, 1.6, 0.9), CFrame.new(0, -1.4, 0))
	addPart(model, root, "Torso", Vector3.new(2, 1.8, 1), CFrame.new(0, 0.3, 0))
	addPart(model, root, "LeftArm", Vector3.new(0.6, 1.6, 0.6), CFrame.new(-1.3, 0.2, 0))
	addPart(model, root, "RightArm", Vector3.new(0.6, 1.6, 0.6), CFrame.new(1.3, 0.2, 0))
	addPart(model, root, "Head", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 2, 0), Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		local eye = addPart(
			model,
			root,
			"Eye",
			Vector3.new(0.25, 0.25, 0.25),
			CFrame.new(side * 0.35, 2.15, -0.72),
			Enum.PartType.Ball
		)
		eye.Color = Color3.fromRGB(30, 25, 30)
	end
	return model
end

local function createRig(): Model
	local template = ServerStorage:FindFirstChild("CustomerRig")
	if template and template:IsA("Model") and template.PrimaryPart then
		local clone = template:Clone()
		clone.Name = "Customer"
		clone.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		return clone
	end
	return buildBlockyRig()
end

-- Gives the blocky rig a new random skin tone and outfit (custom rigs are left alone).
local function randomizeLook(model: Model)
	local skin = pick(SKIN_TONES)
	local shirt = pick(OUTFIT_COLORS)
	local pants = pick(OUTFIT_COLORS)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			if part.Name == "Head" or part.Name == "LeftArm" or part.Name == "RightArm" then
				part.Color = skin
			elseif part.Name == "Torso" then
				part.Color = shirt
			elseif part.Name == "Legs" then
				part.Color = pants
			end
		end
	end
end

-- Takes a rig from the pool (or builds one), freshly randomized. Caller positions and parents it.
function CustomerRig.acquire(): Model
	local model = table.remove(pool) or createRig()
	randomizeLook(model)
	return model
end

-- Returns a rig to the pool. Clears everything the customer added to it.
function CustomerRig.release(model: Model)
	model.Parent = nil
	for name in model:GetAttributes() do
		model:SetAttribute(name, nil)
	end
	local root = model.PrimaryPart
	if root then
		for _, child in root:GetChildren() do
			if child:IsA("ProximityPrompt") then
				child:Destroy()
			end
		end
	end
	table.insert(pool, model)
end

return CustomerRig
