--!strict
--[[
	ZoneController
	When you arrive in an area (Player attribute "Neighborhood"), smoothly changes
	this client's lighting to that area's look (Shared/Data/Neighborhoods Lighting:
	ambient, Atmosphere, ColorCorrection). Lighting changes here are local to this player.
	The time of day follows the server's day/night clock (Workspace attribute
	ClockTime from EventService); an area's own ClockTime is only used until that
	attribute exists. Music lives in SoundController.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Data.GameConfig)
local Neighborhoods = require(Shared.Data.Neighborhoods)

local player = Players.LocalPlayer

local FADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local ZoneController = {}

local atmosphere: Atmosphere
local colorCorrection: ColorCorrectionEffect

-- Finds an existing effect of this class in Lighting (yours from Studio) or makes one.
local function ensure<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing :: any
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created :: any
end

local function applyArea(areaId: string)
	local area = Neighborhoods[areaId]
	if area == nil then
		return
	end
	local look = area.Lighting
	if Workspace:GetAttribute("ClockTime") == nil then
		Lighting.ClockTime = look.ClockTime
	end
	TweenService:Create(Lighting, FADE, {
		Ambient = look.Ambient,
		OutdoorAmbient = look.Ambient,
	}):Play()
	TweenService:Create(atmosphere, FADE, {
		Color = look.AtmosphereColor,
		Decay = look.AtmosphereDecay,
		Density = look.AtmosphereDensity,
		Haze = look.AtmosphereHaze,
	}):Play()
	TweenService:Create(colorCorrection, FADE, {
		TintColor = look.TintColor,
		Saturation = look.Saturation,
		Contrast = look.Contrast,
		Brightness = look.Brightness,
	}):Play()
end

-- Copies the server clock into Lighting whenever it changes (every 2 s, a tiny
-- step). Moving the sun every frame would make phones redo lighting constantly.
local function followClock()
	local target = Workspace:GetAttribute("ClockTime") :: number?
	if target then
		Lighting.ClockTime = target % 24
	end
end

function ZoneController.Init()
	atmosphere = ensure("Atmosphere", "ZoneAtmosphere")
	colorCorrection = ensure("ColorCorrectionEffect", "ZoneColor")
	local bloom = ensure("BloomEffect", "ZoneBloom") :: BloomEffect
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 0.95
end

function ZoneController.Start()
	local function update()
		applyArea((player:GetAttribute("Neighborhood") :: string?) or GameConfig.Starting.Neighborhood)
	end
	player:GetAttributeChangedSignal("Neighborhood"):Connect(update)
	update()
	Workspace:GetAttributeChangedSignal("ClockTime"):Connect(followClock)
	followClock()
end

return ZoneController
