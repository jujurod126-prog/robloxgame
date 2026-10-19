--!strict
--[[
	PetRules
	Pet slots, boosts, egg prices and merging. The server validates with these
	and the UI displays with the same functions, so they always agree.
]]

local Shared = script.Parent.Parent
local Eggs = require(Shared.Data.Eggs)
local GameConfig = require(Shared.Data.GameConfig)
local GameData = require(Shared.Types.GameData)
local PlayerDataTypes = require(Shared.Types.PlayerData)
local Pets = require(Shared.Data.Pets)
local RebirthSkills = require(Shared.Data.RebirthSkills)

type PlayerData = PlayerDataTypes.PlayerData
type PetInstance = PlayerDataTypes.PetInstance

export type Boosts = {
	CoinMultiplier: number, -- 0.1 = +10%
	MoveSpeed: number,
	ScoopSpeed: number,
	TipBonus: number,
}

export type EggStatus = {
	CanBuy: boolean,
	Reason: string?, -- why not, for the UI / error message
	Cost: number,
	Currency: GameData.CurrencyId,
}

local BOOST_LABELS: { [GameData.PetBoostStat]: string } = {
	CoinMultiplier = "Coins",
	MoveSpeed = "Speed",
	ScoopSpeed = "Scoop",
	TipBonus = "Tips",
}

local PetRules = {}

local PASS_EXTRA_SLOTS = 2 -- the Extra Pet Slots game pass

-- How many pets can be equipped at once (base + Extra Pet Slot skill + game pass).
function PetRules.equipSlots(data: PlayerData): number
	local skillLevel = data.Skills.ExtraPetSlot or 0
	local fromSkill = if skillLevel > 0 then RebirthSkills.ExtraPetSlot.Values[skillLevel] else 0
	local fromPass = if data.OwnedPasses.ExtraPetSlots then PASS_EXTRA_SLOTS else 0
	return GameConfig.Pets.BaseEquipSlots + fromSkill + fromPass
end

function PetRules.inventoryCount(data: PlayerData): number
	local count = 0
	for _ in data.Pets.Inventory do
		count += 1
	end
	return count
end

-- Equipped pet ids that really exist, without duplicates, capped at the slot count.
function PetRules.equipped(data: PlayerData): { string }
	local result: { string } = {}
	for _, petGuid in data.Pets.Equipped do
		if #result >= PetRules.equipSlots(data) then
			break
		end
		if data.Pets.Inventory[petGuid] and not table.find(result, petGuid) then
			table.insert(result, petGuid)
		end
	end
	return result
end

-- One pet's boost amount (golden pets are stronger).
function PetRules.boostAmount(pet: PetInstance): number
	local def = Pets[pet.PetId]
	if def == nil then
		return 0
	end
	local multiplier = if pet.Variant == "Golden" then GameConfig.Pets.GoldenBoostMultiplier else 1
	return def.BoostAmount * multiplier
end

-- "+5% Coins"
function PetRules.boostLabel(pet: PetInstance): string
	local def = Pets[pet.PetId]
	if def == nil then
		return ""
	end
	return `+{math.floor(PetRules.boostAmount(pet) * 100 + 0.5)}% {BOOST_LABELS[def.BoostStat]}`
end

-- Total boosts from all equipped pets (they add together).
function PetRules.totalBoosts(data: PlayerData): Boosts
	local boosts: Boosts = { CoinMultiplier = 0, MoveSpeed = 0, ScoopSpeed = 0, TipBonus = 0 }
	for _, petGuid in PetRules.equipped(data) do
		local pet = data.Pets.Inventory[petGuid]
		local def = Pets[pet.PetId]
		if def then
			(boosts :: any)[def.BoostStat] += PetRules.boostAmount(pet)
		end
	end
	return boosts
end

-- Unlocked, normal (not golden) copies of a pet that a merge would use.
function PetRules.mergeCandidates(data: PlayerData, petId: string): { string }
	local result: { string } = {}
	for petGuid, pet in data.Pets.Inventory do
		if pet.PetId == petId and pet.Variant == "Normal" and not pet.Locked then
			table.insert(result, petGuid)
		end
	end
	table.sort(result) -- deterministic
	return result
end

function PetRules.canMerge(data: PlayerData, petId: string): boolean
	return #PetRules.mergeCandidates(data, petId) >= GameConfig.Pets.MergeCount
end

-- Can the player buy `count` of this egg right now?
function PetRules.eggStatus(data: PlayerData, eggId: string, count: number): EggStatus
	local egg = Eggs[eggId]
	assert(egg, `Unknown egg {eggId}`)
	local cost = egg.Price * count
	local status: EggStatus = { CanBuy = false, Reason = nil, Cost = cost, Currency = egg.Currency }
	if egg.EventOnly then
		status.Reason = "Only available during events."
	elseif PetRules.inventoryCount(data) + count > GameConfig.Pets.MaxInventory then
		status.Reason = "Your pet inventory is full! Delete or merge some pets."
	elseif (data :: any)[egg.Currency] < cost then
		status.Reason = `Not enough {egg.Currency}.`
	else
		status.CanBuy = true
	end
	return status
end

return PetRules
