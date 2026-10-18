--!strict
--[[
	ConeTool
	Builds the Cone tool the player holds, and draws the scoops on top of it.
]]

local ConeTool = {}

local CONE_COLOR = Color3.fromRGB(222, 170, 100)
local SCOOP_SIZE = 0.75
local SCOOP_STACK_GAP = 0.55

function ConeTool.create(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Cone"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Scoop ice cream at your truck, then serve customers"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 1.4, 0.6)
	handle.Color = CONE_COLOR
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	return tool
end

-- Replaces the scoop balls on the cone with one ball per color, stacked upward.
function ConeTool.setScoops(tool: Tool, colors: { Color3 })
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if handle == nil then
		return
	end
	for _, child in handle:GetChildren() do
		if child.Name == "Scoop" then
			child:Destroy()
		end
	end
	for index, color in colors do
		local scoop = Instance.new("Part")
		scoop.Name = "Scoop"
		scoop.Shape = Enum.PartType.Ball
		scoop.Size = Vector3.new(SCOOP_SIZE, SCOOP_SIZE, SCOOP_SIZE)
		scoop.Color = color
		scoop.Material = Enum.Material.SmoothPlastic
		scoop.CanCollide = false
		scoop.Massless = true
		scoop.CFrame = handle.CFrame * CFrame.new(0, handle.Size.Y / 2 + (index - 0.5) * SCOOP_STACK_GAP, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = scoop
		weld.Parent = scoop
		scoop.Parent = handle
	end
end

return ConeTool
