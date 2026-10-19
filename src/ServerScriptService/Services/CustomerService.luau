--!strict
--[[
	CustomerService
	Runs each player's customers (server-controlled, one session per player):
	  * a session runs while the player is in the neighborhood their truck is parked in
	    (none in the Hub); it uses that neighborhood's spots, pay, tastes and rare-customer boost
	  * keeps up to servingCapacity customers at the counter, each a type chosen by
	    CustomerPicker (Regular, Kid, Tourist, Influencer, VIP Critic)
	  * gives each an order and a patience timer; the Serve prompt checks the cone and pays out
	  * combo (Player attribute "Combo") and Reputation change with every result
	  * VIP Critics give a Critic Trophy for each Legendary flavor they're served
	Everything is cleaned up when the player leaves, goes to the Hub, or the truck is rebuilt.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local CustomerNames = require(Shared.Data.CustomerNames)
local Flavors = require(Shared.Data.Flavors)
local Formulas = require(Shared.Modules.Formulas)
local GameConfig = require(Shared.Data.GameConfig)
local GameData = require(Shared.Types.GameData)
local Neighborhoods = require(Shared.Data.Neighborhoods)
local PlayerStats = require(Shared.Modules.PlayerStats)
local RebirthRules = require(Shared.Modules.RebirthRules)
local Remotes = require(Shared.Modules.Remotes)
local Toppings = require(Shared.Data.Toppings)

local ServerModules = script.Parent.Parent.Modules
local Customer = require(ServerModules.Customer)
local CustomerPicker = require(ServerModules.CustomerPicker)
local CustomerRig = require(ServerModules.CustomerRig)
local Notify = require(ServerModules.Notify)
local Orders = require(ServerModules.Orders)
local ConeService = require(script.Parent.ConeService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local NeighborhoodService = require(script.Parent.NeighborhoodService)
local TruckService = require(script.Parent.TruckService)

type Customer = Customer.Customer

local EXIT_SIDE_GAP = 10 -- leaving customers walk this far past the truck's side

type Session = {
	player: Player,
	truck: Model,
	area: GameData.NeighborhoodDef,
	spots: { [number]: Customer | boolean }, -- true = reserved, a customer is on the way
	alive: boolean,
}

local CustomerService = {}

local customersFolder: Folder
local sessions: { [Player]: Session } = {}
local combos: { [Player]: number } = {} -- correct orders in a row (not saved)
local random = Random.new()

local flow = GameConfig.CustomerFlow

-- ===== Positions (relative to the truck: it faces -Z, customers stand at CounterZ) =====

local function truckPivot(session: Session): CFrame
	return (session.truck.PrimaryPart :: BasePart).CFrame
end

local function spotPosition(session: Session, spotIndex: number, capacity: number, height: number): Vector3
	local x = (spotIndex - (capacity + 1) / 2) * flow.SpotSpacing
	local z = session.truck:GetAttribute("CounterZ") :: number
	return (truckPivot(session) * CFrame.new(x, height, z)).Position
end

local function entryCFrame(session: Session, height: number): CFrame
	local z = (session.truck:GetAttribute("CounterZ") :: number) - flow.SpawnDistance
	local position = (truckPivot(session) * CFrame.new(random:NextNumber(-8, 8), height, z)).Position
	return CFrame.lookAt(position, position - truckPivot(session).LookVector)
end

local function exitPosition(session: Session, height: number): Vector3
	local side = if random:NextNumber() < 0.5 then -1 else 1
	local x = side * ((session.truck:GetAttribute("Width") :: number) / 2 + EXIT_SIDE_GAP)
	local z = (session.truck:GetAttribute("CounterZ") :: number) - flow.SpawnDistance
	return (truckPivot(session) * CFrame.new(x, height, z)).Position
end

local function capacityFor(session: Session): number
	local data = DataService.getData(session.player)
	return if data then PlayerStats.servingCapacity(data, session.area) else 0
end

-- ===== Combo and Reputation =====

local function setCombo(player: Player, combo: number)
	combos[player] = combo
	player:SetAttribute("Combo", combo)
	if combo > 0 then
		DataService.update(player, { "Stats", "HighestCombo" }, function(best)
			return math.max(best, combo)
		end)
	end
end

local function changeReputation(player: Player, delta: number)
	local config = GameConfig.Reputation
	DataService.update(player, { "Reputation" }, function(rating)
		return math.clamp(rating + delta, config.Min, config.Max)
	end)
end

-- ===== Customer lifecycle =====

local fill: (session: Session) -> ()

-- Ends a customer's visit: frees its spot right away (so the next can come), then walks off.
local function leave(session: Session, customer: Customer, mood: Customer.Mood)
	if customer.state == "Leaving" or customer.released then
		return
	end
	Customer.startLeaving(customer, mood)
	if session.spots[customer.spotIndex] == customer then
		session.spots[customer.spotIndex] = nil
	end
	fill(session)
	if Customer.walkTo(customer, exitPosition(session, CustomerRig.rootHeight(customer.def.Id))) then
		Customer.release(customer)
	end
end

local function awardCriticTrophy(player: Player, flavorId: string)
	local data = DataService.getData(player)
	if data and not data.Collectibles.CriticTrophies[flavorId] then
		DataService.set(player, { "Collectibles", "CriticTrophies", flavorId }, true)
		Notify.send(player, `The critic loved it! New Critic Trophy: {Flavors[flavorId].DisplayName}`, "Info")
	end
end

local settle: (session: Session, customer: Customer, correct: boolean) -> ()

local function onServe(session: Session, customer: Customer, player: Player)
	if player ~= session.player or customer.state ~= "Waiting" or customer.order == nil then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local data = DataService.getData(player)
	if root == nil or data == nil then
		return
	end
	if (root.Position - customer.root.Position).Magnitude > flow.ServeDistance then
		return
	end
	if ConeService.getScoopCount(player) == 0 then
		Notify.send(player, "Scoop some ice cream at your truck first!", "Error")
		return
	end

	local correct = Orders.isCorrect(customer.order :: Customer.Order, ConeService.takeCone(player))
	settle(session, customer, correct)
end

--[[
	Pays for an order and sends the customer off: combo, payout, stats, Reputation,
	critic trophy, coin popup, mood. Used by manual serving and by auto-serve.
]]
function settle(session: Session, customer: Customer, correct: boolean)
	local player = session.player
	local data = DataService.getData(player)
	if data == nil or customer.order == nil then
		return
	end
	local order = customer.order :: Customer.Order
	local patience = Customer.patienceFraction(customer)

	-- Combo counts this order before paying, so the 5th correct order in a row already gets x1.1.
	local combo = if correct then (combos[player] or 0) + 1 else 0
	setCombo(player, combo)
	local comboMultiplier = Formulas.comboMultiplier(combo)

	local base, tip = Formulas.orderPayout({
		ScoopValue = Flavors[order.FlavorId].CoinValue * order.Scoops,
		ToppingMultiplier = if order.ToppingId then Toppings[order.ToppingId].ValueMultiplier else 1,
		HasTopping = order.ToppingId ~= nil,
		MatchesPreference = Orders.matchesPreference(order, session.area),
		Customer = customer.def,
		Neighborhood = session.area,
		Truck = PlayerStats.truck(data),
		TipBonus = PlayerStats.tipBonus(data),
		PatienceFraction = patience,
		ComboMultiplier = comboMultiplier,
		Correct = correct,
	})
	local coins = EconomyService.awardCoins(player, base + tip)

	DataService.increment(player, { "Stats", "CustomersServed" }, 1)
	if correct then
		DataService.increment(player, { "Stats", "PerfectOrders" }, 1)
		changeReputation(player, GameConfig.Reputation.CorrectOrder + customer.def.ReputationBonus)
		-- Only for the rarity they asked for (the loadout may have changed while they walked in).
		local demanded = customer.def.DemandsRarity
		if customer.def.GivesCollectible and (demanded == nil or Flavors[order.FlavorId].Rarity == demanded) then
			awardCriticTrophy(player, order.FlavorId)
		end
	else
		changeReputation(player, GameConfig.Reputation.WrongOrder)
	end
	Remotes.event("OrderResult")
		:FireClient(player, customer.root.Position + Vector3.new(0, 3, 0), coins, correct, comboMultiplier)

	local mood: Customer.Mood = if not correct
		then "Sad"
		elseif patience >= GameConfig.Orders.DelightedPatience then "Love"
		else "Happy"
	leave(session, customer, mood)
end

local function announce(player: Player, customerDef: GameData.CustomerDef)
	if customerDef.Id == "VIP" then
		Notify.send(player, "A VIP Critic is here! They want a Legendary flavor.", "Info")
	elseif customerDef.Id == "Influencer" then
		Notify.send(player, "An Influencer stopped by! Serve them well for bonus Reputation.", "Info")
	end
end

local function spawnCustomer(session: Session, spotIndex: number)
	if not session.alive then
		return
	end
	local data = DataService.getData(session.player)
	if data == nil then
		session.spots[spotIndex] = nil
		return
	end

	local def = CustomerPicker.pick(data, session.area)
	local height = CustomerRig.rootHeight(def.Id)
	local baseName = CustomerNames[random:NextInteger(1, #CustomerNames)]
	local name = if def.Id == "Regular" then baseName else `{def.DisplayName} {baseName}`
	local customer = Customer.new(session.player, def, name, spotIndex, entryCFrame(session, height), customersFolder)
	session.spots[spotIndex] = customer

	local target = spotPosition(session, spotIndex, capacityFor(session), height)
	if not Customer.walkTo(customer, target, -truckPivot(session).LookVector) or not session.alive then
		return
	end

	-- Re-read data: it may have changed while the customer was walking.
	local current = DataService.getData(session.player)
	if current == nil then
		return
	end
	local order = Orders.create(current, def, session.area)
	local prompt = Customer.showOrder(customer, order, def.PatienceSeconds)
	prompt.Triggered:Connect(function(player: Player)
		onServe(session, customer, player)
	end)
	customer.patienceThread = task.delay(def.PatienceSeconds, function()
		-- Ran out of patience: no pay, combo broken, small Reputation hit.
		setCombo(session.player, 0)
		changeReputation(session.player, GameConfig.Reputation.CustomerLeft)
		leave(session, customer, "Angry")
	end)
	announce(session.player, def)
end

-- Reserves free spots up to the serving capacity and sends a customer to each after a short delay.
function fill(session: Session)
	if not session.alive then
		return
	end
	local capacity = capacityFor(session)
	-- Faster Customers skill, Rush Hour and heatwaves all shorten the wait before the next customer.
	local data = DataService.getData(session.player)
	local speedUp = 1 + (if data then RebirthRules.skillValue(data, "FasterCustomers") else 0)
	if EventService.isRushHour(session.player) then
		speedUp *= GameConfig.RushHour.SpawnRateMultiplier
	end
	if Workspace:GetAttribute("Weather") == "Heatwave" then
		speedUp *= GameConfig.World.Weather.Heatwave.DemandMultiplier
	end
	local occupied = 0
	for _ in session.spots do
		occupied += 1
	end
	for spotIndex = 1, session.area.CustomerSpots do
		if occupied >= capacity then
			break
		end
		if session.spots[spotIndex] == nil then
			session.spots[spotIndex] = true
			occupied += 1
			local delay = random:NextNumber(flow.ArriveDelayMin, flow.ArriveDelayMax) / speedUp
			task.delay(delay, spawnCustomer, session, spotIndex)
		end
	end
end

-- ===== Auto-serve (game pass, and the truck's auto-serve burst) =====

local lastAutoServe: { [Player]: number } = {}

-- True if this player's truck should auto-serve right now, and how often.
local function autoServeInterval(player: Player): number?
	local data = DataService.getData(player)
	if data == nil then
		return nil
	end
	local burst = PlayerStats.truck(data).AutoServeBurst
	if burst and (os.clock() % burst.Interval) < burst.Duration then
		return GameConfig.AutoServe.BurstIntervalSeconds
	end
	if data.OwnedPasses.AutoServe then
		return GameConfig.AutoServe.PassIntervalSeconds
	end
	return nil
end

local function autoServeTick()
	local now = os.clock()
	for player, session in sessions do
		local interval = autoServeInterval(player)
		if interval and now - (lastAutoServe[player] or 0) >= interval then
			for _, entry in session.spots do
				if type(entry) == "table" and entry.state == "Waiting" then
					lastAutoServe[player] = now
					-- Own thread: settling waits while the customer walks away.
					task.spawn(settle, session, entry, true) -- auto-serve always gets the order right
					break
				end
			end
		end
	end
end

-- ===== Sessions =====

local function endSession(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	session.alive = false
	sessions[player] = nil
	for _, entry in session.spots do
		if type(entry) == "table" then
			Customer.release(entry)
		end
	end
	-- Customers already walking away aren't in spots; they finish and release themselves.
end

local function startSession(player: Player, truck: Model)
	endSession(player)
	local area = Neighborhoods[truck:GetAttribute("Neighborhood") :: string]
	if area == nil or area.IsHub then
		return
	end
	local session: Session = { player = player, truck = truck, area = area, spots = {}, alive = true }
	sessions[player] = session
	fill(session)
end

-- Customers only come while the player is in the same area as their truck.
local function refreshSession(player: Player)
	local truck = TruckService.getTruck(player)
	local area = NeighborhoodService.getArea(player)
	if truck == nil or area == nil or truck:GetAttribute("Neighborhood") ~= area then
		endSession(player)
		return
	end
	local session = sessions[player]
	if session == nil or session.truck ~= truck then
		startSession(player, truck)
	end
end

-- ===== Lifecycle =====

function CustomerService.Init()
	customersFolder = Instance.new("Folder")
	customersFolder.Name = "Customers"
	customersFolder.Parent = Workspace
end

function CustomerService.Start()
	TruckService.TruckSpawned:Connect(refreshSession)
	TruckService.TruckRemoved:Connect(endSession)
	NeighborhoodService.AreaChanged:Connect(refreshSession)
	Players.PlayerRemoving:Connect(function(player)
		endSession(player)
		combos[player] = nil
		lastAutoServe[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			autoServeTick()
		end
	end)

	-- Bigger serving capacity (upgrades, new truck tier) means more customers at once.
	DataService.Changed:Connect(function(player: Player, path: { any })
		if #path == 0 and combos[player] then
			setCombo(player, 0) -- data was wiped
		end
		local session = sessions[player]
		if session and (#path == 0 or path[1] == "Truck") then
			fill(session)
		end
	end)
end

return CustomerService
