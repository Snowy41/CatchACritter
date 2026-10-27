-- Wild critters: spawning (species / rarity / mutation / size rolls), wandering, fleeing, and
-- server-side validation of catches. Successful catches are handed to `CritterService.onCaught`.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CritterDefs = require(ReplicatedStorage.Shared.CritterDefs)
local CritterModels = require(script.Parent.CritterModels)

local CritterService = {}

-- set by Main: function(player, entry) -> boolean (false = player can't take it)
CritterService.onCaught = nil :: ((Player, Config.CritterEntry) -> boolean)?
-- set by Main: function(player) -> boolean (true = player may start a catch, e.g. not carrying)
CritterService.canCatch = nil :: ((Player) -> boolean)?
-- set by Main: function(player) -> number of catches so far
CritterService.totalCatches = nil :: ((Player) -> number)?

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
}

local rng = Random.new()
local folder: Folder
local wild: { [string]: Wild } = {}
local areasByZone: { [string]: { BasePart } } = {}
local countByZone: { [string]: number } = {}
local speciesByZone: { [string]: { string } } = {}

type CatchSession = { token: string, critterId: string, started: number, guaranteed: boolean }
local sessions: { [Player]: CatchSession } = {}

--------------------------------------------------------------------------- rolls

local function rollRarity(zone: string): string
	local weights = Config.ZoneRarityWeights[zone]
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

local function rollMutation(): string?
	local x = rng:NextNumber()
	for _, m in ipairs(Config.Mutations) do
		if x < m.chance then
			return m.name
		end
		x -= m.chance
	end
	return nil
end

local function rollEntry(zone: string): Config.CritterEntry?
	local list = speciesByZone[zone]
	if not list or #list == 0 then
		return nil
	end
	local species = list[rng:NextInteger(1, #list)]
	local def = CritterDefs[species]
	-- weight: mostly close to average, occasionally much heavier/lighter
	local factor = 0.7 + 0.7 * (rng:NextNumber() + rng:NextNumber()) / 2
	return {
		species = species,
		rarity = rollRarity(zone),
		mutation = rollMutation(),
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
	local model = CritterModels.build(entry)
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

local function despawn(id: string)
	local w = wild[id]
	if not w then
		return
	end
	wild[id] = nil
	countByZone[w.zone] -= 1
	w.model:Destroy()
	task.delay(Config.RespawnDelay, spawnOne, w.zone)
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
	if w.frozenBy then
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
	if CritterService.canCatch and not CritterService.canCatch(player) then
		return { ok = false, reason = "Bring your critter home first!" }
	end
	if (hrp.Position - w.pos).Magnitude > Config.CatchRange + 2 then
		return { ok = false, reason = "Too far away" }
	end
	local guaranteed = CritterService.totalCatches ~= nil and CritterService.totalCatches(player) < Config.GuaranteedCatches
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
		zone = guaranteed and 1 or w.rarity.catchZone,
		speed = w.rarity.cursorSpeed,
		guaranteed = guaranteed,
		name = CritterDefs[w.entry.species].displayName,
		rarity = w.entry.rarity,
	}
end

function CritterService.submitCatch(player: Player, token: any, hit: any)
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
	if success and CritterService.onCaught then
		success = CritterService.onCaught(player, w.entry)
	end
	if success then
		despawn(w.id)
		return { ok = true, success = true, entry = w.entry }
	end
	-- missed: the critter bolts away from the player
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

function CritterService.releasePlayer(player: Player)
	local s = sessions[player]
	if s and wild[s.critterId] then
		wild[s.critterId].frozenBy = nil
	end
	sessions[player] = nil
end

--------------------------------------------------------------------------- init

function CritterService.init()
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
	for zone, n in pairs(Config.WildPerZone) do
		for _ = 1, n do
			spawnOne(zone)
		end
	end
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
