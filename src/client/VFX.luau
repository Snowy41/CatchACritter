-- Client-side world effects. Everything here is local (not replicated) and cleans itself up.
-- Style: chunky part confetti and neon shapes, matching the block look of the game.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Icons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Icons"))

local VFX = {}

local folder = Instance.new("Folder")
folder.Name = "LocalFx"
folder.Parent = workspace

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local CONFETTI = {
	Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 210, 60), Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(120, 230, 90), Color3.fromRGB(255, 140, 210), Color3.fromRGB(190, 120, 255),
}

local function tween(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function fxPart(size: Vector3, cf: CFrame, color: Color3, neon: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

-- One-shot particle burst from an invisible anchor.
local function emit(pos: Vector3, count: number, props: { [string]: any })
	local anchor = fxPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), Color3.new(1, 1, 1))
	anchor.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = props.texture or SPARKLE
	e.Color = props.color or ColorSequence.new(Color3.new(1, 1, 1))
	e.Size = props.size or NumberSequence.new(0.8, 0)
	e.Lifetime = props.lifetime or NumberRange.new(0.5, 0.9)
	e.Speed = props.speed or NumberRange.new(8, 14)
	e.SpreadAngle = props.spread or Vector2.new(180, 180)
	e.Acceleration = props.acceleration or Vector3.new(0, -10, 0)
	e.Drag = props.drag or 2
	e.LightEmission = props.lightEmission or 1
	e.Transparency = props.transparency or NumberSequence.new(0, 1)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.Parent = anchor
	e:Emit(count)
	Debris:AddItem(anchor, 3)
end

-- Little block confetti flying out and fading (physics parts, local only).
function VFX.confetti(pos: Vector3, count: number?)
	for _ = 1, count or 18 do
		local s = math.random(25, 45) / 100
		local p = fxPart(Vector3.new(s, s * 0.4, s), CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), CONFETTI[math.random(#CONFETTI)])
		p.Anchored = false
		p.Massless = true
		p.AssemblyLinearVelocity = Vector3.new(math.random(-14, 14), math.random(18, 30), math.random(-14, 14))
		p.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		task.delay(0.9, function()
			tween(p, 0.4, { Transparency = 1 })
		end)
		Debris:AddItem(p, 1.4)
	end
end

-- Expanding flat neon ring.
function VFX.shockwave(pos: Vector3, color: Color3, radius: number?)
	local r = radius or 10
	local p = fxPart(Vector3.new(0.15, 1, 1), CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, true)
	p.Shape = Enum.PartType.Cylinder
	p.Transparency = 0.2
	tween(p, 0.45, { Size = Vector3.new(0.15, r * 2, r * 2), Transparency = 1 })
	Debris:AddItem(p, 0.6)
end

function VFX.stars(pos: Vector3, color: Color3, count: number?)
	emit(pos, count or 24, {
		color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4), Color3.new(1, 1, 1)),
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }),
		speed = NumberRange.new(10, 18),
	})
end

function VFX.poof(pos: Vector3, color: Color3?)
	emit(pos, 10, {
		texture = SMOKE,
		color = ColorSequence.new(color or Color3.fromRGB(235, 230, 220)),
		size = NumberSequence.new(2, 4),
		lifetime = NumberRange.new(0.4, 0.7),
		speed = NumberRange.new(4, 8),
		acceleration = Vector3.new(0, 4, 0),
		lightEmission = 0,
		transparency = NumberSequence.new(0.3, 1),
	})
end

-- Vertical light column (deposits, speed-ups).
function VFX.beam(pos: Vector3, color: Color3, height: number?, width: number?)
	local h = height or 14
	local w = width or 4
	local p = fxPart(Vector3.new(h, w, w), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, true)
	p.Shape = Enum.PartType.Cylinder
	p.Transparency = 0.35
	tween(p, 0.6, { Size = Vector3.new(h, 0.2, 0.2), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Debris:AddItem(p, 0.7)
end

-- Floating text that rises and fades (e.g. "+12").
function VFX.floatText(pos: Vector3, text: string, color: Color3)
	local anchor = fxPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), Color3.new(1, 1, 1))
	anchor.Transparency = 1
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromOffset(160, 50)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Color3.fromRGB(20, 14, 36)
	s.Parent = t
	t.Parent = g
	tween(anchor, 1, { CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)) })
	task.delay(0.6, function()
		tween(t, 0.4, { TextTransparency = 1 })
		tween(s, 0.4, { Transparency = 1 })
	end)
	Debris:AddItem(anchor, 1.1)
end

-- Stars circling a character's head after a guardian bonk.
function VFX.dizzy(character: Model, duration: number?)
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local g = Instance.new("BillboardGui")
	g.Name = "Dizzy"
	g.Size = UDim2.fromOffset(120, 60)
	g.StudsOffset = Vector3.new(0, 2.2, 0)
	g.LightInfluence = 0
	g.Adornee = head
	g.Parent = folder
	local stars = {}
	for i = 1, 3 do
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = Icons.Star
		img.Size = UDim2.fromOffset(30, 30)
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Parent = g
		stars[i] = img
	end
	local t0 = os.clock()
	local d = duration or 1.6
	task.spawn(function()
		while os.clock() - t0 < d and g.Parent do
			local t = os.clock() - t0
			for i, img in ipairs(stars) do
				local a = t * 6 + i * (math.pi * 2 / 3)
				img.Position = UDim2.new(0.5, math.cos(a) * 44, 0.5, math.sin(a) * 12)
				img.ZIndex = math.sin(a) > 0 and 2 or 1
			end
			task.wait()
		end
		g:Destroy()
	end)
end

-- Sound helper (cached instances under SoundService).
local cache: { [string]: Sound } = {}
function VFX.sound(id: string, volume: number?, pitch: number?)
	local key = id .. "/" .. tostring(pitch or 1)
	local s = cache[key]
	if not s then
		s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volume or 0.6
		s.PlaybackSpeed = pitch or 1
		s.Parent = SoundService
		cache[key] = s
	end
	SoundService:PlayLocalSound(s :: Sound)
end

return VFX
