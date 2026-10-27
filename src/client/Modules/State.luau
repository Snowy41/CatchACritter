-- Client mirror of the player state the server pushes through StateService (quests, Critterdex,
-- eggs, titles, welcome-back reward ...). Simple values are player attributes instead.
--   State.get(key)            -> current value (may be nil)
--   State.observe(key, fn)    -> fn(value) now and on every change; returns the connection

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Signal = require(ReplicatedStorage.Shared:WaitForChild("Util"):WaitForChild("Signal"))

local State = {}

local values: { [string]: any } = {}
local signals: { [string]: any } = {}
local received: { [string]: boolean } = {}

local function signalFor(key: string)
	local s = signals[key]
	if not s then
		s = Signal.new()
		signals[key] = s
	end
	return s
end

local function set(key: string, value: any)
	values[key] = value
	received[key] = true
	signalFor(key):Fire(value)
end

Net.event("State").OnClientEvent:Connect(set)
task.spawn(function()
	local ok, snapshot = pcall(function()
		return Net.func("GetState"):InvokeServer()
	end)
	if ok and typeof(snapshot) == "table" then
		for key, value in pairs(snapshot) do
			if not received[key] then -- a live update that arrived first is newer
				set(key, value)
			end
		end
	end
end)

function State.get(key: string): any
	return values[key]
end

function State.observe(key: string, fn: (any) -> ())
	task.spawn(fn, values[key])
	return signalFor(key):Connect(fn)
end

return State
