-- Upgrades bought with coins. Each upgrade is a small definition (cost per level, how it applies),
-- so new upgrades (net, carry capacity, stealth, base slots) are added to UPGRADES only.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local FxService = require(script.Parent.FxService)

local ShopService = {}
ShopService.Priority = 40

type Upgrade = {
	costs: { number }, -- cost of level 1, 2, ...
	level: (data: DataService.Data) -> number,
	apply: (player: Player, data: DataService.Data, newLevel: number) -> (),
	message: (newLevel: number) -> string,
}

local UPGRADES: { [string]: Upgrade } = {
	Speed = {
		costs = Config.SpeedCosts,
		level = function(data)
			return data.speedLevel
		end,
		apply = function(player, data, newLevel)
			data.speedLevel = newLevel
			player:SetAttribute("SpeedLevel", newLevel)
			BaseService.applyWalkSpeed(player)
			FxService.toAll("SpeedUp", { userId = player.UserId, level = newLevel })
		end,
		message = function(newLevel)
			return ("Speed %d unlocked!"):format(newLevel)
		end,
	},
}

function ShopService.buy(player: Player, name: any)
	local data = DataService.get(player)
	local upgrade = typeof(name) == "string" and UPGRADES[name]
	if not data or not upgrade then
		return { ok = false }
	end
	local nextLevel = upgrade.level(data) + 1
	local cost = upgrade.costs[nextLevel]
	if not cost then
		return { ok = false, message = "Already maxed out!" }
	end
	if not BaseService.spendCoins(player, cost) then
		return { ok = false, message = ("You need %d coins"):format(cost) }
	end
	upgrade.apply(player, data, nextLevel)
	FxService.notify(player, upgrade.message(nextLevel), "success")
	return { ok = true, level = nextLevel }
end

function ShopService.Start()
	Net.func("BuyUpgrade").OnServerInvoke = ShopService.buy
	-- proximity prompt on the shop stall counter
	for _, stall in ipairs(CollectionService:GetTagged("ShopStall")) do
		local counter = stall:FindFirstChild("Counter")
		if counter and not counter:FindFirstChild("ShopPrompt") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "ShopPrompt"
			prompt.ActionText = "Buy Speed"
			prompt.ObjectText = "Shop"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = counter
			prompt.Triggered:Connect(function(player)
				local result = ShopService.buy(player, "Speed")
				if not result.ok and result.message then
					FxService.notify(player, result.message, "warn")
				end
			end)
		end
	end
end

return ShopService
