--!strict
-- Minimal signal for decoupled communication between modules (server services, client controllers).
--   local s = Signal.new()
--   local conn = s:Connect(function(a, b) ... end)
--   s:Fire(1, 2)
--   conn:Disconnect()

export type Connection = { Disconnect: (self: Connection) -> (), Connected: boolean }
export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> Connection,
	Once: (self: Signal, fn: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	Wait: (self: Signal) -> ...any,
}

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal
	local self = setmetatable({ _handlers = {} :: { [any]: (...any) -> () } }, Signal)
	return (self :: any) :: Signal
end

function Signal:Connect(fn: (...any) -> ()): Connection
	local key = {}
	self._handlers[key] = fn
	local conn = { Connected = true }
	function conn.Disconnect(c)
		c.Connected = false
		self._handlers[key] = nil
	end
	return (conn :: any) :: Connection
end

function Signal:Once(fn: (...any) -> ()): Connection
	local conn: Connection
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

-- Handlers run in their own threads, so one failing handler can't break the others.
function Signal:Fire(...: any)
	for _, fn in pairs(self._handlers) do
		task.spawn(fn, ...)
	end
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

return Signal
