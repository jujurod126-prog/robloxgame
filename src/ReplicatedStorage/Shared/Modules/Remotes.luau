--!strict
--[[
	Remotes
	The single list of every RemoteEvent / RemoteFunction name.
	The server creates them all at startup (Remotes.createAll); clients wait for them.
	docs/UI_CONTRACT.md documents each one's direction and arguments.

	Server: Remotes.createAll() once, then Remotes.event("DataPatch")
	Client: Remotes.event("DataPatch") (waits until the server has created it)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local WAIT_TIMEOUT = 30

export type EventName = "DataPatch" | "OrderResult" | "Notify" | "SelectFlavor"
export type FunctionName =
	"GetSnapshot"
	| "BuyUpgrade"
	| "BuyTruckTier"
	| "UnlockFlavor"
	| "EquipFlavor"
	| "UnlockTopping"
	| "AddTopping"

-- Add new names to BOTH the type above and the list below.
local EVENT_NAMES: { EventName } = {
	"DataPatch", -- Server -> Client: (seq: number, path: {string}, value: any)
	"OrderResult", -- Server -> Client: (position: Vector3, coins: number, correct: boolean, comboMultiplier: number)
	"Notify", -- Server -> Client: (message: string, kind: "Info" | "Error")
	"SelectFlavor", -- Client -> Server: (slot: number) choose which loaded flavor the dispenser scoops
}

local FUNCTION_NAMES: { FunctionName } = {
	"GetSnapshot", -- Client -> Server: () -> { Seq: number, Data: PlayerData }?
	"BuyUpgrade", -- Client -> Server: (statId: string) -> PurchaseResult
	"BuyTruckTier", -- Client -> Server: (tier: number) -> PurchaseResult
	"UnlockFlavor", -- Client -> Server: (flavorId: string) -> PurchaseResult
	"EquipFlavor", -- Client -> Server: (flavorId: string, slot: number) -> PurchaseResult
	"UnlockTopping", -- Client -> Server: (toppingId: string) -> PurchaseResult
	"AddTopping", -- Client -> Server: (toppingId: string) -> PurchaseResult (put a topping on your cone)
}

-- What purchase RemoteFunctions return. Message is shown to the player.
export type PurchaseResult = { Ok: boolean, Message: string }

local Remotes = {}

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		assert(folder and folder:IsA("Folder"), "Remotes.createAll() must run before remotes are used")
		return folder
	end
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT)
	assert(folder and folder:IsA("Folder"), "Timed out waiting for the Remotes folder")
	return folder
end

local cache: { [string]: Instance } = {}

local function getRemote(name: string): Instance
	local cached = cache[name]
	if cached then
		return cached
	end
	local folder = getFolder()
	local remote = if RunService:IsServer()
		then folder:FindFirstChild(name)
		else folder:WaitForChild(name, WAIT_TIMEOUT)
	assert(remote, `Remote "{name}" does not exist (is it listed in Remotes.luau?)`)
	cache[name] = remote
	return remote
end

-- Server only: builds ReplicatedStorage.Remotes with every remote listed above.
function Remotes.createAll()
	assert(RunService:IsServer(), "Remotes.createAll is server-only")
	assert(not ReplicatedStorage:FindFirstChild(FOLDER_NAME), "Remotes.createAll called twice")

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in EVENT_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in FUNCTION_NAMES do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

function Remotes.event(name: EventName): RemoteEvent
	return getRemote(name) :: RemoteEvent
end

function Remotes.func(name: FunctionName): RemoteFunction
	return getRemote(name) :: RemoteFunction
end

return Remotes
