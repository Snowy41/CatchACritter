-- Menu framework: side buttons on the left edge and modal panels (one open at a time).
--   Panel.sideButton({ name, label, icon, color, order, hotkey, onClick })
--       -> { root, face, setBadge(n | bool), setActive(bool) }
--   Panel.new({ name, title, icon, size, headerTop, headerBottom, button })
--       -> { window, content, holder, open(), close(), toggle(), isOpen(), Opened, Closed }
--   Panel.actionButton(parent, props) -> (button, label)
-- Controllers build their own content inside `content`. Opening a panel blurs the world, slides
-- the window in and highlights its side button.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Icons = require(Shared:WaitForChild("Icons"))
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

local side = UIKit.area(gui, "Side", UDim2.fromOffset(116, 450), UDim2.new(0, 26, 0.5, 50), Vector2.new(0, 0.5))
local list = Instance.new("UIListLayout")
list.SortOrder = Enum.SortOrder.LayoutOrder
list.VerticalAlignment = Enum.VerticalAlignment.Center
list.Padding = UDim.new(0, 14)
list.Parent = side

local modalLayer = Instance.new("Frame")
modalLayer.Name = "Modal"
modalLayer.BackgroundTransparency = 1
modalLayer.Size = UDim2.fromScale(1, 1)
modalLayer.Parent = gui
local center = UIKit.area(modalLayer, "Center", UDim2.fromOffset(760, 560), UDim2.fromScale(0.5, 0.53), Vector2.new(0.5, 0.5))
center.ZIndex = 2 -- above every backdrop
UIKit.autoScale({ side, center })

-- world blur behind open panels (local effect)
local blur = Instance.new("BlurEffect")
blur.Name = "MenuBlur"
blur.Size = 0
blur.Enabled = false
blur.Parent = Lighting

Panel.gui = gui

--------------------------------------------------------------------------- side buttons

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
		-- short wiggle every 2.5 s
		local phase = t % 2.5
		obj.Rotation = phase < 0.5 and math.sin(phase * 40) * 10 * (1 - phase / 0.5) or 0
	end
end)

function Panel.sideButton(props: { [string]: any })
	local slot = Instance.new("Frame")
	slot.Name = props.name or "SideButton"
	slot.BackgroundTransparency = 1
	slot.Size = UDim2.fromOffset(104, 106)
	slot.LayoutOrder = props.order or 10
	slot.Parent = side

	-- gold ring shown while the button's panel is open
	local ring = Instance.new("Frame")
	ring.Name = "ActiveRing"
	ring.BackgroundColor3 = Color3.fromRGB(255, 220, 90)
	ring.Size = UDim2.fromOffset(102, 102)
	ring.Position = UDim2.new(0.5, 0, 0, 47)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Visible = false
	UIKit.corner(ring, 28)
	UIKit.stroke(ring, 3)
	ring.Parent = slot

	local b = UIKit.button(slot, {
		name = "Button", size = UDim2.fromOffset(88, 88), position = UDim2.new(0.5, 0, 0, 44),
		color = props.color or UIKit.Colors.Blue, radius = 24, depth = 6, shineInterval = 4 + math.random() * 2,
	})
	local icon = UIKit.icon(b.face, props.icon, { size = UDim2.fromScale(0.86, 0.86), position = UDim2.fromScale(0.5, 0.44), anchor = Vector2.new(0.5, 0.5) })

	-- label tab overlapping the bottom edge (same language as the SPEED shop tab)
	local tab = UIKit.pill(b.root, {
		name = "Tab", size = UDim2.fromOffset(92, 26), position = UDim2.new(0.5, 0, 1, 2), anchor = Vector2.new(0.5, 0.5), radius = 10,
	})
	tab.holder.ZIndex = 7
	UIKit.text(tab.body, { text = props.label or "", bold = true, size = UDim2.new(1, -10, 0.7, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), strokeThickness = 2 })

	-- keyboard hint
	if props.hotkey and UserInputService.KeyboardEnabled then
		local key = UIKit.pill(b.root, { name = "Key", size = UDim2.fromOffset(26, 26), position = UDim2.new(0, -8, 0, -8), radius = 8 })
		key.holder.ZIndex = 9
		UIKit.text(key.body, { text = props.hotkey.Name, bold = true, size = UDim2.new(1, -6, 0.7, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), strokeThickness = 2 })
	end

	local badge = UIKit.pill(b.root, {
		name = "Badge", size = UDim2.fromOffset(32, 32), position = UDim2.new(1, 10, 0, -10), anchor = Vector2.new(1, 0), radius = 16,
		top = Color3.fromRGB(255, 110, 100), bottom = Color3.fromRGB(215, 40, 50),
	})
	badge.holder.ZIndex = 9
	local pulse = Instance.new("UIScale")
	pulse.Name = "PulseScale"
	pulse.Parent = badge.holder
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

