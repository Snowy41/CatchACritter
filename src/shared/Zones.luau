--!strict
-- Data-driven zone definitions. Everything zone-specific lives here, so a new zone is a new entry:
-- unlock requirement, wild spawn count + rarity weights, guarded nest, guardian, lucky spawns.
-- Species per zone come from CritterDefs (species list their zones). Map geometry carries the
-- matching CollectionService tags with a "Zone" attribute (CritterSpawnArea, NestSpot, GuardianSpot).

export type GuardianDef = {
	template: string, -- model in ServerStorage.GuardianTemplates
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

export type NestDef = {
	critters: number,
	respawn: number, -- seconds until a caught nest critter is replaced
	rarityWeights: { [string]: number },
}

export type ZoneDef = {
	name: string,
	displayName: string,
	requiredSpeed: number,
	requiredRebirth: number,
	wildCount: number,
	rarityWeights: { [string]: number },
	luckySpawns: boolean,
	nest: NestDef?,
	guardian: GuardianDef?,
}

local Zones = {}

Zones.Order = { "Meadow", "Swamp", "Volcano" }

Zones.Defs = {
	Meadow = {
		name = "Meadow",
		displayName = "Meadow",
		requiredSpeed = 0,
		requiredRebirth = 0,
		wildCount = 16,
		rarityWeights = { Common = 70, Uncommon = 30 },
		luckySpawns = true,
		nest = { critters = 2, respawn = 25, rarityWeights = { Uncommon = 55, Rare = 40, Epic = 5 } },
		guardian = {
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
	},
	Swamp = {
		name = "Swamp",
		displayName = "Swamp",
		requiredSpeed = 1,
		requiredRebirth = 0,
		wildCount = 14, -- spawns once Swamp species exist in CritterDefs
		rarityWeights = { Uncommon = 60, Rare = 40 },
		luckySpawns = false,
		nest = nil,
		guardian = nil,
	},
	Volcano = {
		name = "Volcano",
		displayName = "Volcano",
		requiredSpeed = 2,
		requiredRebirth = 0,
		wildCount = 12,
		rarityWeights = { Rare = 75, Epic = 25 },
		luckySpawns = false,
		nest = nil,
		guardian = nil,
	},
} :: { [string]: ZoneDef }

function Zones.get(name: string): ZoneDef?
	return Zones.Defs[name]
end

-- Iterate zones in path order.
function Zones.each(): () -> (number, ZoneDef)
	local i = 0
	return function()
		i += 1
		local name = Zones.Order[i]
		return (name and i) :: any, (name and Zones.Defs[name]) :: any
	end
end

return Zones
