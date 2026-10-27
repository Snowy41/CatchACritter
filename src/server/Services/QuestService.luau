-- Daily quests (pool in shared/Quests): three per UTC day, rolled per player. Missing a day costs
-- nothing. Claiming all three gives a bonus egg.
-- State pushed to the client: "quests" = { day, list, bonusClaimed, resetsAt }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Net = require(ReplicatedStorage.Shared.Net)
local Quests = require(ReplicatedStorage.Shared.Quests)
local BaseService = require(script.Parent.BaseService)
local CritterService = require(script.Parent.CritterService)
local DataService = require(script.Parent.DataService)
local EggService = require(script.Parent.EggService)
local FxService = require(script.Parent.FxService)
local StateService = require(script.Parent.StateService)

local QuestService = {}
QuestService.Priority = 45

local function push(player: Player, data: DataService.Data)
	local q = data.quests
	if q then
		StateService.set(player, "quests", { day = q.day, list = q.list, bonusClaimed = q.bonusClaimed, resetsAt = (q.day + 1) * 86400 })
		local ready = 0
		for _, e in ipairs(q.list) do
			if not e.claimed and e.progress >= e.goal then
				ready += 1
			end
		end
		player:SetAttribute("QuestsReady", ready)
	end
end

-- Rolls today's quests if the stored ones are from another day.
local function ensureToday(player: Player, data: DataService.Data): boolean
	local today = Quests.day()
	if data.quests and data.quests.day == today then
		return false
	end
	local rng = Random.new(player.UserId * 7919 + today)
	local pool = table.clone(Quests.Pool)
	local list = {}
	local income = BaseService.baseIncome(player)
	for _ = 1, math.min(Quests.PerDay, #pool) do
		local def = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(list, {
			id = def.id,
			goal = def.goals[rng:NextInteger(1, #def.goals)],
			progress = 0,
			reward = math.floor(math.max(def.minReward, income * def.rewardSeconds)),
			claimed = false,
		})
	end
	data.quests = { day = today, list = list, bonusClaimed = false }
	return true
end

local function advance(player: Player, matches: (Quests.QuestDef) -> boolean)
	local data = DataService.get(player)
	if not data then
		return
	end
	ensureToday(player, data)
	local changed = false
	for _, e in ipairs((data.quests :: any).list) do
		local def = Quests.ById[e.id]
		if def and e.progress < e.goal and matches(def) then
			e.progress += 1
			changed = true
			if e.progress >= e.goal then
				FxService.toPlayer(player, "QuestDone", { text = def.text:format(e.goal) })
			end
		end
	end
	if changed then
		push(player, data)
	end
end

local function rollBonusRarity(): string
	local total = 0
	for _, w in pairs(Quests.BonusEggRarities) do
		total += w
	end
	local pick = math.random() * total
	for _, r in ipairs(Config.Rarities) do
		local w = Quests.BonusEggRarities[r.name]
		if w then
			pick -= w
			if pick <= 0 then
				return r.name
			end
		end
	end
	return "Uncommon"
end

local function claim(player: Player, index: any)
	local data = DataService.get(player)
	if not data or typeof(index) ~= "number" then
		return { ok = false }
	end
	ensureToday(player, data)
	local q = data.quests :: any
	local e = q.list[index]
	if not e or e.claimed or e.progress < e.goal then
		return { ok = false }
	end
	e.claimed = true
	BaseService.addCoins(player, e.reward)
	FxService.toPlayer(player, "Reward", { amount = e.reward })
	-- all done: bonus egg from a random species of the player's base (or any Meadow species)
	local all = true
	for _, x in ipairs(q.list) do
		all = all and x.claimed
	end
	if all and not q.bonusClaimed then
		q.bonusClaimed = true
		local species = {}
		for _, entry in pairs(data.base) do
			table.insert(species, entry.species)
		end
		if #species == 0 then
			species = { "CloverBun", "Buzzpup" }
		end
		local rarity = rollBonusRarity()
		local egg = EggService.give(player, species[math.random(1, #species)], rarity, nil, true)
		if egg then
			FxService.announceTo(player, ("All quests done! A %s egg was placed in your nest"):format(rarity), rarity, Icons.Egg)
		else
			BaseService.addCoins(player, 500)
			FxService.notify(player, "All quests done! +500 coins", "coins")
		end
	end
	push(player, data)
	return { ok = true }
end

function QuestService.Start()
	Net.func("ClaimQuest").OnServerInvoke = claim
	CritterService.Caught:Connect(function(player: Player, entry, nestZone)
		local weather = workspace:GetAttribute("Weather")
		local featured = workspace:GetAttribute("CritterOfTheHour")
		advance(player, function(def)
			if def.event ~= "Catch" then
				return false
			end
			if def.minTier and Config.tier(entry.rarity) < def.minTier then
				return false
			end
			if def.duringWeather and (weather == nil or weather == "Clear") then
				return false
			end
			if def.featured and entry.species ~= featured then
				return false
			end
			if def.fromNest and not nestZone then
				return false
			end
			return true
		end)
	end)
	BaseService.Collected:Connect(function(player: Player)
		advance(player, function(def)
			return def.event == "Collect"
		end)
	end)
	-- new day while online: fresh quests
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.get(player)
				if data and ensureToday(player, data) then
					push(player, data)
					FxService.announceTo(player, "New daily quests are here!", nil, Icons.Quests)
				end
			end
		end
	end)
end

function QuestService.PlayerAdded(player: Player, data: DataService.Data)
	ensureToday(player, data)
	push(player, data)
end

return QuestService
