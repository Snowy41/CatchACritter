-- Wild critters: spawning (species / rarity / mutation / size rolls), wandering, fleeing, guarded
-- nest critters, special (lucky) spawns and server-side validation of catches.
-- Zone data (counts, weights, nests) comes from shared/Zones.
-- Signals: Caught(player, entry, nestZone?), NestCaught(player, zone)

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local CritterDefs = require(ReplicatedStorage.Shared.CritterDefs)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Zones = require(ReplicatedStorage.Shared.Zones)
local CritterModels = require(ServerScriptService.Lib.CritterModels)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local FxService = require(script.Parent.FxService)

local CritterService = {}
CritterService.Priority = 30

CritterService.Caught = Signal.new()
CritterService.NestCaught = Signal.new()

type Wild = {
	id: string,
	model: Model,
	entry: Config.CritterEntry,
	rarity: Config.Rarity,
	zone: string,
	area: BasePart,
	pos: Vector3,
	target: Vector3,
	yaw: number,
	pauseUntil: number,
	fleeUntil: number,
	frozenBy: Player?,
	nest: string?, -- zone of the guarded nest this critter sits in (nil = free-roaming)
	special: boolean?, -- lucky/onboarding spawn: extra, not counted, leaves after a while
	stunnedUntil: number?, -- after a near miss the critter stumbles (no fleeing) for a moment
}

local rng = Random.new()
local folder: Folder
local wild: { [string]: Wild } = {}
local areasByZone: { [string]: { BasePart } } = {}
local countByZone: { [string]: number } = {}
local speciesByZone: { [string]: { string } } = {}
local nests: { [string]: BasePart } = {} -- zone -> NestSpot
local nestCount: { [string]: number } = {}

type CatchSession = { token: string, critterId: string, started: number, guaranteed: boolean }
local sessions: { [Player]: CatchSession } = {}

--------------------------------------------------------------------------- rolls

local function rollRarity(weights: { [string]: number }): string
	local total = 0
	for _, w in pairs(weights) do
		total += w
	end
	local pick = rng:NextNumber() * total
	for _, r in ipairs(Config.Rarities) do
		local w = weights[r.name]
		if w then
			pick -= w
			if pick <= 0 then
				return r.name
			end
		end
	end
	return "Common"
end

-- Mutations at spawn: one main natural mutation roll, sometimes a second natural one, and
-- rarely a weather mutation (Frozen, Rainbow, Lava, Ghost) that the critter already has.
local function rollMutations(zone: string): (string?, { string }?, string?)
	local main: string? = nil
	local x = rng:NextNumber()
	for _, m in ipairs(Config.Mutations) do
		if x < m.chance then
			main = m.name
			break
		end
		x -= m.chance
	end
	local extra: { string }? = nil
	if main then
		for _, m in ipairs(Config.Mutations) do
			local conflicts = (main == "Giant" and m.name == "Tiny") or (main == "Tiny" and m.name == "Giant")
			if m.chance > 0 and m.name ~= main and not conflicts and rng:NextNumber() < m.chance * Config.ExtraMutationFactor * 10 then
				extra = { m.name }
				break
			end
		end
	end
	local weather: string? = nil
	for _, m in ipairs(Config.Mutations) do
		local c = (m.spawnChance or 0) * (m.zoneBoost and m.zoneBoost[zone] or 1)
		if c > 0 and rng:NextNumber() < c then
			weather = m.name
			break
		end
	end
	return main, extra, weather
end

local function weightsFor(zone: string, inNest: boolean?): { [string]: number }
	local def = Zones.get(zone)
	if not def then
		return { Common = 1 }
	end
	if inNest and def.nest then
		return def.nest.rarityWeights
	end
	return def.rarityWeights
end

-- species of a zone that can spawn now with this rarity
local function candidates(zone: string, rarity: string): { string }
	local list = {}
	for _, sp in ipairs(speciesByZone[zone] or {}) do
		if CritterDefs.isAvailable(sp) and CritterDefs.allowsRarity(sp, rarity) then
			table.insert(list, sp)
		end
	end
	return list
