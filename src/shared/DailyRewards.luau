--!strict
-- 7-day reward calendar. One claim per UTC day; missing a day costs nothing - the next claim
-- simply continues with the next day. After day 7 the calendar starts over.
-- Coins scale with income (never less than `min`); eggs go into the base nest.

export type Reward = {
	coinsSeconds: number?, -- coins = income per second * this ...
	coinsMin: number?, -- ... at least this many
	egg: string?, -- rarity of a bonus egg
	label: string, -- short text on the card
	icon: string, -- Icons key
}

local DailyRewards = {}

DailyRewards.Days = {
	{ coinsSeconds = 300, coinsMin = 200, label = "COINS", icon = "Coin" },
	{ coinsSeconds = 450, coinsMin = 350, label = "COINS", icon = "Coin" },
	{ egg = "Uncommon", label = "UNCOMMON EGG", icon = "Egg" },
	{ coinsSeconds = 900, coinsMin = 700, label = "COINS", icon = "Cash" },
	{ egg = "Rare", label = "RARE EGG", icon = "Egg" },
	{ coinsSeconds = 1800, coinsMin = 1500, label = "BIG COINS", icon = "Cash" },
	{ egg = "Epic", coinsSeconds = 3600, coinsMin = 4000, label = "EPIC EGG + COINS", icon = "Gift" },
} :: { Reward }

function DailyRewards.coins(r: Reward, incomePerSecond: number): number
	if not r.coinsSeconds then
		return 0
	end
	return math.floor(math.max(r.coinsMin or 0, incomePerSecond * r.coinsSeconds))
end

return DailyRewards
