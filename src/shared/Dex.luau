--!strict
-- Critterdex layout (GDD "Critterdex"): one entry per species and variant (Normal + every
-- mutation). Pages group entries: one page per zone (the Normal variants of its species) and one
-- page per mutation (that mutation on every species). A completed page gives coins + a title.
-- Everything is derived from CritterDefs, Zones and Config, so new species/zones/mutations show
-- up automatically.

local Config = require(script.Parent.Config)
local CritterDefs = require(script.Parent.CritterDefs)
local Zones = require(script.Parent.Zones)

export type Page = {
	id: string,
	title: string,
	kind: string, -- "Zone" | "Mutation"
	keys: { string }, -- entry keys "Species:Variant"
	rewardCoins: number,
	rewardTitle: string?, -- Titles id
}

local Dex = {}

local ZONE_TITLES = { Meadow = "MeadowRanger", Swamp = "SwampStalker", Volcano = "VolcanoVeteran" }
local MUTATION_TITLES = {
	Shiny = "ShinyHunter", Giant = "GiantTamer", Tiny = "TinyFinder", Golden = "GoldDigger",
	Frozen = "FrostKeeper", Rainbow = "RainbowChaser",
}

function Dex.key(species: string, variant: string?): string
	return species .. ":" .. (variant or "Normal")
end

-- Every variant a caught/hatched/mutated critter counts for.
function Dex.keysFor(entry: Config.CritterEntry): { string }
	local keys = { Dex.key(entry.species, "Normal") }
	if entry.mutation then
		table.insert(keys, Dex.key(entry.species, entry.mutation))
	end
	if entry.weather then
		table.insert(keys, Dex.key(entry.species, entry.weather))
	end
	return keys
end

local function speciesIn(zone: string): { string }
	local list = {}
	for id, def in pairs(CritterDefs) do
		if table.find(def.zones, zone) then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		return CritterDefs[a].displayName < CritterDefs[b].displayName
	end)
	return list
end

local function allSpecies(): { string }
	local list = {}
	for _, zone in Zones.each() do
		for _, sp in ipairs(speciesIn(zone.name)) do
			if not table.find(list, sp) then
				table.insert(list, sp)
			end
		end
	end
	return list
end

Dex.Pages = {} :: { Page }
for i, zone in Zones.each() do
	local species = speciesIn(zone.name)
	if #species > 0 then
		local keys = {}
		for _, sp in ipairs(species) do
			table.insert(keys, Dex.key(sp))
		end
		table.insert(Dex.Pages, {
			id = "Zone_" .. zone.name, title = zone.displayName, kind = "Zone", keys = keys,
			rewardCoins = 250 * i * i, rewardTitle = ZONE_TITLES[zone.name],
		})
	end
end
for _, m in ipairs(Config.Mutations) do
	local keys = {}
	for _, sp in ipairs(allSpecies()) do
		table.insert(keys, Dex.key(sp, m.name))
	end
	table.insert(Dex.Pages, {
		id = "Mutation_" .. m.name, title = m.name, kind = "Mutation", keys = keys,
		rewardCoins = math.floor(150 * m.incomeMult), rewardTitle = MUTATION_TITLES[m.name],
	})
end

Dex.PageById = {} :: { [string]: Page }
Dex.TotalEntries = 0
for _, p in ipairs(Dex.Pages) do
	Dex.PageById[p.id] = p
	Dex.TotalEntries += #p.keys
end

function Dex.count(found: { [string]: boolean }): number
	local n = 0
	for _, p in ipairs(Dex.Pages) do
		for _, k in ipairs(p.keys) do
			if found[k] then
				n += 1
			end
		end
	end
	return n
end

function Dex.pageDone(page: Page, found: { [string]: boolean }): boolean
	for _, k in ipairs(page.keys) do
		if not found[k] then
			return false
		end
	end
	return true
end

return Dex
