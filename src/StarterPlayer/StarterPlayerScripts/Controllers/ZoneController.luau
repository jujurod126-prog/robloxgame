--!strict
--[[
	ZoneController
	When you arrive in an area (Player attribute "Neighborhood"), smoothly changes
	this client's lighting to that area's look (Shared/Data/Neighborhoods Lighting:
	time of day, ambient, Atmosphere, ColorCorrection) and crossfades its music.
	Lighting changes here are local to this player.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Modules.Assets)
local GameConfig = require(Shared.Data.GameConfig)
local Neighborhoods = require(Shared.Data.Neighborhoods)

local player = Players.LocalPlayer

local FADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local MUSIC_VOLUME = 0.35

local ZoneController = {}

local atmosphere: Atmosphere
local colorCorrection: ColorCorrectionEffect
local music: Sound?

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

local function playMusic(soundId: string)
	if music and music.SoundId == soundId then
		return
	end
	local old = music
	if old then
		local fade = TweenService:Create(old, FADE, { Volume = 0 })
		fade.Completed:Connect(function()
			old:Destroy()
		end)
		fade:Play()
	end
	music = nil
	if Assets.isPlaceholder(soundId) then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "ZoneMusic"
	sound.SoundId = soundId
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, FADE, { Volume = MUSIC_VOLUME }):Play()
	music = sound
end

local function applyArea(areaId: string)
	local area = Neighborhoods[areaId]
	if area == nil then
		return
	end
	local look = area.Lighting
	TweenService:Create(Lighting, FADE, {
		ClockTime = look.ClockTime,
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
	playMusic(area.Music)
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
end

return ZoneController