end

-- Rolls a critter: rarity first (zone / nest weights, or forced), then a species allowed for that
-- rarity (stepping the rarity down if no species fits), then mutations and size.
local function rollEntry(zone: string, inNest: boolean?, forcedRarity: string?): Config.CritterEntry?
	local tier = Config.tier(forcedRarity or rollRarity(weightsFor(zone, inNest)))
	local list: { string } = {}
	while tier >= 1 do
		list = candidates(zone, Config.Rarities[tier].name)
		if #list > 0 then
			break
		end
		tier -= 1
	end
	if #list == 0 then
		return nil
	end
	-- Critter of the Hour gets a boosted spawn weight
	local featured = workspace:GetAttribute("CritterOfTheHour")
	local total = 0
	for _, sp in ipairs(list) do
		total += (sp == featured) and Config.CritterOfTheHourBoost or 1
	end
	local pick = rng:NextNumber() * total
	local species = list[#list]
	for _, sp in ipairs(list) do
		pick -= (sp == featured) and Config.CritterOfTheHourBoost or 1
		if pick <= 0 then
			species = sp
			break
		end
	end
	local def = CritterDefs[species]
	-- weight: mostly close to average, occasionally much heavier/lighter
	local factor = 0.7 + 0.7 * (rng:NextNumber() + rng:NextNumber()) / 2
	local main, extra, weather = rollMutations(zone)
	return {
		species = species,
		rarity = Config.Rarities[tier].name,
		mutation = main,
		extra = extra,
		weather = weather,
		sizeKg = math.floor(def.baseKg * factor * 10 + 0.5) / 10,
	}
end

--------------------------------------------------------------------------- placement

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function randomPointIn(area: BasePart): Vector3
	local half = area.Size / 2
	local local_ = Vector3.new(rng:NextNumber(-half.X, half.X) * 0.9, 0, rng:NextNumber(-half.Z, half.Z) * 0.9)
	return area.CFrame:PointToWorldSpace(local_)
end

-- props a critter should walk around/under, never stand on top of
local NOT_GROUND = { Trunk = true, Post = true, Rail = true, Pillar = true, Stone = true, Body = true, Hex = true, Stilt = true, TrunkWall = true }

local gameplayZones: Instance? = nil -- invisible trigger volumes (spawn areas, safe zone) are not ground

local function groundY(x: number, z: number): number
	local ignore: { Instance } = { folder }
	if gameplayZones then
		table.insert(ignore, gameplayZones)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end
	for _ = 1, 4 do
		rayParams.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), rayParams)
		if not hit then
			return 0
		end
		if not NOT_GROUND[hit.Instance.Name] then
			return hit.Position.Y
		end
		table.insert(ignore, hit.Instance)
	end
	return 0
end

local function clampToArea(area: BasePart, p: Vector3): Vector3
	local half = area.Size / 2
	local l = area.CFrame:PointToObjectSpace(p)
	return area.CFrame:PointToWorldSpace(Vector3.new(math.clamp(l.X, -half.X, half.X), 0, math.clamp(l.Z, -half.Z, half.Z)))
end

local function place(w: Wild)
	local y = groundY(w.pos.X, w.pos.Z) + (w.model:GetAttribute("RootHeight") or 0.2)
	w.model:PivotTo(CFrame.new(w.pos.X, y, w.pos.Z) * CFrame.Angles(0, w.yaw, 0))
end

