-- Critterdex (layout in shared/Dex) and titles (shared/Titles).
-- register(player, entry) is called for every catch, hatch and weather mutation. Completed pages
-- are claimed from the Critterdex panel for coins + a title. Titles show on nametags (player
-- attribute "Title" = title id).
-- State pushed to the client: "dex" = { found, claimed }, "titles" = { owned, equipped }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Dex = require(ReplicatedStorage.Shared.Dex)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Net = require(ReplicatedStorage.Shared.Net)
local Titles = require(ReplicatedStorage.Shared.Titles)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local FxService = require(script.Parent.FxService)
local StateService = require(script.Parent.StateService)

local DexService = {}
DexService.Priority = 22

local function push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	StateService.set(player, "dex", { found = data.critterdex, claimed = data.dexClaimed })
	StateService.set(player, "titles", { owned = data.titles, equipped = data.title })
	player:SetAttribute("DexFound", Dex.count(data.critterdex))
	player:SetAttribute("Title", data.title)
end

-- Returns isNew (any variant seen for the first time), found count, total entries.
function DexService.register(player: Player, entry: Config.CritterEntry): (boolean, number, number)
	local data = DataService.get(player)
	if not data then
		return false, 0, Dex.TotalEntries
	end
	local isNew = false
	local before: { [string]: boolean } = {}
	for _, p in ipairs(Dex.Pages) do
		before[p.id] = Dex.pageDone(p, data.critterdex)
	end
	for _, k in ipairs(Dex.keysFor(entry)) do
		if not data.critterdex[k] then
			data.critterdex[k] = true
			isNew = true
		end
	end
	if isNew then
		for _, p in ipairs(Dex.Pages) do
			if not before[p.id] and Dex.pageDone(p, data.critterdex) then
				task.delay(3, function()
					FxService.announceTo(player, ("Critterdex page complete: %s! Claim your reward"):format(p.title), nil, Icons.Book)
				end)
			end
		end
		push(player)
	end
	return isNew, Dex.count(data.critterdex), Dex.TotalEntries
end

function DexService.grantTitle(player: Player, id: string, equip: boolean?, silent: boolean?)
	local data = DataService.get(player)
	if not data or not Titles[id] or data.titles[id] then
		return
	end
	data.titles[id] = true
	if equip or not data.title then
		data.title = id
	end
	if not silent then
		FxService.notify(player, ("New title: %s"):format(Titles[id].text), "success")
	end
	push(player)
end

local function claimPage(player: Player, pageId: any)
	local data = DataService.get(player)
	local page = typeof(pageId) == "string" and Dex.PageById[pageId]
	if not data or not page or data.dexClaimed[page.id] or not Dex.pageDone(page, data.critterdex) then
		return { ok = false }
	end
	data.dexClaimed[page.id] = true
	BaseService.addCoins(player, page.rewardCoins)
	FxService.toPlayer(player, "Reward", { amount = page.rewardCoins, title = page.rewardTitle and Titles[page.rewardTitle].text })
	if page.rewardTitle then
		DexService.grantTitle(player, page.rewardTitle, true)
	end
	push(player)
	return { ok = true }
end

local function setTitle(player: Player, id: any)
	local data = DataService.get(player)
	if not data then
		return { ok = false }
	end
	if id == nil then
		data.title = nil
	elseif typeof(id) == "string" and data.titles[id] then
		data.title = id
	else
		return { ok = false }
	end
	push(player)
	return { ok = true }
end

-- Copies of the critter templates for the Critterdex viewports on the client.
local function replicatePreviews()
	local ServerStorage = game:GetService("ServerStorage")
	local templates = ServerStorage:FindFirstChild("CritterTemplates")
	if not templates or ReplicatedStorage:FindFirstChild("CritterPreviews") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "CritterPreviews"
	for _, m in ipairs(templates:GetChildren()) do
		if m:IsA("Model") then
			local c = m:Clone()
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("KeyframeSequence") then
					d:Destroy()
				end
			end
			c.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
end

function DexService.Start()
	replicatePreviews()
	Net.func("ClaimDexPage").OnServerInvoke = claimPage
	Net.func("SetTitle").OnServerInvoke = setTitle
end

function DexService.PlayerAdded(player: Player, data: DataService.Data)
	-- migrate the v1 dex ("Species/Rarity/Mutation") and count critters already in the base
	for key in pairs(data.dex) do
		local species, _, mutation = string.match(key, "^([^/]+)/([^/]+)/([^/]+)$")
		if species then
			data.critterdex[Dex.key(species)] = true
			if mutation ~= "None" then
				data.critterdex[Dex.key(species, mutation)] = true
			end
		end
	end
	for _, entry in pairs(data.base) do
		for _, k in ipairs(Dex.keysFor(entry)) do
			data.critterdex[k] = true
		end
	end
	push(player)
end

return DexService
