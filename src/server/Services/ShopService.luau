-- Upgrades bought with coins. For now: Speed (opens the zone gates: Speed 1 = Swamp, Speed 2 = Volcano).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)

local ShopService = {}

function ShopService.buy(player: Player, upgrade: any)
	local data = DataService.get(player)
	if not data or upgrade ~= "Speed" then
		return { ok = false }
	end
	local nextLevel = data.speedLevel + 1
	local cost = Config.SpeedCosts[nextLevel]
	if not cost then
		return { ok = false, message = "Max speed reached!" }
	end
	if data.coins < cost then
		return { ok = false, message = ("You need %d coins"):format(cost) }
	end
	data.coins -= cost
	data.speedLevel = nextLevel
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("SpeedLevel", data.speedLevel)
	BaseService.applyWalkSpeed(player)
	BaseService.notify(player, ("Speed %d unlocked!"):format(nextLevel), "success")
	return { ok = true, level = nextLevel }
end

function ShopService.init()
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
					BaseService.notify(player, result.message, "warn")
				end
			end)
		end
	end
end

return ShopService
