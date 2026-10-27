-- Rebirth (GDD "Rebirth"): reset coins and upgrades for a permanent income multiplier, a better
-- net (wider sweet spot) and access to deeper zones (gates with RequiredRebirth). Critters,
-- Critterdex and eggs are kept. Levels and costs in Config.Rebirths.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local DexService = require(script.Parent.DexService)
local FxService = require(script.Parent.FxService)

local RebirthService = {}
RebirthService.Priority = 42

local function rebirth(player: Player)
	local data = DataService.get(player)
	if not data then
		return { ok = false }
	end
	local nextLevel = data.rebirths + 1
	local req = Config.Rebirths[nextLevel]
	if not req then
		return { ok = false, message = "Max rebirth reached!" }
	end
	if data.speedLevel < req.speed then
		return { ok = false, message = ("Reach Speed %d first"):format(req.speed) }
	end
	if data.coins < req.cost then
		return { ok = false, message = ("You need %d coins"):format(req.cost) }
	end
	BaseService.dropCarry(player)
	data.coins = 0
	data.pendingCoins = 0
	data.speedLevel = 0
	data.rebirths = nextLevel
	player:SetAttribute("Coins", 0)
	player:SetAttribute("SpeedLevel", 0)
	player:SetAttribute("Rebirth", nextLevel)
	BaseService.applyWalkSpeed(player)
	BaseService.renderBase(player) -- income labels include the new multiplier
	DexService.grantTitle(player, "Reborn" .. nextLevel, true, true) -- the rebirth banner is the notification
	FxService.toAll("Rebirth", { userId = player.UserId, level = nextLevel })
	FxService.announce(("%s reached REBIRTH %d!"):format(player.DisplayName, nextLevel), "Epic")
	return { ok = true, level = nextLevel }
end

function RebirthService.Start()
	Net.func("Rebirth").OnServerInvoke = rebirth
end

function RebirthService.PlayerAdded(player: Player, data: DataService.Data)
	player:SetAttribute("Rebirth", data.rebirths)
end

return RebirthService
