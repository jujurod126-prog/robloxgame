--!strict
--[[
	SettingsService
	Saves player settings and tutorial progress (both client requests, validated):
	  UpdateSettings({ MusicVolume?, SfxVolume?, ShowTips?, ShowPopups? })
	    volumes are clamped to 0..1, toggles must be booleans, unknown keys ignored
	  TutorialProgress(step, completed)
	    step only moves forward; completed = finished or skipped
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Data.GameConfig)
local Remotes = require(Shared.Modules.Remotes)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local DataService = require(script.Parent.DataService)

type PurchaseResult = Remotes.PurchaseResult

local MAX_TUTORIAL_STEP = 20

local VOLUME_KEYS = { MusicVolume = true, SfxVolume = true }
local TOGGLE_KEYS = { ShowTips = true, ShowPopups = true }

local SettingsService = {}

local limiter = RateLimiter.fromConfig(GameConfig.RateLimits.Default)

local function updateSettings(player: Player, changes: unknown): PurchaseResult
	if not limiter:check(player) then
		return { Ok = false, Message = "Slow down a little!" }
	end
	if type(changes) ~= "table" or DataService.getData(player) == nil then
		return { Ok = false, Message = "Invalid settings." }
	end
	for key, value in changes :: { [any]: any } do
		if VOLUME_KEYS[key] and type(value) == "number" and value == value then
			DataService.set(player, { "Settings", key }, math.clamp(value, 0, 1))
		elseif TOGGLE_KEYS[key] and type(value) == "boolean" then
			DataService.set(player, { "Settings", key }, value)
		end
	end
	return { Ok = true, Message = "Settings saved." }
end

local function tutorialProgress(player: Player, step: unknown, completed: unknown): PurchaseResult
	if not limiter:check(player) then
		return { Ok = false, Message = "Slow down a little!" }
	end
	local data = DataService.getData(player)
	if data == nil or type(step) ~= "number" or type(completed) ~= "boolean" then
		return { Ok = false, Message = "Invalid tutorial step." }
	end
	local newStep = math.clamp(math.floor(step :: number), 0, MAX_TUTORIAL_STEP)
	if newStep > data.Tutorial.Step then
		DataService.set(player, { "Tutorial", "Step" }, newStep)
	end
	if completed and not data.Tutorial.Completed then
		DataService.set(player, { "Tutorial", "Completed" }, true)
	end
	return { Ok = true, Message = "" }
end

function SettingsService.Init() end

function SettingsService.Start()
	Remotes.func("UpdateSettings").OnServerInvoke = updateSettings
	Remotes.func("TutorialProgress").OnServerInvoke = tutorialProgress
end

return SettingsService
