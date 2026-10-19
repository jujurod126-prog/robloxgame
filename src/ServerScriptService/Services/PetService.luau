--!strict
--[[
	PetService
	Eggs and pets. Every request is rate limited and validated on the server:
	  HatchEgg(eggId, count)   pay (Coins or Gems), roll the egg's odds HERE, add the pets
	  EquipPet / UnequipPet    up to PetRules.equipSlots(data)
	  DeletePet                not if locked
	  SetPetLocked             protects a pet from delete / merge
	  MergePets(petId)         5 unlocked normal copies -> 1 golden (stronger boost)

	Equipped pets are shown to every player through the Player attribute
	"EquippedPets" ("Penguin:Normal,Cow:Golden"), which PetFollowController renders.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Eggs = require(Shared.Data.Eggs)
local GameConfig = require(Shared.Data.GameConfig)
local PetRules = require(Shared.Modules.PetRules)
local Pets = require(Shared.Data.Pets)
local PlayerDataTypes = require(Shared.Types.PlayerData)
local Remotes = require(Shared.Modules.Remotes)

local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

type PurchaseResult = Remotes.PurchaseResult
type HatchResult = Remotes.HatchResult
type PetVariant = PlayerDataTypes.PetVariant

local HATCH_COUNTS = { [1] = true, [3] = true }

local PetService = {}

local limiter = RateLimiter.fromConfig(GameConfig.RateLimits.Purchase)
local random = Random.new()

local function fail(message: string): PurchaseResult
	return { Ok = false, Message = message }
end

-- Rolls one pet from an egg's weighted odds (server-side only).
local function rollPet(eggId: string): string
	local egg = Eggs[eggId]
	local total = 0
	for _, entry in egg.Odds do
		total += entry.Weight
	end
	local roll = random:NextNumber() * total
	for _, entry in egg.Odds do
		roll -= entry.Weight
		if roll <= 0 then
			return entry.PetId
		end
	end
	return egg.Odds[#egg.Odds].PetId
end

local function addPet(player: Player, petId: string, variant: PetVariant): string
	local petGuid = HttpService:GenerateGUID(false)
	DataService.set(player, { "Pets", "Inventory", petGuid }, { PetId = petId, Variant = variant, Locked = false })
	return petGuid
end

local function setEquipped(player: Player, list: { string })
	DataService.set(player, { "Pets", "Equipped" }, list)
end

-- Shows the player's equipped pets to everyone (followers are drawn by each client).
local function publishEquipped(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	local parts = {}
	for _, petGuid in PetRules.equipped(data) do
		local pet = data.Pets.Inventory[petGuid]
		table.insert(parts, `{pet.PetId}:{pet.Variant}`)
	end
	player:SetAttribute("EquippedPets", table.concat(parts, ","))
end

-- Validates a pet id argument and returns the player's pet, or an error result.
local function ownedPet(player: Player, petGuid: unknown): (PlayerDataTypes.PetInstance?, PurchaseResult?)
	if not limiter:check(player) then
		return nil, fail("Slow down a little!")
	end
	local data = DataService.getData(player)
	if data == nil then
		return nil, fail("Your data is still loading.")
	end
	if type(petGuid) ~= "string" or data.Pets.Inventory[petGuid] == nil then
		return nil, fail("You don't have that pet.")
	end
	return data.Pets.Inventory[petGuid :: string], nil
end

-- ===== Remote handlers =====

local function hatchEgg(player: Player, eggId: unknown, count: unknown): HatchResult
	if not limiter:check(player) then
		return { Ok = false, Message = "Slow down a little!" }
	end
	if type(eggId) ~= "string" or Eggs[eggId] == nil then
		return { Ok = false, Message = "That egg doesn't exist." }
	end
	if type(count) ~= "number" or not HATCH_COUNTS[count] then
		return { Ok = false, Message = "You can hatch 1 or 3 at a time." }
	end
	local data = DataService.getData(player)
	if data == nil then
		return { Ok = false, Message = "Your data is still loading." }
	end
	local id = eggId :: string
	local amount = count :: number
	local status = PetRules.eggStatus(data, id, amount)
	if not status.CanBuy then
		return { Ok = false, Message = status.Reason or "You can't hatch that right now." }
	end
	if not EconomyService.trySpend(player, status.Currency, status.Cost) then
		return { Ok = false, Message = `Not enough {status.Currency}.` }
	end

	local hatched = {}
	for _ = 1, amount do
		local petId = rollPet(id)
		local petGuid = addPet(player, petId, "Normal")
		table.insert(hatched, { Guid = petGuid, PetId = petId, Variant = "Normal" })
	end
	DataService.increment(player, { "Stats", "EggsHatched" }, amount)

	-- Fill empty pet slots with the new arrivals.
	local current = DataService.getData(player)
	if current then
		local equipped = PetRules.equipped(current)
		for _, pet in hatched do
			if #equipped < PetRules.equipSlots(current) then
				table.insert(equipped, pet.Guid)
			end
		end
		setEquipped(player, equipped)
	end
	return { Ok = true, Message = `You hatched {amount} pet{if amount == 1 then "" else "s"}!`, Pets = hatched }
end

local function equipPet(player: Player, petGuid: unknown): PurchaseResult
	local pet, err = ownedPet(player, petGuid)
	local data = DataService.getData(player)
	if pet == nil or data == nil then
		return err or fail("You don't have that pet.")
	end
	local equipped = PetRules.equipped(data)
	if table.find(equipped, petGuid :: string) then
		return { Ok = true, Message = "Already equipped." }
	end
	if #equipped >= PetRules.equipSlots(data) then
		return fail(`All {PetRules.equipSlots(data)} pet slots are full. Unequip one first.`)
	end
	table.insert(equipped, petGuid :: string)
	setEquipped(player, equipped)
	return { Ok = true, Message = `{Pets[pet.PetId].DisplayName} is following you!` }
end

local function unequipPet(player: Player, petGuid: unknown): PurchaseResult
	local pet, err = ownedPet(player, petGuid)
	local data = DataService.getData(player)
	if pet == nil or data == nil then
		return err or fail("You don't have that pet.")
	end
	local equipped = PetRules.equipped(data)
	local index = table.find(equipped, petGuid :: string)
	if index then
		table.remove(equipped, index)
		setEquipped(player, equipped)
	end
	return { Ok = true, Message = `{Pets[pet.PetId].DisplayName} unequipped.` }
end

local function deletePet(player: Player, petGuid: unknown): PurchaseResult
	local pet, err = ownedPet(player, petGuid)
	local data = DataService.getData(player)
	if pet == nil or data == nil then
		return err or fail("You don't have that pet.")
	end
	if pet.Locked then
		return fail("That pet is locked. Unlock it first.")
	end
	local equipped = PetRules.equipped(data)
	local index = table.find(equipped, petGuid :: string)
	if index then
		table.remove(equipped, index)
		setEquipped(player, equipped)
	end
	DataService.set(player, { "Pets", "Inventory", petGuid :: string }, nil)
	return { Ok = true, Message = `Said goodbye to {Pets[pet.PetId].DisplayName}.` }
end

local function setPetLocked(player: Player, petGuid: unknown, locked: unknown): PurchaseResult
	local pet, err = ownedPet(player, petGuid)
	if pet == nil then
		return err or fail("You don't have that pet.")
	end
	if type(locked) ~= "boolean" then
		return fail("Invalid lock request.")
	end
	DataService.set(player, { "Pets", "Inventory", petGuid :: string, "Locked" }, locked)
	return { Ok = true, Message = if locked then "Pet locked." else "Pet unlocked." }
end

local function mergePets(player: Player, petId: unknown): PurchaseResult
	if not limiter:check(player) then
		return fail("Slow down a little!")
	end
	if type(petId) ~= "string" or Pets[petId] == nil then
		return fail("That pet doesn't exist.")
	end
	local data = DataService.getData(player)
	if data == nil then
		return fail("Your data is still loading.")
	end
	local id = petId :: string
	local candidates = PetRules.mergeCandidates(data, id)
	local needed = GameConfig.Pets.MergeCount
	if #candidates < needed then
		return fail(`You need {needed} unlocked {Pets[id].DisplayName}s to merge.`)
	end

	-- Use unequipped copies first.
	local equipped = PetRules.equipped(data)
	table.sort(candidates, function(a, b)
		local aEquipped = table.find(equipped, a) ~= nil
		local bEquipped = table.find(equipped, b) ~= nil
		if aEquipped ~= bEquipped then
			return not aEquipped
		end
		return a < b
	end)
	local wasEquipped = false
	for index = 1, needed do
		local petGuid = candidates[index]
		local slot = table.find(equipped, petGuid)
		if slot then
			table.remove(equipped, slot)
			wasEquipped = true
		end
		DataService.set(player, { "Pets", "Inventory", petGuid }, nil)
	end
	local golden = addPet(player, id, "Golden")
	if wasEquipped then
		table.insert(equipped, golden)
	end
	setEquipped(player, equipped)
	return { Ok = true, Message = `Golden {Pets[id].DisplayName} created!` }
end

-- ===== Lifecycle =====

function PetService.Init() end

function PetService.Start()
	Remotes.func("HatchEgg").OnServerInvoke = hatchEgg
	Remotes.func("EquipPet").OnServerInvoke = equipPet
	Remotes.func("UnequipPet").OnServerInvoke = unequipPet
	Remotes.func("DeletePet").OnServerInvoke = deletePet
	Remotes.func("SetPetLocked").OnServerInvoke = setPetLocked
	Remotes.func("MergePets").OnServerInvoke = mergePets

	DataService.PlayerLoaded:Connect(publishEquipped)
	DataService.Changed:Connect(function(player: Player, path: { any })
		if #path == 0 or path[1] == "Pets" or path[1] == "Skills" then
			publishEquipped(player)
		end
	end)
end

return PetService
