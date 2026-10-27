-- Menu framework: square side buttons (2-column grid, left edge) and modal panels (one open at a
-- time), in the bright "simulator" style: saturated themed frame with a stud pattern, title bar
-- with a big icon, dark inner area for content, red square close button.
--   Panel.sideButton({ name, label, icon, theme, order, hotkey, onClick })
--       -> { root, face, setBadge(n | bool), setActive(bool) }
--   Panel.new({ name, title, icon, size, theme })   size = content area size
--       -> { window, content, holder, open(), close(), toggle(), isOpen(), bindButton(b), Opened, Closed }
--   Panel.actionButton(parent, props) -> (button, label)   (button.wrapper can pulse)
--   Panel.pulse(guiObject, on)

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared:WaitForChild("Util"):WaitForChild("Signal"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))
local VFX = require(script.Parent:WaitForChild("VFX"))

local Panel = {}

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "Menus"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local side = UIKit.area(gui, "Side", UDim2.fromOffset(212, 330), UDim2.new(0, 18, 0.5, 60), Vector2.new(0, 0.5))
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(98, 98)
grid.CellPadding = UDim2.fromOffset(10, 12)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.VerticalAlignment = Enum.VerticalAlignment.Center
grid.Parent = side

local modalLayer = Instance.new("Frame")
modalLayer.Name = "Modal"
modalLayer.BackgroundTransparency = 1
modalLayer.Size = UDim2.fromScale(1, 1)
modalLayer.Parent = gui
local center = UIKit.area(modalLayer, "Center", UDim2.fromOffset(800, 600), UDim2.fromScale(0.5, 0.53), Vector2.new(0.5, 0.5))
center.ZIndex = 2 -- above every backdrop
UIKit.autoScale({ side, center })

-- world blur behind open panels (local effect)
local blur = Instance.new("BlurEffect")
blur.Name = "MenuBlur"
blur.Size = 0
blur.Enabled = false
blur.Parent = Lighting

Panel.gui = gui

--------------------------------------------------------------------------- animation registries

local pulsing: { [GuiObject]: number } = {} -- object -> pulse amplitude
local wiggling: { [GuiObject]: boolean } = {}
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for obj, amp in pairs(pulsing) do
		local s = obj:FindFirstChild("PulseScale") :: UIScale?
		if s then
			s.Scale = 1 + math.abs(math.sin(t * 4)) * amp
		end
	end
	for obj in pairs(wiggling) do
		local phase = t % 2.5 -- short wiggle every 2.5 s
		obj.Rotation = phase < 0.5 and math.sin(phase * 40) * 10 * (1 - phase / 0.5) or 0
	end
end)

local function pulseScale(obj: GuiObject): UIScale
	local s = obj:FindFirstChild("PulseScale") :: UIScale?
	if not s then
		s = Instance.new("UIScale")
		;(s :: UIScale).Name = "PulseScale"
		;(s :: UIScale).Parent = obj
	end
	return s :: UIScale
end

function Panel.pulse(obj: GuiObject, on: boolean)
	local s = pulseScale(obj)
	pulsing[obj] = on and 0.06 or nil
	if not on then
		s.Scale = 1
	end
end

--------------------------------------------------------------------------- side buttons

