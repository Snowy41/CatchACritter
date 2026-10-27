-- Ambient life per zone around the camera (local only): drifting pollen and petals in the
-- Meadow and at home, glowing fireflies in the Swamp, rising embers and ash in the Volcano.
-- Each zone fades its own emitters in/out as the camera moves along the path.

local Controller = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

function Controller.Start()
	local RunService = game:GetService("RunService")
	local camera = workspace.CurrentCamera

	local box = Instance.new("Part")
	box.Name = "AmbientParticles"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Transparency = 1
	box.Size = Vector3.new(120, 30, 120)
	box.Parent = workspace

	local zones = {
		-- zMax/zMin along the path; emitters + their full Rate
		{ zMax = math.huge, zMin = -680, list = {
			{ emitter(box, { -- pollen
				Texture = SPARKLE, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180),
				Acceleration = Vector3.new(0.6, 0.3, 0), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(1, 0) }),
				Color = ColorSequence.new(Color3.fromRGB(255, 250, 200)), LightEmission = 0.8, Transparency = NumberSequence.new(0.2), RotSpeed = NumberRange.new(-40, 40),
			}), 20 },
			{ emitter(box, { -- petals
				Texture = SPARKLE, Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Bottom,
				Acceleration = Vector3.new(1.2, -0.4, 0.4), Size = NumberSequence.new(0.45), Squash = NumberSequence.new(0.6), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90),
				Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 200)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 240)) }),
				LightEmission = 0.3, Transparency = NumberSequence.new(0.1, 0.6),
			}), 6 },
		} },
		{ zMax = -680, zMin = -1120, list = {
			{ emitter(box, { -- fireflies
				Texture = SPARKLE, Lifetime = NumberRange.new(3, 6), Speed = NumberRange.new(0.3, 1.2), SpreadAngle = Vector2.new(180, 180),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.5), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(1, 0) }),
				Color = ColorSequence.new(Color3.fromRGB(190, 255, 120)), LightEmission = 1, Transparency = NumberSequence.new(0), Brightness = 2,
			}), 26 },
			{ emitter(box, { -- marsh mist
				Texture = SMOKE, Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(0.5, 1), SpreadAngle = Vector2.new(180, 10),
				Size = NumberSequence.new(6, 12), Color = ColorSequence.new(Color3.fromRGB(150, 210, 190)), Transparency = NumberSequence.new(0.85, 1),
			}), 4 },
		} },
		{ zMax = -1120, zMin = -math.huge, list = {
			{ emitter(box, { -- embers
				Texture = SPARKLE, Lifetime = NumberRange.new(2.5, 4.5), Speed = NumberRange.new(2, 5), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30),
				Acceleration = Vector3.new(0.8, 1.5, 0), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
				Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 20)), LightEmission = 1, Brightness = 2,
			}), 30 },
			{ emitter(box, { -- falling ash
				Texture = SPARKLE, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(1, 2), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(40, 40),
				Acceleration = Vector3.new(0.5, -0.3, 0), Size = NumberSequence.new(0.3), Color = ColorSequence.new(Color3.fromRGB(110, 100, 100)), Transparency = NumberSequence.new(0.3, 0.8),
			}), 10 },
		} },
	}
	for _, z in ipairs(zones) do
		for _, pair in ipairs(z.list) do
			pair[1].Rate = 0
		end
	end

	local weights: { number } = {}
	RunService.RenderStepped:Connect(function(dt)
		local pos = camera.CFrame.Position
		box.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
		for i, z in ipairs(zones) do
			-- fade over 40 studs at zone borders
			local inside = math.clamp(math.min(z.zMax - pos.Z, pos.Z - z.zMin) / 40 + 0.5, 0, 1)
			local w = weights[i] or 0
			w += (inside - w) * math.min(1, dt * 2)
			weights[i] = w
			for _, pair in ipairs(z.list) do
				pair[1].Rate = pair[2] * w
			end
		end
	end)
end

return Controller
