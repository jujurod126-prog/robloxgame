--!strict
--[[
	Customer
	One NPC customer: its rig, where it walks, its order and its Serve prompt.
	CustomerService decides WHEN things happen; this module does the doing.

	Replicated to clients as attributes on the model (see docs/UI_CONTRACT.md):
	  OwnerUserId, CustomerName, CustomerType, State ("Arriving" | "Waiting" | "Leaving"),
	  OrderFlavor, OrderScoops, PatienceTotal, PatienceEnd (Workspace:GetServerTimeNow() time),
	  Mood ("Happy" | "Sad" | "Angry", set when leaving)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Flavors = require(Shared.Data.Flavors)
local GameConfig = require(Shared.Data.GameConfig)
local GameData = require(Shared.Types.GameData)

local CustomerRig = require(script.Parent.CustomerRig)

export type State = "Arriving" | "Waiting" | "Leaving"
export type Mood = "Happy" | "Sad" | "Angry"
export type Order = { FlavorId: string, Scoops: number }

export type Customer = {
	owner: Player,
	def: GameData.CustomerDef,
	model: Model,
	root: BasePart,
	spotIndex: number,
	state: State,
	order: Order?,
	patienceTotal: number,
	patienceEnd: number, -- Workspace:GetServerTimeNow() when patience runs out
	patienceThread: thread?,
	tween: Tween?,
	released: boolean,
}

local Customer = {}

function Customer.new(
	owner: Player,
	def: GameData.CustomerDef,
	name: string,
	spotIndex: number,
	start: CFrame,
	parent: Instance
): Customer
	local model = CustomerRig.acquire()
	local root = model.PrimaryPart :: BasePart
	root.CFrame = start
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("CustomerName", name)
	model:SetAttribute("CustomerType", def.Id)
	model:SetAttribute("State", "Arriving")
	model.Parent = parent

	return {
		owner = owner,
		def = def,
		model = model,
		root = root,
		spotIndex = spotIndex,
		state = "Arriving",
		order = nil,
		patienceTotal = 0,
		patienceEnd = 0,
		patienceThread = nil,
		tween = nil,
		released = false,
	}
end

function Customer.setState(customer: Customer, state: State)
	customer.state = state
	customer.model:SetAttribute("State", state)
end

--[[
	Walks (slides) to `target` at CustomerFlow.WalkSpeed, then turns to face `faceDirection`.
	Yields until arrived. Returns false if the customer was released on the way.
]]
function Customer.walkTo(customer: Customer, target: Vector3, faceDirection: Vector3?): boolean
	if customer.released then
		return false
	end
	local root = customer.root
	local from = root.Position
	local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	if flat.Magnitude > 0.05 then
		root.CFrame = CFrame.lookAt(from, from + flat)
		local tween = TweenService:Create(
			root,
			TweenInfo.new(flat.Magnitude / GameConfig.CustomerFlow.WalkSpeed, Enum.EasingStyle.Linear),
			{ CFrame = CFrame.lookAt(target, target + flat) }
		)
		customer.tween = tween
		tween:Play()
		tween.Completed:Wait()
		customer.tween = nil
	end
	if customer.released then
		return false
	end
	if faceDirection then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + faceDirection)
	end
	return true
end

-- Shows the order (attributes for the client bubble) and adds the Serve prompt.
function Customer.showOrder(customer: Customer, order: Order, patienceSeconds: number): ProximityPrompt
	customer.order = order
	customer.patienceTotal = patienceSeconds
	customer.patienceEnd = Workspace:GetServerTimeNow() + patienceSeconds

	local model = customer.model
	model:SetAttribute("OrderFlavor", order.FlavorId)
	model:SetAttribute("OrderScoops", order.Scoops)
	model:SetAttribute("PatienceTotal", patienceSeconds)
	model:SetAttribute("PatienceEnd", customer.patienceEnd)
	Customer.setState(customer, "Waiting")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ServePrompt"
	prompt.ActionText = "Serve"
	prompt.ObjectText = `{order.Scoops}x {Flavors[order.FlavorId].DisplayName}`
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = GameConfig.CustomerFlow.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = customer.root
	return prompt
end

-- 1 when the customer just started waiting, 0 when patience has run out.
function Customer.patienceFraction(customer: Customer): number
	if customer.patienceTotal <= 0 then
		return 0
	end
	return math.clamp((customer.patienceEnd - Workspace:GetServerTimeNow()) / customer.patienceTotal, 0, 1)
end

-- Removes the prompt, records the mood and stops the patience timer.
function Customer.startLeaving(customer: Customer, mood: Mood)
	if customer.patienceThread and coroutine.running() ~= customer.patienceThread then
		task.cancel(customer.patienceThread)
	end
	customer.patienceThread = nil
	local prompt = customer.root:FindFirstChild("ServePrompt")
	if prompt then
		prompt:Destroy()
	end
	customer.model:SetAttribute("Mood", mood)
	Customer.setState(customer, "Leaving")
end

-- Stops everything and returns the rig to the pool. Safe to call more than once.
function Customer.release(customer: Customer)
	if customer.released then
		return
	end
	customer.released = true
	if customer.patienceThread and coroutine.running() ~= customer.patienceThread then
		task.cancel(customer.patienceThread)
	end
	customer.patienceThread = nil
	if customer.tween then
		customer.tween:Cancel() -- resumes any walkTo waiting on it, which then returns false
	end
	CustomerRig.release(customer.model)
end

return Customer
