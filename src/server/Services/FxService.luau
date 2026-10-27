-- Tells clients about moments worth an effect (catch bursts, deposits, coins, guardian events,
-- announcements). Effects themselves are drawn on the client (Controllers/Effects).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local FxService = {}
FxService.Priority = 1

local fx: RemoteEvent
local notify: RemoteEvent

function FxService.Init()
	fx = Net.event("Fx")
	notify = Net.event("Notify")
end

-- Effect for one player only (e.g. coins flying into their HUD).
function FxService.toPlayer(player: Player, kind: string, data: { [string]: any })
	fx:FireClient(player, kind, data)
end

-- Effect everyone should see (e.g. a catch burst).
function FxService.toAll(kind: string, data: { [string]: any })
	fx:FireAllClients(kind, data)
end

-- Toast message on one player's HUD. kind: "info" | "success" | "warn" | "coins"
function FxService.notify(player: Player, text: string, kind: string?)
	notify:FireClient(player, text, kind or "info")
end

-- Server-wide banner, e.g. "A RARE Clover Bun appeared in the Meadow!"
function FxService.announce(text: string, rarity: string?, icon: string?)
	fx:FireAllClients("Announce", { text = text, rarity = rarity, icon = icon })
end

function FxService.announceTo(player: Player, text: string, rarity: string?, icon: string?)
	if player.Parent == Players then
		fx:FireClient(player, "Announce", { text = text, rarity = rarity, icon = icon })
	end
end

return FxService
