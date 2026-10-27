-- Welcome back (GDD "Base"): the base keeps producing at a reduced rate while the player is away,
-- capped, and the coins wait in a welcome-back screen. A reward for returning; nothing is ever
-- lost for being away. State pushed to the client: "welcome" = { amount, seconds } or nil.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local FxService = require(script.Parent.FxService)
local StateService = require(script.Parent.StateService)

local WelcomeService = {}
WelcomeService.Priority = 25

local awaySeconds: { [Player]: number } = {}

local function push(player: Player, data: DataService.Data)
	local amount = math.floor(data.offlinePending)
	StateService.set(player, "welcome", amount > 0 and { amount = amount, seconds = awaySeconds[player] or 0 } or nil)
end

local function claim(player: Player)
	local data = DataService.get(player)
	if not data then
		return { ok = false }
	end
	local amount = math.floor(data.offlinePending)
	if amount <= 0 then
		return { ok = false }
	end
	data.offlinePending = 0
	BaseService.addCoins(player, amount)
	FxService.toPlayer(player, "Collect", { pos = Vector3.zero, amount = amount, screen = true })
	push(player, data)
	return { ok = true, amount = amount }
end

function WelcomeService.Start()
	Net.func("ClaimWelcome").OnServerInvoke = claim
end

function WelcomeService.PlayerAdded(player: Player, data: DataService.Data)
	local last = data.lastOnline
	if last and data.sessions > 1 then
		local away = os.time() - last
		if away >= Config.OfflineMinSeconds then
			local seconds = math.min(away, Config.OfflineCapSeconds)
			data.offlinePending += BaseService.baseIncome(player) * Config.OfflineRate * seconds
			awaySeconds[player] = away
		end
	end
	push(player, data)
end

function WelcomeService.PlayerRemoving(player: Player)
	awaySeconds[player] = nil
end

return WelcomeService
