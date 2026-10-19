--!strict
--[[
	DevCommandsService (STUDIO ONLY)
	Chat commands for testing. They do nothing in a live server.

	/data            print your saved data to the Output window
	/coins <amount>  add Coins (negative to remove)
	/gems <amount>   add Gems
	/rep <stars>     set your Reputation (1 - 5), to test special customers
	/skipday         pretend a day passed: daily reward claimable, new quests within a minute
	/wipe            reset your data to a brand-new player
	/pass <PassId>   toggle a game pass on/off (DoubleCoins, AutoServe, ExtraPetSlots, VipTruck)
	/rush            start a Rush Hour now
	/weather <kind>  set the weather: Clear, Rain or Heatwave
	/time <hour>     jump the day/night clock to an hour (0-24)

	Requires the place to use TextChatService (the default for new places).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Data.GameConfig)
local Products = require(game:GetService("ReplicatedStorage").Shared.Data.Products)

local DataService = require(script.Parent.DataService)
local EventService = require(script.Parent.EventService)

local DevCommandsService = {}

local function addCommand(name: string, handler: (player: Player, argument: string?) -> ())
	local command = Instance.new("TextChatCommand")
	command.Name = "Dev_" .. name
	command.PrimaryAlias = "/" .. name
	command.Triggered:Connect(function(textSource: TextSource, text: string)
		local player = Players:GetPlayerByUserId(textSource.UserId)
		if player then
			handler(player, string.match(text, "^%S+%s+(.+)$"))
		end
	end)
	command.Parent = TextChatService
end

local function parseAmount(argument: string?): number?
	local amount = tonumber(argument)
	if amount == nil or amount ~= amount or math.abs(amount) == math.huge then
		return nil
	end
	return math.floor(amount)
end

function DevCommandsService.Init() end

function DevCommandsService.Start()
	if not RunService:IsStudio() then
		return
	end

	addCommand("data", function(player)
		local data = DataService.getData(player)
		print(`[Dev] {player.Name}'s data:\n{HttpService:JSONEncode(data)}`)
	end)

	addCommand("coins", function(player, argument)
		local amount = parseAmount(argument)
		if amount then
			print(`[Dev] {player.Name} Coins -> {DataService.increment(player, { "Coins" }, amount)}`)
		end
	end)

	addCommand("gems", function(player, argument)
		local amount = parseAmount(argument)
		if amount then
			print(`[Dev] {player.Name} Gems -> {DataService.increment(player, { "Gems" }, amount)}`)
		end
	end)

	addCommand("rep", function(player, argument)
		local stars = tonumber(argument)
		if stars and stars == stars then
			local config = GameConfig.Reputation
			print(
				`[Dev] {player.Name} Reputation -> {DataService.set(
					player,
					{ "Reputation" },
					math.clamp(stars, config.Min, config.Max)
				)}`
			)
		end
	end)

	addCommand("skipday", function(player)
		local data = DataService.getData(player)
		if data then
			local claimHours = GameConfig.Daily.ClaimCooldownHours
			if data.Daily.LastClaimTime > 0 then
				DataService.set(player, { "Daily", "LastClaimTime" }, os.time() - claimHours * 3600 - 1)
			end
			DataService.set(player, { "Quests", "DayKey" }, 0) -- re-rolled on the next check
			print(`[Dev] {player.Name}: skipped a day`)
		end
	end)

	addCommand("wipe", function(player)
		DataService.resetData(player)
		print(`[Dev] {player.Name}'s data was reset`)
	end)

	addCommand("pass", function(player, argument)
		local data = DataService.getData(player)
		if data == nil or argument == nil or Products.GamePasses[argument] == nil then
			print("[Dev] Usage: /pass <PassId>. Pass ids are the keys in Shared/Data/Products.GamePasses")
			return
		end
		local owned = not data.OwnedPasses[argument]
		DataService.set(player, { "OwnedPasses", argument }, if owned then true else nil)
		print(`[Dev] {player.Name}: {argument} -> {if owned then "owned" else "not owned"}`)
	end)

	addCommand("rush", function()
		EventService.forceRushHour()
		print("[Dev] Rush Hour started")
	end)

	addCommand("weather", function(_, argument)
		if argument == "Clear" or argument == "Rain" or argument == "Heatwave" then
			EventService.forceWeather(argument)
			print(`[Dev] Weather -> {argument}`)
		else
			print("[Dev] Usage: /weather Clear | Rain | Heatwave")
		end
	end)

	addCommand("time", function(_, argument)
		local hour = tonumber(argument)
		if hour and hour == hour then
			EventService.setClock(hour)
			print(`[Dev] Clock -> {hour}`)
		end
	end)

	print(
		"[Dev] Studio commands ready: /data, /coins <n>, /gems <n>, /rep <stars>, /skipday, /wipe, /pass <id>,"
			.. " /rush, /weather <kind>, /time <hour>"
	)
end

return DevCommandsService
