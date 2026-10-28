--!strict
-- Game-wide tuning values. All numbers are first drafts for balancing (see GDD "Critters").
-- Zone-specific values (spawn weights, nests, guardians) live in Zones.luau.

local Config = {}

export type Rarity = {
	name: string,
	tier: number, -- 1 = Common ... 8 = Forgotten
	color: Color3,
	incomeMult: number,
	carrySpeed: number, -- walk speed multiplier while carrying
	fleeRadius: number, -- 0 = never flees
	fleeSpeed: number,
	catchZone: number, -- width of the sweet spot on the timing bar (0..1)
	cursorSpeed: number, -- timing bar sweeps per second
}

Config.Rarities = {
	{ name = "Common", color = Color3.fromRGB(210, 214, 220), incomeMult = 1, carrySpeed = 1.0, fleeRadius = 0, fleeSpeed = 0, catchZone = 0.36, cursorSpeed = 0.8 },
	{ name = "Uncommon", color = Color3.fromRGB(110, 220, 90), incomeMult = 2.5, carrySpeed = 0.95, fleeRadius = 12, fleeSpeed = 11, catchZone = 0.28, cursorSpeed = 1.0 },
	{ name = "Rare", color = Color3.fromRGB(80, 170, 255), incomeMult = 6, carrySpeed = 0.9, fleeRadius = 20, fleeSpeed = 15, catchZone = 0.2, cursorSpeed = 1.25 },
	{ name = "Epic", color = Color3.fromRGB(190, 90, 255), incomeMult = 15, carrySpeed = 0.82, fleeRadius = 26, fleeSpeed = 18, catchZone = 0.15, cursorSpeed = 1.5 },
	{ name = "Legendary", color = Color3.fromRGB(255, 190, 40), incomeMult = 40, carrySpeed = 0.72, fleeRadius = 34, fleeSpeed = 22, catchZone = 0.11, cursorSpeed = 1.8 },
	{ name = "Mythic", color = Color3.fromRGB(255, 80, 120), incomeMult = 100, carrySpeed = 0.65, fleeRadius = 40, fleeSpeed = 24, catchZone = 0.09, cursorSpeed = 2.0 },
	{ name = "Secret", color = Color3.fromRGB(40, 40, 50), incomeMult = 250, carrySpeed = 0.55, fleeRadius = 44, fleeSpeed = 26, catchZone = 0.08, cursorSpeed = 2.2 },
	{ name = "Forgotten", color = Color3.fromRGB(120, 255, 230), incomeMult = 600, carrySpeed = 0.5, fleeRadius = 48, fleeSpeed = 28, catchZone = 0.07, cursorSpeed = 2.4 },
} :: { Rarity }

Config.RarityByName = {} :: { [string]: Rarity }
for i, r in ipairs(Config.Rarities) do
	r.tier = i
	Config.RarityByName[r.name] = r
end

function Config.tier(rarityName: string?): number
	local r = rarityName and Config.RarityByName[rarityName]
	return r and r.tier or 1
end

export type Mutation = {
	name: string,
	chance: number, -- spawn chance of a natural mutation (first roll)
	incomeMult: number,
	scale: number?,
	weather: string?, -- weather that grants it to base critters (weather mutations)
	spawnChance: number?, -- weather mutations: chance a wild critter already spawns with it
	zoneBoost: { [string]: number }?, -- spawnChance multiplier per zone
}

-- Natural mutations and weather mutations. A critter can carry several: one natural mutation
-- from the main roll, sometimes a second natural one (Config.ExtraMutationFactor), and one
-- weather mutation - gained in a base during weather or (rarely) already at spawn.
-- Always read them through Config.mutationsOf(entry).
Config.Mutations = {
	{ name = "Shiny", chance = 0.04, incomeMult = 2 },
	{ name = "Giant", chance = 0.02, incomeMult = 3, scale = 1.6 },
	{ name = "Tiny", chance = 0.02, incomeMult = 3, scale = 0.6 },
	{ name = "Golden", chance = 0.005, incomeMult = 10 },
	{ name = "Frozen", chance = 0, incomeMult = 8, weather = "Snowstorm", spawnChance = 0.003 },
	{ name = "Rainbow", chance = 0, incomeMult = 20, weather = "RainbowStorm", spawnChance = 0.0015 },
	{ name = "Lava", chance = 0, incomeMult = 12, weather = "SolarFlare", spawnChance = 0.002, zoneBoost = { Volcano = 5 } },
	{ name = "Ghost", chance = 0, incomeMult = 15, weather = "BloodMoon", spawnChance = 0.0015, zoneBoost = { Swamp = 3 } },
} :: { Mutation }
Config.ExtraMutationFactor = 0.15 -- chance factor for a second natural mutation on top of the first

Config.MutationByName = {} :: { [string]: Mutation }
for _, m in ipairs(Config.Mutations) do
	Config.MutationByName[m.name] = m
end

-- Wild critters
Config.WanderSpeed = 4
Config.RespawnDelay = 3

