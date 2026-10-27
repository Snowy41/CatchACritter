-- Daily reward calendar (shared/DailyRewards): one claim per UTC day, no penalty for missed days
-- (the next claim continues with the next calendar day), cycles after day 7.
-- State pushed to the client: "daily" = { next (1..7), available, nextAt }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyRewards = require(ReplicatedStorage.Shared.DailyRewards)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Net = require(ReplicatedStorage.Shared.Net)
local Quests = require(ReplicatedStorage.Shared.Quests)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local EggService = require(script.Parent.EggService)
local FxService = require(script.Parent.FxService)
local StateService = require(script.Parent.StateService)

local DailyService = {}
DailyService.Priority = 47

local function push(player: Player, data: DataService.Data)
	local d = data.daily
	local today = Quests.day()
	local available = today > d.lastDay
	StateService.set(player, "daily", {
		next = (d.count % #DailyRewards.Days) + 1,
		available = available,
		nextAt = available and 0 or (today + 1) * 86400,
	})
	player:SetAttribute("DailyReady", available)
end

local function claim(player: Player)
	local data = DataService.get(player)
	if not data then
		return { ok = false }
	end
	local d = data.daily
	local today = Quests.day()
	if today <= d.lastDay then
		return { ok = false, message = "Come back tomorrow!" }
	end
	local index = (d.count % #DailyRewards.Days) + 1
	local reward = DailyRewards.Days[index]
	d.count += 1
	d.lastDay = today
	local coins = DailyRewards.coins(reward, BaseService.baseIncome(player))
	if coins > 0 then
		BaseService.addCoins(player, coins)
		FxService.toPlayer(player, "Reward", { amount = coins })
	end
	if reward.egg then
		local species = "CloverBun"
		for _, entry in pairs(data.base) do
			species = entry.species
			break
		end
		if EggService.give(player, species, reward.egg, nil, true) then
			FxService.announceTo(player, ("Day %d: a %s egg is in your nest!"):format(index, reward.egg), reward.egg, Icons.Egg)
		end
	end
	push(player, data)
	return { ok = true, index = index, coins = coins }
end

function DailyService.Start()
	Net.func("ClaimDaily").OnServerInvoke = claim
	-- a new UTC day while online: the next reward becomes available
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.get(player)
				if data and not player:GetAttribute("DailyReady") and Quests.day() > data.daily.lastDay then
					push(player, data)
				end
			end
		end
	end)
end

function DailyService.PlayerAdded(player: Player, data: DataService.Data)
	push(player, data)
end

return DailyService