function Panel.sideButton(props: { [string]: any })
	local theme = UIKit.Themes[props.theme or "Blue"] or UIKit.Themes.Blue
	local slot = Instance.new("Frame")
	slot.Name = props.name or "SideButton"
	slot.BackgroundTransparency = 1
	slot.LayoutOrder = props.order or 10
	slot.Parent = side

	-- gold ring shown while the button's panel is open
	local ring = Instance.new("Frame")
	ring.Name = "ActiveRing"
	ring.BackgroundColor3 = Color3.fromRGB(255, 230, 90)
	ring.Size = UDim2.new(1, 10, 1, 10)
	ring.Position = UDim2.new(0.5, 0, 0.5, 2)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Visible = false
	UIKit.corner(ring, 24)
	UIKit.stroke(ring, 3)
	ring.Parent = slot

	local b = UIKit.button(slot, {
		name = "Button", size = UDim2.new(1, -6, 1, -6), position = UDim2.fromScale(0.5, 0.5),
		color = theme[2]:Lerp(theme[1], 0.35), radius = 20, depth = 6, shineInterval = 4 + math.random() * 2, patternTile = 38,
	})
	-- brighter two-tone face than the default button gradient
	local g = b.face:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(theme[1], theme[2])
	end
	local icon = UIKit.icon(b.face, props.icon, { size = UDim2.fromScale(0.74, 0.74), position = UDim2.fromScale(0.5, 0.42), anchor = Vector2.new(0.5, 0.5), z = 6 })
	local readyStroke: UIStroke? = nil
	UIKit.text(b.face, {
		text = props.label or "", bold = true, size = UDim2.new(1, -8, 0, 22), position = UDim2.new(0.5, 0, 1, -6),
		anchor = Vector2.new(0.5, 1), z = 7, strokeThickness = 3,
	})

	if props.hotkey and UserInputService.KeyboardEnabled then
		local key = UIKit.pill(b.root, { name = "Key", size = UDim2.fromOffset(26, 26), position = UDim2.new(0, -8, 0, -8), radius = 8 })
		key.holder.ZIndex = 9
		UIKit.text(key.body, { text = props.hotkey.Name, bold = true, size = UDim2.new(1, -6, 0.7, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), strokeThickness = 2 })
	end

	local badge = UIKit.pill(b.root, {
		name = "Badge", size = UDim2.fromOffset(32, 32), position = UDim2.new(1, 10, 0, -10), anchor = Vector2.new(1, 0), radius = 16,
		top = Color3.fromRGB(255, 110, 100), bottom = Color3.fromRGB(215, 30, 50),
	})
	badge.holder.ZIndex = 9
	pulseScale(badge.holder)
	local badgeText = UIKit.text(badge.body, { text = "!", bold = true, size = UDim2.new(1, -6, 0.7, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), strokeThickness = 2 })
	badge.holder.Visible = false

	local function click()
		if props.onClick then
			props.onClick()
		end
	end
	b.face.Activated:Connect(click)
	if props.hotkey then
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == props.hotkey then
				VFX.sound(Sounds.Click, 0.4)
				click()
			end
		end)
	end

	local obj = { root = b.root, face = b.face }
	function obj.setBadge(n: number | boolean | nil)
		local show = n == true or (typeof(n) == "number" and n > 0)
		if show and not badge.holder.Visible then
			UIKit.pop(b.face, 0.12)
		end
		badge.holder.Visible = show
		badgeText.Text = typeof(n) == "number" and tostring(n) or "!"
		pulsing[badge.holder] = show and 0.16 or nil
		wiggling[icon] = show or nil
		-- something to claim: animated rainbow outline around the tile
		if show and not readyStroke then
			readyStroke = UIKit.rainbowStroke(b.face, { thickness = 4 })
		elseif not show and readyStroke then
			readyStroke:Destroy()
			readyStroke = nil
			local own = b.face:FindFirstChildOfClass("UIStroke")
			if own then
				own.Enabled = true
			end
		end
		if not show then
			icon.Rotation = 0
		end
	end
	function obj.setActive(on: boolean)
		ring.Visible = on
		if on then
			UIKit.pop(ring, 0.1)
		end
	end
	return obj
end

--------------------------------------------------------------------------- panels

local openPanel: any = nil

function Panel.anyOpen(): boolean
	return openPanel ~= nil
end

function Panel.closeAll()
	if openPanel then
		openPanel.close()
	end
end

local function setBlur(on: boolean)
	if on then
		blur.Enabled = true
		UIKit.tween(blur, 0.25, { Size = 14 })
	else
		local tw = UIKit.tween(blur, 0.2, { Size = 0 })
		tw.Completed:Once(function()
			if not openPanel then
				blur.Enabled = false
			end
		end)
	end
end

local TITLE_H = 66
local MARGIN = 12
local PAD = 14

