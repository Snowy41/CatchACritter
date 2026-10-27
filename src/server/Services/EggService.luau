-- Critter Eggs (GDD "Critter Eggs"): critters in your base lay an egg every few minutes while you
-- are online. Each egg rolls its rarity (parent's, sometimes one higher), may inherit the parent's
-- mutation, and hatches after a real-time timer that keeps running while you're away ("my egg
-- hatches in 2 hours"). Eggs sit in a nest in your base; walk up and hold E to hatch.
-- Signals: Laid(player, egg), Hatched(player, entry)
-- State pushed to the client: "eggs" = { EggEntry }
-- Studio test hook: Workspace attribute DevLayEgg = true -> every player gets an egg that hatches in 5 s.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CritterDefs = require(ReplicatedStorage.Shared.CritterDefs)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local BaseService = require(script.Parent.BaseService)
local DataService = require(script.Parent.DataService)
local DexService = require(script.Parent.DexService)
local FxService = require(script.Parent.FxService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)

local EggService = {}
EggService.Priority = 35

EggService.Laid = Signal.new()
EggService.Hatched = Signal.new()

local NEST_OFFSET = Vector3.new(-14, 0.2, -14.5) -- on the plot floor, opposite the coin pad
local MAX_EGGS = Config.EggCapacity + 2 -- quest bonus eggs may go above the laying capacity
local rng = Random.new()
local nextLay: { [Player]: number } = {}

--------------------------------------------------------------------------- models

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function nestCFrame(plot: Model): CFrame?
	local floor = plot:FindFirstChild("Floor") :: BasePart?
	return floor and floor.CFrame * CFrame.new(NEST_OFFSET + Vector3.new(0, floor.Size.Y / 2 - 0.2, 0))
end

-- Straw nest built from parts (built once per owner, removed when they leave).
local function buildNest(plot: Model): Model?
	local cf = nestCFrame(plot)
	if not cf then
		return nil
	end
	local old = plot:FindFirstChild("EggNest")
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "EggNest"
	local base = part(m, {
		Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 8.4, 8.4),
		CFrame = cf * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(150, 105, 60), Material = Enum.Material.Grass, CanCollide = true,
	})
	m.PrimaryPart = base
	-- woven rim: tilted planks around the edge
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		part(m, {
			Name = "Straw", Size = Vector3.new(1.9, 0.55, 0.7),
			CFrame = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.75, -3.9) * CFrame.Angles(math.rad(18), 0, math.rad(i % 2 == 0 and 12 or -12)),
			Color = (i % 2 == 0) and Color3.fromRGB(220, 175, 95) or Color3.fromRGB(190, 140, 70),
		})
	end
	-- sign stick
	part(m, { Name = "Post", Size = Vector3.new(0.35, 3.2, 0.35), CFrame = cf * CFrame.new(0, 1.6, 4.6), Color = Color3.fromRGB(120, 80, 45) })
	local board = part(m, { Name = "Board", Size = Vector3.new(3.4, 1.2, 0.25), CFrame = cf * CFrame.new(0, 3.1, 4.6), Color = Color3.fromRGB(235, 200, 140) })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.LightInfluence = 0.3
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = "EGGS"
	t.TextColor3 = Color3.fromRGB(110, 70, 35)
	t.Parent = sg
	sg.Parent = board
	m.Parent = plot
	return m
end

local function eggSpot(index: number, count: number): Vector3
	if count <= 1 then
		return Vector3.zero
	end
	local a = (index - 1) / count * math.pi * 2
	return Vector3.new(math.cos(a) * 1.9, 0, math.sin(a) * 1.9)
end

