--!strict
--[[
	NeighborhoodRules
	Whether a player can unlock / enter a neighborhood. Server validates gates
	and pads with these; the client uses them for gate signs and barriers.
	Neighborhoods unlock in order (Order 1, 2, 3...), each needing the one before.
]]

local Shared = script.Parent.Parent
local Neighborhoods = require(Shared.Data.Neighborhoods)
local PlayerDataTypes = require(Shared.Types.PlayerData)

type PlayerData = PlayerDataTypes.PlayerData

export type State =
	"Unlocked"
	| "Available" -- can be unlocked now (may still be unaffordable)
	| "NeedsPrevious" -- unlock the neighborhood before it first
	| "NeedsRebirth"

export type Status = { State: State, Cost: number, CanBuy: boolean }

local NeighborhoodRules = {}

-- The neighborhood that comes right before this one (nil for the first and the Hub).
function NeighborhoodRules.previous(neighborhoodId: string): string?
	local area = Neighborhoods[neighborhoodId]
	if area == nil or area.IsHub then
		return nil
	end
	for id, other in Neighborhoods do
		if not other.IsHub and other.Order == area.Order - 1 then
			return id
		end
	end
	return nil
end

-- neighborhoodId must be a key of Shared/Data/Neighborhoods.
function NeighborhoodRules.status(data: PlayerData, neighborhoodId: string): Status
	local area = Neighborhoods[neighborhoodId]
	assert(area, `Unknown neighborhood {neighborhoodId}`)
	local state: State
	local previous = NeighborhoodRules.previous(neighborhoodId)
	if area.IsHub or area.UnlockCost == 0 or data.Neighborhoods.Unlocked[neighborhoodId] then
		state = "Unlocked"
	elseif data.Rebirths < area.RequiresRebirths then
		state = "NeedsRebirth"
	elseif previous and not data.Neighborhoods.Unlocked[previous] then
		state = "NeedsPrevious"
	else
		state = "Available"
	end
	return { State = state, Cost = area.UnlockCost, CanBuy = state == "Available" and data.Coins >= area.UnlockCost }
end

-- True if the player may be in this area right now.
function NeighborhoodRules.canEnter(data: PlayerData, neighborhoodId: string): boolean
	local area = Neighborhoods[neighborhoodId]
	return area ~= nil
		and NeighborhoodRules.status(data, neighborhoodId).State == "Unlocked"
		and data.Rebirths >= area.RequiresRebirths
end

return NeighborhoodRules
