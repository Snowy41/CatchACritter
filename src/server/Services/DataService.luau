-- Player data: load on join (called by the loader before any PlayerAdded hook), autosave,
-- save on leave and on server shutdown. If DataStores are unavailable (e.g. Studio without API
-- access) the game still runs, but nothing is saved.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}
DataService.Priority = 0

export type Data = {
	version: number,
	coins: number,
	pendingCoins: number,
	speedLevel: number,
	totalCatches: number,
	sessions: number, -- number of times the player has joined (1 = first session)
	slotsUnlocked: number,
	base: { [string]: Config.CritterEntry }, -- slot index (as string) -> critter
	dex: { [string]: boolean }, -- "Species/Rarity/Mutation" -> seen
}

local CURRENT_VERSION = 1

local function defaultData(): Data
	return {
		version = CURRENT_VERSION,
		coins = 0,
		pendingCoins = 0,
		speedLevel = 0,
		totalCatches = 0,
		sessions = 0,
		slotsUnlocked = Config.StartSlots,
		base = {},
		dex = {},
	}
end

local function reconcile(data: any): Data
	for k, v in pairs(defaultData()) do
		if data[k] == nil then
			data[k] = v
		end
	end
	data.version = CURRENT_VERSION
	return data
end

local store: DataStore? = nil
local sessions: { [Player]: { data: Data, canSave: boolean } } = {}

local function key(player: Player): string
	return "player_" .. player.UserId
end

function DataService.load(player: Player): Data
	local data: Data? = nil
	local canSave = false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return (store :: DataStore):GetAsync(key(player))
			end)
			if ok then
				data = result and reconcile(result) or defaultData()
				canSave = true
				break
			end
			warn(("[DataService] load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
			task.wait(1.5 * attempt)
		end
	end
	-- never overwrite real data after a failed load: play on a temporary profile instead
	local d = data or defaultData()
	d.sessions += 1
	sessions[player] = { data = d, canSave = canSave and data ~= nil }
	return d
end

function DataService.get(player: Player): Data?
	local s = sessions[player]
	return s and s.data
end

function DataService.save(player: Player)
	local s = sessions[player]
	if not s or not s.canSave or not store then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player), function()
			return s.data
		end)
	end)
	if not ok then
		warn("[DataService] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.release(player: Player)
	DataService.save(player)
	sessions[player] = nil
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable, progress will not be saved:", result)
	end
end

function DataService.Start()
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in pairs(sessions) do
				task.spawn(DataService.save, player)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player in pairs(sessions) do
			pending += 1
			task.spawn(function()
				DataService.save(player)
				pending -= 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
			task.wait(0.2)
		end
	end)
end

return DataService
