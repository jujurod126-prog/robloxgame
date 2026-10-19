--!strict
--[[
	WorldLayout
	Where each area of the world is, and how its ground looks. WorldBuilder
	builds the islands from this; TruckService puts truck lots on them.

	Areas are separate islands far apart, so each can have its own lighting
	and music (applied when you teleport in). Coordinates are world studs;
	every island's ground top is at y = 0.
	Positions inside an area are offsets from its Center:
	  * truck lots line up along X at LotRowZ (trucks face -Z, customers come from -Z)
	  * Spawn is where you arrive in the Hub; in other areas you appear behind your truck
	  * HubPad is the teleport pad back to the Hub
]]

local Shared = script.Parent.Parent
local TableUtil = require(Shared.Modules.TableUtil)

export type AreaLayout = {
	Center: Vector3,
	Size: Vector2, -- ground X by Z
	GroundColor: Color3,
	GroundMaterial: Enum.Material,
	LotRowZ: number, -- offset of the truck lot row from Center
	Spawn: Vector3, -- offset from Center
	HubPad: Vector3?, -- offset from Center (nil for the Hub itself)
}

local ISLAND = Vector2.new(420, 420)

local WorldLayout: { [string]: AreaLayout } = {
	Hub = {
		Center = Vector3.new(0, 0, -900),
		Size = Vector2.new(360, 300),
		GroundColor = Color3.fromRGB(255, 236, 214),
		GroundMaterial = Enum.Material.SmoothPlastic,
		LotRowZ = 0,
		Spawn = Vector3.new(0, 3, 60),
		HubPad = nil,
	},
	SunnySidewalk = {
		Center = Vector3.new(0, 0, 0),
		Size = ISLAND,
		GroundColor = Color3.fromRGB(120, 200, 100),
		GroundMaterial = Enum.Material.Grass,
		LotRowZ = 60,
		Spawn = Vector3.new(0, 3, 100),
		HubPad = Vector3.new(0, 0, 140),
	},
	BeachBoardwalk = {
		Center = Vector3.new(1200, 0, 0),
		Size = ISLAND,
		GroundColor = Color3.fromRGB(245, 222, 160),
		GroundMaterial = Enum.Material.Sand,
		LotRowZ = 60,
		Spawn = Vector3.new(0, 3, 100),
		HubPad = Vector3.new(0, 0, 140),
	},
	CarnivalSquare = {
		Center = Vector3.new(2400, 0, 0),
		Size = ISLAND,
		GroundColor = Color3.fromRGB(255, 205, 190),
		GroundMaterial = Enum.Material.SmoothPlastic,
		LotRowZ = 60,
		Spawn = Vector3.new(0, 3, 100),
		HubPad = Vector3.new(0, 0, 140),
	},
	SnowyVillage = {
		Center = Vector3.new(3600, 0, 0),
		Size = ISLAND,
		GroundColor = Color3.fromRGB(240, 248, 255),
		GroundMaterial = Enum.Material.Snow,
		LotRowZ = 60,
		Spawn = Vector3.new(0, 3, 100),
		HubPad = Vector3.new(0, 0, 140),
	},
	CandyKingdom = {
		Center = Vector3.new(4800, 0, 0),
		Size = ISLAND,
		GroundColor = Color3.fromRGB(255, 190, 220),
		GroundMaterial = Enum.Material.SmoothPlastic,
		LotRowZ = 60,
		Spawn = Vector3.new(0, 3, 100),
		HubPad = Vector3.new(0, 0, 140),
	},
}

return TableUtil.deepFreeze(WorldLayout)
