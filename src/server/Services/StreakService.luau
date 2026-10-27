-- Catch streaks: catches less than Config.StreakWindow seconds apart build a streak. From x2 on
-- every catch pays bonus coins that grow with the streak (capped at Config.StreakMax).
-- Player attributes for the HUD: Streak (number), StreakEnds (os.time()).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseService = require(script.Parent.BaseService)
local CritterService = require(script.Parent.CritterService)
local FxService = require(script.Parent.FxService)

local StreakService = {}
StreakService.Priority = 46

local last: { [Player]: number } = {}

local function bonusFor(player: Player, streak: number): number
	local s = math.min(streak, Config.StreakMax)
	return math.floor(math.max(15, BaseService.baseIncome(player) * 4) * (s - 1) * 0.5)
end

function StreakService.Start()
	CritterService.Caught:Connect(function(player: Player)
		local now = os.clock()
		local streak = player:GetAttribute("Streak") or 0
		if last[player] and now - last[player] <= Config.StreakWindow then
			streak += 1
		else
			streak = 1
		end
		last[player] = now
		player:SetAttribute("Streak", streak)
		player:SetAttribute("StreakEnds", os.time() + Config.StreakWindow)
		if streak >= 2 then
			local bonus = bonusFor(player, streak)
			BaseService.addCoins(player, bonus)
			FxService.toPlayer(player, "Streak", { streak = streak, bonus = bonus })
		end
	end)
	-- expire streaks
	task.spawn(function()
		while true do
			task.wait(1)
			for player, t in pairs(last) do
				if os.clock() - t > Config.StreakWindow then
					last[player] = nil
					if player.Parent then
						player:SetAttribute("Streak", 0)
					end
				end
			end
		end
	end)
end

function StreakService.PlayerRemoving(player: Player)
	last[player] = nil
end

return StreakService
