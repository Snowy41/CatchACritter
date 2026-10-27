--!strict
-- Game-wide tuning values. All numbers are first drafts for balancing (see GDD "Critters").

local Config = {}

export type Rarity = {
	name: string,
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
for _, r in ipairs(Config.Rarities) do
	Config.RarityByName[r.name] = r
end

-- Spawn weights per zone (only rarities listed here can spawn naturally in that zone).
Config.ZoneRarityWeights = {
	Meadow = { Common = 70, Uncommon = 30 },
	Swamp = { Uncommon = 60, Rare = 40 },
	Volcano = { Rare = 75, Epic = 25 },
} :: { [string]: { [string]: number } }

export type Mutation = { name: string, chance: number, incomeMult: number, scale: number? }

-- Natural mutations (at most one per critter). Weather mutations come later.
Config.Mutations = {
	{ name = "Shiny", chance = 0.04, incomeMult = 2 },
	{ name = "Giant", chance = 0.02, incomeMult = 3, scale = 1.6 },
	{ name = "Tiny", chance = 0.02, incomeMult = 3, scale = 0.6 },
	{ name = "Golden", chance = 0.005, incomeMult = 10 },
} :: { Mutation }

Config.MutationByName = {} :: { [string]: Mutation }
for _, m in ipairs(Config.Mutations) do
	Config.MutationByName[m.name] = m
end

-- Wild critters
Config.WildPerZone = { Meadow = 16, Swamp = 0, Volcano = 0 } :: { [string]: number }
Config.WanderSpeed = 4
Config.RespawnDelay = 3

-- Guarded nests: rarer critters sit in the nest next to the sleeping zone guardian.
Config.NestRarityWeights = {
	Meadow = { Uncommon = 55, Rare = 40, Epic = 5 },
} :: { [string]: { [string]: number } }
Config.NestCritters = 2 -- critters sitting in each nest
Config.NestRespawn = 25 -- seconds until a caught nest critter is replaced

export type GuardianDef = {
	template: string,
	displayName: string,
	wakeRadius: number, -- players inside this radius around the nest fill the meter
	wakeIdle: number, -- meter per second for a player standing/walking slowly nearby
	wakeRunning: number, -- extra meter per second while running nearby
	wakeOnCatch: number, -- instant meter when someone snatches a nest critter
	wakeDecay: number, -- meter lost per second with nobody nearby
	chaseSpeed: number,
	returnSpeed: number,
	chaseTime: number, -- gives up after this many seconds
	chaseLeash: number, -- gives up when this far from its spot
	bumpRange: number,
	knockback: number,
	protectNewcomers: boolean, -- stays asleep for players in their first session (GDD onboarding)
}

Config.Guardians = {
	Meadow = {
		template = "Bramblebear",
		displayName = "Bramblebear",
		wakeRadius = 30,
		wakeIdle = 5,
		wakeRunning = 13,
		wakeOnCatch = 45,
		wakeDecay = 10,
		chaseSpeed = 13,
		returnSpeed = 9,
		chaseTime = 22,
		chaseLeash = 190,
		bumpRange = 7,
		knockback = 26,
		protectNewcomers = true,
	},
} :: { [string]: GuardianDef }

-- Catching
Config.CatchRange = 11
Config.CatchTimeout = 8 -- seconds a critter stays frozen while the timing bar is open
Config.GuaranteedCatches = 3 -- the first N catches of a new player always succeed

-- Movement / upgrades
Config.BaseWalkSpeed = 16
Config.WalkSpeedPerLevel = 4
Config.SpeedCosts = { 50, 250, 1000, 4000, 12000 } -- cost of level 1, 2, ...

-- Base
Config.StartSlots = 6
Config.IncomeTick = 1 -- seconds

-- Saving
Config.DataStoreName = "PlayerData_v1"
Config.AutosaveInterval = 120

export type CritterEntry = {
	species: string,
	rarity: string,
	mutation: string?,
	sizeKg: number,
}

-- Coins per second produced by one critter in a base.
function Config.income(entry: CritterEntry, baseIncome: number, baseKg: number): number
	local rarity = Config.RarityByName[entry.rarity]
	local mutation = entry.mutation and Config.MutationByName[entry.mutation]
	local sizeNorm = math.clamp((entry.sizeKg / baseKg - 0.7) / 0.7, 0, 1)
	local sizeFactor = 0.9 + 0.2 * sizeNorm -- size changes income only slightly (+-10 %)
	return baseIncome * (rarity and rarity.incomeMult or 1) * (mutation and mutation.incomeMult or 1) * sizeFactor
end

function Config.walkSpeed(speedLevel: number): number
	return Config.BaseWalkSpeed + Config.WalkSpeedPerLevel * speedLevel
end

return Config
