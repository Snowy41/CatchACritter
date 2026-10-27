-- Small UI kit for the HUD: consistent chunky "simulator" look.
--  * pills: dark gradient panel + soft drop shadow, icon overlapping the left edge
--  * 3D buttons: gradient face on a darker lip, shine sweep, hover grow, press sink
--  * text: bold game font with a thick dark outline, vertically centred helpers

local TweenService = game:GetService("TweenService")

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne
UIKit.FontBold = Enum.Font.LuckiestGuy
UIKit.Ink = Color3.fromRGB(20, 14, 36) -- outline colour (matches the icon pack's dark outline)
UIKit.PanelTop = Color3.fromRGB(64, 50, 110)
UIKit.PanelBottom = Color3.fromRGB(32, 24, 60)

UIKit.Colors = {
	Green = Color3.fromRGB(92, 214, 70),
	Blue = Color3.fromRGB(66, 156, 255),
	Gold = Color3.fromRGB(255, 192, 36),
	Red = Color3.fromRGB(255, 84, 84),
	Purple = Color3.fromRGB(170, 96, 255),
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
	t.Position = props.position or UDim2.new()
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

	UIKit.shineSweep(face, radius, props.shineInterval)

	local hovered, pressed = false, false
	local function refresh()
		tween(scale, 0.14, { Scale = pressed and 0.95 or (hovered and 1.07 or 1) }, Enum.EasingStyle.Back)
		tween(face, 0.06, { Position = UDim2.fromOffset(0, pressed and depth - 1 or 0) })
	end
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
