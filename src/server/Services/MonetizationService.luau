-- Robux products (shared/Products): gamepass ownership + perks and coin-pack receipts.
-- Perks are exposed as player attributes the other services read:
--   IncomeBoost (number, multiplies income), CatchBonus (number, multiplies the sweet spot),
--   AutoCollect (bool), Pass_<Key> (bool, for the store UI).
-- Receipts are idempotent (data.purchases[PurchaseId]) and only granted once the data is loaded.
-- Studio test hook: Workspace attribute DevOwnAllPasses = true -> everyone owns every pass.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Products = require(ReplicatedStorage.Shared.Products)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local DexService = require(script.Parent.DexService)
local FxService = require(script.Parent.FxService)

local MonetizationService = {}
MonetizationService.Priority = 26

local owned: { [Player]: { [string]: boolean } } = {}

local function devOwnsAll(): boolean
	return RunService:IsStudio() and workspace:GetAttribute("DevOwnAllPasses") == true
end

local function applyPerks(player: Player)
	local own = owned[player] or {}
	local income, catch, auto = 1, 1, false
	for _, pass in ipairs(Products.Passes) do
		local has = own[pass.key] == true or devOwnsAll()
		player:SetAttribute("Pass_" .. pass.key, has)
		if has then
			income *= pass.incomeMult or 1
			catch *= pass.catchBonus or 1
			auto = auto or pass.autoCollect == true
			if pass.title then
				DexService.grantTitle(player, pass.title, false, true)
			end
		end
	end
	player:SetAttribute("IncomeBoost", income)
	player:SetAttribute("CatchBonus", catch)
	player:SetAttribute("AutoCollect", auto)
	BaseService.renderBase(player) -- income labels include the boost
end

local function refreshOwnership(player: Player)
	local own = owned[player] or {}
	owned[player] = own
	for _, pass in ipairs(Products.Passes) do
		if pass.id ~= 0 and not own[pass.key] then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			own[pass.key] = ok and has == true
		end
	end
	applyPerks(player)
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local data = player and DataService.get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- retried on the next join
	end
	if data.purchases[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local pack = Products.PackById[info.ProductId]
	if not pack then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local coins = Products.packCoins(pack, BaseService.baseIncome(player))
	BaseService.addCoins(player, coins)
	data.purchases[info.PurchaseId] = true
	DataService.save(player)
	FxService.toPlayer(player, "Reward", { amount = coins })
	FxService.notify(player, ("Thank you! +%d coins"):format(coins), "coins")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, pass in ipairs(Products.Passes) do
			if pass.id == passId then
				owned[player] = owned[player] or {}
				owned[player][pass.key] = true
				applyPerks(player)
				FxService.announceTo(player, ("%s unlocked - thank you!"):format(pass.name), "Legendary")
			end
		end
	end)
	workspace:GetAttributeChangedSignal("DevOwnAllPasses"):Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do
			applyPerks(player)
		end
	end)
end

function MonetizationService.PlayerAdded(player: Player)
	task.spawn(refreshOwnership, player)
end

function MonetizationService.PlayerRemoving(player: Player)
	owned[player] = nil
end

return MonetizationService
