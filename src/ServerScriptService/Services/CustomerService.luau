--!strict
--[[
	CustomerService
	Runs each player's customers (server-controlled, one session per player):
	  * keeps up to servingCapacity customers at the truck's counter
	  * gives each one an order and a patience timer
	  * handles the Serve prompt: checks the cone against the order and pays out
	  * customers whose patience runs out leave without paying
	Everything is cleaned up when the player leaves or their truck is rebuilt.

	Stage 4: orders use the truck's loaded flavors and unlocked toppings; serving
	tracks a combo (Player attribute "Combo") and changes Reputation.
	Stage 5 adds more customer types and neighborhoods.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local CustomerNames = require(Shared.Data.CustomerNames)
local Customers = require(Shared.Data.Customers)
local Flavors = require(Shared.Data.Flavors)
local Formulas = require(Shared.Modules.Formulas)
local GameConfig = require(Shared.Data.GameConfig)
local Neighborhoods = require(Shared.Data.Neighborhoods)
local PlayerStats = require(Shared.Modules.PlayerStats)
local Remotes = require(Shared.Modules.Remotes)
local Toppings = require(Shared.Data.Toppings)

local ServerModules = script.Parent.Parent.Modules
local Customer = require(ServerModules.Customer)
local CustomerRig = require(ServerModules.CustomerRig)
local Notify = require(ServerModules.Notify)
local Orders = require(ServerModules.Orders)
local ConeService = require(script.Parent.ConeService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local TruckService = require(script.Parent.TruckService)

type Customer = Customer.Customer

-- Until Stage 5: only the starting area and the Regular customer.
local CURRENT_NEIGHBORHOOD = Neighborhoods[GameConfig.Starting.Neighborhood]
local CUSTOMER_TYPE = Customers.Regular
local EXIT_SIDE_GAP = 10 -- leaving customers walk this far past the truck's side

type Session = {
	player: Player,
	truck: Model,
	spots: { [number]: Customer | boolean }, -- true = reserved, a customer is on the way
	alive: boolean,
}

local CustomerService = {}

local customersFolder: Folder
local sessions: { [Player]: Session } = {}
local combos: { [Player]: number } = {} -- correct orders in a row (not saved)
local random = Random.new()

local flow = GameConfig.CustomerFlow

-- World positions are all relative to the truck: it faces -Z, customers stand at CounterZ.
local function truckPivot(session: Session): CFrame
	return (session.truck.PrimaryPart :: BasePart).CFrame
end

local function spotPosition(session: Session, spotIndex: number, capacity: number): Vector3
	local x = (spotIndex - (capacity + 1) / 2) * flow.SpotSpacing
	local z = session.truck:GetAttribute("CounterZ") :: number
	return (truckPivot(session) * CFrame.new(x, CustomerRig.ROOT_HEIGHT, z)).Position
end

local function entryCFrame(session: Session): CFrame
	local z = (session.truck:GetAttribute("CounterZ") :: number) - flow.SpawnDistance
	local position = (truckPivot(session) * CFrame.new(random:NextNumber(-8, 8), CustomerRig.ROOT_HEIGHT, z)).Position
	return CFrame.lookAt(position, position + truckPivot(session).LookVector * -1)
end

local function exitPosition(session: Session): Vector3
	local side = if random:NextNumber() < 0.5 then -1 else 1
	local x = side * ((session.truck:GetAttribute("Width") :: number) / 2 + EXIT_SIDE_GAP)
	local z = (session.truck:GetAttribute("CounterZ") :: number) - flow.SpawnDistance
	return (truckPivot(session) * CFrame.new(x, CustomerRig.ROOT_HEIGHT, z)).Position
end

local function capacityFor(player: Player): number
	local data = DataService.getData(player)
	return if data then PlayerStats.servingCapacity(data, CURRENT_NEIGHBORHOOD) else 0
end

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
	if Customer.walkTo(customer, exitPosition(session)) then
		Customer.release(customer)
	end
end

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

	local order = customer.order :: Customer.Order
	local patience = Customer.patienceFraction(customer)
	local correct = Orders.isCorrect(order, ConeService.takeCone(player))

	-- Combo counts this order before paying, so the 5th correct order in a row already gets x1.1.
	local combo = if correct then (combos[player] or 0) + 1 else 0
	setCombo(player, combo)
	local comboMultiplier = Formulas.comboMultiplier(combo)

	local base, tip = Formulas.orderPayout({
		ScoopValue = Flavors[order.FlavorId].CoinValue * order.Scoops,
		ToppingMultiplier = if order.ToppingId then Toppings[order.ToppingId].ValueMultiplier else 1,
		HasTopping = order.ToppingId ~= nil,
		MatchesPreference = Orders.matchesPreference(order, CURRENT_NEIGHBORHOOD),
		Customer = customer.def,
		Neighborhood = CURRENT_NEIGHBORHOOD,
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

local function spawnCustomer(session: Session, spotIndex: number)
	if not session.alive then
		return
	end
	local data = DataService.getData(session.player)
	if data == nil then
		session.spots[spotIndex] = nil
		return
	end

	local name = CustomerNames[random:NextInteger(1, #CustomerNames)]
	local customer = Customer.new(session.player, CUSTOMER_TYPE, name, spotIndex, entryCFrame(session), customersFolder)
	session.spots[spotIndex] = customer

	local target = spotPosition(session, spotIndex, capacityFor(session.player))
	if not Customer.walkTo(customer, target, truckPivot(session).LookVector * -1) or not session.alive then
		return
	end

	-- Re-read data: it may have changed while the customer was walking.
	local current = DataService.getData(session.player)
	if current == nil then
		return
	end
	local order = Orders.create(current, CUSTOMER_TYPE, CURRENT_NEIGHBORHOOD)
	local prompt = Customer.showOrder(customer, order, CUSTOMER_TYPE.PatienceSeconds)
	prompt.Triggered:Connect(function(player: Player)
		onServe(session, customer, player)
	end)
	customer.patienceThread = task.delay(CUSTOMER_TYPE.PatienceSeconds, function()
		-- Ran out of patience: no pay, combo broken, small Reputation hit.
		setCombo(session.player, 0)
		changeReputation(session.player, GameConfig.Reputation.CustomerLeft)
		leave(session, customer, "Angry")
	end)
end

-- Reserves free spots up to the serving capacity and sends a customer to each after a short delay.
function fill(session: Session)
	if not session.alive then
		return
	end
	local capacity = capacityFor(session.player)
	local occupied = 0
	for _ in session.spots do
		occupied += 1
	end
	for spotIndex = 1, CURRENT_NEIGHBORHOOD.CustomerSpots do
		if occupied >= capacity then
			break
		end
		if session.spots[spotIndex] == nil then
			session.spots[spotIndex] = true
			occupied += 1
			task.delay(random:NextNumber(flow.ArriveDelayMin, flow.ArriveDelayMax), spawnCustomer, session, spotIndex)
		end
	end
end

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
	endSession(player) -- a rebuilt truck starts a fresh line of customers
	local session: Session = { player = player, truck = truck, spots = {}, alive = true }
	sessions[player] = session
	fill(session)
end

-- ===== Lifecycle =====

function CustomerService.Init()
	customersFolder = Instance.new("Folder")
	customersFolder.Name = "Customers"
	customersFolder.Parent = Workspace
end

function CustomerService.Start()
	TruckService.TruckSpawned:Connect(startSession)
	TruckService.TruckRemoved:Connect(endSession)
	Players.PlayerRemoving:Connect(function(player)
		endSession(player)
		combos[player] = nil
	end)

	-- Bigger serving capacity (upgrades, new truck tier) means more customers at once.
	DataService.Changed:Connect(function(player: Player, path: { any })
		local session = sessions[player]
		if session and (#path == 0 or path[1] == "Truck") then
			fill(session)
		end
	end)
end

return CustomerService
