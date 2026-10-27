-- Small UI kit for the HUD: bright, saturated "simulator" look.
--  * pills: gradient panel (dark or themed colour) + soft drop shadow, icon overlapping the left
--    edge, optional tiled pattern (shared/Textures)
--  * 3D buttons: saturated gradient face with a star pattern on a darker lip, shine sweep, hover
--    grow, press sink
--  * text: bold game font with a thick dark outline, vertically centred helpers
--  * sunbursts: spinning rays behind rewards / buyables

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RunService = game:GetService("RunService")

local Sounds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sounds"))
local Textures = require(ReplicatedStorage.Shared:WaitForChild("Textures"))
local VFX -- lazily required (VFX lives next to this module)
local function click()
	VFX = VFX or require(script.Parent:WaitForChild("VFX"))
	VFX.sound(Sounds.Click, 0.5)
end

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne
UIKit.FontBold = Enum.Font.LuckiestGuy
UIKit.Ink = Color3.fromRGB(20, 14, 36) -- outline colour (matches the icon pack's dark outline)
UIKit.PanelTop = Color3.fromRGB(78, 58, 172)
UIKit.PanelBottom = Color3.fromRGB(40, 26, 104)
UIKit.Textures = Textures

UIKit.Colors = {
	Green = Color3.fromRGB(70, 222, 60),
	Blue = Color3.fromRGB(40, 150, 255),
	Gold = Color3.fromRGB(255, 186, 0),
	Red = Color3.fromRGB(255, 62, 72),
	Purple = Color3.fromRGB(162, 76, 255),
	Pink = Color3.fromRGB(255, 70, 170),
	Orange = Color3.fromRGB(255, 132, 20),
	Cyan = Color3.fromRGB(30, 205, 255),
}

-- Saturated two-tone gradients for panels, cards and pills (top, bottom).
UIKit.Themes = {
	Gold = { Color3.fromRGB(255, 214, 50), Color3.fromRGB(255, 140, 0) },
	Orange = { Color3.fromRGB(255, 170, 50), Color3.fromRGB(240, 90, 10) },
	Green = { Color3.fromRGB(130, 245, 80), Color3.fromRGB(30, 170, 40) },
	Blue = { Color3.fromRGB(90, 200, 255), Color3.fromRGB(20, 110, 240) },
	Cyan = { Color3.fromRGB(110, 240, 255), Color3.fromRGB(10, 160, 230) },
	Purple = { Color3.fromRGB(200, 120, 255), Color3.fromRGB(110, 40, 230) },
	Pink = { Color3.fromRGB(255, 130, 210), Color3.fromRGB(225, 30, 140) },
	Red = { Color3.fromRGB(255, 110, 100), Color3.fromRGB(215, 30, 50) },
	Navy = { Color3.fromRGB(70, 60, 170), Color3.fromRGB(34, 24, 96) },
}

local function darker(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end
local function lighter(c: Color3, f: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), f)
end
UIKit.darker = darker
UIKit.lighter = lighter

local function tween(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
UIKit.tween = tween

function UIKit.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius and UDim.new(0, radius) or UDim.new(0.3, 0)
	c.Parent = parent
	return c
end

function UIKit.stroke(parent: Instance, thickness: number?, color: Color3?, mode: Enum.ApplyStrokeMode?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or UIKit.Ink
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

function UIKit.gradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = parent
	return g
end

-- Text with a thick outline. `bold` = chunky display font (numbers, buttons, titles).
-- Default placement: fills the parent; pass position/size/anchor to override.
function UIKit.text(parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = props.bold and UIKit.FontBold or UIKit.Font
	t.TextScaled = true
	t.TextColor3 = props.color or Color3.new(1, 1, 1)
	t.Text = props.text or ""
	t.Size = props.size or UDim2.fromScale(1, 1)
	-- Optical centring: both fonts reserve descender space below the baseline, so capitals and
	-- digits sit above the geometric centre. Shift the label down by a share of its own height.
	local k = props.bold and 0.1 or 0.05
	local sz = t.Size
	t.Position = (props.position or UDim2.new()) + UDim2.new(0, 0, sz.Y.Scale * k, sz.Y.Offset * k)
	t.AnchorPoint = props.anchor or Vector2.zero
	t.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.ZIndex = props.z or 4
	UIKit.stroke(t, props.strokeThickness or 3, props.strokeColor or UIKit.Ink, Enum.ApplyStrokeMode.Contextual)
	t.Parent = parent
	return t
end

function UIKit.icon(parent: Instance, image: string, props: { [string]: any }): ImageLabel
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Image = image
	i.ScaleType = Enum.ScaleType.Fit
	i.Size = props.size or UDim2.fromScale(1, 1)
	i.Position = props.position or UDim2.new()
	i.AnchorPoint = props.anchor or Vector2.zero
	i.Rotation = props.rotation or 0
	i.ZIndex = props.z or 5
	i.Parent = parent
	return i
end

-- Diagonal light sweep across a rounded face, repeating every `interval` seconds.
function UIKit.shineSweep(face: GuiObject, radius: number?, interval: number?)
	local overlay = Instance.new("Frame")
	overlay.Name = "Sweep"
	overlay.BackgroundColor3 = Color3.new(1, 1, 1)
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = face.ZIndex + 1
	overlay.Active = false
	UIKit.corner(overlay, radius)
	local g = Instance.new("UIGradient")
	g.Rotation = 20
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Offset = Vector2.new(-1, 0)
	g.Parent = overlay
	overlay.Parent = face
	task.spawn(function()
		task.wait(math.random() * (interval or 3.5))
		while overlay.Parent do
			g.Offset = Vector2.new(-1, 0)
			local tw = tween(g, 0.7, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			tw.Completed:Wait()
			task.wait(interval or 3.5)
		end
	end)
	return overlay
end

-- Rounded panel with drop shadow and an optional icon overlapping the left edge.
-- Returns { holder = Frame (position/visibility), body = Frame (put content here), icon = ImageLabel? }
function UIKit.pill(parent: Instance, props: { [string]: any })
	local radius = props.radius or 16
	local holder = Instance.new("Frame")
	holder.Name = props.name or "Pill"
	holder.BackgroundTransparency = 1
	holder.Size = props.size
	holder.Position = props.position or UDim2.new()
	holder.AnchorPoint = props.anchor or Vector2.zero

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.7
	shadow.BorderSizePixel = 0
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.fromOffset(0, 5)
	shadow.ZIndex = 1
	UIKit.corner(shadow, radius)
	shadow.Parent = holder

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundColor3 = Color3.new(1, 1, 1)
	body.Size = UDim2.fromScale(1, 1)
	body.ZIndex = 2
	UIKit.corner(body, radius)
	UIKit.gradient(body, props.top or UIKit.PanelTop, props.bottom or UIKit.PanelBottom)
	UIKit.stroke(body, 3)
	body.Parent = holder

	if props.pattern then
		UIKit.pattern(body, props.pattern, { radius = radius, transparency = props.patternTransparency or 0.86, tile = props.patternTile })
	end

	local hl = Instance.new("Frame")
	hl.Name = "Highlight"
	hl.BackgroundColor3 = Color3.new(1, 1, 1)
	hl.BackgroundTransparency = 0.82
	hl.BorderSizePixel = 0
	hl.Size = UDim2.new(1, -2 * radius, 0, 3)
	hl.Position = UDim2.new(0, radius, 0, 4)
	hl.ZIndex = 3
	UIKit.corner(hl, 2)
	hl.Parent = body

	local icon
	if props.icon then
		local h = holder.Size.Y.Offset
		local s = h * (props.iconScale or 1.3)
		icon = UIKit.icon(holder, props.icon, {
			size = UDim2.fromOffset(s, s),
			position = UDim2.new(0, -s * 0.38, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			z = 6,
		})
	end
	holder.Parent = parent
	return { holder = holder, body = body, icon = icon }
end

-- 3D button: darker lip underneath, gradient face, static shine + periodic sweep,
-- grows on hover, sinks + shrinks on press.
-- Returns { root = Frame, face = TextButton }
function UIKit.button(parent: Instance, props: { [string]: any })
	local color: Color3 = props.color or UIKit.Colors.Green
	local depth = props.depth or 6
	local radius = props.radius

	local root = Instance.new("Frame")
	root.Name = props.name or "Button"
	root.BackgroundTransparency = 1
	root.Size = props.size
	root.Position = props.position or UDim2.new()
	root.AnchorPoint = props.anchor or Vector2.new(0.5, 0.5)
	local scale = Instance.new("UIScale")
	scale.Name = "HoverScale"
	scale.Parent = root

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.72
	shadow.BorderSizePixel = 0
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.fromOffset(0, depth + 5)
	shadow.ZIndex = 1
	UIKit.corner(shadow, radius)
	shadow.Parent = root

	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.Size = UDim2.fromScale(1, 1)
	lip.Position = UDim2.fromOffset(0, depth)
	lip.BackgroundColor3 = darker(color, 0.55)
	lip.ZIndex = 2
	UIKit.corner(lip, radius)
	UIKit.stroke(lip, 3)
	lip.Parent = root

	local face = Instance.new("TextButton")
	face.Name = "Face"
	face.Text = ""
	face.AutoButtonColor = false
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.ZIndex = 3
	UIKit.corner(face, radius)
	UIKit.gradient(face, lighter(color, 0.3), color)
	UIKit.stroke(face, 3)
	face.Parent = root

	-- static gloss on the upper part of the face
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BorderSizePixel = 0
	gloss.Size = UDim2.new(1, -12, 0.42, 0)
	gloss.Position = UDim2.new(0, 6, 0, 5)
	gloss.ZIndex = 3
	UIKit.corner(gloss, radius and math.max(radius - 5, 4) or nil)
	local gg = Instance.new("UIGradient")
	gg.Rotation = 90
	gg.Transparency = NumberSequence.new(0.55, 1)
	gg.Parent = gloss
	gloss.Parent = face

	if props.pattern ~= false then
		UIKit.pattern(face, props.pattern or "Paws", { radius = radius, transparency = props.patternTransparency or 0.8, tile = props.patternTile or 46 })
	end
	UIKit.shineSweep(face, radius, props.shineInterval)

	-- soft glow behind the button while hovered
	local glow = Instance.new("ImageLabel")
	glow.Name = "HoverGlow"
	glow.BackgroundTransparency = 1
	glow.Image = Textures.Glow
	glow.ImageColor3 = lighter(color, 0.4)
	glow.ImageTransparency = 1
	glow.Size = UDim2.new(1.9, 0, 1.9, 0)
	glow.Position = UDim2.fromScale(0.5, 0.55)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.ZIndex = 0
	glow.Parent = root

	local hovered, pressed = false, false
	local function refresh()
		tween(scale, 0.14, { Scale = pressed and 0.95 or (hovered and 1.07 or 1) }, Enum.EasingStyle.Back)
		tween(face, 0.06, { Position = UDim2.fromOffset(0, pressed and depth - 1 or 0) })
		tween(glow, 0.2, { ImageTransparency = hovered and 0.35 or 1 })
	end
	face.ClipsDescendants = true
	face.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			UIKit.ripple(face, Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	face.MouseEnter:Connect(function()
		hovered = true
		refresh()
	end)
	face.MouseLeave:Connect(function()
		hovered, pressed = false, false
		refresh()
	end)
	face.MouseButton1Down:Connect(function()
		pressed = true
		refresh()
	end)
	face.MouseButton1Up:Connect(function()
		pressed = false
		refresh()
	end)
	face.Activated:Connect(function()
		pressed = false
		refresh()
		click()
	end)

	root.Parent = parent
	return { root = root, face = face }
end

-- Re-tints a UIKit.button (only call on change, not every frame).
function UIKit.setButtonColor(button, color: Color3)
	local g = button.face:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(lighter(color, 0.3), color)
	end
	local lip = button.root:FindFirstChild("Lip") :: Frame?
	if lip then
		lip.BackgroundColor3 = darker(color, 0.55)
	end
end

-- Scale bounce, e.g. when a value changes.
function UIKit.pop(obj: GuiObject, amount: number?)
	local s = obj:FindFirstChild("PopScale") :: UIScale?
	if not s then
		s = Instance.new("UIScale")
		s.Name = "PopScale"
		s.Parent = obj
	end
	local scale = s :: UIScale
	scale.Scale = 1 + (amount or 0.18)
	tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Uniform scaling for phones and large monitors: each HUD area is anchored to its screen
-- edge, a UIScale on it scales around that anchor.
function UIKit.autoScale(containers: { GuiObject })
	local camera = workspace.CurrentCamera
	local scales = {}
	for _, c in ipairs(containers) do
		local s = Instance.new("UIScale")
		s.Parent = c
		table.insert(scales, s)
	end
	local function update()
		local v = math.clamp(camera.ViewportSize.Y / 900, 0.62, 1.25)
		for _, s in ipairs(scales) do
			s.Scale = v
		end
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
end

-- Tiled white pattern over a frame (stars, studs, triangles ...), clipped to its rounded corners.
function UIKit.pattern(parent: GuiObject, name: string, props: { [string]: any }?): ImageLabel
	local o = props or {}
	local img = Instance.new("ImageLabel")
	img.Name = "Pattern"
	img.BackgroundTransparency = 1
	img.Image = Textures[name] or name
	img.ScaleType = Enum.ScaleType.Tile
	local tile = o.tile or 56
	img.TileSize = UDim2.fromOffset(tile, tile)
	img.ImageColor3 = o.color or Color3.new(1, 1, 1)
	img.ImageTransparency = o.transparency or 0.85
	img.Size = UDim2.fromScale(1, 1)
	img.ZIndex = o.z or parent.ZIndex
	img.Active = false
	if o.radius then
		UIKit.corner(img, o.radius)
	end
	img.Parent = parent
	return img
end

-- Spinning sunburst rays behind an item (rewards, buyables, eggs). Returns the ImageLabel.
local spinning: { [ImageLabel]: number } = {}
RunService.RenderStepped:Connect(function(dt)
	for img, speed in pairs(spinning) do
		if img.Parent then
			img.Rotation = (img.Rotation + speed * dt) % 360
		else
			spinning[img] = nil
		end
	end
end)
function UIKit.sunburst(parent: Instance, props: { [string]: any }): ImageLabel
	local img = Instance.new("ImageLabel")
	img.Name = "Sunburst"
	img.BackgroundTransparency = 1
	img.Image = Textures.Sunburst
	img.ImageColor3 = props.color or Color3.fromRGB(255, 240, 160)
	img.ImageTransparency = props.transparency or 0.2
	img.Size = props.size or UDim2.fromScale(1.6, 1.6)
	img.Position = props.position or UDim2.fromScale(0.5, 0.5)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.ZIndex = props.z or 1
	img.Parent = parent
	spinning[img] = props.speed or 25
	return img
end

--------------------------------------------------------------------------- effects

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 90)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(60, 170, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(170, 90, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 70)),
})
UIKit.Rainbow = RAINBOW

local rotating: { [UIGradient]: number } = {}
local bobbing: { [GuiObject]: { base: UDim2, amp: number, speed: number, phase: number } } = {}
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	for g, speed in pairs(rotating) do
		if g.Parent then
			g.Rotation = (g.Rotation + speed * dt) % 360
		else
			rotating[g] = nil
		end
	end
	for obj, b in pairs(bobbing) do
		if obj.Parent then
			obj.Position = b.base + UDim2.fromOffset(0, math.sin(t * b.speed + b.phase) * b.amp)
		else
			bobbing[obj] = nil
		end
	end
end)

-- Animated rainbow outline (premium / special items). Replaces the object's own UIStroke look.
function UIKit.rainbowStroke(obj: GuiObject, props: { [string]: any }?): UIStroke
	local o = props or {}
	local st = Instance.new("UIStroke")
	st.Name = "RainbowStroke"
	st.Thickness = o.thickness or 4
	st.Color = Color3.new(1, 1, 1)
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.LineJoinMode = Enum.LineJoinMode.Round
	local old = obj:FindFirstChildOfClass("UIStroke")
	if old and old ~= st then
		old.Enabled = false
	end
	local g = Instance.new("UIGradient")
	g.Color = o.colors or RAINBOW
	g.Parent = st
	st.Parent = obj
	rotating[g] = o.speed or 120
	return st
end

-- Rotating gradient sheen on a frame's own gradient (e.g. a premium card background).
function UIKit.spinGradient(g: UIGradient, speed: number?)
	rotating[g] = speed or 40
end

-- Soft round glow behind something.
function UIKit.glow(parent: Instance, props: { [string]: any }): ImageLabel
	local img = Instance.new("ImageLabel")
	img.Name = "Glow"
	img.BackgroundTransparency = 1
	img.Image = Textures.Glow
	img.ImageColor3 = props.color or Color3.fromRGB(255, 240, 160)
	img.ImageTransparency = props.transparency or 0.3
	img.Size = props.size or UDim2.fromScale(1.8, 1.8)
	img.Position = props.position or UDim2.fromScale(0.5, 0.5)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.ZIndex = props.z or 1
	img.Parent = parent
	return img
end

-- Gentle idle bob (icons, rewards).
function UIKit.bob(obj: GuiObject, amp: number?, speed: number?)
	bobbing[obj] = { base = obj.Position, amp = amp or 3, speed = speed or 2.2, phase = math.random() * 6 }
end

-- Sparkles that pop up across a frame and fade, while it is visible. Stops when destroyed.
function UIKit.sparkles(parent: GuiObject, props: { [string]: any }?)
	local o = props or {}
	local rate = o.rate or 3 -- per second
	local colors = o.colors or { Color3.new(1, 1, 1), Color3.fromRGB(255, 240, 150) }
	task.spawn(function()
		while parent.Parent do
			task.wait(1 / rate * (0.6 + math.random() * 0.8))
			local onScreen = parent.Visible and parent.AbsoluteSize.X > 0
			local anc = parent:FindFirstAncestorWhichIsA("LayerCollector")
			if onScreen and anc and anc.Enabled then
				local sp = Instance.new("ImageLabel")
				sp.BackgroundTransparency = 1
				sp.Image = Textures.Sparkle
				sp.ImageColor3 = colors[math.random(1, #colors)]
				local size = math.random(o.minSize or 14, o.maxSize or 30)
				sp.Size = UDim2.fromOffset(0, 0)
				sp.AnchorPoint = Vector2.new(0.5, 0.5)
				sp.Position = UDim2.fromScale(math.random(), math.random())
				sp.Rotation = math.random(0, 90)
				sp.ZIndex = o.z or (parent.ZIndex + 5)
				sp.Parent = parent
				tween(sp, 0.35, { Size = UDim2.fromOffset(size, size), Rotation = sp.Rotation + 45 }, Enum.EasingStyle.Back)
				task.delay(0.45, function()
					local tw = tween(sp, 0.5, { Size = UDim2.fromOffset(0, 0), ImageTransparency = 1, Rotation = sp.Rotation + 45 })
					tw.Completed:Wait()
					sp:Destroy()
				end)
			end
		end
	end)
end

-- Notched ribbon banner ("LIMITED!", "BEST VALUE", "NEW!"), 9-sliced so it fits any width.
function UIKit.ribbon(parent: Instance, props: { [string]: any })
	local holder = Instance.new("Frame")
	holder.Name = props.name or "Ribbon"
	holder.BackgroundTransparency = 1
	holder.Size = props.size or UDim2.fromOffset(150, 38)
	holder.Position = props.position or UDim2.new()
	holder.AnchorPoint = props.anchor or Vector2.new(0.5, 0.5)
	holder.Rotation = props.rotation or 0
	holder.ZIndex = props.z or 9
	holder.Parent = parent
	local img = Instance.new("ImageLabel")
	img.Name = "Band"
	img.BackgroundTransparency = 1
	img.Image = Textures.Ribbon
	img.ScaleType = Enum.ScaleType.Slice
	img.SliceCenter = Rect.new(48, 24, 464, 104)
	img.SliceScale = 0.32
	img.ImageColor3 = props.color or Color3.fromRGB(255, 70, 90)
	img.Size = UDim2.fromScale(1, 1)
	img.ZIndex = holder.ZIndex
	img.Parent = holder
	if props.rainbow then
		local g = Instance.new("UIGradient")
		g.Color = RAINBOW
		g.Parent = img
		rotating[g] = 0 -- registered so it is cleaned up; offset animation below
		task.spawn(function()
			while g.Parent do
				g.Offset = Vector2.new(((os.clock() * 0.4) % 2) - 1, 0)
				task.wait()
			end
		end)
	end
	local label = UIKit.text(holder, {
		text = props.text or "", bold = true, size = UDim2.new(1, -36, 0.62, 0), position = UDim2.fromScale(0.5, 0.46),
		anchor = Vector2.new(0.5, 0.5), z = holder.ZIndex + 1, strokeThickness = 2.5,
	})
	return { holder = holder, band = img, label = label }
end

-- Click ripple: a white circle expanding from the input point inside a button face.
function UIKit.ripple(face: GuiObject, screenPos: Vector2)
	local r = Instance.new("Frame")
	r.BackgroundColor3 = Color3.new(1, 1, 1)
	r.BackgroundTransparency = 0.55
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	local rel = screenPos - face.AbsolutePosition
	r.Position = UDim2.fromOffset(rel.X, rel.Y)
	r.Size = UDim2.fromOffset(0, 0)
	r.ZIndex = face.ZIndex + 3
	UIKit.corner(r, 999)
	r.Parent = face
	local d = math.max(face.AbsoluteSize.X, face.AbsoluteSize.Y) * 2.2
	tween(r, 0.45, { Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1 })
	task.delay(0.5, function()
		r:Destroy()
	end)
end

-- Pops a list of GuiObjects in one after another (cards when a panel opens).
function UIKit.staggerIn(objects: { GuiObject }, step: number?)
	for i, obj in ipairs(objects) do
		local s = obj:FindFirstChild("EnterScale") :: UIScale?
		if not s then
			s = Instance.new("UIScale")
			;(s :: UIScale).Name = "EnterScale"
			;(s :: UIScale).Parent = obj
		end
		;(s :: UIScale).Scale = 0.01
		task.delay((i - 1) * (step or 0.05), function()
			tween(s :: UIScale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
end

-- Glossy progress bar: dark rounded track, gradient fill with a highlight stripe, centred label.
-- Returns { root, fill, label, set(fraction, text?, color?) }; fill animates.
UIKit.BarGold = { Color3.fromRGB(255, 225, 90), Color3.fromRGB(240, 150, 20) }
UIKit.BarGreen = { Color3.fromRGB(150, 255, 120), Color3.fromRGB(60, 190, 50) }
UIKit.BarPurple = { Color3.fromRGB(215, 160, 255), Color3.fromRGB(140, 70, 230) }
UIKit.BarPink = { Color3.fromRGB(255, 160, 220), Color3.fromRGB(225, 70, 160) }
function UIKit.progressBar(parent: Instance, props: { [string]: any })
	local radius = props.radius or 10
	local track = Instance.new("Frame")
	track.Name = props.name or "Bar"
	track.BackgroundColor3 = Color3.fromRGB(20, 14, 40)
	track.Size = props.size or UDim2.new(1, 0, 0, 22)
	track.Position = props.position or UDim2.new()
	track.AnchorPoint = props.anchor or Vector2.zero
	track.ZIndex = props.z or 4
	UIKit.corner(track, radius)
	UIKit.stroke(track, props.stroke or 2.5)
	track.Parent = parent
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = track.ZIndex + 1
	UIKit.corner(fill, radius)
	local colors = props.colors or UIKit.BarGold
	local grad = UIKit.gradient(fill, colors[1], colors[2])
	fill.Parent = track
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.6
	shine.BorderSizePixel = 0
	shine.Size = UDim2.new(1, -8, 0.22, 0)
	shine.Position = UDim2.new(0, 4, 0.12, 0)
	shine.ZIndex = fill.ZIndex
	UIKit.corner(shine, radius)
	shine.Parent = fill
	local label = UIKit.text(track, {
		text = props.text or "", bold = true, size = UDim2.new(1, -10, 0.86, 0), position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5), z = track.ZIndex + 2, strokeThickness = 2,
	})
	local bar = { root = track, fill = fill, label = label }
	function bar.set(fraction: number, text: string?, newColors: { Color3 }?)
		local f = math.clamp(fraction, 0, 1)
		fill.Visible = f > 0
		UIKit.tween(fill, 0.35, { Size = UDim2.fromScale(math.max(f, 0.06), 1) }, Enum.EasingStyle.Quart)
		if text then
			label.Text = text
		end
		if newColors then
			grad.Color = ColorSequence.new(newColors[1], newColors[2])
		end
	end
	return bar
end

-- Darker recessed area inside a panel (groups content visually).
function UIKit.inset(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.Name = props.name or "Inset"
	f.BackgroundColor3 = props.color or Color3.fromRGB(24, 17, 46)
	f.BackgroundTransparency = props.transparency or 0.35
	f.Size = props.size or UDim2.fromScale(1, 1)
	f.Position = props.position or UDim2.new()
	f.AnchorPoint = props.anchor or Vector2.zero
	f.ZIndex = props.z or 3
	UIKit.corner(f, props.radius or 16)
	local s = UIKit.stroke(f, 2, Color3.fromRGB(90, 70, 150))
	s.Transparency = 0.4
	f.Parent = parent
	return f
end

-- Tilted rubber stamp ("DONE!", "NEW!", "MAX") that slams in with a bounce.
function UIKit.stamp(parent: Instance, props: { [string]: any })
	local s = UIKit.pill(parent, {
		name = props.name or "Stamp", size = props.size or UDim2.fromOffset(110, 38), position = props.position, anchor = props.anchor or Vector2.new(0.5, 0.5),
		radius = 12, top = props.top or Color3.fromRGB(150, 255, 120), bottom = props.bottom or Color3.fromRGB(60, 180, 50),
	})
	s.holder.Rotation = props.rotation or -8
	s.holder.ZIndex = props.z or 9
	UIKit.text(s.body, { text = props.text or "", bold = true, size = UDim2.new(1, -10, 0.66, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), strokeThickness = 2.5 })
	if props.slam ~= false then
		local sc = Instance.new("UIScale")
		sc.Scale = 2
		sc.Parent = s.holder
		tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	return s
end

-- Styles a ScrollingFrame's scroll bar to match the kit.
function UIKit.styleScroll(scroll: ScrollingFrame)
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = Color3.fromRGB(170, 140, 255)
	scroll.ScrollBarImageTransparency = 0.2
	scroll.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	scroll.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	scroll.BorderSizePixel = 0
	scroll.BackgroundTransparency = 1
end

function UIKit.area(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor
	f.Parent = parent
	return f
end

return UIKit
