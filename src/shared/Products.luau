--!strict
-- Robux products. Gamepasses give permanent perks; coin packs (developer products) give coins
-- scaled to the player's income (never less than `min`).
-- `id` = 0 until the product exists on the Roblox dashboard: the store shows it, but buying says
-- "Coming soon". `price` is only for display - the real price is set on the dashboard.
-- Fair-play rules (GDD): no random paid items, nothing that takes from other players.

export type Pass = {
	key: string,
	id: number,
	name: string,
	desc: string,
	icon: string, -- Icons key
	price: number,
	theme: string, -- UIKit.Themes key
	ribbon: string?,
	incomeMult: number?, -- multiplies all income
	catchBonus: number?, -- multiplies the sweet-spot width
	autoCollect: boolean?, -- income goes straight to the wallet
	title: string?, -- Titles id granted while owned
}

export type CoinPack = {
	key: string,
	id: number,
	name: string,
	seconds: number, -- coins = income per second * seconds ...
	min: number, -- ... but at least this many
	price: number,
	ribbon: string?,
}

local Products = {}

Products.Passes = {
	{ key = "DoubleCoins", id = 0, name = "2x Coins", desc = "Double ALL coin income forever!", icon = "Coin", price = 199, theme = "Gold", ribbon = "BEST VALUE", incomeMult = 2 },
	{ key = "Vip", id = 0, name = "VIP", desc = "+20% income, VIP title and nametag badge", icon = "Vip", price = 299, theme = "Purple", ribbon = "POPULAR", incomeMult = 1.2, title = "Vip" },
	{ key = "LuckyCharm", id = 0, name = "Lucky Charm", desc = "+30% bigger catch zone - catch rare critters easier", icon = "Lucky", price = 249, theme = "Green", catchBonus = 1.3 },
	{ key = "AutoCollect", id = 0, name = "Auto Collect", desc = "Coins fly straight into your wallet", icon = "Magnet", price = 149, theme = "Blue", autoCollect = true },
} :: { Pass }

Products.CoinPacks = {
	{ key = "CoinsS", id = 0, name = "Coin Pouch", seconds = 600, min = 500, price = 25 },
	{ key = "CoinsM", id = 0, name = "Coin Sack", seconds = 3600, min = 3000, price = 75, ribbon = "POPULAR" },
	{ key = "CoinsL", id = 0, name = "Coin Chest", seconds = 4 * 3600, min = 15000, price = 199, ribbon = "BEST VALUE" },
	{ key = "CoinsXL", id = 0, name = "Coin Vault", seconds = 12 * 3600, min = 50000, price = 449 },
} :: { CoinPack }

Products.PassByKey = {} :: { [string]: Pass }
for _, p in ipairs(Products.Passes) do
	Products.PassByKey[p.key] = p
end
Products.PackByKey = {} :: { [string]: CoinPack }
Products.PackById = {} :: { [number]: CoinPack }
for _, p in ipairs(Products.CoinPacks) do
	Products.PackByKey[p.key] = p
	if p.id ~= 0 then
		Products.PackById[p.id] = p
	end
end

function Products.packCoins(pack: CoinPack, incomePerSecond: number): number
	return math.floor(math.max(pack.min, incomePerSecond * pack.seconds))
end

return Products
