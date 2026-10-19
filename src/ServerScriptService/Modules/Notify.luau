--!strict
--[[
	Notify
	Sends a short on-screen message to one player (shown by the HUD toast).
	Notify.send(player, "Your cone is full!", "Error")
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

export type Kind = "Info" | "Error"

local Notify = {}

function Notify.send(player: Player, message: string, kind: Kind?)
	Remotes.event("Notify"):FireClient(player, message, kind or "Info")
end

export type CelebrateKind = "Unlock" | "Rebirth" | "Golden" | "Purchase"

-- Confetti and a little screen shake for a big moment.
function Notify.celebrate(player: Player, kind: CelebrateKind)
	Remotes.event("Celebrate"):FireClient(player, kind)
end

return Notify
