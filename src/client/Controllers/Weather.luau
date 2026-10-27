-- Weather visuals (driven by the Workspace attribute "Weather" set by WeatherService):
--  Rain: blue streaks following the camera, heavier clouds
--  Snowstorm: drifting snow, heavier clouds
--  RainbowStorm: a big rainbow arc over the Meadow + colourful sparkles
-- The atmosphere/colour tint is blended in by the ZoneAmbience controller.

local RunService = game:GetService("RunService")

local Controller = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local function emitterPart(): Part
	local p = Instance.new("Part")
	p.Name = "WeatherEmitter"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(160, 1, 160)
	p.Parent = workspace
	return p
end

local function rain(parent: Part)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Rate = 700
	e.Lifetime = NumberRange.new(0.9, 1.2)
	e.Speed = NumberRange.new(70, 85)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(3, 3)
	e.Size = NumberSequence.new(0.18)
	e.Squash = NumberSequence.new(-3) -- stretch into streaks along the fall direction
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Color = ColorSequence.new(Color3.fromRGB(190, 220, 255))
	e.Transparency = NumberSequence.new(0.35)
	e.LightEmission = 0.3
	e.Parent = parent
end

local function snow(parent: Part)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Rate = 260
	e.Lifetime = NumberRange.new(5, 7)
	e.Speed = NumberRange.new(8, 12)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(3, 0, 1)
	e.Size = NumberSequence.new(0.45)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	e.Transparency = NumberSequence.new(0.1, 0.6)
	e.LightEmission = 0.4
	e.Parent = parent
end

local function sparkles(parent: Part)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Rate = 90
	e.Lifetime = NumberRange.new(3, 5)
	e.Speed = NumberRange.new(4, 8)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(40, 40)
	e.Size = NumberSequence.new(0.6, 0)
	e.LightEmission = 1
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 70)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 120)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 170, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 120, 255)),
	})
	e.Parent = parent
end

-- Big rainbow arc made of neon segments (local only, built once per storm).
local function rainbowArc(): Model
	local m = Instance.new("Model")
	m.Name = "Rainbow"
	local colors = {
		Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 230, 70),
		Color3.fromRGB(100, 220, 100), Color3.fromRGB(80, 170, 255), Color3.fromRGB(120, 110, 255), Color3.fromRGB(190, 110, 255),
	}
	local center = Vector3.new(0, -40, -560)
	local segs = 30
	for band, c in ipairs(colors) do
		local r = 300 - band * 9
		for i = 0, segs - 1 do
			local a0 = math.pi * i / segs
			local a1 = math.pi * (i + 1) / segs
			local p0 = center + Vector3.new(math.cos(a0) * r, math.sin(a0) * r, 0)
			local p1 = center + Vector3.new(math.cos(a1) * r, math.sin(a1) * r, 0)
			local part = Instance.new("Part")
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Material = Enum.Material.Neon
			part.Color = c
			part.Transparency = 0.45
			part.Size = Vector3.new(9.5, 1, (p1 - p0).Magnitude + 0.6)
			part.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
			part.Parent = m
		end
	end
	m.Parent = workspace
	return m
end

function Controller.Start()
	local camera = workspace.CurrentCamera
	local emitter: Part? = nil
	local arc: Model? = nil
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	local baseCover = clouds and clouds.Cover or 0.5
	local baseDensity = clouds and clouds.Density or 0.55

	local function apply()
		local weather = workspace:GetAttribute("Weather") or "Clear"
		if emitter then
			emitter:Destroy()
			emitter = nil
		end
		if arc then
			arc:Destroy()
			arc = nil
		end
		if clouds then
			local heavy = weather == "Rain" or weather == "Snowstorm"
			clouds.Cover = heavy and 0.85 or baseCover
			clouds.Density = heavy and 0.8 or baseDensity
			clouds.Color = weather == "Rain" and Color3.fromRGB(200, 205, 215) or Color3.new(1, 1, 1)
		end
		if weather == "Clear" then
			return
		end
		local e = emitterPart()
		if weather == "Rain" then
			rain(e)
		elseif weather == "Snowstorm" then
			snow(e)
		elseif weather == "RainbowStorm" then
			sparkles(e)
			arc = rainbowArc()
		end
		emitter = e
	end

	workspace:GetAttributeChangedSignal("Weather"):Connect(apply)
	apply()
	RunService.RenderStepped:Connect(function()
		if emitter then
			emitter.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 45, 0))
		end
	end)
end

return Controller
