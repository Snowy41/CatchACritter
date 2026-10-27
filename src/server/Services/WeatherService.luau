-- Habitat weather (GDD "Events, weather and FOMO"): mostly clear; every few minutes a weather
-- event runs for a few minutes. While it runs, critters in the bases of ONLINE players can gain
-- that weather's mutation (offline bases are never touched - rewards for being online, never
-- penalties for being away).
-- Workspace attributes for clients/board: Weather, WeatherEnds, NextWeather, NextWeatherAt,
-- IncomeMultiplier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CritterDefs = require(ReplicatedStorage.Shared.CritterDefs)
local BaseService = require(script.Parent.BaseService)
local CritterService = require(script.Parent.CritterService)
local DataService = require(script.Parent.DataService)
local FxService = require(script.Parent.FxService)
local PlotService = require(script.Parent.PlotService)

local WeatherService = {}
WeatherService.Priority = 65

type WeatherDef = {
	name: string,
	displayName: string,
	weight: number,
	duration: { number }, -- seconds (min, max)
	incomeMult: number,
	mutation: string?, -- weather mutation rolled on base critters
	mutationChance: number, -- per critter per roll
	luckySpawns: number, -- extra Rare spawns during the event
}

local WEATHERS: { WeatherDef } = {
	{ name = "Rain", displayName = "Rain", weight = 45, duration = { 120, 180 }, incomeMult = 1.5, mutation = nil, mutationChance = 0, luckySpawns = 0 },
	{ name = "Snowstorm", displayName = "Snowstorm", weight = 35, duration = { 120, 160 }, incomeMult = 1, mutation = "Frozen", mutationChance = 0.03, luckySpawns = 0 },
	{ name = "RainbowStorm", displayName = "Rainbow Storm", weight = 20, duration = { 100, 140 }, incomeMult = 1.2, mutation = "Rainbow", mutationChance = 0.015, luckySpawns = 2 },
}
local GAP = { 300, 720 } -- seconds of clear weather between events
local ROLL_EVERY = 10 -- seconds between mutation rolls

local rng = Random.new()
local byName: { [string]: WeatherDef } = {}
for _, w in ipairs(WEATHERS) do
	byName[w.name] = w
end

local function pickWeather(): WeatherDef
	local total = 0
	for _, w in ipairs(WEATHERS) do
		total += w.weight
	end
	local pick = rng:NextNumber() * total
	for _, w in ipairs(WEATHERS) do
		pick -= w.weight
		if pick <= 0 then
			return w
		end
	end
	return WEATHERS[1]
end

local function scheduleNext(after: number)
	local nextW = pickWeather()
	workspace:SetAttribute("NextWeather", nextW.name)
	workspace:SetAttribute("NextWeatherAt", after + rng:NextInteger(GAP[1], GAP[2]))
end

local function rollMutations(w: WeatherDef)
	if not w.mutation then
		return
	end
	-- Studio test hook: Workspace attribute DevWeatherChance (0..1) overrides the roll chance
	local chance = w.mutationChance
	local dev = RunService:IsStudio() and workspace:GetAttribute("DevWeatherChance")
	if typeof(dev) == "number" then
		chance = dev
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.get(player)
		local plot = PlotService.getPlot(player)
		if data and plot then
			for key, entry in pairs(data.base) do
				if not entry.weather and rng:NextNumber() < chance then
					entry.weather = w.mutation
					local index = tonumber(key) :: number
					BaseService.rerenderSlot(player, index)
					local slot = PlotService.slot(plot, index)
					if slot then
						FxService.toAll("WeatherMutate", { pos = slot.Position + Vector3.new(0, slot.Size.Y / 2, 0), weather = w.mutation })
					end
					local m = Config.MutationByName[w.mutation]
					FxService.notify(player, ("Your %s turned %s! x%d"):format(CritterDefs[entry.species].displayName, string.upper(w.mutation), m and m.incomeMult or 1), "success")
				end
			end
		end
	end
end

local function startWeather(w: WeatherDef)
	local now = os.time()
	workspace:SetAttribute("Weather", w.name)
	workspace:SetAttribute("WeatherEnds", now + rng:NextInteger(w.duration[1], w.duration[2]))
	workspace:SetAttribute("IncomeMultiplier", w.incomeMult)
	local line = ({
		Rain = "It's raining - coins flow 1.5x faster!",
		Snowstorm = "SNOWSTORM! Critters in your base can turn FROZEN!",
		RainbowStorm = "RAINBOW STORM! Rainbow critters and extra Rare spawns!",
	})[w.name] or (w.displayName .. "!")
	FxService.announce(line)
	for i = 1, w.luckySpawns do
		task.delay(i * 20, function()
			if workspace:GetAttribute("Weather") == w.name and CritterService.hasSpecies("Meadow") then
				local model, entry = CritterService.spawnSpecial("Meadow", "Rare")
				if model and entry then
					FxService.announce(("A RARE %s appeared in the Rainbow Storm!"):format(CritterDefs[entry.species].displayName), "Rare")
				end
			end
		end)
	end
end

local function endWeather()
	workspace:SetAttribute("Weather", "Clear")
	workspace:SetAttribute("WeatherEnds", nil)
	workspace:SetAttribute("IncomeMultiplier", 1)
	scheduleNext(os.time())
end

function WeatherService.Init()
	workspace:SetAttribute("Weather", "Clear")
	workspace:SetAttribute("IncomeMultiplier", 1)
	scheduleNext(os.time())
end

function WeatherService.Start()
	local lastRoll = 0
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			-- Studio test hook: set Workspace attribute DevWeather = "Rain" / "Snowstorm" / "RainbowStorm"
			local forced = RunService:IsStudio() and workspace:GetAttribute("DevWeather")
			if typeof(forced) == "string" and byName[forced] then
				workspace:SetAttribute("DevWeather", nil)
				startWeather(byName[forced])
			end
			local current = workspace:GetAttribute("Weather")
			if current == "Clear" then
				if now >= (workspace:GetAttribute("NextWeatherAt") or math.huge) then
					startWeather(byName[workspace:GetAttribute("NextWeather")] or pickWeather())
				end
			else
				if now >= (workspace:GetAttribute("WeatherEnds") or 0) then
					endWeather()
				elseif now - lastRoll >= ROLL_EVERY then
					lastRoll = now
					rollMutations(byName[current])
				end
			end
		end
	end)
end

return WeatherService
