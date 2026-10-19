--!strict
--[[
	Server entry point.
	1. Checks the game data modules for mistakes.
	2. Creates all RemoteEvents / RemoteFunctions.
	3. Calls Init() on every service (set up state, no yielding, no cross-service calls),
	   then Start() on every service (connect events, begin loops).
	Order matters: DataService is first so others can rely on it in Start().
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local GameDataValidation = require(script.Parent.Modules.GameDataValidation)

type Service = { Init: () -> ...any, Start: () -> ...any }

local Services = script.Parent.Services
local SERVICE_ORDER: { ModuleScript } = {
	Services.DataService,
	Services.EconomyService,
	Services.TruckService,
	Services.NeighborhoodService,
	Services.ConeService,
	Services.CustomerService,
	Services.UpgradeService,
	Services.FlavorService,
	Services.PetService,
	Services.QuestService,
	Services.RebirthService,
	Services.EventService,
	Services.LeaderboardService,
	Services.MarketService,
	Services.DevCommandsService,
}

GameDataValidation.run()
Remotes.createAll()

local services: { Service } = {}
for _, module in SERVICE_ORDER do
	table.insert(services, (require :: any)(module))
end

for index, service in services do
	local ok, err = pcall(service.Init)
	if not ok then
		error(`[Main] {SERVICE_ORDER[index].Name}.Init failed: {err}`)
	end
end

for index, service in services do
	-- Each Start runs in its own thread so one slow service can't hold up the rest.
	task.spawn(function()
		local ok, err = pcall(service.Start)
		if not ok then
			warn(`[Main] {SERVICE_ORDER[index].Name}.Start failed: {err}`)
		end
	end)
end

print("[Main] Server started")
