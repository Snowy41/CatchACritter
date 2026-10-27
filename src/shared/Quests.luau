--!strict
-- Daily quests (GDD "Daily quests"): three short tasks per UTC day, picked per player from this
-- pool. Missing a day costs nothing. Completing all three gives a bonus egg.
-- A quest counts an event ("Catch", "Collect", "Deposit") when its filter matches.

export type QuestDef = {
	id: string,
	text: string, -- %d = goal
	event: string,
	goals: { number }, -- one is picked per day
	rewardSeconds: number, -- reward = max(minReward, income/s * rewardSeconds)
	minReward: number,
	minTier: number?, -- Catch: rarity tier at least
	duringWeather: boolean?, -- Catch: while a weather event runs
	featured: boolean?, -- Catch: the Critter of the Hour
	fromNest: boolean?, -- Catch: from a guarded nest
}

local Quests = {}

Quests.Pool = {
	{ id = "Catch", text = "Catch %d critters", event = "Catch", goals = { 6, 8, 10 }, rewardSeconds = 240, minReward = 60 },
	{ id = "CatchUncommon", text = "Catch %d Uncommon or better", event = "Catch", goals = { 3, 4 }, rewardSeconds = 300, minReward = 80, minTier = 2 },
	{ id = "CatchRare", text = "Catch a Rare or better", event = "Catch", goals = { 1 }, rewardSeconds = 420, minReward = 120, minTier = 3 },
	{ id = "CatchWeather", text = "Catch %d critters during weather", event = "Catch", goals = { 2, 3 }, rewardSeconds = 300, minReward = 80, duringWeather = true },
	{ id = "CatchFeatured", text = "Catch %d Critters of the Hour", event = "Catch", goals = { 2, 3 }, rewardSeconds = 300, minReward = 80, featured = true },
	{ id = "CatchNest", text = "Snatch a critter from a guarded nest", event = "Catch", goals = { 1 }, rewardSeconds = 420, minReward = 120, fromNest = true },
	{ id = "Collect", text = "Collect coins from your pad %d times", event = "Collect", goals = { 4, 6 }, rewardSeconds = 180, minReward = 50 },
} :: { QuestDef }

Quests.ById = {} :: { [string]: QuestDef }
for _, q in ipairs(Quests.Pool) do
	Quests.ById[q.id] = q
end

Quests.PerDay = 3
Quests.BonusEggRarities = { Uncommon = 60, Rare = 35, Epic = 5 } :: { [string]: number }

function Quests.day(t: number?): number
	return math.floor((t or os.time()) / 86400) -- UTC day number; resets at 00:00 UTC
end

return Quests
