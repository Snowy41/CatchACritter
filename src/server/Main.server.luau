-- Server entry point: wires the services together and handles player join/leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services.DataService)
local PlotService = require(Services.PlotService)
local BaseService = require(Services.BaseService)
local CritterService = require(Services.CritterService)
local ShopService = require(Services.ShopService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

DataService.init()
PlotService.init()
BaseService.init()
ShopService.init()

CritterService.canCatch = function(player)
	return not BaseService.isCarrying(player)
end
CritterService.onCaught = BaseService.startCarry
CritterService.totalCatches = function(player)
	local data = DataService.get(player)
	return data and data.totalCatches or 0
end
CritterService.init()

local requestCatch = Remotes:WaitForChild("RequestCatch") :: RemoteFunction
local submitCatch = Remotes:WaitForChild("SubmitCatch") :: RemoteFunction
local buyUpgrade = Remotes:WaitForChild("BuyUpgrade") :: RemoteFunction
requestCatch.OnServerInvoke = CritterService.requestCatch
submitCatch.OnServerInvoke = CritterService.submitCatch
buyUpgrade.OnServerInvoke = ShopService.buy

local function onCharacter(player: Player, character: Model)
	BaseService.dropCarry(player) -- a new character never carries the old critter
	PlotService.spawnCharacter(player, character)
	local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if hum then
		BaseService.applyWalkSpeed(player)
	end
end

local function onPlayerAdded(player: Player)
	DataService.load(player)
	if not player.Parent then
		return -- left while loading
	end
	PlotService.assign(player)
	BaseService.onPlayerReady(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	CritterService.releasePlayer(player)
	BaseService.onPlayerLeaving(player)
	PlotService.release(player)
	DataService.release(player)
end)
