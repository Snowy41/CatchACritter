-- Tells clients about moments worth an effect (catch bursts, deposits, coins, guardian events,
-- announcements). Effects themselves are drawn on the client (src/client/Effects.client.luau).
-- Remotes live in ReplicatedStorage.RuntimeRemotes (created at runtime, not synced by Rojo).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FxService = {}

local folder = ReplicatedStorage:FindFirstChild("RuntimeRemotes") or Instance.new("Folder")
folder.Name = "RuntimeRemotes"
folder.Parent = ReplicatedStorage

function FxService.remote(name: string): RemoteEvent
	local r = folder:FindFirstChild(name) :: RemoteEvent?
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	return r :: RemoteEvent
end

local fx = FxService.remote("Fx")

-- Effect for one player only (e.g. coins flying into their HUD).
function FxService.toPlayer(player: Player, kind: string, data: { [string]: any })
	fx:FireClient(player, kind, data)
end

-- Effect everyone nearby should see (e.g. a catch burst).
function FxService.toAll(kind: string, data: { [string]: any })
	fx:FireAllClients(kind, data)
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
