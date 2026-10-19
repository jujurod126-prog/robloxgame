--!strict
--[[
	SoundController
	All of this player's music and the volume settings.
	  * "Music" and "SFX" SoundGroups (UILib.soundGroup); their volumes follow
	    PlayerData.Settings.MusicVolume / SfxVolume
	  * zone music by the Player attribute "Neighborhood", crossfaded;
	    the Rush Hour track replaces it while the player's RushHourEnds is in the future
	  * the area's truck jingle plays once on arrival
	  * scoop sound whenever ConeScoops goes up
	Sounds whose asset id is still a placeholder are skipped silently.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Modules.Assets)
local GameConfig = require(Shared.Data.GameConfig)
local Neighborhoods = require(Shared.Data.Neighborhoods)

local UILib = require(script.Parent.Parent.UI.UILib)
local DataController = require(script.Parent.DataController)

local player = Players.LocalPlayer

local FADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local MUSIC_VOLUME = 0.35 -- each track's own volume; the Music group scales it
local JINGLE_VOLUME = 0.6

local SoundController = {}

local musicGroup: SoundGroup
local sfxGroup: SoundGroup
local music: Sound? = nil
local rushCheckToken = 0

local function currentArea(): string
	return (player:GetAttribute("Neighborhood") :: string?) or GameConfig.Starting.Neighborhood
end

local function isRushHour(): boolean
	local ends = player:GetAttribute("RushHourEnds") :: number?
	return ends ~= nil and Workspace:GetServerTimeNow() < ends
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
	sound.Name = "Music"
	sound.SoundId = soundId
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = musicGroup
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, FADE, { Volume = MUSIC_VOLUME }):Play()
	music = sound
end

local function updateMusic()
	local area = Neighborhoods[currentArea()]
	if isRushHour() and not Assets.isPlaceholder(Assets.MUSIC_RUSH_HOUR) then
		playMusic(Assets.MUSIC_RUSH_HOUR)
	elseif area then
		playMusic(area.Music)
	end
end

-- Switches back to the zone track when this player's Rush Hour ends
-- (re-checks until it really has, in case the server clock shifted a little).
local function scheduleRushCheck(token: number)
	local ends = player:GetAttribute("RushHourEnds") :: number?
	if ends and ends > Workspace:GetServerTimeNow() then
		task.delay(ends - Workspace:GetServerTimeNow() + 0.1, function()
			if token == rushCheckToken then
				updateMusic()
				scheduleRushCheck(token)
			end
		end)
	end
end

local function onRushHourChanged()
	updateMusic()
	rushCheckToken += 1
	scheduleRushCheck(rushCheckToken)
end

local function onArrive()
	updateMusic()
	local area = Neighborhoods[currentArea()]
	if area then
		UILib.playSound(area.Jingle, 1, JINGLE_VOLUME)
	end
end

local function applyVolumes(settings: any)
	if settings then
		musicGroup.Volume = settings.MusicVolume
		sfxGroup.Volume = settings.SfxVolume
	end
end

function SoundController.Init()
	musicGroup = UILib.soundGroup("Music")
	sfxGroup = UILib.soundGroup("SFX")
end

function SoundController.Start()
	DataController.observe("Settings", applyVolumes)

	player:GetAttributeChangedSignal("Neighborhood"):Connect(onArrive)
	player:GetAttributeChangedSignal("RushHourEnds"):Connect(onRushHourChanged)
	onRushHourChanged()

	local lastScoops = (player:GetAttribute("ConeScoops") :: number?) or 0
	player:GetAttributeChangedSignal("ConeScoops"):Connect(function()
		local scoops = (player:GetAttribute("ConeScoops") :: number?) or 0
		if scoops > lastScoops then
			UILib.playSound(Assets.SFX_SCOOP, 0.95 + scoops * 0.05)
		end
		lastScoops = scoops
	end)
end

return SoundController
