-- Procedural life for critters (client only, on top of their keyframe Idle):
--  * animation state: Run while moving (speed-scaled), Happy after a happy hop, else Idle
--    (sets the local Anim / AnimSpeed attributes that CritterAnimator plays), dust from the feet
--  * per-species ambient effects (pollen, clover leaves, bubbles, embers, ... - CritterDefs.fx)
--  * "!" pop when a critter starts fleeing
--  * head turns towards the nearest player close by
--  * base critters do a happy hop with hearts every few seconds
--  * rarity auras: pulsing ground ring, orbiting light motes (Epic+), spinning halo (Legendary+)
-- Works through the rig's Motor6D C0 (Body / Head joints), which composes with the Animator.
-- Only critters near the camera are animated (LOD).

local Controller = {}

local LOD = 110 -- studs from the camera

function Controller.Start()
	local CollectionService = game:GetService("CollectionService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared:WaitForChild("Config"))
	local Textures = require(Shared:WaitForChild("Textures"))

	local Settings = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Settings"))
	local camera = workspace.CurrentCamera
	local INK = Color3.fromRGB(20, 14, 36)

	-- Per-species ambient effects (CritterDefs[species].fx). `at` = part name to emit from.
	local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
	local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
	local SPECIES_FX: { [string]: { [string]: any } } = {
		clover = { texture = SPARKLE, color = Color3.fromRGB(120, 230, 90), rate = 1.2, runRate = 6, size = 0.3, lifetime = 1.2, speed = 1, accel = Vector3.new(0, -1, 0), at = "Head" },
		pollen = { texture = SPARKLE, color = Color3.fromRGB(255, 225, 90), rate = 2, runRate = 10, size = 0.25, lifetime = 1, speed = 0.6, accel = Vector3.new(0, 0.6, 0), light = 1 },
		bubbles = { texture = Textures.Ring, color = Color3.fromRGB(190, 240, 255), rate = 1.2, runRate = 2, size = 0.35, lifetime = 1.6, speed = 1.2, accel = Vector3.new(0, 1.2, 0), at = "Head" },
		drips = { texture = SPARKLE, color = Color3.fromRGB(120, 200, 255), rate = 0.4, runRate = 9, size = 0.22, lifetime = 0.6, speed = 2, accel = Vector3.new(0, -12, 0) },
		embers = { texture = SPARKLE, color = Color3.fromRGB(255, 140, 40), rate = 4, runRate = 14, size = 0.3, lifetime = 0.9, speed = 2, accel = Vector3.new(0, 3, 0), light = 1 },
		smoke = { texture = SMOKE, color = Color3.fromRGB(90, 80, 80), rate = 1.5, runRate = 5, size = 0.9, lifetime = 1.4, speed = 1.5, accel = Vector3.new(0, 2, 0), transparency = 0.5 },
		spores = { texture = SPARKLE, color = Color3.fromRGB(140, 255, 220), rate = 3, runRate = 8, size = 0.28, lifetime = 2, speed = 0.5, accel = Vector3.new(0, 0.4, 0), light = 1, at = "Head" },
		petals = { texture = SPARKLE, color = Color3.fromRGB(255, 150, 210), rate = 2.5, runRate = 10, size = 0.35, lifetime = 1.6, speed = 1, accel = Vector3.new(0.5, -0.8, 0) },
		stars = { texture = Textures.Sparkle, color = Color3.fromRGB(200, 230, 255), rate = 5, runRate = 14, size = 0.45, lifetime = 1.2, speed = 1, accel = Vector3.new(0, 0.5, 0), light = 1 },
		shadow = { texture = SMOKE, color = Color3.fromRGB(60, 30, 90), rate = 4, runRate = 12, size = 1.1, lifetime = 1.2, speed = 0.8, accel = Vector3.new(0, 1, 0), transparency = 0.4 },
		runes = { texture = Textures.Sparkle, color = Color3.fromRGB(120, 255, 230), rate = 2.5, runRate = 6, size = 0.4, lifetime = 1.8, speed = 0.6, accel = Vector3.new(0, 0.8, 0), light = 1 },
	}
	local SPECIES_DEFAULT_FX = { CloverBun = "clover", Buzzpup = "pollen", Croaklet = "bubbles", Snapjaw = "drips" }

	type Life = {
		model: Model,
		root: BasePart,
		body: Motor6D?,
		bodyC0: CFrame?,
		head: Motor6D?,
		headC0: CFrame?,
		lastPos: Vector3,
		speed: number,
		phase: number,
		yaw: number,
		fleeing: boolean,
		lastAlert: number,
		inBase: boolean,
		nextHappy: number,
		happyT: number,
		dust: ParticleEmitter?,
		hearts: ParticleEmitter?,
		ring: BasePart?,
		ringSize: Vector3?,
		motes: { BasePart },
		halo: BillboardGui?,
		tier: number,
		size: number,
		fx: ParticleEmitter?,
		fxPreset: { [string]: any }?,
	}
	local lives: { [Model]: Life } = {}

	local function joint(model: Model, name: string): Motor6D?
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") and d.Name == name then
				return d
			end
		end
		return nil
	end

	local function alert(life: Life)
		local g = Instance.new("BillboardGui")
		g.Name = "FleeAlert"
		g.Size = UDim2.fromOffset(60, 70)
		g.StudsOffsetWorldSpace = Vector3.new(0, life.size + 1.2, 0)
		g.AlwaysOnTop = true
		g.LightInfluence = 0
		g.MaxDistance = 90
		g.Adornee = life.root
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = true
		t.Text = "!"
		t.TextColor3 = Color3.fromRGB(255, 220, 60)
		local s = Instance.new("UIStroke")
		s.Thickness = 4
		s.Color = INK
		s.Parent = t
		t.Parent = g
		local sc = Instance.new("UIScale")
		sc.Scale = 0.2
		sc.Parent = t
		g.Parent = Players.LocalPlayer.PlayerGui
		game:GetService("TweenService"):Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(0.7, function()
			game:GetService("TweenService"):Create(t, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			game:GetService("TweenService"):Create(s, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			task.wait(0.35)
			g:Destroy()
		end)
	end

	local function setup(model: Instance)
		if not model:IsA("Model") or lives[model] then
			return
		end
		-- with streaming the parts (and PrimaryPart) can arrive after the model itself
		local waited = 0
		repeat
			task.wait(0.1)
			waited += 0.1
		until (model.PrimaryPart and model:FindFirstChildWhichIsA("Motor6D", true)) or waited > 10 or not model.Parent
		local rarityName = model:GetAttribute("Rarity")
		local root = model.PrimaryPart
		if not rarityName or not root or model.Name == "CarriedCritter" then
			return -- guardians (no rarity) and carried critters are left alone
		end
		local _, bbox = model:GetBoundingBox()
		local r = Config.RarityByName[rarityName]
		local tier = r and r.tier or 1
		local color = r and r.color or Color3.new(1, 1, 1)
		local body = joint(model, "Body")
		local head = joint(model, "Head")
		local life: Life = {
			model = model,
			root = root,
			body = body,
			bodyC0 = body and body.C0,
			head = head,
			headC0 = head and head.C0,
			lastPos = root.Position,
			speed = 0,
			phase = math.random() * 10,
			yaw = 0,
			fleeing = false,
			lastAlert = 0,
			inBase = model:FindFirstAncestor("CritterDisplays") ~= nil,
			nextHappy = os.clock() + math.random(2, 8),
			happyT = -1,
			motes = {},
			tier = tier,
			size = bbox.Y,
		}
		-- dust from the feet
		local att = Instance.new("Attachment")
		att.Name = "LifeFeet"
		att.WorldPosition = root.Position - Vector3.new(0, bbox.Y * 0.35, 0)
		att.Parent = root
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
		dust.Rate = 0
		dust.Lifetime = NumberRange.new(0.35, 0.6)
		dust.Speed = NumberRange.new(1, 3)
		dust.SpreadAngle = Vector2.new(60, 20)
		dust.Size = NumberSequence.new(0.6, 1.6)
		dust.Color = ColorSequence.new(Color3.fromRGB(225, 210, 175))
		dust.Transparency = NumberSequence.new(0.4, 1)
		dust.Parent = att
		life.dust = dust
		-- species ambient effect
		local species = model:GetAttribute("Species")
		local defs = require(Shared:WaitForChild("CritterDefs"))
		local key = (species and defs[species] and defs[species].fx) or SPECIES_DEFAULT_FX[species or ""]
		local pr = key and SPECIES_FX[key]
		if pr then
			local src = (pr.at and model:FindFirstChild(pr.at, true)) or root
			if not src:IsA("BasePart") then
				src = root
			end
			local e = Instance.new("ParticleEmitter")
			e.Name = "SpeciesFx"
			e.Texture = pr.texture
			e.Color = ColorSequence.new(pr.color)
			e.Rate = pr.rate
			e.Lifetime = NumberRange.new(pr.lifetime * 0.7, pr.lifetime)
			e.Speed = NumberRange.new(pr.speed * 0.5, pr.speed)
			e.SpreadAngle = Vector2.new(60, 60)
			e.Acceleration = pr.accel
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, pr.size), NumberSequenceKeypoint.new(1, 0) })
			e.Transparency = NumberSequence.new(pr.transparency or 0.1, 1)
			e.LightEmission = pr.light or 0
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-60, 60)
			e.Parent = src
			life.fx = e
			life.fxPreset = pr
		end
		-- hearts for happy hops (base critters)
		if life.inBase then
			local h = Instance.new("ParticleEmitter")
			h.Texture = Textures.Heart
			h.Rate = 0
			h.Lifetime = NumberRange.new(0.8, 1.2)
			h.Speed = NumberRange.new(2, 4)
			h.SpreadAngle = Vector2.new(35, 35)
			h.EmissionDirection = Enum.NormalId.Top
			h.Acceleration = Vector3.new(0, 1, 0)
			h.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.7), NumberSequenceKeypoint.new(1, 0.3) })
			h.Color = ColorSequence.new(Color3.fromRGB(255, 90, 140))
			h.Transparency = NumberSequence.new(0, 1)
			h.LightEmission = 0.3
			h.Parent = root
			life.hearts = h
		end
		-- rarity aura
		local ring = model:FindFirstChild("RarityRing") :: BasePart?
		if ring then
			life.ring = ring
			life.ringSize = ring.Size
		end
		if tier >= 4 then
			for i = 1, (tier >= 6 and 4 or 3) do
				local m = Instance.new("Part")
				m.Name = "AuraMote"
				m.Shape = Enum.PartType.Ball
				m.Size = Vector3.new(0.35, 0.35, 0.35)
				m.Material = Enum.Material.Neon
				m.Color = color:Lerp(Color3.new(1, 1, 1), 0.3)
				m.Anchored = true
				m.CanCollide = false
				m.CanQuery = false
				m.CanTouch = false
				m.CastShadow = false
				m.Parent = model
				local trail0 = Instance.new("Attachment")
				trail0.Position = Vector3.new(0, 0.12, 0)
				trail0.Parent = m
				local trail1 = Instance.new("Attachment")
				trail1.Position = Vector3.new(0, -0.12, 0)
				trail1.Parent = m
				local tr = Instance.new("Trail")
				tr.Attachment0 = trail0
				tr.Attachment1 = trail1
				tr.Lifetime = 0.35
				tr.LightEmission = 1
				tr.Color = ColorSequence.new(color)
				tr.Transparency = NumberSequence.new(0.2, 1)
				tr.Parent = m
				table.insert(life.motes, m)
			end
		end
		if tier >= 5 then
			local g = Instance.new("BillboardGui")
			g.Name = "AuraHalo"
			local d = math.max(bbox.X, bbox.Y, bbox.Z) * 2.6
			g.Size = UDim2.new(d, 0, d, 0)
			g:SetAttribute("ScreenSpace", true)
			g.LightInfluence = 0
			g.AlwaysOnTop = false
			g.MaxDistance = 150
			g.Adornee = root
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = Textures.Sunburst
			img.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3)
			img.ImageTransparency = 0.35
			img.Size = UDim2.fromScale(1, 1)
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromScale(0.5, 0.5)
			img.Parent = g
			g.Parent = root
			life.halo = g
		end
		lives[model] = life
		model.Destroying:Connect(function()
			lives[model] = nil
		end)
	end

	CollectionService:GetInstanceAddedSignal("AnimatedCritter"):Connect(setup)
	CollectionService:GetInstanceRemovedSignal("AnimatedCritter"):Connect(function(m)
		lives[m] = nil
	end)
	for _, m in ipairs(CollectionService:GetTagged("AnimatedCritter")) do
		task.spawn(setup, m)
	end

	local function nearestPlayer(pos: Vector3): Vector3?
		local best, bd = nil, 18
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				local d = (hrp.Position - pos).Magnitude
				if d < bd then
					best, bd = hrp.Position, d
				end
			end
		end
		return best
	end

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local camPos = camera.CFrame.Position
		for model, life in pairs(lives) do
			local root = life.root
			if not model.Parent or not root.Parent then
				lives[model] = nil
				continue
			end
			local pos = root.Position
			if (pos - camPos).Magnitude > LOD then
				continue
			end
			-- smoothed horizontal speed
			local delta = Vector3.new(pos.X - life.lastPos.X, 0, pos.Z - life.lastPos.Z)
			life.lastPos = pos
			local inst = delta.Magnitude / math.max(dt, 1 / 240)
			life.speed += (inst - life.speed) * math.min(1, dt * 6)
			local speed = life.speed

			-- flee alert when a critter suddenly speeds up
			local fleeing = speed > 9
			if fleeing and not life.fleeing and now - life.lastAlert > 3 then
				life.lastAlert = now
				alert(life)
			end
			life.fleeing = fleeing
			local low = Settings.lowQuality()
			if life.dust then
				life.dust.Rate = (speed > 5 and not low) and speed * 2.5 or 0
			end

			-- happy hop in the base
			if life.inBase and now >= life.nextHappy then
				life.nextHappy = now + math.random(5, 10)
				life.happyT = now
				if life.hearts then
					life.hearts:Emit(math.random(3, 5))
				end
			end

			-- animation state (local attribute; CritterAnimator plays it): Run while moving (faster
			-- when fleeing), Happy for a moment after a happy hop, otherwise Idle
			local anim = "Idle"
			local animSpeed = 1
			if speed > 1.5 then
				anim = "Run"
				animSpeed = math.clamp(speed / 9, 0.6, 2.2)
			elseif now - life.happyT < 1 then
				anim = "Happy"
			end
			if model:GetAttribute("Anim") ~= anim then
				model:SetAttribute("Anim", anim)
			end
			if anim == "Run" and math.abs((model:GetAttribute("AnimSpeed") or 1) - animSpeed) > 0.15 then
				model:SetAttribute("AnimSpeed", animSpeed)
			elseif anim ~= "Run" and model:GetAttribute("AnimSpeed") ~= nil then
				model:SetAttribute("AnimSpeed", nil)
			end

			-- species effect: idle rate, stronger while running
			if life.fx and life.fxPreset then
				local pr = life.fxPreset
				life.fx.Rate = low and 0 or ((anim == "Run" and (pr.runRate or pr.rate) or pr.rate) or 0)
			end

			-- head: look towards a player close by
			if life.head and life.headC0 and life.head.Part0 then
				local targetYaw = 0
				local p = nearestPlayer(pos)
				if p and speed < 6 then
					local look = root.CFrame:PointToObjectSpace(p)
					targetYaw = math.clamp(math.atan2(-look.X, -look.Z), -0.7, 0.7)
				end
				life.yaw += (targetYaw - life.yaw) * math.min(1, dt * 5)
				local worldUp = (life.head.Part0.CFrame * life.headC0).Rotation:VectorToObjectSpace(Vector3.yAxis)
				life.head.C0 = life.headC0 * CFrame.fromAxisAngle(worldUp, life.yaw)
			end

			-- aura
			if life.ring and life.ringSize then
				local k = 1 + math.sin(now * 3 + life.phase) * 0.08
				life.ring.Size = Vector3.new(life.ringSize.X, life.ringSize.Y * k, life.ringSize.Z * k)
				life.ring.Transparency = 0.45 + math.sin(now * 3 + life.phase) * 0.15
			end
			if #life.motes > 0 then
				local rad = life.size * 0.9
				for i, m in ipairs(life.motes) do
					m.Transparency = low and 1 or 0
					local tr = m:FindFirstChildOfClass("Trail")
					if tr then
						tr.Enabled = not low
					end
					local a = now * 2.2 + i * (math.pi * 2 / #life.motes)
					m.CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * rad, life.size * 0.1 + math.sin(now * 3 + i) * life.size * 0.25, math.sin(a) * rad))
				end
			end
			if life.halo then
				life.halo.Enabled = not low
				local img = life.halo:FindFirstChildOfClass("ImageLabel")
				if img then
					img.Rotation = (now * 25) % 360
				end
			end
		end
	end)
end

return Controller
