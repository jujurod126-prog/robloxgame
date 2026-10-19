--!strict
--[[
	EventService
	World-wide events, shared by everyone in the server:
	  * day/night: Workspace attributes ClockTime (0-24) and TimeOfDay ("Day" | "Sunset" | "Night");
	    CustomerPicker uses TimeOfDay (more kids by day, more tourists at sunset)
	  * weather: Workspace attribute Weather ("Clear" | "Rain" | "Heatwave");
	    rain slows customers down, a heatwave doubles how often they come
	  * Rush Hour every 8-10 minutes: customers come twice as often for 60 s
	    (+ the player's Longer Rush Hour skill), everyone gets bonus Gems.
	    Each player's end time is their Player attribute RushHourEnds (server time).
	Banners go to clients through the EventBanner remote.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Data.GameConfig)
local RebirthRules = require(Shared.Modules.RebirthRules)
local Remotes = require(Shared.Modules.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local CLOCK_UPDATE_SECONDS = 2
local START_HOUR = 9 -- the clock when the server starts

local EventService = {}

local random = Random.new()
local rushHourEndsAt = 0 -- server time; 0 = no Rush Hour running

local world = GameConfig.World
local rush = GameConfig.RushHour

local function timeOfDay(hour: number): string
	if hour >= world.DayStartsAt and hour < world.SunsetStartsAt then
		return "Day"
	elseif hour >= world.SunsetStartsAt and hour < world.NightStartsAt then
		return "Sunset"
	end
	return "Night"
end

-- ===== Day / night =====

local clockStarted = os.clock()
local clockStartHour = START_HOUR

local function runClock()
	while true do
		local hour = (clockStartHour + (os.clock() - clockStarted) / world.DayNightCycleSeconds * 24) % 24
		Workspace:SetAttribute("ClockTime", hour)
		Workspace:SetAttribute("TimeOfDay", timeOfDay(hour))
		task.wait(CLOCK_UPDATE_SECONDS)
	end
end

-- ===== Weather =====

local function banner(text: string, seconds: number, kind: string)
	Remotes.event("EventBanner"):FireAllClients(text, seconds, kind)
end

local function runWeather()
	Workspace:SetAttribute("Weather", "Clear")
	while true do
		task.wait(random:NextNumber(world.WeatherCheckMinSeconds, world.WeatherCheckMaxSeconds))
		local roll = random:NextNumber()
		local rain, heat = world.Weather.Rain, world.Weather.Heatwave
		if roll < rain.Chance then
			Workspace:SetAttribute("Weather", "Rain")
			banner("It's raining! Customers walk a little slower.", 4, "Weather")
			task.wait(rain.DurationSeconds)
		elseif roll < rain.Chance + heat.Chance then
			Workspace:SetAttribute("Weather", "Heatwave")
			banner("Heatwave! Everyone wants ice cream!", 4, "Weather")
			task.wait(heat.DurationSeconds)
		end
		Workspace:SetAttribute("Weather", "Clear")
	end
end

-- ===== Rush Hour =====

-- Starts (or joins) the current Rush Hour for one player: their own end time and bonus Gems.
local function joinRushHour(player: Player)
	local data = DataService.getData(player)
	if data == nil or Workspace:GetServerTimeNow() >= rushHourEndsAt then
		return
	end
	local extra = RebirthRules.skillValue(data, "RushHourDuration")
	player:SetAttribute("RushHourEnds", rushHourEndsAt + extra)
	EconomyService.awardGems(player, rush.GemBonus)
end

local function startRushHour()
	rushHourEndsAt = Workspace:GetServerTimeNow() + rush.DurationSeconds
	Workspace:SetAttribute("RushHourEnds", rushHourEndsAt)
	banner(
		`RUSH HOUR! Customers x{rush.SpawnRateMultiplier} and +{rush.GemBonus} Gems!`,
		rush.DurationSeconds,
		"RushHour"
	)
	for _, player in Players:GetPlayers() do
		joinRushHour(player)
	end
end

local function runRushHour()
	while true do
		task.wait(random:NextNumber(rush.IntervalMinSeconds, rush.IntervalMaxSeconds))
		startRushHour()
		task.wait(rush.DurationSeconds)
	end
end

-- ===== Public API =====

-- Starts a Rush Hour right now (Studio test command /rush).
function EventService.forceRushHour()
	if Workspace:GetServerTimeNow() >= rushHourEndsAt then
		startRushHour()
	end
end

-- Sets the weather right now (Studio test command /weather). It clears after its normal duration.
function EventService.forceWeather(weather: "Clear" | "Rain" | "Heatwave")
	Workspace:SetAttribute("Weather", weather)
	if weather ~= "Clear" then
		local config = world.Weather[weather]
		banner(`Weather: {weather}!`, 4, "Weather")
		task.delay(config.DurationSeconds, function()
			if Workspace:GetAttribute("Weather") == weather then
				Workspace:SetAttribute("Weather", "Clear")
			end
		end)
	end
end

-- Jumps the day/night clock to an hour (Studio test command /time).
function EventService.setClock(hour: number)
	clockStartHour = math.clamp(hour, 0, 24) % 24
	clockStarted = os.clock()
	Workspace:SetAttribute("ClockTime", clockStartHour)
	Workspace:SetAttribute("TimeOfDay", timeOfDay(clockStartHour))
end

-- True while Rush Hour is running for this player.
function EventService.isRushHour(player: Player): boolean
	local ends = player:GetAttribute("RushHourEnds") :: number?
	return ends ~= nil and Workspace:GetServerTimeNow() < ends
end

-- ===== Lifecycle =====

function EventService.Init()
	Workspace:SetAttribute("ClockTime", START_HOUR)
	Workspace:SetAttribute("TimeOfDay", timeOfDay(START_HOUR))
	Workspace:SetAttribute("Weather", "Clear")
	Workspace:SetAttribute("RushHourEnds", 0)
end

function EventService.Start()
	DataService.PlayerLoaded:Connect(joinRushHour) -- joined mid Rush Hour: count them in
	task.spawn(runClock)
	task.spawn(runWeather)
	task.spawn(runRushHour)
end

return EventService
