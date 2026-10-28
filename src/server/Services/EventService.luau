-- Server events that make "something is always about to happen" (GDD: Events, weather and FOMO):
--  * Critter of the Hour: one species gets a boosted spawn weight each hour, announced
--  * Lucky spawns: every few minutes a Rare/Epic critter appears in the Meadow with a light pillar
--  * Onboarding: a newcomer's first deposit triggers a scripted Rare spawn near them
--  * Schedule board in the plaza shows the live countdowns

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CritterDefs = require(ReplicatedStorage.Shared.CritterDefs)
local Zones = require(ReplicatedStorage.Shared.Zones)
local BaseService = require(script.Parent.BaseService)
local CritterService = require(script.Parent.CritterService)
local FxService = require(script.Parent.FxService)

local EventService = {}
EventService.Priority = 60

local rng = Random.new()
local nextLucky = 0
local onboarded: { [Player]: boolean } = {}

local function speciesList(): { string }
	local list = {}
	for species in pairs(CritterDefs) do
		if not CritterDefs.isSpecial(species) then
			table.insert(list, species)
		end
	end
	table.sort(list)
	return list
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d = seconds // 86400
	local h = (seconds % 86400) // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if d > 0 then
		return ("%dd %dh"):format(d, h)
	elseif h > 0 then
		return ("%d:%02d:%02d"):format(h, m, s)
	end
	return ("%d:%02d"):format(m, s)
end

-- seconds until the next weekly update (Friday 17:00 UTC by default)
local function secondsToUpdate(now: number): number
	local t = os.date("!*t", now) :: any
	local daysAhead = (Config.UpdateWeekday - t.wday) % 7
	local target = now - (t.hour * 3600 + t.min * 60 + t.sec) + daysAhead * 86400 + Config.UpdateHourUTC * 3600
	if target <= now then
		target += 7 * 86400
	end
	return target - now
end

--------------------------------------------------------------------------- critter of the hour

local function updateCritterOfTheHour(announce: boolean)
	local list = speciesList()
	local hour = os.time() // 3600
	local species = list[(hour % #list) + 1]
	if workspace:GetAttribute("CritterOfTheHour") ~= species then
		workspace:SetAttribute("CritterOfTheHour", species)
		if announce then
			FxService.announce(("Critter of the Hour: %s! More of them are out now."):format(CritterDefs[species].displayName))
		end
	end
	workspace:SetAttribute("CritterOfTheHourEnds", (hour + 1) * 3600)
end

--------------------------------------------------------------------------- lucky spawns

local function rollLuckyRarity(): string
	local total = 0
	for _, w in pairs(Config.LuckySpawnWeights) do
		total += w
	end
	local pick = rng:NextNumber() * total
	for _, r in ipairs(Config.Rarities) do
		local w = Config.LuckySpawnWeights[r.name]
		if w then
			pick -= w
			if pick <= 0 then
				return r.name
			end
		end
	end
	return "Rare"
end

local function luckySpawn(zone: string, rarity: string, near: Vector3?, onlyFor: Player?)
	local model, entry = CritterService.spawnSpecial(zone, rarity, near)
	if not model or not entry then
		return
	end
	local name = CritterDefs[entry.species].displayName
	local text = ("A %s %s appeared in the %s!"):format(string.upper(rarity), name, zone)
	if onlyFor then
		FxService.announceTo(onlyFor, "RARE SPAWN! " .. text, rarity)
	else
		FxService.announce(text, rarity)
	end
end

local function scheduleNextLucky()
	nextLucky = os.time() + rng:NextInteger(Config.LuckySpawnInterval[1], Config.LuckySpawnInterval[2])
	workspace:SetAttribute("NextLuckySpawn", nextLucky)
end

--------------------------------------------------------------------------- onboarding

-- A newcomer's first deposit (BaseService.Deposited) triggers the scripted Rare spawn of the
-- "first 60 seconds" (GDD), close to the Meadow entrance.
local function onDeposit(player: Player)
	if onboarded[player] or player:GetAttribute("Newcomer") ~= true then
		return
	end
	onboarded[player] = true
	task.delay(Config.OnboardingRareDelay, function()
		if player.Parent then
			luckySpawn("Meadow", "Rare", Vector3.new(0, 0, -290), player)
		end
	end)
end

function EventService.PlayerRemoving(player: Player)
	onboarded[player] = nil
end

--------------------------------------------------------------------------- schedule board

local function setRow(board: Instance, i: number, text: string)
	local row = board:FindFirstChild("Row" .. i, true)
	if row and row:IsA("TextLabel") then
		row.Text = text
	end
end

local WEATHER_NAMES = { Rain = "Rain", Snowstorm = "Snowstorm", RainbowStorm = "Rainbow Storm", Clear = "Clear" }

local function updateBoards()
	local now = os.time()
	local species = workspace:GetAttribute("CritterOfTheHour")
	local cotH = species and CritterDefs[species] and CritterDefs[species].displayName or "?"
	local weather = workspace:GetAttribute("Weather") or "Clear"
	local weatherTitle, weatherLine
	if weather ~= "Clear" then
		weatherTitle = "WEATHER NOW"
		weatherLine = ("%s  -  %s left"):format(WEATHER_NAMES[weather] or weather, formatTime((workspace:GetAttribute("WeatherEnds") or now) - now))
	else
		local nextW = workspace:GetAttribute("NextWeather") or "?"
		weatherTitle = "NEXT WEATHER"
		weatherLine = ("%s in %s"):format(WEATHER_NAMES[nextW] or nextW, formatTime((workspace:GetAttribute("NextWeatherAt") or now) - now))
	end
	for _, board in ipairs(CollectionService:GetTagged("ScheduleBoard")) do
		setRow(board, 1, weatherTitle)
		setRow(board, 2, weatherLine)
		setRow(board, 3, "CRITTER OF THE HOUR")
		setRow(board, 4, ("%s  -  %s"):format(cotH, formatTime((workspace:GetAttribute("CritterOfTheHourEnds") or now) - now)))
		setRow(board, 5, "UPDATE in " .. formatTime(secondsToUpdate(now)))
	end
end

-- zones that currently get lucky spawns (flag in Zones + species exist)
local function luckyZones(): { string }
	local list = {}
	for _, z in Zones.each() do
		if z.luckySpawns and CritterService.hasSpecies(z.name) then
			table.insert(list, z.name)
		end
	end
	return list
end

function EventService.Start()
	BaseService.Deposited:Connect(onDeposit)
	updateCritterOfTheHour(false)
	scheduleNextLucky()
	task.spawn(function()
		while true do
			task.wait(1)
			updateCritterOfTheHour(true)
			-- Studio test hook: set Workspace attribute DevLuckySpawn = true to force one now
			if RunService:IsStudio() and workspace:GetAttribute("DevLuckySpawn") == true then
				workspace:SetAttribute("DevLuckySpawn", false)
				nextLucky = 0
			end
			if os.time() >= nextLucky then
				scheduleNextLucky()
				local zones = luckyZones()
				if #zones > 0 then
					luckySpawn(zones[rng:NextInteger(1, #zones)], rollLuckyRarity())
				end
			end
			updateBoards()
		end
	end)
end

return EventService
