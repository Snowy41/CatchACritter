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
local CritterService = require(script.Parent.CritterService)
local FxService = require(script.Parent.FxService)

local EventService = {}

local rng = Random.new()
local nextLucky = 0
local onboarded: { [Player]: boolean } = {}

local function speciesList(): { string }
	local list = {}
	for species in pairs(CritterDefs) do
		table.insert(list, species)
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

-- Called by BaseService after a deposit. A newcomer's first deposit triggers the scripted Rare
-- spawn of the "first 60 seconds" (GDD), close to the Meadow entrance.
function EventService.onDeposit(player: Player)
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

function EventService.release(player: Player)
	onboarded[player] = nil
end

--------------------------------------------------------------------------- schedule board

local function setRow(board: Instance, i: number, text: string)
	local row = board:FindFirstChild("Row" .. i, true)
	if row and row:IsA("TextLabel") then
		row.Text = text
	end
end

local function updateBoards()
	local now = os.time()
	local species = workspace:GetAttribute("CritterOfTheHour")
	local cotH = species and CritterDefs[species] and CritterDefs[species].displayName or "?"
	for _, board in ipairs(CollectionService:GetTagged("ScheduleBoard")) do
		setRow(board, 1, "CRITTER OF THE HOUR")
		setRow(board, 2, ("%s  -  %s"):format(cotH, formatTime((workspace:GetAttribute("CritterOfTheHourEnds") or now) - now)))
		setRow(board, 3, "LUCKY SPAWN")
		setRow(board, 4, "in " .. formatTime(nextLucky - now))
		setRow(board, 5, "UPDATE in " .. formatTime(secondsToUpdate(now)))
	end
end

function EventService.init()
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
				luckySpawn("Meadow", rollLuckyRarity())
			end
			updateBoards()
		end
	end)
end

return EventService