function Panel.new(props: { [string]: any })
	local size: Vector2 = props.size or Vector2.new(640, 460)
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

	local headerTop = props.headerTop or Color3.fromRGB(255, 205, 70)
	local window = UIKit.pill(holder, { name = "Window", size = UDim2.fromScale(1, 1), radius = 28 })
	window.body.Active = true -- clicks inside the window never fall through to the backdrop
	-- coloured top band that ties the window to its header colour
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.Size = UDim2.new(1, 0, 0, 64)
	band.ZIndex = 2
	UIKit.corner(band, 28)
	local bg = Instance.new("UIGradient")
	bg.Rotation = 90
	bg.Color = ColorSequence.new(headerTop:Lerp(UIKit.PanelTop, 0.55), UIKit.PanelTop)
	bg.Transparency = NumberSequence.new(0, 1)
	bg.Parent = band
	band.Parent = window.body

	-- header ribbon overlapping the top edge
	local header = UIKit.pill(holder, {
		name = "Header", size = UDim2.fromOffset(math.min(size.X - 160, 380), 58), position = UDim2.new(0.5, 0, 0, 0), anchor = Vector2.new(0.5, 0.5),
		radius = 20, icon = props.icon, iconScale = 1.55, top = headerTop, bottom = props.headerBottom or Color3.fromRGB(225, 130, 15),
	})
	header.holder.ZIndex = 8
	UIKit.shineSweep(header.body, 20, 3)
	UIKit.text(header.body, { text = props.title or "", bold = true, size = UDim2.new(1, -76, 0.62, 0), position = UDim2.new(0.5, 20, 0.5, 0), anchor = Vector2.new(0.5, 0.5) })

	local close = Instance.new("ImageButton")
	close.Name = "Close"
	close.BackgroundTransparency = 1
	close.Image = Icons.Close
	close.Size = UDim2.fromOffset(62, 62)
	close.Position = UDim2.new(1, 16, 0, -16)
	close.AnchorPoint = Vector2.new(1, 0)
	close.ZIndex = 9
	close.Parent = holder

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -44, 1, -70)
	content.Position = UDim2.fromOffset(22, 48)
	content.ZIndex = 4
	content.Parent = window.body

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
	close.Activated:Connect(self.close)
	close.MouseEnter:Connect(function()
		UIKit.tween(close, 0.12, { Size = UDim2.fromOffset(70, 70), Rotation = 90 }, Enum.EasingStyle.Back)
	end)
	close.MouseLeave:Connect(function()
		UIKit.tween(close, 0.12, { Size = UDim2.fromOffset(62, 62), Rotation = 0 })
	end)
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
		color = props.color or UIKit.Colors.Green, radius = props.radius or 14, depth = 5,
	})
	local label = UIKit.text(b.face, { text = props.text or "", bold = true, size = UDim2.new(1, -14, 0.6, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), z = 6 })
	b.wrapper = wrapper
	return b, label
end

-- Makes a button breathe (scale pulse) while `on`.
function Panel.pulse(obj: GuiObject, on: boolean)
	local s = obj:FindFirstChild("PulseScale") :: UIScale?
	if not s then
		s = Instance.new("UIScale")
		;(s :: UIScale).Name = "PulseScale"
		;(s :: UIScale).Parent = obj
	end
	pulsing[obj] = on and 0.06 or nil
	if not on then
		(s :: UIScale).Scale = 1
	end
end

return Panel
