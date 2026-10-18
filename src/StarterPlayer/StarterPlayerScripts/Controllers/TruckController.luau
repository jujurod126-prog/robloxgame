--!strict
--[[
	TruckController
	Client-side touches for trucks (the server owns the trucks themselves):
	  * hides other players' Scoop prompts, so you only see your own
	  * on touch-only devices, scooping is a tap instead of a hold
	    (the server still enforces the scoop cooldown)
	  * shows an owner nameplate above every truck
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Trucks = require(ReplicatedStorage.Shared.Data.Trucks)

local player = Players.LocalPlayer

local TruckController = {}

local nameplates: { [Model]: BillboardGui } = {}

local function isTouchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Tap-to-scoop: no hold, then the prompt disables itself for the scoop time.
local function setupTapToScoop(prompt: ProximityPrompt)
	local function forceTap()
		if prompt.HoldDuration ~= 0 then
			prompt.HoldDuration = 0
		end
	end
	forceTap()
	prompt:GetPropertyChangedSignal("HoldDuration"):Connect(forceTap) -- server updates it on upgrades

	prompt.Triggered:Connect(function()
		prompt.Enabled = false
		task.delay((prompt:GetAttribute("ScoopSeconds") :: number?) or 1, function()
			prompt.Enabled = true
		end)
	end)
end

local function createNameplate(truck: Model)
	local root = truck.PrimaryPart or truck:WaitForChild("Root", 5) :: BasePart?
	local ownerName = truck:GetAttribute("OwnerName")
	if root == nil or ownerName == nil then
		return
	end
	local tier = Trucks[(truck:GetAttribute("Tier") :: number?) or 1]

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TruckNameplate"
	billboard.Adornee = root
	billboard.Size = UDim2.fromScale(8, 1.6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 11, 0)
	billboard.MaxDistance = 120
	billboard.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(70, 45, 60)
	label.Text = `{ownerName}'s {if tier then tier.DisplayName else "Truck"}`
	label.Parent = billboard

	billboard.Parent = player:WaitForChild("PlayerGui")
	nameplates[truck] = billboard
end

local function onTruckAdded(truck: Instance)
	if not truck:IsA("Model") then
		return
	end
	local isMine = truck:GetAttribute("OwnerUserId") == player.UserId

	local dispenser = truck:WaitForChild("Dispenser", 5)
	local prompt = dispenser and dispenser:WaitForChild("ScoopPrompt", 5) :: ProximityPrompt?
	if prompt then
		if not isMine then
			prompt.Enabled = false
		elseif isTouchOnly() then
			setupTapToScoop(prompt)
		end
	end

	createNameplate(truck)
end

local function onTruckRemoved(truck: Instance)
	local billboard = nameplates[truck :: Model]
	if billboard then
		billboard:Destroy()
		nameplates[truck :: Model] = nil
	end
end

function TruckController.Init() end

function TruckController.Start()
	local folder = Workspace:WaitForChild("Trucks")
	folder.ChildAdded:Connect(onTruckAdded)
	folder.ChildRemoved:Connect(onTruckRemoved)
	for _, truck in folder:GetChildren() do
		task.spawn(onTruckAdded, truck)
	end
end

return TruckController
