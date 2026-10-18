--!strict
--[[
	Signal
	A tiny event object for script-to-script communication (no Instances needed).

	local changed = Signal.new()
	local connection = changed:Connect(function(a, b) ... end)
	changed:Fire(1, 2)
	connection:Disconnect()

	Each handler runs in its own thread (task.spawn), so one handler erroring
	or yielding never blocks the others.
]]

local Connection = {}
Connection.__index = Connection

export type Connection = typeof(setmetatable(
	{} :: { Connected: boolean, _signal: any, _handler: (...any) -> () },
	Connection
))

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable({} :: { _connections: { Connection } }, Signal))

function Connection.Disconnect(self: Connection)
	if not self.Connected then
		return
	end
	self.Connected = false
	local connections = self._signal._connections
	local index = table.find(connections, self)
	if index then
		table.remove(connections, index)
	end
end

function Signal.new(): Signal
	return setmetatable({ _connections = {} }, Signal)
end

function Signal.Connect(self: Signal, handler: (...any) -> ()): Connection
	local connection = setmetatable({ Connected = true, _signal = self, _handler = handler }, Connection)
	table.insert(self._connections, connection)
	return connection
end

-- Like Connect, but disconnects itself after the first Fire.
function Signal.Once(self: Signal, handler: (...any) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

-- Yields the current thread until the next Fire and returns its arguments.
function Signal.Wait(self: Signal): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.Fire(self: Signal, ...: any)
	-- Copy first so handlers that disconnect while firing don't make others get skipped.
	for _, connection in table.clone(self._connections) do
		if connection.Connected then
			task.spawn(connection._handler, ...)
		end
	end
end

function Signal.DisconnectAll(self: Signal)
	for _, connection in self._connections do
		connection.Connected = false
	end
	table.clear(self._connections)
end

return Signal