-- Egg model: two stacked balls (wide bottom, narrower top), rarity colour, darker spots,
-- neon band from Epic upward (neon = rarity signal).
local function buildEgg(nest: Model, egg: DataService.EggEntry, index: number, count: number): Model
	local base = (nest.PrimaryPart :: BasePart).CFrame * CFrame.Angles(0, 0, math.rad(-90))
	local cf = CFrame.new((base * CFrame.new(eggSpot(index, count) + Vector3.new(0, 0.25, 0))).Position)
	local r = Config.RarityByName[egg.rarity]
	local color = r.color:Lerp(Color3.new(1, 1, 1), r.tier == 1 and 0.4 or 0.15)
	local m = Instance.new("Model")
	m.Name = "Egg_" .. egg.id
	local bottom = part(m, { Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.new(1.9, 1.9, 1.9), CFrame = cf * CFrame.new(0, 0.95, 0), Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = true })
	part(m, { Name = "Top", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5), CFrame = cf * CFrame.new(0, 1.55, 0), Color = color, Material = Enum.Material.SmoothPlastic })
	local spot = color:Lerp(Color3.new(0, 0, 0), 0.35)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + 0.4
		local y = (i % 2 == 0) and 1.05 or 1.55
		local rad = (i % 2 == 0) and 0.93 or 0.72
		part(m, {
			Name = "Spot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 0.42, 0.42),
			CFrame = cf * CFrame.Angles(0, a, 0) * CFrame.new(rad, y, 0), Color = spot,
		})
	end
	if r.tier >= 4 then
		part(m, {
			Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, 1.96, 1.96),
			CFrame = cf * CFrame.new(0, 1.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = r.color, Material = Enum.Material.Neon,
		})
	end
	m.PrimaryPart = bottom
	m:SetAttribute("EggId", egg.id)
	m:SetAttribute("Rarity", egg.rarity)
	m:SetAttribute("HatchAt", egg.hatchAt)

	-- countdown label (text driven on the client by Controllers/Eggs from HatchAt)
	local g = Instance.new("BillboardGui")
	g.Name = "EggLabel"
	g.Size = UDim2.fromOffset(150, 52)
	g.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	g.MaxDistance = 60
	g.LightInfluence = 0
	local name = Instance.new("TextLabel")
	name.Name = "Rarity"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.45, 0)
	name.Font = Enum.Font.LuckiestGuy
	name.TextScaled = true
	name.Text = string.upper(egg.rarity) .. " EGG"
	name.TextColor3 = r.color:Lerp(Color3.new(1, 1, 1), 0.3)
	local s1 = Instance.new("UIStroke")
	s1.Thickness = 2.5
	s1.Color = Color3.fromRGB(20, 14, 36)
	s1.Parent = name
	name.Parent = g
	local timer = Instance.new("TextLabel")
	timer.Name = "Timer"
	timer.BackgroundTransparency = 1
	timer.Position = UDim2.fromScale(0, 0.45)
	timer.Size = UDim2.new(1, 0, 0.55, 0)
	timer.Font = Enum.Font.LuckiestGuy
	timer.TextScaled = true
	timer.Text = ""
	timer.TextColor3 = Color3.new(1, 1, 1)
	local s2 = Instance.new("UIStroke")
	s2.Thickness = 2.5
	s2.Color = Color3.fromRGB(20, 14, 36)
	s2.Parent = timer
	timer.Parent = g
	g.Adornee = bottom
	g.Parent = bottom
	m.Parent = nest
	return m
end

--------------------------------------------------------------------------- state

local hatch -- forward declaration

