-- Draws the effects the server reports via the Net "Fx" event, plus ambient effects:
--  world: catch burst, miss poof, deposit beam, speed-up, guardian wake/bonk, guardian Zzz/dust,
--         speed trails on players with Speed >= 1
--  HUD:   coins flying into the coin counter, catch card, chase warning, announcement banner

local Controller = {}

function Controller.Start()

	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared:WaitForChild("Config"))
	local Icons = require(Shared:WaitForChild("Icons"))
	local Sounds = require(Shared:WaitForChild("Sounds"))
	local UIKit = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UIKit"))
	local VFX = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("VFX"))

	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local Fx = require(Shared:WaitForChild("Net")).event("Fx")

	local RARITY_INDEX: { [string]: number } = {}
	for i, r in ipairs(Config.Rarities) do
		RARITY_INDEX[r.name] = i
	end
	local function rarityColor(name: string?): Color3
		local r = name and Config.RarityByName[name]
		return r and r.color or Color3.new(1, 1, 1)
	end
	local function nearMe(pos: Vector3, range: number): boolean
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		return hrp ~= nil and (hrp.Position - pos).Magnitude < range
	end
	local function characterOf(userId: number): Model?
		local plr = Players:GetPlayerByUserId(userId)
		return plr and plr.Character
	end

	--------------------------------------------------------------------------- overlay gui

	local fxGui = Instance.new("ScreenGui")
	fxGui.Name = "FxGui"
	fxGui.ResetOnSpawn = false
	fxGui.IgnoreGuiInset = true
	fxGui.ScreenInsets = Enum.ScreenInsets.None
	fxGui.DisplayOrder = 5
	fxGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	fxGui.Parent = player:WaitForChild("PlayerGui")

	local center = UIKit.area(fxGui, "Center", UDim2.fromOffset(600, 420), UDim2.new(0.5, 0, 0, 90), Vector2.new(0.5, 0))
	UIKit.autoScale({ center })

	--------------------------------------------------------------------------- coins fly into the HUD

	local function coinTarget(): (Vector2?, GuiObject?)
		local hud = player.PlayerGui:FindFirstChild("Hud") :: ScreenGui?
		local pill = hud and hud:FindFirstChild("Coins", true)
		local icon = pill and pill:FindFirstChildOfClass("ImageLabel")
		if not hud or not icon then
			return nil, nil
		end
		return hud.AbsolutePosition + icon.AbsolutePosition + icon.AbsoluteSize / 2, icon
	end

	local function flyCoins(worldPos: Vector3, amount: number)
		local target, icon = coinTarget()
		if not target then
			return
		end
		local screen, onScreen = camera:WorldToViewportPoint(worldPos + Vector3.new(0, 3, 0))
		local start = onScreen and Vector2.new(screen.X, screen.Y) or (camera.ViewportSize / 2)
		local n = math.clamp(math.floor(amount / 4), 4, 14)
		for i = 1, n do
			task.delay((i - 1) * 0.05, function()
				local c = Instance.new("ImageLabel")
				c.BackgroundTransparency = 1
				c.Image = Icons.Coin
				c.Size = UDim2.fromOffset(42, 42)
				c.AnchorPoint = Vector2.new(0.5, 0.5)
				local spread = Vector2.new(math.random(-70, 70), math.random(-60, 20))
				c.Position = UDim2.fromOffset(start.X, start.Y)
				c.ZIndex = 20
				c.Parent = fxGui
				-- burst out, then swoop into the counter
				local mid = start + spread
				UIKit.tween(c, 0.22, { Position = UDim2.fromOffset(mid.X, mid.Y), Rotation = math.random(-40, 40) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				task.wait(0.22)
				local tw = UIKit.tween(c, 0.45, { Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(30, 30) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				tw.Completed:Wait()
				c:Destroy()
				VFX.sound(Sounds.Coin, 0.35, 1 + i * 0.03)
				if icon then
					UIKit.pop(icon :: GuiObject, 0.12)
				end
			end)
		end
		-- "+amount" next to the counter
		task.delay(0.6, function()
			local plus = UIKit.text(fxGui, {
				text = "+" .. tostring(amount), bold = true, color = Color3.fromRGB(255, 225, 90),
				size = UDim2.fromOffset(140, 40), position = UDim2.fromOffset(target.X + 150, target.Y), anchor = Vector2.new(0, 0.5), z = 21,
				alignX = Enum.TextXAlignment.Left,
			})
			UIKit.tween(plus, 0.9, { Position = UDim2.fromOffset(target.X + 150, target.Y - 40), TextTransparency = 1 })
			task.delay(0.95, function()
				plus:Destroy()
			end)
		end)
	end

	--------------------------------------------------------------------------- catch card

	local function catchCard(d: { [string]: any })
		local color = rarityColor(d.rarity)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(420, 132)
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Position = UDim2.new(0.5, 0, 0, -160)
		holder.Parent = center
		local card = UIKit.pill(holder, {
			name = "Card", size = UDim2.fromOffset(380, 118), position = UDim2.new(0.5, 20, 0, 0), anchor = Vector2.new(0.5, 0),
			icon = Icons.Paw, iconScale = 1.05, radius = 22,
			top = UIKit.lighter(color, 0.15):Lerp(UIKit.PanelTop, 0.45), bottom = color:Lerp(UIKit.PanelBottom, 0.65),
		})
		UIKit.text(card.body, { text = "CAUGHT!", bold = true, size = UDim2.new(1, -110, 0, 26), position = UDim2.fromOffset(92, 10), alignX = Enum.TextXAlignment.Left, color = Color3.fromRGB(255, 225, 90) })
		UIKit.text(card.body, {
			text = (d.mutation and (d.mutation .. " ") or "") .. d.name, bold = true,
			size = UDim2.new(1, -110, 0, 36), position = UDim2.fromOffset(92, 36), alignX = Enum.TextXAlignment.Left,
		})
		local ribbon = UIKit.pill(card.body, {
			name = "Ribbon", size = UDim2.fromOffset(124, 28), position = UDim2.fromOffset(92, 78), radius = 10,
			top = UIKit.lighter(color, 0.2), bottom = color,
		})
		UIKit.text(ribbon.body, { text = string.upper(d.rarity), bold = true, size = UDim2.new(1, -10, 0.7, 0), position = UDim2.new(0.5, 0, 0.5, 0), anchor = Vector2.new(0.5, 0.5), strokeThickness = 2 })
		UIKit.text(card.body, {
			text = ("%.1f kg   +%s/s"):format(d.sizeKg, string.format("%.1f", d.income)),
			size = UDim2.new(1, -240, 0, 24), position = UDim2.fromOffset(226, 80), alignX = Enum.TextXAlignment.Left, strokeThickness = 2.5,
		})
		if d.isNew then
			local badge = UIKit.pill(holder, {
				name = "New", size = UDim2.fromOffset(86, 34), position = UDim2.new(1, -6, 0, -10), anchor = Vector2.new(1, 0), radius = 12,
				top = Color3.fromRGB(255, 110, 110), bottom = Color3.fromRGB(210, 40, 60),
			})
			badge.holder.Rotation = 8
			UIKit.text(badge.body, { text = "NEW!", bold = true, size = UDim2.new(1, -8, 0.7, 0), position = UDim2.new(0.5, 0, 0.5, 0), anchor = Vector2.new(0.5, 0.5), strokeThickness = 2 })
		end
		UIKit.tween(holder, 0.45, { Position = UDim2.new(0.5, 0, 0, 120) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local big = (RARITY_INDEX[d.rarity] or 1) >= 3
		VFX.sound((big or d.isNew) and Sounds.Fanfare or Sounds.Catch, big and 0.6 or 0.45)
		task.delay(2.6, function()
			UIKit.tween(holder, 0.35, { Position = UDim2.new(0.5, 0, 0, -170) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.wait(0.4)
			holder:Destroy()
		end)
	end

	--------------------------------------------------------------------------- chase warning

	local vignette = Instance.new("Frame")
	vignette.Name = "ChaseVignette"
	vignette.BackgroundTransparency = 1
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.Visible = false
	vignette.Parent = fxGui
	local edges = {}
	for i, spec in ipairs({
		{ UDim2.new(1, 0, 0.22, 0), UDim2.new(), 90 },
		{ UDim2.new(1, 0, 0.22, 0), UDim2.new(0, 0, 0.78, 0), 270 },
		{ UDim2.new(0.16, 0, 1, 0), UDim2.new(), 0 },
		{ UDim2.new(0.16, 0, 1, 0), UDim2.new(0.84, 0, 0, 0), 180 },
	}) do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
		f.Size = spec[1]
		f.Position = spec[2]
		local g = Instance.new("UIGradient")
		g.Rotation = spec[3]
		g.Transparency = NumberSequence.new(0.35, 1)
		g.Parent = f
		f.Parent = vignette
		edges[i] = f
	end
	local runBanner = UIKit.pill(center, {
		name = "Run", size = UDim2.fromOffset(400, 60), position = UDim2.new(0.5, 20, 0, 270), anchor = Vector2.new(0.5, 0),
		icon = Icons.Warning, iconScale = 1.4, top = Color3.fromRGB(255, 110, 90), bottom = Color3.fromRGB(190, 40, 50),
	})
	local runText = UIKit.text(runBanner.body, { text = "RUN HOME!", bold = true, size = UDim2.new(1, -80, 0.62, 0), position = UDim2.new(0, 62, 0.5, 0), anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left })
	runBanner.holder.Visible = false
	local chased = false

	RunService.RenderStepped:Connect(function()
		if chased then
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * 7)
			for _, f in ipairs(edges) do
				f.BackgroundTransparency = 0.25 + pulse * 0.35
			end
			runBanner.holder.Rotation = math.sin(os.clock() * 10) * 2
		end
	end)

	local function setChased(on: boolean, name: string?)
		chased = on
		vignette.Visible = on
		runBanner.holder.Visible = on
		if on then
			runText.Text = ("RUN HOME! %s is coming!"):format(name or "The guardian")
			UIKit.pop(runBanner.holder, 0.25)
			VFX.sound(Sounds.Whoosh, 0.6, 0.8)
		end
	end

	--------------------------------------------------------------------------- announcement banner

	local function announce(d: { [string]: any })
		local color = d.rarity and rarityColor(d.rarity) or Color3.fromRGB(255, 196, 40)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(560, 70)
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Position = UDim2.new(0.5, 0, 0, -100)
		holder.Parent = center
		local pill = UIKit.pill(holder, {
			name = "Announce", size = UDim2.fromOffset(520, 64), position = UDim2.new(0.5, 20, 0, 0), anchor = Vector2.new(0.5, 0),
			icon = d.icon or Icons.Star, iconScale = 1.45, radius = 20,
			top = UIKit.lighter(color, 0.2), bottom = color:Lerp(Color3.new(0, 0, 0), 0.25),
		})
		UIKit.text(pill.body, { text = d.text, bold = true, size = UDim2.new(1, -88, 0.56, 0), position = UDim2.new(0, 70, 0.5, 0), anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left })
		UIKit.shineSweep(pill.body, 20, 1.2)
		UIKit.tween(holder, 0.5, { Position = UDim2.new(0.5, 0, 0, 30) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		VFX.sound(Sounds.Fanfare, 0.55)
		task.delay(4.5, function()
			UIKit.tween(holder, 0.4, { Position = UDim2.new(0.5, 0, 0, -110) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.wait(0.45)
			holder:Destroy()
		end)
	end

	--------------------------------------------------------------------------- server events

	local handlers: { [string]: (any) -> () } = {
		Catch = function(d)
			local c = rarityColor(d.rarity)
			VFX.stars(d.pos + Vector3.new(0, 1.5, 0), c, 26)
			VFX.confetti(d.pos + Vector3.new(0, 1, 0), 16)
			VFX.shockwave(d.pos, c, 8)
			VFX.poof(d.pos, Color3.new(1, 1, 1))
		end,
		Miss = function(d)
			VFX.poof(d.pos)
			VFX.floatText(d.pos + Vector3.new(0, 3, 0), "?!", Color3.fromRGB(255, 120, 100))
			if nearMe(d.pos, 40) then
				VFX.sound(Sounds.Whoosh, 0.5, 1.2)
			end
		end,
		CatchCard = catchCard,
		Deposit = function(d)
			local c = rarityColor(d.rarity)
			VFX.beam(d.pos, c, 16, 5)
			VFX.stars(d.pos + Vector3.new(0, 2, 0), c, 18)
			VFX.shockwave(d.pos, c, 5)
			if nearMe(d.pos, 60) then
				VFX.sound(Sounds.Pop, 0.6)
			end
		end,
		Collect = function(d)
			VFX.stars(d.pos + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 215, 60), 22)
			VFX.shockwave(d.pos, Color3.fromRGB(255, 205, 50), 6)
			flyCoins(d.pos, d.amount)
		end,
		SpeedUp = function(d)
			local char = characterOf(d.userId)
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				local feet = hrp.Position - Vector3.new(0, 3, 0)
				VFX.shockwave(feet, Color3.fromRGB(90, 200, 255), 10)
				VFX.beam(feet, Color3.fromRGB(120, 220, 255), 14, 6)
				VFX.stars(hrp.Position, Color3.fromRGB(150, 230, 255), 30)
			end
			if d.userId == player.UserId then
				VFX.sound(Sounds.Fanfare, 0.5)
			end
		end,
		GuardianWake = function(d)
			VFX.shockwave(d.pos, Color3.fromRGB(255, 150, 60), 18)
			VFX.floatText(d.pos + Vector3.new(0, 18, 0), "!", Color3.fromRGB(255, 215, 60))
			if nearMe(d.pos, 80) then
				VFX.sound(Sounds.Whoosh, 0.7, 0.7)
			end
		end,
		Chased = function(d)
			setChased(d.on == true, d.name)
		end,
		Bonk = function(d)
			local char = characterOf(d.userId)
			local head = char and char:FindFirstChild("Head") :: BasePart?
			if char and head then
				VFX.dizzy(char, 1.8)
				VFX.stars(head.Position, Color3.fromRGB(255, 225, 90), 16)
				VFX.poof(head.Position - Vector3.new(0, 2.5, 0))
				if nearMe(head.Position, 60) then
					VFX.sound(Sounds.Whoosh, 0.7, 0.6)
				end
			end
		end,
		Announce = announce,
		WeatherMutate = function(d)
			local c = d.weather == "Frozen" and Color3.fromRGB(170, 225, 255) or Color3.fromHSV(math.random(), 0.7, 1)
			VFX.beam(d.pos, c, 18, 5)
			VFX.stars(d.pos + Vector3.new(0, 2, 0), c, 30)
			VFX.confetti(d.pos + Vector3.new(0, 1, 0), 20)
			VFX.shockwave(d.pos, c, 7)
			if nearMe(d.pos, 70) then
				VFX.sound(Sounds.Fanfare, 0.5)
			end
		end,
	}

	Fx.OnClientEvent:Connect(function(kind: string, data: any)
		local h = handlers[kind]
		if h then
			h(data)
		end
	end)

	--------------------------------------------------------------------------- guardian ambience

	local function zzz(model: Model)
		local head = model:FindFirstChild("Head", true) :: BasePart?
		if not head then
			return
		end
		local g = Instance.new("BillboardGui")
		g.Size = UDim2.fromOffset(60, 60)
		g.StudsOffsetWorldSpace = Vector3.new(math.random(-10, 10) / 10, 3, 0)
		g.Adornee = head
		g.LightInfluence = 0
		g.MaxDistance = 90
		g.Parent = player.PlayerGui
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = true
		t.Text = "Z"
		t.TextColor3 = Color3.fromRGB(200, 230, 255)
		t.Rotation = math.random(-20, 20)
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Color = Color3.fromRGB(20, 14, 36)
		s.Parent = t
		t.Parent = g
		UIKit.tween(g, 2.2, { StudsOffsetWorldSpace = g.StudsOffsetWorldSpace + Vector3.new(2, 5, 0), Size = UDim2.fromOffset(90, 90) }, Enum.EasingStyle.Sine)
		task.delay(1.4, function()
			UIKit.tween(t, 0.8, { TextTransparency = 1 })
			UIKit.tween(s, 0.8, { Transparency = 1 })
		end)
		task.delay(2.3, function()
			g:Destroy()
		end)
	end

	local dustEmitters: { [Model]: ParticleEmitter } = {}
	local function dust(model: Model): ParticleEmitter?
		local e = dustEmitters[model]
		if e and e.Parent then
			return e
		end
		local root = model.PrimaryPart
		if not root then
			return nil
		end
		local p = Instance.new("ParticleEmitter")
		p.Texture = "rbxasset://textures/particles/smoke_main.dds"
		p.Rate = 22
		p.Lifetime = NumberRange.new(0.5, 0.9)
		p.Speed = NumberRange.new(2, 5)
		p.SpreadAngle = Vector2.new(70, 20)
		p.EmissionDirection = Enum.NormalId.Back
		p.Size = NumberSequence.new(1.5, 4)
		p.Color = ColorSequence.new(Color3.fromRGB(205, 180, 130))
		p.Transparency = NumberSequence.new(0.35, 1)
		p.Enabled = false
		p.Parent = root
		dustEmitters[model] = p
		return p
	end

	task.spawn(function()
		local guardians = workspace:WaitForChild("Guardians", 30)
		if not guardians then
			return
		end
		while true do
			for _, m in ipairs(guardians:GetChildren()) do
				if m:IsA("Model") then
					local state = m:GetAttribute("State")
					if state == "Sleeping" and nearMe(m:GetPivot().Position, 120) then
						zzz(m)
					end
					local d = dust(m)
					if d then
						d.Enabled = state == "Chasing" or state == "Returning"
					end
				end
			end
			task.wait(1.1)
		end
	end)

	--------------------------------------------------------------------------- speed trails

	local function applyTrail(plr: Player)
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		local old = hrp:FindFirstChild("SpeedTrail")
		if old then
			old:Destroy()
		end
		local level = plr:GetAttribute("SpeedLevel") or 0
		if level < 1 then
			return
		end
		local a0 = hrp:FindFirstChild("TrailTop") or Instance.new("Attachment")
		a0.Name = "TrailTop"
		a0.Position = Vector3.new(0, 0.9, 0.4)
		a0.Parent = hrp
		local a1 = hrp:FindFirstChild("TrailBottom") or Instance.new("Attachment")
		a1.Name = "TrailBottom"
		a1.Position = Vector3.new(0, -1.6, 0.4)
		a1.Parent = hrp
		local t = Instance.new("Trail")
		t.Name = "SpeedTrail"
		t.Attachment0 = a0 :: Attachment
		t.Attachment1 = a1 :: Attachment
		t.Lifetime = 0.18 + 0.05 * math.min(level, 5)
		t.MinLength = 0.3
		t.LightEmission = 0.6
		t.FaceCamera = true
		t.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(110, 210, 255))
		t.Transparency = NumberSequence.new(0.35, 1)
		t.WidthScale = NumberSequence.new(1, 0.2)
		t.Parent = hrp
	end

	local function watch(plr: Player)
		plr.CharacterAdded:Connect(function()
			task.wait(0.5)
			applyTrail(plr)
		end)
		plr:GetAttributeChangedSignal("SpeedLevel"):Connect(function()
			applyTrail(plr)
		end)
		if plr.Character then
			applyTrail(plr)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, plr in ipairs(Players:GetPlayers()) do
		task.spawn(watch, plr)
	end
end

return Controller