function Panel.new(props: { [string]: any })
	local inner: Vector2 = props.size or Vector2.new(600, 400)
	local size = inner + Vector2.new(2 * (MARGIN + PAD), TITLE_H + MARGIN + 2 * PAD)
	local theme = UIKit.Themes[props.theme or "Blue"] or UIKit.Themes.Blue

	local backdrop = Instance.new("TextButton")
	backdrop.Name = (props.name or "Panel") .. "Backdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = Color3.fromRGB(10, 6, 24)
	backdrop.BackgroundTransparency = 1
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Visible = false
	backdrop.ZIndex = 0
	backdrop.Parent = modalLayer

	local holder = Instance.new("Frame")
	holder.Name = props.name or "Panel"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size.X, size.Y)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Visible = false
	holder.Parent = center
	local scale = Instance.new("UIScale")
	scale.Parent = holder

	-- outer frame: saturated theme gradient + stud pattern, thick outline, drop shadow
	local window = UIKit.pill(holder, {
		name = "Window", size = UDim2.fromScale(1, 1), radius = 26, top = theme[1], bottom = theme[2],
		pattern = "Stud", patternTransparency = 0.55, patternTile = 44,
	})
	window.body.Active = true -- clicks inside the window never fall through to the backdrop
	local outline = window.body:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Thickness = 4
	end

	-- title bar: big icon + title, left aligned
	UIKit.glow(holder, { size = UDim2.fromOffset(150, 150), position = UDim2.fromOffset(28, 24), color = theme[1], transparency = 0.25, z = 8 })
	local iconImg = UIKit.icon(holder, props.icon, { size = UDim2.fromOffset(84, 84), position = UDim2.fromOffset(-14, -18), z = 9 })
	iconImg.Rotation = -8
	UIKit.bob(iconImg, 5, 1.6)
	UIKit.sparkles(window.body, { rate = 2.2, z = 8, minSize = 12, maxSize = 26 })
	UIKit.text(holder, {
		text = props.title or "", bold = true, size = UDim2.new(1, -220, 0, 40), position = UDim2.fromOffset(80, 13), z = 9,
		alignX = Enum.TextXAlignment.Left, strokeThickness = 3.5,
	})

	-- red square close button
	local closeBtn = UIKit.button(holder, {
		name = "Close", size = UDim2.fromOffset(54, 54), position = UDim2.new(1, -38, 0, 34), color = UIKit.Colors.Red, radius = 14, depth = 5, pattern = false,
	})
	closeBtn.root.ZIndex = 9
	UIKit.text(closeBtn.face, { text = "X", bold = true, size = UDim2.new(0.62, 0, 0.62, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), z = 7 })

	-- dark inner area for content
	local innerFrame = Instance.new("Frame")
	innerFrame.Name = "Inner"
	innerFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	innerFrame.Size = UDim2.new(1, -2 * MARGIN, 1, -(TITLE_H + MARGIN))
	innerFrame.Position = UDim2.fromOffset(MARGIN, TITLE_H)
	innerFrame.ZIndex = 3
	UIKit.corner(innerFrame, 20)
	UIKit.gradient(innerFrame, Color3.fromRGB(48, 36, 112), Color3.fromRGB(26, 18, 66))
	UIKit.stroke(innerFrame, 3.5)
	UIKit.pattern(innerFrame, "Triangles", { radius = 20, transparency = 0.94, tile = 180 })
	innerFrame.Parent = window.body

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -2 * PAD, 1, -2 * PAD)
	content.Position = UDim2.fromOffset(PAD, PAD)
	content.ZIndex = 4
	content.Parent = innerFrame

	local self: any = { window = window, content = content, holder = holder, Opened = Signal.new(), Closed = Signal.new() }
	local button = props.button
	local isOpen = false
	function self.isOpen()
		return isOpen
	end
	function self.bindButton(b)
		button = b
	end
	function self.open()
		if isOpen then
			return
		end
		if openPanel and openPanel ~= self then
			openPanel.close()
		end
		openPanel = self
		isOpen = true
		backdrop.Visible = true
		holder.Visible = true
		UIKit.tween(backdrop, 0.2, { BackgroundTransparency = 0.45 })
		scale.Scale = 0.75
		holder.Position = UDim2.new(0.5, 0, 0.5, 40)
		UIKit.tween(scale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
		UIKit.tween(holder, 0.32, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
		setBlur(true)
		VFX.sound(Sounds.Pop, 0.45, 1.15)
		if button then
			button.setActive(true)
		end
		self.Opened:Fire()
	end
	function self.close()
		if not isOpen then
			return
		end
		isOpen = false
		if openPanel == self then
			openPanel = nil
		end
		UIKit.tween(backdrop, 0.15, { BackgroundTransparency = 1 })
		UIKit.tween(holder, 0.15, { Position = UDim2.new(0.5, 0, 0.5, 30) })
		local tw = UIKit.tween(scale, 0.15, { Scale = 0.8 })
		tw.Completed:Once(function()
			if not isOpen then
				holder.Visible = false
				backdrop.Visible = false
			end
		end)
		if not openPanel then
			setBlur(false)
		end
		VFX.sound(Sounds.Whoosh, 0.25, 1.6)
		if button then
			button.setActive(false)
		end
		self.Closed:Fire()
	end
	function self.toggle()
		if isOpen then
			self.close()
		else
			self.open()
		end
	end
	closeBtn.face.Activated:Connect(self.close)
	backdrop.Activated:Connect(self.close)
	return self
end

-- A 3D action button with a centred label (claim, equip, rebirth ...). The button sits in a
-- wrapper frame (b.wrapper) so it can pulse (Panel.pulse) without fighting the hover scale.
function Panel.actionButton(parent: Instance, props: { [string]: any })
	local size = props.size or UDim2.fromOffset(120, 44)
	local wrapper = Instance.new("Frame")
	wrapper.Name = (props.name or "Action")
	wrapper.BackgroundTransparency = 1
	wrapper.Size = size
	wrapper.Position = props.position or UDim2.new()
	wrapper.AnchorPoint = props.anchor or Vector2.new(0.5, 0.5)
	wrapper.ZIndex = 5
	wrapper.Parent = parent
	local b = UIKit.button(wrapper, {
		name = "Button", size = UDim2.fromScale(1, 1), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5),
		color = props.color or UIKit.Colors.Green, radius = props.radius or 14, depth = 5, patternTile = 30,
	})
	local label = UIKit.text(b.face, { text = props.text or "", bold = true, size = UDim2.new(1, -14, 0.6, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), z = 6 })
	b.wrapper = wrapper
	return b, label
end

return Panel
