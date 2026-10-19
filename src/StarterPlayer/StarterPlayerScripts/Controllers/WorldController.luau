--!strict
--[[
	WorldController
	Client-side touches for the world the server builds (Workspace.World):
	  * floating signs on any part with a SignText attribute
	  * neighborhood gates: the sign shows the price or lock reason; once YOU have
	    unlocked a neighborhood its barrier disappears and the Unlock prompt hides
	    (only for you - the server still checks access on the teleport pad)
	  * Hub counters (parts with OpensWindow) open their window when you use the prompt
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local NeighborhoodRules = require(Shared.Modules.NeighborhoodRules)
local Neighborhoods = require(Shared.Data.Neighborhoods)
local NumberFormat = require(Shared.Modules.NumberFormat)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)
local WindowManager = require(UI.WindowManager)

local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

local Colors = Theme.Colors

local WorldController = {}

type Gate = { model: Model, id: string, barrier: BasePart?, prompt: ProximityPrompt?, status: TextLabel? }

local gates: { [Model]: Gate } = {}

local function createSign(part: BasePart): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Adornee = part
	billboard.Size = UDim2.fromScale(14, 3)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, (part:GetAttribute("SignHeight") :: number?) or 4, 0)
	billboard.MaxDistance = 160
	billboard.Parent = part -- removed together with the part when it streams out
	local label = UILib.createLabel(billboard, { Text = part:GetAttribute("SignText") :: string })
	UILib.outlinedText(label)
	return label
end

-- Barrier, prompt and status line for one gate, from the player's current data.
local function updateGate(gate: Gate)
	local data = DataController.getData()
	local area = Neighborhoods[gate.id]
	if data == nil or area == nil then
		return
	end
	local status = NeighborhoodRules.status(data, gate.id)
	local open = status.State == "Unlocked" and NeighborhoodRules.canEnter(data, gate.id)
	if gate.barrier then
		gate.barrier.Transparency = if open then 1 else 0.2
		gate.barrier.CanCollide = not open
	end
	if gate.prompt then
		gate.prompt.Enabled = status.State ~= "Unlocked"
		gate.prompt.ActionText = if status.State == "Available"
			then `Unlock for {NumberFormat.short(status.Cost)}`
			else "Locked"
	end
	if gate.status then
		if open then
			gate.status.Text = "Open!"
			gate.status.TextColor3 = Colors.Green
		elseif status.State == "NeedsRebirth" then
			gate.status.Text = `Needs Rebirth {area.RequiresRebirths}`
			gate.status.TextColor3 = Colors.Pink
		elseif status.State == "NeedsPrevious" then
			gate.status.Text = "Unlock the previous area first"
			gate.status.TextColor3 = Colors.TextLight
		else
			gate.status.Text = `Unlock for {NumberFormat.short(status.Cost)} Coins`
			gate.status.TextColor3 = Colors.Coin
		end
	end
end

local function setupGate(model: Model)
	local id = model:GetAttribute("NeighborhoodId") :: string
	local barrier = model:FindFirstChild("Barrier") :: BasePart?
	local gate: Gate = {
		model = model,
		id = id,
		barrier = barrier,
		prompt = barrier and barrier:FindFirstChild("UnlockPrompt") :: ProximityPrompt?,
		status = nil,
	}
	if barrier then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "GateStatus"
		billboard.Adornee = barrier
		billboard.Size = UDim2.fromScale(16, 2.4)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
		billboard.MaxDistance = 120
		billboard.Parent = barrier
		local label = UILib.createLabel(billboard, {})
		UILib.outlinedText(label)
		gate.status = label
	end
	gates[model] = gate
	model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			gates[model] = nil -- streamed out or removed
		end
	end)
	updateGate(gate)
end

local function setupWindowPrompt(part: BasePart)
	local window = part:GetAttribute("OpensWindow") :: string
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if prompt == nil then
		return
	end
	prompt.Triggered:Connect(function()
		if WindowManager.isRegistered(window) then
			WindowManager.open(window)
		else
			NotificationController.toast(`{part:GetAttribute("SignText") or window} opens in a later update!`, "Info")
		end
	end)
end

local function setup(instance: Instance)
	if instance:IsA("BasePart") then
		if instance:GetAttribute("SignText") then
			createSign(instance)
		end
		if instance:GetAttribute("OpensWindow") then
			setupWindowPrompt(instance)
		end
	elseif instance:IsA("Model") and instance:GetAttribute("NeighborhoodId") then
		setupGate(instance)
	end
end

function WorldController.Init() end

function WorldController.Start()
	local world = Workspace:WaitForChild("World")
	DataController.waitForData()
	for _, descendant in world:GetDescendants() do
		setup(descendant)
	end
	-- With StreamingEnabled, far-away parts arrive later.
	world.DescendantAdded:Connect(setup)

	-- Coins change on every serve: refresh the gates at most once per frame.
	local pending = false
	DataController.Changed:Connect(function(path: { any })
		local key = path[1]
		if not pending and (#path == 0 or key == "Neighborhoods" or key == "Coins" or key == "Rebirths") then
			pending = true
			task.defer(function()
				pending = false
				for _, gate in gates do
					updateGate(gate)
				end
			end)
		end
	end)
end

return WorldController
