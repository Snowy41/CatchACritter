-- Summoning rituals (GDD "Summoning rituals"): a circle in the map (tag "SummonCircle", attribute
-- Zone) with pads (parts named Pad*, attribute Species) around a Core part. When every pad has a
-- player standing on it who owns that pad's species in their base, the ritual charges for a few
-- seconds and summons a Secret critter for everyone. One ritual per circle per cooldown.
-- Circle attributes for clients: State ("Idle" | "Charging" | "Cooldown"), ChargeEnds,
-- CooldownEnds, Ready (pads ready), Needed (pads total).
-- Studio test hook: Workspace attribute DevSummonSolo = true -> one ready pad is enough.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CritterDefs = require(ReplicatedStorage.Shared.CritterDefs)
local CritterService = require(script.Parent.CritterService)
local DataService = require(script.Parent.DataService)
local FxService = require(script.Parent.FxService)

local SummonService = {}
SummonService.Priority = 80

local IDLE = Color3.fromRGB(120, 110, 170)
local OCCUPIED = Color3.fromRGB(255, 120, 120) -- someone stands there but lacks the species
local READY = Color3.fromRGB(140, 255, 220)

local function owns(player: Player, species: string): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	for _, entry in pairs(data.base) do
		if entry.species == species then
			return true
		end
	end
	return false
end

local function standingOn(pad: BasePart): { Player }
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local rel = pad.CFrame:PointToObjectSpace(hrp.Position)
			local radius = math.max(pad.Size.Y, pad.Size.Z) / 2 -- pads are cylinders lying on their side
			if Vector2.new(rel.Y, rel.Z).Magnitude <= radius and math.abs(rel.X) < 6 then
				table.insert(list, plr)
			end
		end
	end
	return list
end

local function setPad(pad: BasePart, color: Color3, glow: boolean)
	pad.Color = color
	pad.Material = glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
end

local function summon(circle: Model, core: BasePart)
	local zone = circle:GetAttribute("Zone") or "Meadow"
	FxService.toAll("Summon", { pos = core.Position })
	task.wait(1.2)
	local model, entry = CritterService.spawnSpecial(zone, "Secret", core.Position)
	if model and entry then
		FxService.announce(("A SECRET %s was summoned at the circle!"):format(CritterDefs[entry.species].displayName), "Secret")
	end
end

local function run(circle: Model)
	local core = circle:FindFirstChild("Core") :: BasePart?
	local pads: { BasePart } = {}
	for _, c in ipairs(circle:GetChildren()) do
		if c:IsA("BasePart") and c.Name:match("^Pad") and c:GetAttribute("Species") then
			table.insert(pads, c)
		end
	end
	if not core or #pads == 0 then
		warn("[SummonService] circle without Core or pads:", circle:GetFullName())
		return
	end
	circle:SetAttribute("Needed", #pads)
	circle:SetAttribute("State", "Idle")
	local chargeEnds: number? = nil
	while circle.Parent do
		task.wait(0.25)
		local now = os.time()
		local cooldown = circle:GetAttribute("CooldownEnds") or 0
		if now < cooldown then
			circle:SetAttribute("State", "Cooldown")
			for _, pad in ipairs(pads) do
				setPad(pad, IDLE, false)
			end
			continue
		end
		local ready = 0
		for _, pad in ipairs(pads) do
			local species = pad:GetAttribute("Species")
			local players = standingOn(pad)
			local ok = false
			for _, plr in ipairs(players) do
				if owns(plr, species) then
					ok = true
				end
			end
			if ok then
				ready += 1
				setPad(pad, READY, true)
			else
				setPad(pad, #players > 0 and OCCUPIED or IDLE, false)
			end
		end
		circle:SetAttribute("Ready", ready)
		local needed = (RunService:IsStudio() and workspace:GetAttribute("DevSummonSolo")) and 1 or #pads
		if ready >= needed then
			if not chargeEnds then
				chargeEnds = os.clock() + Config.SummonCharge
				circle:SetAttribute("State", "Charging")
				circle:SetAttribute("ChargeEnds", os.time() + Config.SummonCharge)
				FxService.toAll("SummonCharge", { pos = core.Position, duration = Config.SummonCharge })
			elseif os.clock() >= chargeEnds then
				chargeEnds = nil
				circle:SetAttribute("CooldownEnds", now + Config.SummonCooldown)
				summon(circle, core)
			end
		else
			if chargeEnds then
				FxService.toAll("SummonCancel", { pos = core.Position })
			end
			chargeEnds = nil
			circle:SetAttribute("State", "Idle")
		end
	end
end

function SummonService.Start()
	for _, circle in ipairs(CollectionService:GetTagged("SummonCircle")) do
		if circle:IsA("Model") then
			task.spawn(run, circle)
		end
	end
end

return SummonService
