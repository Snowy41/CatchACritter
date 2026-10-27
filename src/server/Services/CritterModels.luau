-- Builds critter models from templates (ServerStorage.CritterTemplates) for a critter entry:
-- applies mutation visuals and scale, adds a nameplate and tags the model for the client animator.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CritterDefs = require(ReplicatedStorage.Shared.CritterDefs)

local Templates = ServerStorage:WaitForChild("CritterTemplates")

local CritterModels = {}

-- parts that keep their colour on Golden critters (eyes, mouth)
local KEEP_COLOUR = {
	Eye = true, Iris = true, Pupil = true, Shine = true, ShineBig = true, ShineSmall = true, ShineDot = true,
	EyeRim = true, Mouth = true, MouthCorner = true, Grin = true, GrinCornerL = true, GrinCornerR = true,
	Tooth = true, Fang = true, Tongue = true, TongueTip = true, TongueLine = true, Nose = true,
}

local function applyMutation(model: Model, mutation: string?)
	if mutation == "Golden" then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 and not KEEP_COLOUR[p.Name] then
				p.Color = Color3.fromRGB(255, 205, 60)
				p.Reflectance = 0.25
			end
		end
	elseif mutation == "Shiny" then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Rate = 8
		sparkle.Lifetime = NumberRange.new(0.6, 1.1)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new(0.35, 0)
		sparkle.LightEmission = 1
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 255, 220))
		sparkle.Parent = model.PrimaryPart
	end
end

local RARITY_INDEX: { [string]: number } = {}
for i, r in ipairs(Config.Rarities) do
	RARITY_INDEX[r.name] = i
end

-- Rarity readability from far away: ground ring (Uncommon+), sparkles (Rare+), glow (Epic+),
-- light pillar (Legendary+). Rings follow the model (welded to the root).
local function applyRarityFx(model: Model, rarityName: string, beam: boolean, beamMinTier: number)
	local rarity = Config.RarityByName[rarityName]
	local tier = RARITY_INDEX[rarityName] or 1
	local root = model.PrimaryPart
	if not rarity or not root or tier < 2 then
		return
	end
	local _, size = model:GetBoundingBox()
	local dia = math.max(size.X, size.Z) * 1.25
	local ring = Instance.new("Part")
	ring.Name = "RarityRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.08, dia, dia)
	ring.CFrame = root.CFrame * CFrame.new(0, -root.Size.Y / 2 + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = rarity.color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.55
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Massless = true
	ring.Anchored = false
	ring.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = ring
	weld.Parent = ring
	if tier >= 3 then
		local p = Instance.new("ParticleEmitter")
		p.Name = "RaritySparkles"
		p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		p.Rate = 3 + tier
		p.Lifetime = NumberRange.new(0.8, 1.4)
		p.Speed = NumberRange.new(1, 2.5)
		p.SpreadAngle = Vector2.new(60, 60)
		p.EmissionDirection = Enum.NormalId.Top
		p.Size = NumberSequence.new(0.45, 0)
		p.LightEmission = 1
		p.Color = ColorSequence.new(rarity.color:Lerp(Color3.new(1, 1, 1), 0.35))
		p.Parent = ring
	end
	if tier >= 4 then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = root
	end
	if beam and tier >= beamMinTier then
		local a0 = Instance.new("Attachment")
		a0.Parent = ring
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(60, 0, 0) -- ring is rotated: local X points up
		a1.Parent = ring
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = 3
		b.Width1 = 1
		b.FaceCamera = true
		b.LightEmission = 1
		b.Color = ColorSequence.new(rarity.color)
		b.Transparency = NumberSequence.new(0.35, 1)
		b.Parent = ring
	end
end

local function nameplate(model: Model, entry: Config.CritterEntry, offsetY: number)
	local def = CritterDefs[entry.species]
	local rarity = Config.RarityByName[entry.rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromOffset(160, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 70
	gui.LightInfluence = 0

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.55, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = (entry.mutation and (entry.mutation .. " ") or "") .. def.displayName
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = title
	title.Parent = gui

	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.new(0, 0, 0.55, 0)
	sub.Size = UDim2.new(1, 0, 0.45, 0)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.FredokaOne
	sub.TextScaled = true
	sub.TextColor3 = rarity and rarity.color or Color3.new(1, 1, 1)
	sub.Text = ("%s  ·  %.1f kg"):format(entry.rarity, entry.sizeKg)
	local stroke2 = Instance.new("UIStroke")
	stroke2.Thickness = 2
	stroke2.Parent = sub
	sub.Parent = gui

	gui.Parent = model.PrimaryPart
end

export type BuildOptions = {
	scale: number?, -- extra scale on top of the mutation scale (e.g. carried critters)
	label: boolean?,
	fx: boolean?, -- rarity ring/sparkles (default true)
	beam: boolean?, -- light pillar for Legendary+ (default false; wild critters use it)
	beamMinTier: number?, -- lowest rarity tier that gets the pillar (default 5 = Legendary)
}

function CritterModels.build(entry: Config.CritterEntry, opts: BuildOptions?): Model
	local options: BuildOptions = opts or {}
	local def = CritterDefs[entry.species]
	local template = Templates:FindFirstChild(def.template) :: Model
	local model = template:Clone()
	model.Name = def.displayName
	local mutation = entry.mutation and Config.MutationByName[entry.mutation]
	local scale = (mutation and mutation.scale or 1) * (options.scale or 1)
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	applyMutation(model, entry.mutation)
	if options.fx ~= false then
		applyRarityFx(model, entry.rarity, options.beam == true, options.beamMinTier or 5)
	end
	model:SetAttribute("Species", entry.species)
	model:SetAttribute("Rarity", entry.rarity)
	model:SetAttribute("Mutation", entry.mutation)
	model:SetAttribute("SizeKg", entry.sizeKg)
	model:SetAttribute("RootHeight", (template:GetAttribute("RootHeight") or 0.2) * scale)
	if options.label ~= false then
		local _, size = model:GetBoundingBox()
		nameplate(model, entry, size.Y + 0.6)
	end
	CollectionService:AddTag(model, "AnimatedCritter")
	return model
end

return CritterModels
