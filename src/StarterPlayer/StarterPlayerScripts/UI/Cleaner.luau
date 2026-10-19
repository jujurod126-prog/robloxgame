--!strict
--[[
	Cleaner
	Collects things to undo later - connections, tweens, instances, functions -
	and cleans them all at once. Windows use one per "open" so closing a window
	disconnects its events and cancels its tweens.

	local cleaner = Cleaner.new()
	cleaner:add(signal:Connect(...))
	cleaner:add(someFrame)
	cleaner:clean()
]]

export type Cleaner = {
	add: <T>(self: Cleaner, item: T) -> T,
	clean: (self: Cleaner) -> (),
}

local Cleaner = {}

function Cleaner.new(): Cleaner
	local items: { any } = {}
	local cleaner = {} :: any

	function cleaner:add(item)
		table.insert(items, item)
		return item
	end

	function cleaner:clean()
		-- Newest first, so children go before the things they depend on.
		for index = #items, 1, -1 do
			local item = items[index]
			local kind = typeof(item)
			if kind == "RBXScriptConnection" or (kind == "table" and item.Disconnect) then
				item:Disconnect() -- Roblox connections and our Signal connections
			elseif kind == "Instance" then
				if item:IsA("Tween") then
					item:Cancel()
				end
				item:Destroy()
			elseif kind == "function" then
				item()
			end
		end
		table.clear(items)
	end

	return cleaner :: Cleaner
end

return Cleaner
