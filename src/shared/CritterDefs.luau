--!strict
-- Critter species. `template` is the model name in ServerStorage.CritterTemplates.

export type Species = {
	displayName: string,
	template: string,
	zones: { string },
	baseIncome: number, -- coins per second at Common, no mutation, average size
	baseKg: number, -- average weight shown on the nameplate
	-- limited event critter (GDD "Limited critters"): only spawns between these unix times
	limited: { from: number, to: number }?,
	-- rarity range this species can spawn with (default Common .. Legendary). Special species
	-- (e.g. Mythic-only) set minRarity high; the spawner picks the rarity first, then a species.
	minRarity: string?,
	maxRarity: string?,
	fx: string?, -- client ambient effect preset (Controllers/CritterLife SPECIES_FX)
}

local CritterDefs: { [string]: Species } = {
	CloverBun = {
		displayName = "Clover Bun",
		template = "CloverBun",
		zones = { "Meadow" },
		baseIncome = 1,
		baseKg = 1.8,
	},
	Buzzpup = {
		displayName = "Buzzpup",
		template = "Buzzpup",
		zones = { "Meadow" },
		baseIncome = 1.4,
		baseKg = 1.2,
	},
	-- Swamp (unlocked with Speed 1)
	Croaklet = { -- sleepy axolotl-frog: heavy lids, pink gill frills, lily pad crown
		displayName = "Croaklet",
		template = "Croaklet",
		zones = { "Swamp" },
		baseIncome = 2.2,
		baseKg = 2.4,
	},
	Snapjaw = { -- sly baby croc: slit eyes, raised brow, toothy grin, back scutes
		displayName = "Snapjaw",
		template = "Snapjaw",
		zones = { "Swamp" },
		baseIncome = 2.8,
		baseKg = 4.5,
	},
}

local TIERS = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7, Forgotten = 8 }

-- can this species spawn with this rarity?
local function allowsRarity(id: string, rarity: string): boolean
	local def = CritterDefs[id]
	local t = TIERS[rarity] or 1
	return def ~= nil and t >= (TIERS[def.minRarity or "Common"] or 1) and t <= (TIERS[def.maxRarity or "Legendary"] or 5)
end

-- special species only exist at Mythic or higher (they get their own Critterdex page)
local function isSpecial(id: string): boolean
	local def = CritterDefs[id]
	return def ~= nil and (TIERS[def.minRarity or "Common"] or 1) >= 6
end

-- false for limited critters outside their event window
local function isAvailable(id: string, now: number?): boolean
	local def = CritterDefs[id]
	local l = def and def.limited
	if not l then
		return def ~= nil
	end
	local t = now or os.time()
	return t >= l.from and t < l.to
end

return setmetatable(CritterDefs, { __index = { isAvailable = isAvailable, allowsRarity = allowsRarity, isSpecial = isSpecial } }) :: any