local function render(player: Player)
	local plot = PlotService.getPlot(player)
	local data = DataService.get(player)
	if not plot or not data then
		return
	end
	local nest = plot:FindFirstChild("EggNest") :: Model?
	if not nest then
		nest = buildNest(plot)
	end
	if not nest then
		return
	end
	for _, c in ipairs(nest:GetChildren()) do
		if c:IsA("Model") and c:GetAttribute("EggId") then
			c:Destroy()
		end
	end
	for i, egg in ipairs(data.eggs) do
		local m = buildEgg(nest, egg, i, #data.eggs)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "HatchPrompt"
		prompt.ActionText = "Hatch"
		prompt.ObjectText = egg.rarity .. " Egg"
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Enabled = os.time() >= egg.hatchAt
		prompt:SetAttribute("OwnerUserId", player.UserId)
		prompt.Triggered:Connect(function(who)
			if who == player then
				hatch(player, egg.id)
			end
		end)
		prompt.Parent = m.PrimaryPart
	end
	StateService.set(player, "eggs", data.eggs)
end

local function rollSize(species: string): number
	local def = CritterDefs[species]
	local factor = 0.7 + 0.7 * (rng:NextNumber() + rng:NextNumber()) / 2
	return math.floor(def.baseKg * factor * 10 + 0.5) / 10
end

-- Adds an egg to a player's nest. ignoreCap: quest bonus eggs may exceed the laying capacity.
function EggService.give(player: Player, species: string, rarity: string, mutation: string?, ignoreCap: boolean?): DataService.EggEntry?
	local data = DataService.get(player)
	if not data or not CritterDefs[species] then
		return nil
	end
	if #data.eggs >= (ignoreCap and MAX_EGGS or Config.EggCapacity) then
		return nil
	end
	local now = os.time()
	local egg: DataService.EggEntry = {
		id = HttpService:GenerateGUID(false),
		species = species,
		rarity = rarity,
		mutation = mutation,
		laidAt = now,
		hatchAt = now + (Config.EggHatchSeconds[rarity] or 600),
	}
	table.insert(data.eggs, egg)
	render(player)
	local plot = PlotService.getPlot(player)
	local nest = plot and plot:FindFirstChild("EggNest") :: Model?
	if nest then
		FxService.toAll("Deposit", { pos = nest:GetPivot().Position + Vector3.new(0, 1, 0), rarity = rarity })
	end
	EggService.Laid:Fire(player, egg)
	return egg
end

local function lay(player: Player)
	local data = DataService.get(player)
	if not data or #data.eggs >= Config.EggCapacity then
		return
	end
	local parents = {}
	for _, entry in pairs(data.base) do
		table.insert(parents, entry)
	end
	if #parents == 0 then
		return
	end
	local parent = parents[rng:NextInteger(1, #parents)]
	local tier = Config.tier(parent.rarity)
	if rng:NextNumber() < Config.EggUpgradeChance and tier < #Config.Rarities then
		tier += 1
	end
	local rarity = Config.Rarities[tier].name
	local mutation = (parent.mutation and rng:NextNumber() < Config.EggInheritChance) and parent.mutation or nil
	local egg = EggService.give(player, parent.species, rarity, mutation)
	if egg then
		FxService.notify(player, ("Your %s laid a %s egg!"):format(CritterDefs[parent.species].displayName, rarity), "success")
	end
end

function hatch(player: Player, eggId: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	local index, egg = nil, nil
	for i, e in ipairs(data.eggs) do
		if e.id == eggId then
			index, egg = i, e
		end
	end
	if not egg or os.time() < egg.hatchAt then
		return
	end
	if BaseService.isCarrying(player) then
		FxService.notify(player, "Put your critter down first!", "warn")
		return
	end
	if not BaseService.hasFreeSlot(player) then
		FxService.notify(player, "Your base is full! Hold F on a critter to sell it", "warn")
		return
	end
	table.remove(data.eggs, index)
	local entry: Config.CritterEntry = {
		species = egg.species,
		rarity = egg.rarity,
		mutation = egg.mutation,
		sizeKg = rollSize(egg.species),
	}
	local plot = PlotService.getPlot(player)
	local nest = plot and plot:FindFirstChild("EggNest") :: Model?
	if nest then
		FxService.toAll("Hatch", { pos = nest:GetPivot().Position + Vector3.new(0, 1.5, 0), rarity = egg.rarity })
	end
	BaseService.place(player, entry)
	local isNew, found, total = DexService.register(player, entry)
	FxService.toPlayer(player, "CatchCard", BaseService.cardData(player, entry, { isNew = isNew, dexFound = found, dexTotal = total, hatched = true }))
	render(player)
	EggService.Hatched:Fire(player, entry)
end

--------------------------------------------------------------------------- lifecycle

function EggService.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			local devEgg = RunService:IsStudio() and workspace:GetAttribute("DevLayEgg") == true
			if devEgg then
				workspace:SetAttribute("DevLayEgg", nil)
			end
			for _, player in ipairs(Players:GetPlayers()) do
				if devEgg then
					local data = DataService.get(player)
					local parent = data and next(data.base) and data.base[next(data.base)]
					local egg = EggService.give(player, parent and parent.species or "CloverBun", parent and parent.rarity or "Common", nil, true)
					if egg then
						egg.hatchAt = now + 5
						render(player)
					end
				end
				local data = DataService.get(player)
				if data then
					-- laying runs on online time only
					if nextLay[player] and os.clock() >= nextLay[player] then
						nextLay[player] = os.clock() + rng:NextInteger(Config.EggLayInterval[1], Config.EggLayInterval[2])
						lay(player)
					end
					-- enable hatch prompts of eggs that just became ready
					local plot = PlotService.getPlot(player)
					local nest = plot and plot:FindFirstChild("EggNest")
					if nest then
						for _, m in ipairs(nest:GetChildren()) do
							local hatchAt = m:GetAttribute("HatchAt")
							local prompt = m:IsA("Model") and m.PrimaryPart and m.PrimaryPart:FindFirstChild("HatchPrompt") :: ProximityPrompt?
							if prompt and hatchAt and now >= hatchAt and not prompt.Enabled then
								prompt.Enabled = true
								FxService.notify(player, ("Your %s egg is ready to hatch!"):format(m:GetAttribute("Rarity")), "success")
							end
						end
					end
				end
			end
		end
	end)
end

function EggService.PlayerAdded(player: Player, data: DataService.Data)
	nextLay[player] = os.clock() + rng:NextInteger(Config.EggLayInterval[1], Config.EggLayInterval[2])
	render(player)
	local ready = 0
	for _, e in ipairs(data.eggs) do
		if os.time() >= e.hatchAt then
			ready += 1
		end
	end
	if ready > 0 then
		task.delay(6, function()
			FxService.announceTo(player, ready == 1 and "An egg in your base is ready to hatch!" or ("%d eggs in your base are ready to hatch!"):format(ready), nil, Icons.Egg)
		end)
	end
end

function EggService.PlayerRemoving(player: Player)
	nextLay[player] = nil
	local plot = PlotService.getPlot(player)
	local nest = plot and plot:FindFirstChild("EggNest")
	if nest then
		nest:Destroy()
	end
end

return EggService
