-- Pushes structured per-player state (quests, Critterdex, eggs, titles, welcome-back reward ...)
-- to that player's client. Simple values stay player attributes; tables go through here.
-- Client side: Modules/State (snapshot via GetState, then live updates via the State event).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local StateService = {}
StateService.Priority = 2

local cache: { [Player]: { [string]: any } } = {}
local event: RemoteEvent

function StateService.set(player: Player, key: string, value: any)
	local c = cache[player]
	if not c then
		c = {}
		cache[player] = c
	end
	c[key] = value
	event:FireClient(player, key, value)
end

function StateService.get(player: Player, key: string): any
	local c = cache[player]
	return c and c[key]
end

function StateService.Init()
	event = Net.event("State")
	Net.func("GetState").OnServerInvoke = function(player)
		return cache[player] or {}
	end
end

function StateService.PlayerRemoving(player: Player)
	cache[player] = nil
end

return StateService
