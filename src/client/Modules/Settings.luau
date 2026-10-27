-- Client settings (saved on the server via SetSetting, mirrored through State "settings").
--   Settings.get(key) -> value (with defaults)    Settings.set(key, value)
--   Settings.Changed:Connect(function(key, value) ... end)
-- Keys: music (bool), sfx (bool), shake (bool), quality ("High" | "Low")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local State = require(script.Parent:WaitForChild("State"))

local Settings = {}
Settings.Changed = Signal.new()

local DEFAULTS = { music = true, sfx = true, shake = true, quality = "High" }
local values: { [string]: any } = table.clone(DEFAULTS)

State.observe("settings", function(saved)
	if typeof(saved) ~= "table" then
		return
	end
	for k, default in pairs(DEFAULTS) do
		local v = saved[k]
		if v == nil then
			v = default
		end
		if values[k] ~= v then
			values[k] = v
			Settings.Changed:Fire(k, v)
		end
	end
end)

function Settings.get(key: string): any
	return values[key]
end

function Settings.set(key: string, value: any)
	if values[key] == value then
		return
	end
	values[key] = value
	Settings.Changed:Fire(key, value)
	task.spawn(function()
		Net.func("SetSetting"):InvokeServer(key, value)
	end)
end

function Settings.lowQuality(): boolean
	return values.quality == "Low"
end

return Settings
