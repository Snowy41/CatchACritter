--!strict
-- Player roles shown on nametags. Assign by user id (Users) and/or by group rank (GroupId + Ranks).
-- The highest-priority matching role wins.

local Icons = require(script.Parent.Icons)

export type Role = {
	name: string,
	label: string,
	icon: string?,
	top: Color3,
	bottom: Color3,
	priority: number,
}

local Roles = {}

Roles.Defs = {
	Owner = { name = "Owner", label = "OWNER", icon = Icons.Crown, top = Color3.fromRGB(255, 214, 70), bottom = Color3.fromRGB(230, 140, 20), priority = 100 },
	Admin = { name = "Admin", label = "ADMIN", icon = Icons.Verify, top = Color3.fromRGB(255, 110, 110), bottom = Color3.fromRGB(200, 45, 60), priority = 80 },
	Moderator = { name = "Moderator", label = "MOD", icon = Icons.Verify, top = Color3.fromRGB(110, 190, 255), bottom = Color3.fromRGB(40, 120, 230), priority = 60 },
	Tester = { name = "Tester", label = "TESTER", icon = Icons.Verify, top = Color3.fromRGB(190, 140, 255), bottom = Color3.fromRGB(120, 70, 220), priority = 40 },
} :: { [string]: Role }

-- user id -> role name
Roles.Users = {
	[4664295] = "Owner",
} :: { [number]: string }

-- optional: a Roblox group whose ranks map to roles (rank number -> role name, highest rank first)
Roles.GroupId = nil :: number?
Roles.GroupRanks = {} :: { [number]: string }

-- Returns the role for a player (server or client). Group lookups yield, so call off the main path.
function Roles.of(player: Player): Role?
	local best: Role? = nil
	local direct = Roles.Users[player.UserId]
	if direct then
		best = Roles.Defs[direct]
	end
	if Roles.GroupId then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(Roles.GroupId :: number)
		end)
		if ok and rank and rank > 0 then
			local bestRank = -1
			for r, roleName in pairs(Roles.GroupRanks) do
				if rank >= r and r > bestRank then
					bestRank = r
					local role = Roles.Defs[roleName]
					if role and (not best or role.priority > best.priority) then
						best = role
					end
				end
			end
		end
	end
	return best
end

return Roles
