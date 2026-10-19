--!strict
--[[
	PetFollowController
	Draws every player's equipped pets floating behind them (2D sprites on
	billboards, so the pet art works without 3D models). Reads each player's
	"EquippedPets" attribute ("Penguin:Normal,Cow:Golden") set by PetService.
	Followers are local-only parts; one Heartbeat loop moves all of them smoothly.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Pets = require(Shared.Data.Pets)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)

local FOLLOW_SPEED = 8 -- higher = snappier
local ROW_SPACING = 3.2 -- studs between pets side by side
local BEHIND = 5 -- studs behind the player
local HOVER = 1.5 -- studs above the player's root
local BOB_HEIGHT = 0.35
local SNAP_DISTANCE = 60 -- farther than this (e.g. after a teleport) jumps straight to the player

local PetFollowController = {}

type Follower = { part: Part, index: number }
type Owner = { followers: { Follower }, connections: { RBXScriptConnection } }

local folder: Folder
local owners: { [Player]: Owner } = {}

local function clearFollowers(owner: Owner)
	for _, follower in owner.followers do
		follower.part:Destroy()
	end
	table.clear(owner.followers)
end

local function createFollower(petId: string, golden: boolean, index: number): Follower?
	local def = Pets[petId]
	if def == nil then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = "PetFollower"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.Parent = folder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(3, 3)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	billboard.Parent = part

	if golden then
		-- A soft gold glow behind golden pets.
		local glow = UILib.createFrame(billboard, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.1, 1.1),
			BackgroundColor3 = Theme.Colors.Coin,
			BackgroundTransparency = 0.45,
		})
		UILib.addCorner(glow, Theme.Sizes.CornerPill)
	end
	UILib.createIcon(billboard, def.Icon, Theme.Rarity[def.Rarity], def.DisplayName:sub(1, 1), {
		ZIndex = 2,
	})
	return { part = part, index = index }
end

local function rebuild(player: Player, owner: Owner)
	clearFollowers(owner)
	local list = (player:GetAttribute("EquippedPets") :: string?) or ""
	local index = 0
	for entry in string.gmatch(list, "[^,]+") do
		local petId, variant = string.match(entry, "^(%w+):(%w+)$")
		if petId then
			index += 1
			local follower = createFollower(petId, variant == "Golden", index)
			if follower then
				table.insert(owner.followers, follower)
			end
		end
	end
	-- Start them at the player so they don't fly in from the world origin.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		for _, follower in owner.followers do
			follower.part.CFrame = root.CFrame
		end
	end
end

local function watch(player: Player)
	local owner: Owner = { followers = {}, connections = {} }
	owners[player] = owner
	table.insert(
		owner.connections,
		player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
			rebuild(player, owner)
		end)
	)
	table.insert(
		owner.connections,
		player.CharacterAdded:Connect(function()
			rebuild(player, owner)
		end)
	)
	rebuild(player, owner)
end

local function unwatch(player: Player)
	local owner = owners[player]
	if owner then
		clearFollowers(owner)
		for _, connection in owner.connections do
			connection:Disconnect()
		end
		owners[player] = nil
	end
end

local function step(deltaTime: number)
	local alpha = 1 - math.exp(-FOLLOW_SPEED * deltaTime)
	local now = os.clock()
	for player, owner in owners do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local count = #owner.followers
		if root and count > 0 then
			for _, follower in owner.followers do
				local x = (follower.index - (count + 1) / 2) * ROW_SPACING
				local bob = math.sin(now * 3 + follower.index) * BOB_HEIGHT
				local target = (root.CFrame * CFrame.new(x, HOVER + bob, BEHIND)).Position
				local current = follower.part.Position
				local position = if (target - current).Magnitude > SNAP_DISTANCE
					then target
					else current:Lerp(target, alpha)
				follower.part.CFrame = CFrame.new(position)
			end
		end
	end
end

function PetFollowController.Init()
	folder = Instance.new("Folder")
	folder.Name = "PetFollowers"
	folder.Parent = Workspace
end

function PetFollowController.Start()
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(unwatch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	RunService.Heartbeat:Connect(step)
end

return PetFollowController
