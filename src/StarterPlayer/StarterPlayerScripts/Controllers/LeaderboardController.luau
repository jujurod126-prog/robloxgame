--!strict
--[[
	LeaderboardController
	Draws the top-10 lists on the Hub's LeaderboardWall (a part WorldBuilder makes,
	or one named "LeaderboardWall" in your own World map). The lists come from
	LeaderboardService as JSON in ReplicatedStorage.Leaderboards (MostCoins,
	MostRebirths) and redraw whenever the server refreshes them.
	Both big faces of the wall get a SurfaceGui, so it reads from either side.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Data.GameConfig)
local NumberFormat = require(Shared.Modules.NumberFormat)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local UILib = require(UI.UILib)

local player = Players.LocalPlayer
local Colors = Theme.Colors

local BOARDS = {
	{ Key = "MostCoins", Title = "Most Coins Earned" },
	{ Key = "MostRebirths", Title = "Most Rebirths" },
}
local PIXELS_PER_STUD = 25
local RANK_COLORS = { Colors.Coin, Color3.fromRGB(215, 220, 230), Color3.fromRGB(230, 160, 110) }

type Entry = { Rank: number, Name: string, Value: number }

local LeaderboardController = {}

local columns: { [string]: { Frame } } = {} -- board key -> its column frame on each face

local function decode(value: StringValue): { Entry }
	local ok, list = pcall(HttpService.JSONDecode, HttpService, value.Value)
	return if ok and type(list) == "table" then list else {}
end

local function drawColumn(column: Frame, entries: { Entry })
	for _, child in column:GetChildren() do
		if child.Name == "Row" then
			child:Destroy()
		end
	end
	local rows = GameConfig.Leaderboards.TopCount
	for index = 1, rows do
		local entry = entries[index]
		local isMe = entry ~= nil and entry.Name == player.Name
		local row = UILib.createFrame(column, {
			Name = "Row",
			LayoutOrder = index,
			Size = UDim2.fromScale(1, 0.84 / rows),
			BackgroundColor3 = if isMe then Colors.FrostingPink else Colors.Cream,
			BackgroundTransparency = if index % 2 == 0 then 0.2 else 0,
		})
		UILib.addCorner(row, UDim.new(0.25, 0))
		local rank = UILib.createLabel(row, {
			Position = UDim2.fromScale(0.02, 0.1),
			Size = UDim2.fromScale(0.12, 0.8),
			Text = `#{index}`,
			TextColor3 = RANK_COLORS[index] or Colors.Text,
		})
		if RANK_COLORS[index] then
			rank.TextStrokeColor3 = Colors.Outline
			rank.TextStrokeTransparency = 0
		end
		UILib.createLabel(row, {
			Position = UDim2.fromScale(0.16, 0.1),
			Size = UDim2.fromScale(0.52, 0.8),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if entry then entry.Name else "---",
		})
		UILib.createLabel(row, {
			Position = UDim2.fromScale(0.7, 0.1),
			Size = UDim2.fromScale(0.28, 0.8),
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = if entry then NumberFormat.short(entry.Value) else "",
		})
	end
end

local function buildFace(wall: BasePart, face: Enum.NormalId)
	local surface = Instance.new("SurfaceGui")
	surface.Name = `Leaderboards{face.Name}`
	surface.Face = face
	surface.Adornee = wall
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = PIXELS_PER_STUD
	surface.LightInfluence = 0
	surface.MaxDistance = 200
	surface.Parent = wall -- goes away with the wall if it streams out

	local holder = UILib.createFrame(surface, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	UILib.addPadding(holder, 0.03)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.04, 0)
	layout.Parent = holder

	for index, board in BOARDS do
		local column = UILib.createFrame(holder, {
			Name = board.Key,
			LayoutOrder = index,
			Size = UDim2.fromScale(0.46, 1),
			BackgroundTransparency = 1,
		})
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0.006, 0)
		list.Parent = column
		local title = UILib.createLabel(column, {
			Name = "Title",
			LayoutOrder = 0,
			Size = UDim2.fromScale(1, 0.1),
			Text = board.Title,
		})
		UILib.outlinedText(title)
		columns[board.Key] = columns[board.Key] or {}
		table.insert(columns[board.Key], column)
	end
end

local function redraw(key: string, value: StringValue)
	local entries = decode(value)
	local list: { Frame } = columns[key] or {}
	for _, column in list do
		if column.Parent then
			drawColumn(column, entries)
		end
	end
end

local function setupWall(wall: BasePart)
	table.clear(columns)
	buildFace(wall, Enum.NormalId.Front)
	buildFace(wall, Enum.NormalId.Back)
	local folder = ReplicatedStorage:FindFirstChild("Leaderboards")
	if folder then
		for _, board in BOARDS do
			local value = folder:FindFirstChild(board.Key)
			if value and value:IsA("StringValue") then
				redraw(board.Key, value)
			end
		end
	end
end

function LeaderboardController.Init() end

function LeaderboardController.Start()
	local folder = ReplicatedStorage:WaitForChild("Leaderboards", 30)
	if folder == nil then
		return
	end
	for _, board in BOARDS do
		local value = folder:WaitForChild(board.Key, 30)
		if value and value:IsA("StringValue") then
			value.Changed:Connect(function()
				redraw(board.Key, value)
			end)
		end
	end

	-- The wall can stream in and out, so watch for it.
	local world = Workspace:WaitForChild("World")
	local function check(instance: Instance)
		if instance.Name == "LeaderboardWall" and instance:IsA("BasePart") then
			setupWall(instance)
		end
	end
	for _, descendant in world:GetDescendants() do
		check(descendant)
	end
	world.DescendantAdded:Connect(check)
end

return LeaderboardController
