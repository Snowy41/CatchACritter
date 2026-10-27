-- Small UI kit for the HUD: consistent chunky "simulator" look.
--  * 3D buttons: coloured face with gradient + shine on a darker lip, press-down animation
--  * pills: dark rounded panels with an icon overlapping the left edge
--  * text: bold game font with a thick dark outline

local TweenService = game:GetService("TweenService")

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne
UIKit.FontBold = Enum.Font.LuckiestGuy
UIKit.Ink = Color3.fromRGB(20, 14, 36) -- outline colour (matches the icon pack's dark outline)
UIKit.PanelTop = Color3.fromRGB(58, 46, 98)
UIKit.PanelBottom = Color3.fromRGB(34, 26, 62)

UIKit.Colors = {
	Green = Color3.fromRGB(96, 214, 72),
	Blue = Color3.fromRGB(70, 160, 255),
	Gold = Color3.fromRGB(255, 196, 40),
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

-- Text with a thick outline. `bold` uses the chunky display font (numbers, buttons, titles).
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
	t.ZIndex = props.z or 3
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
	i.ZIndex = props.z or 4
	i.Parent = parent
	return i
end

-- Dark rounded panel (pill) with an optional icon overlapping its left edge.
function UIKit.pill(parent: Instance, props: { [string]: any })
	local frame = Instance.new("Frame")
	frame.Name = props.name or "Pill"
	frame.Size = props.size
	frame.Position = props.position or UDim2.new()
	frame.AnchorPoint = props.anchor or Vector2.zero
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	UIKit.corner(frame, props.radius or 14)
	UIKit.gradient(frame, props.top or UIKit.PanelTop, props.bottom or UIKit.PanelBottom)
	UIKit.stroke(frame, 3)
	-- thin inner highlight along the top edge
	local hl = Instance.new("Frame")
	hl.Name = "Highlight"
	hl.BackgroundColor3 = Color3.new(1, 1, 1)
	hl.BackgroundTransparency = 0.85
	hl.BorderSizePixel = 0
	hl.Size = UDim2.new(1, -16, 0, 3)
	hl.Position = UDim2.fromOffset(8, 4)
	hl.ZIndex = 2
	UIKit.corner(hl, 2)
	hl.Parent = frame
	local icon
	if props.icon then
		local h = frame.Size.Y.Offset
		icon = UIKit.icon(frame, props.icon, {
			size = UDim2.fromOffset(h * 1.35, h * 1.35),
			position = UDim2.new(0, -h * 0.45, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			z = 5,
		})
	end
	frame.Parent = parent
	return frame, icon
end

-- 3D button: darker "lip" underneath, gradient face, shine; sinks when pressed.
-- Returns the clickable face (TextButton) and the root frame.
function UIKit.button(parent: Instance, props: { [string]: any })
	local color: Color3 = props.color or UIKit.Colors.Green
	local depth = props.depth or 6
	local root = Instance.new("Frame")
	root.Name = props.name or "Button"
	root.BackgroundTransparency = 1
	root.Size = props.size
	root.Position = props.position or UDim2.new()
	root.AnchorPoint = props.anchor or Vector2.new(0.5, 0.5)

	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.Size = UDim2.new(1, 0, 1, 0)
	lip.Position = UDim2.fromOffset(0, depth)
	lip.BackgroundColor3 = darker(color, 0.55)
	UIKit.corner(lip, props.radius)
	UIKit.stroke(lip, 3)
	lip.Parent = root

	local face = Instance.new("TextButton")
	face.Name = "Face"
	face.Text = ""
	face.AutoButtonColor = false
	face.Size = UDim2.new(1, 0, 1, 0)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	UIKit.corner(face, props.radius)
	UIKit.gradient(face, lighter(color, 0.25), color)
	UIKit.stroke(face, 3)
	face.ZIndex = 2
	face.Parent = root

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.7
	shine.BorderSizePixel = 0
	shine.Size = UDim2.new(1, -14, 0.38, 0)
	shine.Position = UDim2.new(0, 7, 0, 5)
	shine.ZIndex = 2
	UIKit.corner(shine, props.radius and math.max(props.radius - 4, 4) or nil)
	local sg = Instance.new("UIGradient")
	sg.Rotation = 90
	sg.Transparency = NumberSequence.new(0.2, 1)
	sg.Parent = shine
	shine.Parent = face

	local function press(down: boolean)
		TweenService:Create(face, TweenInfo.new(0.06), { Position = UDim2.fromOffset(0, down and depth - 1 or 0) }):Play()
	end
	face.MouseButton1Down:Connect(function()
		press(true)
	end)
	face.MouseButton1Up:Connect(function()
		press(false)
	end)
	face.MouseLeave:Connect(function()
		press(false)
	end)

	root.Parent = parent
	return face, root
end

-- Tints an existing UIKit.button to a new colour.
function UIKit.setButtonColor(root: Frame, color: Color3)
	local face = root:FindFirstChild("Face")
	local lip = root:FindFirstChild("Lip") :: Frame?
	if face then
		local g = face:FindFirstChildOfClass("UIGradient")
		if g then
			g.Color = ColorSequence.new(lighter(color, 0.25), color)
		end
	end
	if lip then
		lip.BackgroundColor3 = darker(color, 0.55)
	end
end

-- Uniform scaling for small screens (phones) and large monitors. Each HUD area is a container
-- anchored to its screen corner/edge; a UIScale on it scales around that anchor.
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

-- Invisible container anchored at a screen position (used as a HUD area).
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
