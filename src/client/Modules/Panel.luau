-- Menu framework: side buttons on the left edge and modal panels (one open at a time).
--   Panel.sideButton({ name, label, icon, color, order, onClick }) -> { root, face, setBadge(n) }
--   Panel.new({ name, title, icon, size }) -> { window, content, open(), close(), toggle(), isOpen(), Opened, Closed }
-- Controllers build their own content inside `content`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Icons"))
local Signal = require(ReplicatedStorage.Shared:WaitForChild("Util"):WaitForChild("Signal"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local Panel = {}

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "Menus"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local side = UIKit.area(gui, "Side", UDim2.fromOffset(110, 420), UDim2.new(0, 22, 0.5, 30), Vector2.new(0, 0.5))
local list = Instance.new("UIListLayout")
list.SortOrder = Enum.SortOrder.LayoutOrder
list.VerticalAlignment = Enum.VerticalAlignment.Center
list.Padding = UDim.new(0, 16)
list.Parent = side

local modalLayer = Instance.new("Frame")
modalLayer.Name = "Modal"
modalLayer.BackgroundTransparency = 1
modalLayer.Size = UDim2.fromScale(1, 1)
modalLayer.Parent = gui
local center = UIKit.area(modalLayer, "Center", UDim2.fromOffset(700, 520), UDim2.fromScale(0.5, 0.52), Vector2.new(0.5, 0.5))
center.ZIndex = 2 -- above every backdrop
UIKit.autoScale({ side, center })

Panel.gui = gui

function Panel.sideButton(props: { [string]: any })
	local slot = Instance.new("Frame")
	slot.Name = props.name or "SideButton"
	slot.BackgroundTransparency = 1
	slot.Size = UDim2.fromOffset(92, 96)
	slot.LayoutOrder = props.order or 10
	slot.Parent = side
	local b = UIKit.button(slot, {
		name = "Button", size = UDim2.fromOffset(78, 78), position = UDim2.new(0.5, 0, 0, 39),
		color = props.color or UIKit.Colors.Blue, radius = 22, depth = 6, shineInterval = 4 + math.random() * 2,
	})
	UIKit.icon(b.face, props.icon, { size = UDim2.fromScale(0.78, 0.78), position = UDim2.fromScale(0.5, 0.48), anchor = Vector2.new(0.5, 0.5) })
	UIKit.text(b.root, {
		text = props.label or "", bold = true, size = UDim2.new(1.3, 0, 0, 22), position = UDim2.new(0.5, 0, 1, 2),
		anchor = Vector2.new(0.5, 0), z = 7, strokeThickness = 2.5,
	})
	local badge = UIKit.pill(b.root, {
		name = "Badge", size = UDim2.fromOffset(30, 30), position = UDim2.new(1, 8, 0, -8), anchor = Vector2.new(1, 0), radius = 15,
		top = Color3.fromRGB(255, 110, 100), bottom = Color3.fromRGB(215, 40, 50),
	})
	badge.holder.ZIndex = 9
	local badgeText = UIKit.text(badge.body, { text = "!", bold = true, size = UDim2.new(1, -6, 0.7, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), strokeThickness = 2 })
	badge.holder.Visible = false
	b.face.Activated:Connect(function()
		if props.onClick then
			props.onClick()
		end
	end)
	local function setBadge(n: number | boolean | nil)
		local show = n == true or (typeof(n) == "number" and n > 0)
		if show and not badge.holder.Visible then
			UIKit.pop(badge.holder, 0.4)
		end
		badge.holder.Visible = show
		badgeText.Text = typeof(n) == "number" and tostring(n) or "!"
	end
	return { root = b.root, face = b.face, setBadge = setBadge }
end

local openPanel: any = nil

function Panel.closeAll()
	if openPanel then
		openPanel.close()
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

	local window = UIKit.pill(holder, { name = "Window", size = UDim2.fromScale(1, 1), radius = 26 })
	window.body.Active = true -- clicks inside the window never fall through to the backdrop
	-- header ribbon overlapping the top edge
	local header = UIKit.pill(holder, {
		name = "Header", size = UDim2.fromOffset(math.min(size.X - 140, 360), 54), position = UDim2.new(0.5, 0, 0, 0), anchor = Vector2.new(0.5, 0.5),
		radius = 18, icon = props.icon, iconScale = 1.5, top = props.headerTop or Color3.fromRGB(255, 205, 70), bottom = props.headerBottom or Color3.fromRGB(225, 130, 15),
	})
	header.holder.ZIndex = 8
	UIKit.text(header.body, { text = props.title or "", bold = true, size = UDim2.new(1, -70, 0.62, 0), position = UDim2.new(0.5, 18, 0.5, 0), anchor = Vector2.new(0.5, 0.5) })

	local close = Instance.new("ImageButton")
	close.Name = "Close"
	close.BackgroundTransparency = 1
	close.Image = Icons.Close
	close.Size = UDim2.fromOffset(60, 60)
	close.Position = UDim2.new(1, 14, 0, -14)
	close.AnchorPoint = Vector2.new(1, 0)
	close.ZIndex = 9
	close.Parent = holder

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -40, 1, -64)
	content.Position = UDim2.fromOffset(20, 44)
	content.ZIndex = 4
	content.Parent = window.body

	local self: any = { window = window, content = content, holder = holder, Opened = Signal.new(), Closed = Signal.new() }
	local isOpen = false
	function self.isOpen()
		return isOpen
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
		UIKit.tween(backdrop, 0.2, { BackgroundTransparency = 0.5 })
		scale.Scale = 0.7
		UIKit.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
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
		local tw = UIKit.tween(scale, 0.15, { Scale = 0.8 })
		tw.Completed:Once(function()
			if not isOpen then
				holder.Visible = false
				backdrop.Visible = false
			end
		end)
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
		UIKit.tween(close, 0.12, { Size = UDim2.fromOffset(66, 66) }, Enum.EasingStyle.Back)
	end)
	close.MouseLeave:Connect(function()
		UIKit.tween(close, 0.12, { Size = UDim2.fromOffset(60, 60) })
	end)
	backdrop.Activated:Connect(self.close)
	return self
end

-- A small 3D action button with a centred label (claim, equip, rebirth ...).
function Panel.actionButton(parent: Instance, props: { [string]: any })
	local b = UIKit.button(parent, {
		name = props.name or "Action", size = props.size or UDim2.fromOffset(120, 44), position = props.position,
		anchor = props.anchor, color = props.color or UIKit.Colors.Green, radius = 14, depth = 5,
	})
	local label = UIKit.text(b.face, { text = props.text or "", bold = true, size = UDim2.new(1, -14, 0.6, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), z = 6 })
	return b, label
end

return Panel
