--!strict
--[[
	Client entry point.
	Calls Init() on every controller, then Start(). DataController goes first
	so the others can call DataController.waitForData() in Start().
	The client never changes saved data; it only displays it and sends requests.
]]

type Controller = { Init: () -> ...any, Start: () -> ...any }

local Controllers = script.Parent.Controllers
local CONTROLLER_ORDER: { ModuleScript } = {
	Controllers.DataController,
	Controllers.SoundController,
	Controllers.NotificationController,
	Controllers.HudController,
	Controllers.OrderBarController,
	Controllers.TruckController,
	Controllers.WorldController,
	Controllers.ZoneController,
	Controllers.WeatherController,
	Controllers.LeaderboardController,
	Controllers.CustomerController,
	Controllers.ShopController,
	Controllers.FlavorController,
	Controllers.PetController,
	Controllers.PetFollowController,
	Controllers.RebirthController,
	Controllers.QuestController,
	Controllers.DailyRewardController,
	Controllers.SettingsController,
	Controllers.StoreController,
	Controllers.JuiceController,
	Controllers.ChatTagController,
	Controllers.TutorialController,
}

local controllers: { Controller } = {}
for _, module in CONTROLLER_ORDER do
	table.insert(controllers, (require :: any)(module))
end

for index, controller in controllers do
	local ok, err = pcall(controller.Init)
	if not ok then
		error(`[Main] {CONTROLLER_ORDER[index].Name}.Init failed: {err}`)
	end
end

for index, controller in controllers do
	task.spawn(function()
		local ok, err = pcall(controller.Start)
		if not ok then
			warn(`[Main] {CONTROLLER_ORDER[index].Name}.Start failed: {err}`)
		end
	end)
end
