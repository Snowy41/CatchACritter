-- Saves the player's client settings in their data (music, sfx, quality, shake) and sends them
-- back on join (State "settings"). Values are validated against the known keys.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)

local SettingsService = {}
SettingsService.Priority = 24

-- key -> validator
local KEYS: { [string]: (any) -> boolean } = {
	music = function(v)
		return typeof(v) == "boolean"
	end,
	sfx = function(v)
		return typeof(v) == "boolean"
	end,
	shake = function(v)
		return typeof(v) == "boolean"
	end,
	quality = function(v)
		return v == "High" or v == "Low"
	end,
}

function SettingsService.Start()
	Net.func("SetSetting").OnServerInvoke = function(player, key, value)
		local data = DataService.get(player)
		local valid = typeof(key) == "string" and KEYS[key]
		if not data or not valid or not valid(value) then
			return { ok = false }
		end
		data.settings[key] = value
		StateService.set(player, "settings", data.settings)
		return { ok = true }
	end
end

function SettingsService.PlayerAdded(player: Player, data: DataService.Data)
	StateService.set(player, "settings", data.settings)
end

return SettingsService