-- Events
Config.CritterOfTheHourBoost = 3 -- spawn weight multiplier for the featured species
Config.LuckySpawnInterval = { 240, 420 } -- seconds between lucky spawns (min, max)
Config.LuckySpawnWeights = { Rare = 85, Epic = 15 } :: { [string]: number }
Config.LuckySpawnLifetime = 150 -- seconds before an uncaught lucky critter leaves
Config.OnboardingRareDelay = 10 -- seconds after a newcomer's first deposit until their scripted Rare spawns
Config.UpdateWeekday = 6 -- weekly update day (os.date wday: 1 = Sunday ... 6 = Friday)
Config.UpdateHourUTC = 17 -- 18:00 CET

-- Catching
Config.CatchRange = 11
Config.CatchTimeout = 8 -- seconds a critter stays frozen while the timing bar is open
Config.GuaranteedCatches = 3 -- the first N catches of a new player always succeed

-- Movement / upgrades
Config.BaseWalkSpeed = 16
Config.WalkSpeedPerLevel = 4
Config.SpeedCosts = { 25, 250, 1000, 4000, 12000 } -- cost of level 1, 2, ... (level 1 is cheap: first upgrade within ~30 s)

-- Base
Config.StartSlots = 6
Config.IncomeTick = 1 -- seconds

-- Catch feel
Config.NearMissMargin = 0.07 -- a miss this close to the sweet spot counts as "SO CLOSE!"
Config.NearMissPause = 1.4 -- seconds the critter stumbles after a near miss (time for a retry)

-- Welcome back: capped offline earnings, a reward for returning (never a loss for being away)
Config.OfflineRate = 0.5 -- share of normal income produced while away
Config.OfflineCapSeconds = 3 * 3600
Config.OfflineMinSeconds = 120

-- Rebirth: reset coins + upgrades (critters, Critterdex and eggs stay) for permanent bonuses
Config.Rebirths = {
	{ cost = 25000, speed = 3 },
	{ cost = 150000, speed = 4 },
	{ cost = 750000, speed = 5 },
} :: { { cost: number, speed: number } }
Config.RebirthIncomeBonus = 0.5 -- +50 % income per rebirth
Config.RebirthCatchBonus = 0.12 -- +12 % sweet-spot width per rebirth ("better net")

-- Eggs: base critters lay eggs while their owner is online; the hatch timer runs in real time
Config.EggLayInterval = { 300, 540 } -- seconds online between eggs
Config.EggCapacity = 3 -- nest spots per base; no eggs are laid while the nest is full
Config.EggUpgradeChance = 0.2 -- chance an egg is one rarity above its parent
Config.EggInheritChance = 0.25 -- chance the parent's natural mutation is passed on
Config.EggHatchSeconds = {
	Common = 180, Uncommon = 600, Rare = 1800, Epic = 3600,
	Legendary = 7200, Mythic = 14400, Secret = 28800, Forgotten = 43200,
} :: { [string]: number }

-- Selling a base critter (frees the slot): coins = income per second * this
Config.SellSeconds = 90

-- Catch streak: catches less than StreakWindow seconds apart build a streak with bonus coins
Config.StreakWindow = 30
Config.StreakMax = 10 -- bonus stops growing here

-- Social
Config.ServerAnnounceMinTier = 5 -- Legendary+: "RKG caught a LEGENDARY ...!" for the server
Config.GlobalFeedMinTier = 7 -- Secret+: ticker message in every server
Config.GroupId = nil :: number? -- Roblox group; members get the "Pack Member" title (cosmetic only)
Config.SummonCooldown = 900 -- seconds between summoning rituals per server
Config.SummonCharge = 5 -- seconds every pad has to stay occupied

-- Saving
Config.DataStoreName = "PlayerData_v1"
Config.AutosaveInterval = 120

export type CritterEntry = {
	species: string,
	rarity: string,
	mutation: string?, -- main natural mutation
	extra: { string }?, -- further natural mutations (rare double mutations)
	weather: string?, -- weather mutation (Frozen, Rainbow, Lava, Ghost)
	sizeKg: number,
}

-- All mutations of a critter in display order (natural first, weather last), without duplicates.
function Config.mutationsOf(entry: CritterEntry): { string }
	local list, seen = {}, {}
	local function add(m: string?)
		if m and not seen[m] and Config.MutationByName[m] then
			seen[m] = true
			table.insert(list, m)
		end
	end
	add(entry.mutation)
	for _, m in ipairs(entry.extra or {}) do
		add(m)
	end
	add(entry.weather)
	return list
end

-- "Shiny Giant" style label ("" when there are none).
function Config.mutationLabel(entry: CritterEntry): string
	return table.concat(Config.mutationsOf(entry), " ")
end

-- Coins per second produced by one critter in a base.
function Config.income(entry: CritterEntry, baseIncome: number, baseKg: number): number
	local rarity = Config.RarityByName[entry.rarity]
	local mult = 1
	for _, name in ipairs(Config.mutationsOf(entry)) do
		mult *= Config.MutationByName[name].incomeMult
	end
	local sizeNorm = math.clamp((entry.sizeKg / baseKg - 0.7) / 0.7, 0, 1)
	local sizeFactor = 0.9 + 0.2 * sizeNorm -- size changes income only slightly (+-10 %)
	return baseIncome * (rarity and rarity.incomeMult or 1) * mult * sizeFactor
end

function Config.walkSpeed(speedLevel: number): number
	return Config.BaseWalkSpeed + Config.WalkSpeedPerLevel * speedLevel
end

return Config
