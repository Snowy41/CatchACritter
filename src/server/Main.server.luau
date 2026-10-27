-- Server entry point: loads every ModuleScript in Services and runs its lifecycle.
--
-- Service contract (all fields optional except returning a table):
--   Priority: number                     -- lower runs first (Init, Start, PlayerAdded); PlayerRemoving runs in reverse
--   Init(): ()                           -- set up state, no yielding, other services may not be ready yet
--   Start(): ()                          -- connect signals, start loops, bind remotes
--   PlayerAdded(player, data): ()        -- after DataService loaded the player's data
--   PlayerRemoving(player): ()           -- before the data is saved and released
-- Services talk to each other by requiring each other and through Signals (shared/Util/Signal).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
Net.createAll()

local servicesFolder = script.Parent:WaitForChild("Services")
local DataService = require(servicesFolder:WaitForChild("DataService")) :: any

type Service = {
	Priority: number?,
	Init: (() -> ())?,
	Start: (() -> ())?,
	PlayerAdded: ((Player, any) -> ())?,
	PlayerRemoving: ((Player) -> ())?,
}

local services: { { name: string, mod: Service } } = {}
for _, m in ipairs(servicesFolder:GetChildren()) do
	if m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if ok and typeof(mod) == "table" then
			table.insert(services, { name = m.Name, mod = mod })
		else
			warn(("[Main] failed to load service %s: %s"):format(m.Name, tostring(mod)))
		end
	end
end
table.sort(services, function(a, b)
	local pa, pb = a.mod.Priority or 100, b.mod.Priority or 100
	if pa == pb then
		return a.name < b.name
	end
	return pa < pb
end)

local function run(stage: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(("[Main] %s failed: %s"):format(stage, tostring(err)))
	end
end

for _, s in ipairs(services) do
	if s.mod.Init then
		run(s.name .. ".Init", s.mod.Init)
	end
end
for _, s in ipairs(services) do
	if s.mod.Start then
		run(s.name .. ".Start", s.mod.Start)
	end
end

local function onPlayerAdded(player: Player)
	local data = DataService.load(player)
	if not player.Parent then
		DataService.release(player)
		return -- left while loading
	end
	for _, s in ipairs(services) do
		if s.mod.PlayerAdded and s.mod ~= DataService then
			run(s.name .. ".PlayerAdded", function()
				(s.mod.PlayerAdded :: any)(player, data)
			end)
		end
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	for i = #services, 1, -1 do
		local s = services[i]
		if s.mod.PlayerRemoving then
			run(s.name .. ".PlayerRemoving", function()
				(s.mod.PlayerRemoving :: any)(player)
			end)
		end
	end
	DataService.release(player)
end)

print(("[Main] %d services running"):format(#services))