local function spawnOne(zone: string)
	local areas = areasByZone[zone]
	local entry = rollEntry(zone)
	if not areas or #areas == 0 or not entry then
		return
	end
	local area = areas[rng:NextInteger(1, #areas)]
	local model = CritterModels.build(entry, { beam = true })
	local id = HttpService:GenerateGUID(false)
	model:SetAttribute("CritterId", id)
	model:SetAttribute("Zone", zone)
	local start = randomPointIn(area)
	local w: Wild = {
		id = id,
		model = model,
		entry = entry,
		rarity = Config.RarityByName[entry.rarity],
		zone = zone,
		area = area,
		pos = start,
		target = start,
		yaw = rng:NextNumber(0, math.pi * 2),
		pauseUntil = os.clock() + rng:NextNumber(0, 3),
		fleeUntil = 0,
		frozenBy = nil,
	}
	place(w)
	model.Parent = folder
	wild[id] = w
	countByZone[zone] = (countByZone[zone] or 0) + 1
end

local function spawnNestCritter(zone: string, entry: Config.CritterEntry?)
	local nest = nests[zone]
	local e = entry or rollEntry(zone, true)
	local zoneDef = Zones.get(zone)
	local nestDef = zoneDef and zoneDef.nest
	if not nest or not e or not nestDef or (nestCount[zone] or 0) >= nestDef.critters then
		return
	end
	local model = CritterModels.build(e)
	local id = HttpService:GenerateGUID(false)
	model:SetAttribute("CritterId", id)
	model:SetAttribute("Zone", zone)
	model:SetAttribute("InNest", true)
	local slot = nestCount[zone] or 0
	local a = rng:NextNumber(0, math.pi * 2) + slot * math.pi
	local pos = nest.Position + Vector3.new(math.cos(a) * 2.2, 0, math.sin(a) * 2.2)
	local w: Wild = {
		id = id,
		model = model,
		entry = e,
		rarity = Config.RarityByName[e.rarity],
		zone = zone,
		area = nest,
		pos = pos,
		target = pos,
		yaw = rng:NextNumber(0, math.pi * 2),
		pauseUntil = math.huge,
		fleeUntil = 0,
		frozenBy = nil,
		nest = zone,
	}
	place(w)
	model.Parent = folder
	wild[id] = w
	nestCount[zone] = slot + 1
end

local function despawn(id: string, respawn: boolean?)
	local w = wild[id]
	if not w then
		return
	end
	wild[id] = nil
	w.model:Destroy()
	if w.special then
		return -- extra spawn: nothing to refill
	elseif w.nest then
		nestCount[w.nest] -= 1
		local nestDef = (Zones.get(w.nest) :: Zones.ZoneDef).nest
		if respawn ~= false and nestDef then
			task.delay(nestDef.respawn, spawnNestCritter, w.nest)
		end
	else
		countByZone[w.zone] -= 1
		task.delay(Config.RespawnDelay, spawnOne, w.zone)
	end
end

-- Zones that have species to spawn (used for lucky spawns etc.).
function CritterService.hasSpecies(zone: string): boolean
	local list = speciesByZone[zone]
	return list ~= nil and #list > 0
end

-- A critter dropped by a player (guardian bump) runs straight back into its nest.
function CritterService.returnToNest(zone: string, entry: Config.CritterEntry)
	spawnNestCritter(zone, entry)
end

-- Lucky / onboarding spawn: a free-roaming critter of a forced rarity, with a light pillar from
-- Rare upward. `near` places it within ~25 studs of a position inside the zone's spawn areas.
-- Returns the model and entry, or nil.
function CritterService.spawnSpecial(zone: string, rarity: string, near: Vector3?): (Model?, Config.CritterEntry?)
	local areas = areasByZone[zone]
	local entry = rollEntry(zone, false, rarity)
	if not areas or #areas == 0 or not entry then
		return nil, nil
	end
	local area = areas[rng:NextInteger(1, #areas)]
	if near then
		local best, bestD = area, math.huge
		for _, a in ipairs(areas) do
			local d = (a.Position - near).Magnitude
			if d < bestD then
				best, bestD = a, d
			end
		end
		area = best
	end
	local start = near and clampToArea(area, near + Vector3.new(rng:NextNumber(-25, 25), 0, rng:NextNumber(-25, 25))) or randomPointIn(area)
	local model = CritterModels.build(entry, { beam = true, beamMinTier = 3 })
	local id = HttpService:GenerateGUID(false)
	model:SetAttribute("CritterId", id)
	model:SetAttribute("Zone", zone)
	model:SetAttribute("Lucky", true)
	local w: Wild = {
		id = id,
		model = model,
		entry = entry,
		rarity = Config.RarityByName[entry.rarity],
		zone = zone,
		area = area,
		pos = start,
		target = start,
		yaw = rng:NextNumber(0, math.pi * 2),
		pauseUntil = os.clock() + 2,
		fleeUntil = 0,
		frozenBy = nil,
		special = true,
	}
	place(w)
	model.Parent = folder
	wild[id] = w
	task.delay(Config.LuckySpawnLifetime, function()
		local still = wild[id]
		if still and not still.frozenBy then
			despawn(id)
		end
	end)
	return model, entry
end

--------------------------------------------------------------------------- movement

local function nearestPlayer(pos: Vector3): (Vector3?, number)
	local best, bestD = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local d = (hrp.Position - pos).Magnitude
			if d < bestD then
				best, bestD = hrp.Position, d
			end
		end
	end
	return best, bestD
end

local function step(w: Wild, dt: number, now: number)
	if w.frozenBy or w.nest then
		return -- nest critters stay put: the guardian is their protection
	end
	if w.stunnedUntil and now < w.stunnedUntil then
		return
	end
	local speed = Config.WanderSpeed
	local threat, dist = nearestPlayer(w.pos)
	if threat and w.rarity.fleeRadius > 0 and dist < w.rarity.fleeRadius then
		-- run directly away from the closest player
		local away = Vector3.new(w.pos.X - threat.X, 0, w.pos.Z - threat.Z)
		if away.Magnitude > 0.01 then
			w.target = clampToArea(w.area, w.pos + away.Unit * 10)
			w.fleeUntil = now + 0.8
			w.pauseUntil = 0
		end
	end
	if now < w.fleeUntil then
		speed = w.rarity.fleeSpeed
	elseif now < w.pauseUntil then
		return
	end
	local delta = Vector3.new(w.target.X - w.pos.X, 0, w.target.Z - w.pos.Z)
	if delta.Magnitude < 0.5 then
		-- arrived: idle a moment, then pick a new wander target
		w.pauseUntil = now + rng:NextNumber(1.5, 4)
		w.target = clampToArea(w.area, w.pos + Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14)))
		return
	end
	local move = math.min(delta.Magnitude, speed * dt)
	local dir = delta.Unit
	w.pos += dir * move
	-- models face -Z: yaw so that LookVector points along the movement
	local targetYaw = math.atan2(-dir.X, -dir.Z)
	local diff = (targetYaw - w.yaw + math.pi) % (2 * math.pi) - math.pi
	w.yaw += diff * math.min(1, dt * 8)
	place(w)
end

--------------------------------------------------------------------------- catching

function CritterService.requestCatch(player: Player, critterId: any)
	if typeof(critterId) ~= "string" then
		return { ok = false }
	end
	local w = wild[critterId]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not w or not hrp or w.frozenBy or sessions[player] then
		return { ok = false }
	end
	if BaseService.isCarrying(player) then
		return { ok = false, reason = "Bring your critter home first!" }
	end
	if (hrp.Position - w.pos).Magnitude > Config.CatchRange + 2 then
		return { ok = false, reason = "Too far away" }
	end
	local data = DataService.get(player)
	local guaranteed = data ~= nil and data.totalCatches < Config.GuaranteedCatches
	-- rebirths widen the sweet spot ("better net")
	local passBonus = player:GetAttribute("CatchBonus")
	local netBonus = (1 + Config.RebirthCatchBonus * (data and data.rebirths or 0)) * (typeof(passBonus) == "number" and passBonus or 1)
	local session: CatchSession = { token = HttpService:GenerateGUID(false), critterId = critterId, started = os.clock(), guaranteed = guaranteed }
	sessions[player] = session
	w.frozenBy = player
	task.delay(Config.CatchTimeout, function()
		if sessions[player] == session then
			sessions[player] = nil
			if wild[critterId] then
				wild[critterId].frozenBy = nil
			end
		end
	end)
	return {
		ok = true,
		token = session.token,
		zone = guaranteed and 1 or math.min(1, w.rarity.catchZone * netBonus),
		speed = w.rarity.cursorSpeed,
		guaranteed = guaranteed,
		name = CritterDefs[w.entry.species].displayName,
		rarity = w.entry.rarity,
	}
end

function CritterService.submitCatch(player: Player, token: any, hit: any, near: any)
	local session = sessions[player]
	if not session or session.token ~= token then
		return { ok = false }
	end
	sessions[player] = nil
	local w = wild[session.critterId]
	if not w then
		return { ok = false }
	end
	w.frozenBy = nil
	-- the timing bar needs at least a moment; instant answers are not accepted
	local success = (session.guaranteed or hit == true) and (os.clock() - session.started) >= 0.25
	if success then
		success = BaseService.startCarry(player, w.entry, w.nest)
	end
	if success then
		local nestZone = w.nest
		FxService.toAll("Catch", { pos = w.pos, rarity = w.entry.rarity })
		despawn(w.id)
		CritterService.Caught:Fire(player, w.entry, nestZone)
		if nestZone then
			CritterService.NestCaught:Fire(player, nestZone)
		end
		return { ok = true, success = true, entry = w.entry }
	end
	-- near miss: the critter stumbles for a moment, so trying again right away feels fair
	if near == true then
		w.stunnedUntil = os.clock() + Config.NearMissPause
		FxService.toAll("NearMiss", { pos = w.pos, userId = player.UserId })
		return { ok = true, success = false, near = true }
	end
	-- missed: the critter bolts away from the player
	FxService.toAll("Miss", { pos = w.pos })
	w.fleeUntil = os.clock() + 1.2
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		local away = Vector3.new(w.pos.X - hrp.Position.X, 0, w.pos.Z - hrp.Position.Z)
		if away.Magnitude > 0.01 then
			w.target = clampToArea(w.area, w.pos + away.Unit * 16)
		end
	end
	return { ok = true, success = false }
end

function CritterService.PlayerRemoving(player: Player)
	local s = sessions[player]
	if s and wild[s.critterId] then
		wild[s.critterId].frozenBy = nil
	end
	sessions[player] = nil
end

--------------------------------------------------------------------------- lifecycle

function CritterService.Init()
	folder = workspace:FindFirstChild("WildCritters") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WildCritters"
		folder.Parent = workspace
	end
	local map = workspace:FindFirstChild("Map")
	gameplayZones = map and map:FindFirstChild("Gameplay")
	for _, area in ipairs(CollectionService:GetTagged("CritterSpawnArea")) do
		if area:IsA("BasePart") then
			local zone = area:GetAttribute("Zone") :: string
			areasByZone[zone] = areasByZone[zone] or {}
			table.insert(areasByZone[zone], area)
		end
	end
	for species, def in pairs(CritterDefs) do
		for _, zone in ipairs(def.zones) do
			speciesByZone[zone] = speciesByZone[zone] or {}
			table.insert(speciesByZone[zone], species)
		end
	end
	for _, spot in ipairs(CollectionService:GetTagged("NestSpot")) do
		local zone = spot:GetAttribute("Zone")
		if spot:IsA("BasePart") and zone then
			nests[zone] = spot
		end
	end
end

function CritterService.Start()
	for _, zone in Zones.each() do
		if CritterService.hasSpecies(zone.name) then
			for _ = 1, zone.wildCount do
				spawnOne(zone.name)
			end
			if zone.nest and nests[zone.name] then
				for _ = 1, zone.nest.critters do
					spawnNestCritter(zone.name)
				end
			end
		end
	end
	Net.func("RequestCatch").OnServerInvoke = CritterService.requestCatch
	Net.func("SubmitCatch").OnServerInvoke = CritterService.submitCatch
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 20 then
			return
		end
		local now = os.clock()
		for _, w in pairs(wild) do
			step(w, acc, now)
		end
		acc = 0
	end)
end

return CritterService
