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
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Data.GameConfig)
local Neighborhoods = require(Shared.Data.Neighborhoods)

local player = Players.LocalPlayer

local FADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
-- How fast the shown clock catches up with the server clock (fraction per second).
local CLOCK_FOLLOW_RATE = 2

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

-- Eases Lighting.ClockTime toward the server clock every frame, going the short
-- way round midnight (23.9 -> 0.1 moves forward, not back through the day).
local function followClock(deltaTime: number)
	local target = Workspace:GetAttribute("ClockTime") :: number?
	if target == nil then
		return
	end
	local current = Lighting.ClockTime
	local difference = (target - current + 12) % 24 - 12
	if math.abs(difference) > 6 then
		Lighting.ClockTime = target -- far off (just joined): jump
	else
		Lighting.ClockTime = (current + difference * math.min(1, deltaTime * CLOCK_FOLLOW_RATE)) % 24
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
	RunService.RenderStepped:Connect(followClock)
end

return ZoneController
