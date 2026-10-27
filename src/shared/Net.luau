--!strict
-- All remotes in one place, created by name at runtime in ReplicatedStorage.Net.
-- Server: Net.event("Notify") creates it if missing. Client: Net.event("Notify") waits for it.
-- Add new remotes to the lists below; unknown names error so typos surface immediately.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	Notify = true, -- server -> client: toast message (text, kind)
	Fx = true, -- server -> client: effect events (kind, data)
	Knockback = true, -- server -> client: push the local character (velocity)
	State = true, -- server -> client: player state value changed (key, value), see StateService
}
local FUNCTIONS = {
	RequestCatch = true, -- client -> server: start a catch on a wild critter
	SubmitCatch = true, -- client -> server: timing-bar result
	BuyUpgrade = true, -- client -> server: buy an upgrade
	GetState = true, -- client -> server: full player state snapshot
	ClaimWelcome = true, -- client -> server: collect the welcome-back coins
	ClaimQuest = true, -- client -> server: claim a finished daily quest (index)
	ClaimDexPage = true, -- client -> server: claim a completed Critterdex page reward (page id)
	SetTitle = true, -- client -> server: equip an earned title (id or nil)
	Rebirth = true, -- client -> server: rebirth
	SetSetting = true, -- client -> server: save a setting (key, value)
	ClaimDaily = true, -- client -> server: claim today's daily reward
}

local IS_SERVER = RunService:IsServer()
local Net = {}

local folder: Folder
if IS_SERVER then
	folder = ReplicatedStorage:FindFirstChild("Net") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Net"
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Net") :: Folder
end

local function get(name: string, className: string): Instance
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	if IS_SERVER then
		local r = Instance.new(className)
		r.Name = name
		r.Parent = folder
		return r
	end
	return folder:WaitForChild(name)
end

function Net.event(name: string): RemoteEvent
	assert(EVENTS[name], "Net: unknown event " .. name)
	return get(name, "RemoteEvent") :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	assert(FUNCTIONS[name], "Net: unknown function " .. name)
	return get(name, "RemoteFunction") :: RemoteFunction
end

-- Server: create every declared remote up front so clients never wait on a missing one.
function Net.createAll()
	assert(IS_SERVER, "Net.createAll is server-only")
	for name in pairs(EVENTS) do
		Net.event(name)
	end
	for name in pairs(FUNCTIONS) do
		Net.func(name)
	end
end

return Net
