-- Catching: picks the nearest wild critter, shows a spinning rarity reticle over it and a big
-- catch button, runs the timing bar and talks to the server (RequestCatch / SubmitCatch).
--  * reticle: rarity coloured, spins and tightens while the timing bar runs
--  * catch button: glow + pulse; Rare+ targets get a sunburst and a rainbow outline
--  * timing bar: stud track, glowing green zone with a gold PERFECT core, cursor with a ghost
--    trail, countdown strip, result stamp (PERFECT! / GOTCHA! / MISS!), shake on a miss
--  * focus: camera zooms in slightly and the screen edges darken while catching; camera punch on
--    a hit
-- Fires Bus.CatchState for other effects.

local Controller = {}

function Controller.Start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared:WaitForChild("Config"))
	local Icons = require(Shared:WaitForChild("Icons"))
	local Sounds = require(Shared:WaitForChild("Sounds"))
	local Textures = require(Shared:WaitForChild("Textures"))
	local Net = require(Shared:WaitForChild("Net"))
	local Modules = script.Parent.Parent:WaitForChild("Modules")
	local UIKit = require(Modules:WaitForChild("UIKit"))
	local VFX = require(Modules:WaitForChild("VFX"))
	local Bus = require(Modules:WaitForChild("Bus"))

	local RequestCatch = Net.func("RequestCatch")
	local SubmitCatch = Net.func("SubmitCatch")
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local GREEN = Color3.fromRGB(150, 255, 120)

	local gui = Instance.new("ScreenGui")
	gui.Name = "CatchHud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 1
	gui.Parent = player:WaitForChild("PlayerGui")

	-- focus vignette (full screen, behind the HUD bits)
	local focusGui = Instance.new("ScreenGui")
	focusGui.Name = "CatchFocus"
	focusGui.IgnoreGuiInset = true
	focusGui.ResetOnSpawn = false
	focusGui.DisplayOrder = 0
	focusGui.Parent = player.PlayerGui
	local vignette = Instance.new("Frame") -- four edge gradients darken the screen borders
	vignette.BackgroundTransparency = 1
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.Parent = focusGui
	local edges = {}
	for i, spec in ipairs({ { 90, UDim2.new(1, 0, 0.3, 0), UDim2.new() }, { 270, UDim2.new(1, 0, 0.3, 0), UDim2.new(0, 0, 0.7, 0) }, { 0, UDim2.new(0.25, 0, 1, 0), UDim2.new() }, { 180, UDim2.new(0.25, 0, 1, 0), UDim2.new(0.75, 0, 0, 0) } }) do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(20, 6, 40)
		f.Size = spec[2]
		f.Position = spec[3]
		f.BackgroundTransparency = 1
		local g = Instance.new("UIGradient")
		g.Rotation = spec[1]
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = f
		f.Parent = vignette
		edges[i] = f
	end

	local bottom = UIKit.area(gui, "Bottom", UDim2.fromOffset(600, 340), UDim2.new(0.5, 0, 1, -18), Vector2.new(0.5, 1))
	UIKit.autoScale({ bottom })

	--------------------------------------------------------------------------- catch button

	local wrap = Instance.new("Frame") -- pulse wrapper so it doesn't fight the hover scale
	wrap.Name = "CatchWrap"
	wrap.BackgroundTransparency = 1
	wrap.Size = UDim2.fromOffset(144, 144)
	wrap.Position = UDim2.new(0.5, 0, 1, -80)
	wrap.AnchorPoint = Vector2.new(0.5, 0.5)
	wrap.Parent = bottom
	local pulse = Instance.new("UIScale")
	pulse.Parent = wrap
	local catch = UIKit.button(wrap, {
		name = "Catch", size = UDim2.fromScale(1, 1), position = UDim2.fromScale(0.5, 0.5),
		color = UIKit.Colors.Green, radius = 72, depth = 8, shineInterval = 2.5,
	})
	local catchIcon = UIKit.icon(catch.face, Icons.Paw, { size = UDim2.fromScale(0.58, 0.58), position = UDim2.fromScale(0.5, 0.4), anchor = Vector2.new(0.5, 0.5), z = 6 })
	local catchLabel = UIKit.text(catch.face, {
		text = "CATCH", bold = true, size = UDim2.new(0.78, 0, 0.22, 0), position = UDim2.new(0.5, 0, 1, -16), anchor = Vector2.new(0.5, 1), z = 6,
	})
	local keyHint = UIKit.pill(catch.root, { name = "Key", size = UDim2.fromOffset(34, 34), position = UDim2.new(1, 6, 0, 2), anchor = Vector2.new(1, 0), radius = 10 })
	UIKit.text(keyHint.body, { text = "E", bold = true, size = UDim2.new(1, -8, 1, -8), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), strokeThickness = 2 })
	keyHint.holder.ZIndex = 9
	keyHint.holder.Visible = UserInputService.KeyboardEnabled
	local catchGlow = UIKit.glow(wrap, { size = UDim2.fromScale(2.1, 2.1), color = GREEN, transparency = 0.4, z = 0 })
	local catchBurst = UIKit.sunburst(wrap, { size = UDim2.fromScale(2.8, 2.8), color = Color3.fromRGB(255, 240, 160), transparency = 0.3, z = 0, speed = 40 })
	catchBurst.Visible = false
	local ringFx = Instance.new("ImageLabel") -- expanding ring that "breathes" out of the button
	ringFx.BackgroundTransparency = 1
	ringFx.Image = Textures.Ring
	ringFx.ImageColor3 = GREEN
	ringFx.AnchorPoint = Vector2.new(0.5, 0.5)
	ringFx.Position = UDim2.fromScale(0.5, 0.5)
	ringFx.ZIndex = 0
	ringFx.Parent = wrap
	wrap.Visible = false
	local catchStroke: UIStroke? = nil

	--------------------------------------------------------------------------- target chip

	local chip = UIKit.pill(bottom, { name = "Target", size = UDim2.fromOffset(300, 44), position = UDim2.new(0.5, 0, 1, -172), anchor = Vector2.new(0.5, 1), radius = 16, pattern = "Paws", patternTile = 40, patternTransparency = 0.85 })
	local chipText = UIKit.text(chip.body, { text = "", bold = true, size = UDim2.new(1, -24, 0.6, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), strokeThickness = 2.5 })
	local chipGradient = chip.body:FindFirstChildOfClass("UIGradient") :: UIGradient
	chip.holder.Visible = false

	--------------------------------------------------------------------------- timing bar

	local bar = UIKit.area(bottom, "TimingBar", UDim2.fromOffset(540, 140), UDim2.new(0.5, 0, 0, 0), Vector2.new(0.5, 0))
	bar.Visible = false
	local barScale = Instance.new("UIScale")
	barScale.Parent = bar
	local barTitle = UIKit.text(bar, { text = "TAP ON GREEN!", bold = true, size = UDim2.new(1, 0, 0, 40), position = UDim2.new(0.5, 0, 0, 0), anchor = Vector2.new(0.5, 0), strokeThickness = 4 })
	local track = UIKit.pill(bar, {
		name = "Track", size = UDim2.new(1, 0, 0, 56), position = UDim2.fromOffset(0, 52), radius = 28,
		top = Color3.fromRGB(30, 22, 60), bottom = Color3.fromRGB(60, 46, 110), pattern = "Stud", patternTransparency = 0.7, patternTile = 30,
	})
	local trackStroke = track.body:FindFirstChildOfClass("UIStroke")
	if trackStroke then
		trackStroke.Thickness = 4
	end
	local zone = Instance.new("Frame")
	zone.Name = "Zone"
	zone.BackgroundColor3 = Color3.new(1, 1, 1)
	zone.Size = UDim2.new(0.3, 0, 1, -12)
	zone.Position = UDim2.fromOffset(0, 6)
	zone.ZIndex = 4
	UIKit.corner(zone, 16)
	UIKit.gradient(zone, Color3.fromRGB(170, 255, 130), Color3.fromRGB(60, 195, 50))
	UIKit.stroke(zone, 2.5, Color3.fromRGB(220, 255, 210))
	zone.Parent = track.body
	local zoneGlow = UIKit.glow(zone, { size = UDim2.new(1.6, 0, 3, 0), color = GREEN, transparency = 0.5, z = 3 })
	local perfect = Instance.new("Frame")
	perfect.Name = "Perfect"
	perfect.BackgroundColor3 = Color3.new(1, 1, 1)
	perfect.Size = UDim2.new(0.3, 0, 1, -8)
	perfect.Position = UDim2.fromScale(0.5, 0.5)
	perfect.AnchorPoint = Vector2.new(0.5, 0.5)
	perfect.ZIndex = 5
	UIKit.corner(perfect, 10)
	UIKit.gradient(perfect, Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 170, 20))
	perfect.Parent = zone
	-- cursor + ghost trail
	local function cursorFrame(alpha: number, z: number): Frame
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BackgroundTransparency = alpha
		f.Size = UDim2.new(0, 16, 1, 24)
		f.Position = UDim2.new(0, 0, 0, -12)
		f.AnchorPoint = Vector2.new(0.5, 0)
		f.ZIndex = z
		UIKit.corner(f, 8)
		f.Parent = track.body
		return f
	end
	local ghosts = { cursorFrame(0.55, 6), cursorFrame(0.7, 6), cursorFrame(0.82, 6) }
	local cursor = cursorFrame(0, 8)
	UIKit.stroke(cursor, 3)
	local cursorIcon = UIKit.icon(cursor, Icons.Paw, { size = UDim2.fromOffset(34, 34), position = UDim2.new(0.5, 0, 0, -6), anchor = Vector2.new(0.5, 1), z = 9 })
	-- countdown strip
	local timer = UIKit.progressBar(bar, { size = UDim2.new(1, -60, 0, 12), position = UDim2.new(0.5, 0, 0, 120), anchor = Vector2.new(0.5, 0), radius = 6, stroke = 2, colors = UIKit.BarGold })
	timer.label.Visible = false

	--------------------------------------------------------------------------- world reticle

	local reticleGui = Instance.new("BillboardGui")
	reticleGui.Name = "CatchReticle"
	reticleGui.AlwaysOnTop = true
	reticleGui.LightInfluence = 0
	reticleGui.Size = UDim2.new(6, 0, 6, 0)
	reticleGui:SetAttribute("ScreenSpace", true) -- sized in studs already (BillboardScale opt-out)
	reticleGui.Enabled = false
	reticleGui.Parent = player.PlayerGui
	-- dark copy underneath = outline, so the reticle reads on bright ground and for white Commons
	local reticleShadow = Instance.new("ImageLabel")
	reticleShadow.BackgroundTransparency = 1
	reticleShadow.Image = Textures.Reticle
	reticleShadow.ImageColor3 = Color3.fromRGB(20, 14, 36)
	reticleShadow.ImageTransparency = 0.15
	reticleShadow.Size = UDim2.fromScale(1.07, 1.07)
	reticleShadow.AnchorPoint = Vector2.new(0.5, 0.5)
	reticleShadow.Position = UDim2.fromScale(0.5, 0.5)
	reticleShadow.ZIndex = 1
	reticleShadow.Parent = reticleGui
	local reticle = Instance.new("ImageLabel")
	reticle.BackgroundTransparency = 1
	reticle.Image = Textures.Reticle
	reticle.Size = UDim2.fromScale(1, 1)
	reticle.AnchorPoint = Vector2.new(0.5, 0.5)
	reticle.Position = UDim2.fromScale(0.5, 0.5)
	reticle.ZIndex = 2
	reticle.Parent = reticleGui

	local wild = workspace:WaitForChild("WildCritters")
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.85
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = workspace

	--------------------------------------------------------------------------- state

	type Active = { token: string, zoneStart: number, zoneSize: number, speed: number, t0: number, done: boolean }
	local target: Model? = nil
	local active: Active? = nil
	local busy = false
	local rareTarget = false
	local focus = 0 -- 0..1 focus effect strength
	local baseFov = camera.FieldOfView
	local punch = 0
	local applyingFov = false

	local function setRare(on: boolean, color: Color3?)
		catchBurst.Visible = on
		catchBurst.ImageColor3 = color and UIKit.lighter(color, 0.45) or Color3.fromRGB(255, 240, 160)
		catchGlow.ImageColor3 = (on and color) and UIKit.lighter(color, 0.3) or GREEN
		if on and not catchStroke then
			catchStroke = UIKit.rainbowStroke(catch.face, { thickness = 5 })
		elseif not on and catchStroke then
			catchStroke:Destroy()
			catchStroke = nil
			local own = catch.face:FindFirstChildOfClass("UIStroke")
			if own then
				own.Enabled = true
			end
		end
	end

	local function cursorPos(a: Active, t: number?): number
		local x = (((t or os.clock()) - a.t0) * a.speed) % 2 -- ping-pong 0..1
		return x <= 1 and x or 2 - x
	end

	local function resultStamp(text: string, top: Color3, bottomColor: Color3)
		local s = UIKit.stamp(bar, { text = text, position = UDim2.new(0.5, 0, 0, 20), size = UDim2.fromOffset(220, 56), top = top, bottom = bottomColor, z = 12 })
		task.delay(0.9, function()
			s.holder:Destroy()
		end)
	end

	local function shake(obj: GuiObject, strength: number)
		local base = obj.Position
		task.spawn(function()
			for i = 1, 8 do
				local k = strength * (1 - i / 8)
				obj.Position = base + UDim2.fromOffset(math.random(-10, 10) * k, math.random(-4, 4) * k)
				task.wait(0.03)
			end
			obj.Position = base
		end)
	end

	local function hideBar(delay: number)
		task.delay(delay, function()
			if not active then
				UIKit.tween(barScale, 0.15, { Scale = 0.6 })
				task.wait(0.15)
				if not active then
					bar.Visible = false
				end
			end
		end)
	end

	local function finishCatch(hit: boolean, near: boolean?, isPerfect: boolean?)
		local a = active
		if not a or a.done then
			return
		end
		a.done = true
		local result = SubmitCatch:InvokeServer(a.token, hit, near == true)
		active = nil
		busy = false
		if result and result.ok and result.success then
			punch = 1
			if isPerfect then
				resultStamp("PERFECT!", Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 160, 20))
				VFX.sound(Sounds.Fanfare, 0.4, 1.2)
			else
				resultStamp("GOTCHA!", Color3.fromRGB(150, 255, 120), Color3.fromRGB(50, 180, 40))
			end
			UIKit.pop(zone, 0.3)
			Bus.CatchState:Fire(isPerfect and "perfect" or "hit")
		elseif result and result.ok and result.near then
			Bus.CatchState:Fire("near")
		else
			resultStamp("MISS!", Color3.fromRGB(255, 120, 110), Color3.fromRGB(210, 40, 50))
			shake(track.holder, 1)
			if result and result.ok then
				Bus.Toast:Fire("It got away!", "warn")
			end
			Bus.CatchState:Fire("miss")
		end
		hideBar(0.75)
		Bus.CatchState:Fire("end")
	end

	local function startCatch()
		if busy or active or not target then
			return
		end
		busy = true
		local res = RequestCatch:InvokeServer(target:GetAttribute("CritterId"))
		if not res or not res.ok then
			busy = false
			if res and res.reason then
				Bus.Toast:Fire(res.reason, "warn")
			end
			return
		end
		local size = math.clamp(res.zone, 0.05, 1)
		local a: Active = {
			token = res.token,
			zoneStart = (size >= 1) and 0 or math.random() * (1 - size),
			zoneSize = size,
			speed = res.speed,
			t0 = os.clock(),
			done = false,
		}
		active = a
		zone.Position = UDim2.new(a.zoneStart, 0, 0, 6)
		zone.Size = UDim2.new(a.zoneSize, 0, 1, -12)
		barTitle.Text = res.guaranteed and "EASY CATCH - TAP!" or "TAP ON GREEN!"
		bar.Visible = true
		barScale.Scale = 0.6
		UIKit.tween(barScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		timer.set(1)
		UIKit.tween(timer.fill, Config.CatchTimeout - 1, { Size = UDim2.fromScale(0.02, 1) }, Enum.EasingStyle.Linear)
		VFX.sound(Sounds.Whoosh, 0.35, 1.4)
		Bus.CatchState:Fire("start", { target = target })
		task.delay(Config.CatchTimeout - 1, function()
			if active == a then
				finishCatch(false)
			end
		end)
	end

	local function press()
		local a = active
		if a then
			if os.clock() - a.t0 < 0.3 then
				return -- the tap that opened the bar doesn't count as the answer
			end
			local x = cursorPos(a)
			local hit = x >= a.zoneStart and x <= a.zoneStart + a.zoneSize
			local rel = (x - a.zoneStart) / math.max(a.zoneSize, 0.001)
			local isPerfect = hit and a.zoneSize < 1 and rel >= 0.35 and rel <= 0.65
			local gap = math.min(math.abs(x - a.zoneStart), math.abs(x - (a.zoneStart + a.zoneSize)))
			UIKit.pop(cursor, 0.4)
			finishCatch(hit, not hit and gap <= Config.NearMissMargin, isPerfect)
		else
			startCatch()
		end
	end

	catch.face.Activated:Connect(press)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
			press()
		end
	end)

	--------------------------------------------------------------------------- per frame

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local a = active
		if a then
			cursor.Position = UDim2.new(cursorPos(a), 0, 0, -12)
			for i, g in ipairs(ghosts) do
				g.Position = UDim2.new(cursorPos(a, now - i * 0.035), 0, 0, -12)
			end
			cursorIcon.Rotation = math.sin(now * 12) * 12
			zoneGlow.ImageTransparency = 0.45 + math.sin(now * 8) * 0.15
			barTitle.Rotation = math.sin(now * 6) * 2
		end

		-- target selection
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local best, bestD = nil, Config.CatchRange
		if hrp and not player:GetAttribute("Carrying") then
			for _, m in ipairs(wild:GetChildren()) do
				if m:IsA("Model") and m.PrimaryPart then
					local d = (m.PrimaryPart.Position - hrp.Position).Magnitude
					if d < bestD then
						best, bestD = m, d
					end
				end
			end
		end
		if not a then
			target = best
		end
		local shown = target ~= nil
		if shown and not wrap.Visible then
			UIKit.pop(catch.face, 0.25)
			VFX.sound(Sounds.Pop, 0.3, 1.3)
		end
		wrap.Visible = shown
		chip.holder.Visible = shown and not a
		highlight.Adornee = target
		reticleGui.Enabled = shown
		reticleGui.Adornee = target and target.PrimaryPart or nil

		-- button life: pulse, breathing ring
		pulse.Scale = shown and (1 + math.abs(math.sin(now * 3.5)) * (a and 0.09 or 0.04)) or 1
		local ringT = (now * 0.8) % 1
		ringFx.Size = UDim2.fromScale(1 + ringT * 0.9, 1 + ringT * 0.9)
		ringFx.ImageTransparency = 0.25 + ringT * 0.75
		catchLabel.Text = a and "NOW!" or "CATCH"
		catchIcon.Rotation = a and math.sin(now * 14) * 10 or 0

		if target then
			local rarity = target:GetAttribute("Rarity") or ""
			local mutation = target:GetAttribute("Mutation")
			local r = Config.RarityByName[rarity]
			local color = r and r.color or Color3.new(1, 1, 1)
			chipText.Text = ("%s%s %s"):format(mutation and (string.upper(mutation) .. " ") or "", string.upper(rarity), target.Name)
			chipGradient.Color = ColorSequence.new(UIKit.lighter(color, 0.1), UIKit.darker(color, 0.45))
			highlight.OutlineColor = UIKit.lighter(color, 0.4)
			highlight.FillColor = color
			reticle.ImageColor3 = (r and r.tier == 1) and Color3.new(1, 1, 1) or UIKit.lighter(color, 0.15)
			ringFx.ImageColor3 = (r and r.tier >= 3) and UIKit.lighter(color, 0.3) or GREEN
			-- reticle: spin, breathe; tighter and faster while catching
			local _, size = target:GetBoundingBox()
			local studs = math.max(size.X, size.Z) * (a and 1.5 or 2.1) + math.sin(now * 5) * 0.3
			reticleGui.Size = UDim2.new(studs, 0, studs, 0)
			reticle.Rotation = (reticle.Rotation + dt * (a and 220 or 60)) % 360
			reticleShadow.Rotation = reticle.Rotation
			local isRare = r ~= nil and r.tier >= 3
			if isRare ~= rareTarget then
				rareTarget = isRare
				setRare(isRare, color)
			end
		elseif rareTarget then
			rareTarget = false
			setRare(false)
		end

		-- focus effect + camera punch
		focus += ((a and 1 or 0) - focus) * math.min(1, dt * 6)
		for _, f in ipairs(edges) do
			f.BackgroundTransparency = 1 - focus * 0.55
		end
		punch = math.max(0, punch - dt * 3)
		if focus > 0.01 or punch > 0 then
			applyingFov = true
			camera.FieldOfView = baseFov - focus * 8 - math.sin(punch * math.pi) * 6
		elseif applyingFov then
			applyingFov = false
			camera.FieldOfView = baseFov
		else
			baseFov = camera.FieldOfView -- follow other changes (e.g. settings)
		end
	end)
end

return Controller
