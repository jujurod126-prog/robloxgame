--!strict
--[[
	CustomerService
	Runs each player's customers (server-controlled, one session per player):
	  * keeps up to servingCapacity customers at the truck's counter
	  * gives each one an order and a patience timer
	  * handles the Serve prompt: checks the cone against the order and pays out
	  * customers whose patience runs out leave without paying
	Everything is cleaned up when the player leaves or their truck is rebuilt.

	Stage 2: one customer type (Regular), one neighborhood (Sunny Sidewalk).
	Stage 4 adds flavors/toppings in orders, combo and Reputation.
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

local ServerModules = script.Parent.Parent.Modules
local Customer = require(ServerModules.Customer)
local CustomerRig = require(ServerModules.CustomerRig)
local Notify = require(ServerModules.Notify)
local ConeService = require(script.Parent.ConeService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local TruckService = require(script.Parent.TruckService)

type Customer = Customer.Customer

-- Stage 2 only has the starting area and the Regular customer.
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
	local scoops = ConeService.takeScoops(player)
	local correct = #scoops == order.Scoops
	for _, flavorId in scoops do
		if flavorId ~= order.FlavorId then
			correct = false
		end
	end

	local base, tip = Formulas.orderPayout({
		ScoopValue = Flavors[order.FlavorId].CoinValue * order.Scoops,
		Customer = customer.def,
		Neighborhood = CURRENT_NEIGHBORHOOD,
		Truck = PlayerStats.truck(data),
		TipBonus = PlayerStats.tipBonus(data),
		PatienceFraction = Customer.patienceFraction(customer),
		Correct = correct,
	})
	local coins = EconomyService.awardCoins(player, base + tip)

	DataService.increment(player, { "Stats", "CustomersServed" }, 1)
	if correct then
		DataService.increment(player, { "Stats", "PerfectOrders" }, 1)
	end
	Remotes.event("OrderResult"):FireClient(player, customer.root.Position + Vector3.new(0, 3, 0), coins, correct)

	leave(session, customer, if correct then "Happy" else "Sad")
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

	-- Orders never ask for more scoops than the player's cone can hold.
	local maxScoops = math.min(CUSTOMER_TYPE.MaxScoops, PlayerStats.coneCapacity(data))
	local order = { FlavorId = PlayerStats.activeFlavor(data), Scoops = random:NextInteger(1, maxScoops) }
	local prompt = Customer.showOrder(customer, order, CUSTOMER_TYPE.PatienceSeconds)
	prompt.Triggered:Connect(function(player: Player)
		onServe(session, customer, player)
	end)
	customer.patienceThread = task.delay(CUSTOMER_TYPE.PatienceSeconds, function()
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
	Players.PlayerRemoving:Connect(endSession)

	-- Bigger serving capacity (upgrades, new truck tier) means more customers at once.
	DataService.Changed:Connect(function(player: Player, path: { any })
		local session = sessions[player]
		if session and (#path == 0 or path[1] == "Truck") then
			fill(session)
		end
	end)
end

return CustomerService
