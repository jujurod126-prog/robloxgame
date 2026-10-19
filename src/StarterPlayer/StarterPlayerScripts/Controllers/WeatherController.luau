--!strict
--[[
	WeatherController
	Shows the server's weather (Workspace attribute "Weather", set by EventService):
	  Rain     - rain falling around the camera, slightly darker colors, rain sound
	  Heatwave - a warm, bright tint
	  Clear    - nothing
	Everything here is local visuals; the gameplay effects happen on the server.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Modules.Assets)

local UILib = require(script.Parent.Parent.UI.UILib)

local FADE = TweenInfo.new(3, Enum.EasingStyle.Sine)
local RAIN_RATE = 400 -- particles per second
local RAIN_HEIGHT = 30 -- studs above the camera where drops start
local BUILTIN_PARTICLE = "rbxasset://textures/particles/sparkles_main.dds"
local RAIN_SOUND_VOLUME = 0.4

type Tint = { TintColor: Color3, Brightness: number, Saturation: number }

local TINTS: { [string]: Tint } = {
	Clear = { TintColor = Color3.new(1, 1, 1), Brightness = 0, Saturation = 0 },
	Rain = { TintColor = Color3.fromRGB(215, 225, 245), Brightness = -0.06, Saturation = -0.15 },
	Heatwave = { TintColor = Color3.fromRGB(255, 232, 205), Brightness = 0.04, Saturation = 0.1 },
}

local WeatherController = {}

local tint: ColorCorrectionEffect
local rainPart: Part
local rain: ParticleEmitter
local rainSound: Sound?

local function createRain()
	rainPart = Instance.new("Part")
	rainPart.Name = "RainEmitter"
	rainPart.Anchored = true
	rainPart.CanCollide = false
	rainPart.CanQuery = false
	rainPart.CanTouch = false
	rainPart.Transparency = 1
	rainPart.Size = Vector3.new(80, 1, 80) -- drops start anywhere over this area

	rain = Instance.new("ParticleEmitter")
	rain.Texture = if Assets.isPlaceholder(Assets.TEXTURE_RAIN_DROP) then BUILTIN_PARTICLE else Assets.TEXTURE_RAIN_DROP
	rain.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255))
	rain.LightEmission = 0.3
	rain.Transparency = NumberSequence.new(0.35)
	rain.Size = NumberSequence.new(0.15)
	rain.Squash = NumberSequence.new(3) -- stretched into streaks
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Speed = NumberRange.new(70, 80)
	rain.Lifetime = NumberRange.new(0.8, 1)
	rain.Rate = RAIN_RATE
	rain.Shape = Enum.ParticleEmitterShape.Box
	rain.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	rain.Enabled = false
	rain.Parent = rainPart

	rainPart.Parent = Workspace.CurrentCamera
end

local function setRainSound(on: boolean)
	if on and rainSound == nil and not Assets.isPlaceholder(Assets.AMBIENT_RAIN) then
		local sound = Instance.new("Sound")
		sound.Name = "Rain"
		sound.SoundId = Assets.AMBIENT_RAIN
		sound.Looped = true
		sound.Volume = 0
		sound.SoundGroup = UILib.soundGroup("SFX")
		sound.Parent = SoundService
		sound:Play()
		TweenService:Create(sound, FADE, { Volume = RAIN_SOUND_VOLUME }):Play()
		rainSound = sound
	elseif not on and rainSound then
		local sound = rainSound :: Sound
		rainSound = nil
		local fade = TweenService:Create(sound, FADE, { Volume = 0 })
		fade.Completed:Connect(function()
			sound:Destroy()
		end)
		fade:Play()
	end
end

local function applyWeather()
	local weather = (Workspace:GetAttribute("Weather") :: string?) or "Clear"
	local look = TINTS[weather] or TINTS.Clear
	TweenService:Create(tint, FADE, look :: any):Play()
	rain.Enabled = weather == "Rain"
	setRainSound(weather == "Rain")
end

function WeatherController.Init()
	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "WeatherTint"
	tint.Parent = Lighting
	createRain()
end

function WeatherController.Start()
	Workspace:GetAttributeChangedSignal("Weather"):Connect(applyWeather)
	applyWeather()

	-- Keep the rain cloud above the camera (only while it's raining).
	RunService.RenderStepped:Connect(function()
		if rain.Enabled then
			local camera = Workspace.CurrentCamera
			rainPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, RAIN_HEIGHT, 0))
			if rainPart.Parent ~= camera then
				rainPart.Parent = camera -- the camera object can be replaced
			end
		end
	end)
end

return WeatherController
