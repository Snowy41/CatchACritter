-- Social moments without chat:
--  * big catches/hatches are announced to the whole server (Legendary+)
--  * Secret+ catches go to a global ticker in every server (MessagingService)
--  * members of the game's group (Config.GroupId) get the cosmetic "Pack Member" title

local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CritterDefs = require(ReplicatedStorage.Shared.CritterDefs)
local CritterService = require(script.Parent.CritterService)
local DexService = require(script.Parent.DexService)
local EggService = require(script.Parent.EggService)
local FxService = require(script.Parent.FxService)

local SocialService = {}
SocialService.Priority = 75

local TOPIC = "GlobalCatch"
local serverId = game.JobId ~= "" and game.JobId or "studio"

local function describe(entry: Config.CritterEntry): string
	local label = Config.mutationLabel(entry)
	return ("%s%s %s"):format(label ~= "" and (string.upper(label) .. " ") or "", string.upper(entry.rarity), CritterDefs[entry.species].displayName)
end

local function celebrate(player: Player, entry: Config.CritterEntry, verb: string)
	local tier = Config.tier(entry.rarity)
	if tier >= Config.ServerAnnounceMinTier then
		FxService.announce(("%s %s a %s!"):format(player.DisplayName, verb, describe(entry)), entry.rarity)
	end
	if tier >= Config.GlobalFeedMinTier then
		task.spawn(pcall, function()
			MessagingService:PublishAsync(TOPIC, { name = player.DisplayName, text = describe(entry), rarity = entry.rarity, server = serverId })
		end)
	end
end

function SocialService.Start()
	CritterService.Caught:Connect(function(player, entry)
		celebrate(player, entry, "caught")
	end)
	EggService.Hatched:Connect(function(player, entry)
		celebrate(player, entry, "hatched")
	end)
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local d = message.Data
				if typeof(d) == "table" and d.server ~= serverId then
					FxService.toAll("Ticker", { text = ("%s caught a %s in another server!"):format(tostring(d.name), tostring(d.text)), rarity = d.rarity })
				end
			end)
		end)
		if not ok then
			warn("[SocialService] global feed unavailable:", err)
		end
	end)
end

function SocialService.PlayerAdded(player: Player)
	local groupId = Config.GroupId
	if groupId then
		task.spawn(function()
			local ok, member = pcall(player.IsInGroup, player, groupId)
			if ok and member then
				DexService.grantTitle(player, "PackMember")
			end
		end)
	end
end

return SocialService
