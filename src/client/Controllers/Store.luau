-- Robux store: gamepass cards (icon on a spinning sunburst, perk text, ribbon, Robux price button
-- or OWNED stamp) and coin packs (coins scaled to your income). Products with id 0 are not set up
-- on the dashboard yet and answer "Coming soon!". Data: shared/Products.

local Controller = {}

function Controller.Start()
	local MarketplaceService = game:GetService("MarketplaceService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Icons = require(Shared:WaitForChild("Icons"))
	local Products = require(Shared:WaitForChild("Products"))
	local Modules = script.Parent.Parent:WaitForChild("Modules")
	local Bus = require(Modules:WaitForChild("Bus"))
	local Panel = require(Modules:WaitForChild("Panel"))
	local UIKit = require(Modules:WaitForChild("UIKit"))

	local player = Players.LocalPlayer
	local panel = Panel.new({ name = "Store", title = "STORE", icon = Icons.Cart, size = Vector2.new(760, 470), theme = "Red" })
	local button = Panel.sideButton({ name = "Store", label = "STORE", icon = Icons.Robux, theme = "Red", order = 5, onClick = panel.toggle })
	panel.bindButton(button)
	local c = panel.content

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ZIndex = 4
	UIKit.styleScroll(scroll)
	scroll.Parent = c
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = scroll

	local function short(n: number): string
		if n >= 1e6 then
			return string.format("%.1fM", n / 1e6)
		elseif n >= 1e4 then
			return string.format("%.1fK", n / 1e3)
		end
		return tostring(math.floor(n))
	end

	local function header(text: string, order: number)
		local h = UIKit.text(scroll, { text = text, bold = true, size = UDim2.new(1, 0, 0, 30), alignX = Enum.TextXAlignment.Left, strokeThickness = 3.5 })
		h.LayoutOrder = order
	end

	local function grid(order: number, height: number): Frame
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, height)
		f.LayoutOrder = order
		f.Parent = scroll
		local g = Instance.new("UIGridLayout")
		g.CellSize = UDim2.new(0.25, -9, 0, height)
		g.CellPadding = UDim2.fromOffset(12, 0)
		g.Parent = f
		return f
	end

	local function buy(kind: string, id: number)
		if id == 0 then
			Bus.Toast:Fire("Coming soon!", "info")
			return
		end
		if kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end

	-- one card: themed body, sunburst + icon, name, text, price button
	local function card(parent: Frame, props: { [string]: any })
		local theme = UIKit.Themes[props.theme] or UIKit.Themes.Blue
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Parent = parent
		local body = UIKit.pill(holder, { size = UDim2.fromScale(1, 1), radius = 20, top = theme[1], bottom = theme[2], pattern = "Paws", patternTransparency = 0.84, patternTile = 50 })
		body.body.ClipsDescendants = true
		UIKit.sunburst(body.body, { size = UDim2.fromOffset(260, 260), position = UDim2.new(0.5, 0, 0, 62), color = Color3.fromRGB(255, 255, 210), transparency = 0.45, speed = 20, z = 2 })
		local icon = UIKit.icon(body.body, props.icon, { size = UDim2.fromOffset(84, 84), position = UDim2.new(0.5, 0, 0, 62), anchor = Vector2.new(0.5, 0.5), z = 5 })
		UIKit.bob(icon, 5, 1.8)
		UIKit.text(body.body, { text = props.name, bold = true, size = UDim2.new(1, -16, 0, 28), position = UDim2.new(0.5, 0, 0, 110), anchor = Vector2.new(0.5, 0), z = 5, strokeThickness = 3 })
		local desc = UIKit.text(body.body, { text = props.desc, size = UDim2.new(1, -18, 0, 44), position = UDim2.new(0.5, 0, 0, 140), anchor = Vector2.new(0.5, 0), z = 5, strokeThickness = 2.5 })
		desc.TextScaled = true
		if props.ribbon then
			UIKit.ribbon(holder, { text = props.ribbon, size = UDim2.fromOffset(140, 32), position = UDim2.new(0.5, 0, 0, 0), rotation = -4, color = Color3.fromRGB(255, 60, 100), rainbow = props.ribbon == "BEST VALUE", z = 9 })
		end
		local b, label = Panel.actionButton(body.body, { text = "", size = UDim2.new(1, -24, 0, 46), position = UDim2.new(0.5, 0, 1, -32), radius = 14 })
		UIKit.icon(b.face, Icons.Robux, { size = UDim2.fromOffset(32, 32), position = UDim2.new(0, 10, 0.5, 0), anchor = Vector2.new(0, 0.5), z = 7 })
		label.Size = UDim2.new(1, -54, 0.6, 0)
		label.Position = UDim2.new(0, 46, 0.5, 0)
		label.AnchorPoint = Vector2.new(0, 0.5)
		label.Text = tostring(props.price)
		b.face.Activated:Connect(props.onBuy)
		return { holder = holder, button = b, label = label, desc = desc, body = body }
	end

	header("GAMEPASSES", 1)
	local passGrid = grid(2, 270)
	local passCards = {}
	for _, pass in ipairs(Products.Passes) do
		passCards[pass.key] = card(passGrid, {
			name = pass.name, desc = pass.desc, icon = Icons[pass.icon] or Icons.Star, theme = pass.theme, ribbon = pass.ribbon, price = pass.price,
			onBuy = function()
				if not player:GetAttribute("Pass_" .. pass.key) then
					buy("pass", pass.id)
				end
			end,
		})
	end
	header("COIN PACKS", 3)
	local packGrid = grid(4, 270)
	local packCards = {}
	for i, pack in ipairs(Products.CoinPacks) do
		packCards[pack.key] = card(packGrid, {
			name = pack.name, desc = "", icon = i <= 2 and Icons.Coin or Icons.Cash, theme = ({ "Gold", "Orange", "Green", "Purple" })[i], ribbon = pack.ribbon, price = pack.price,
			onBuy = function()
				buy("product", pack.id)
			end,
		})
	end

	local function refresh()
		for key, cardObj in pairs(passCards) do
			local owned = player:GetAttribute("Pass_" .. key) == true
			cardObj.label.Text = owned and "OWNED" or tostring(Products.PassByKey[key].price)
			UIKit.setButtonColor(cardObj.button, owned and Color3.fromRGB(110, 100, 140) or UIKit.Colors.Green)
		end
		local ips = player:GetAttribute("IncomePerSecond") or 0
		for key, cardObj in pairs(packCards) do
			cardObj.desc.Text = ("+%s COINS"):format(short(Products.packCoins(Products.PackByKey[key], ips)))
			cardObj.desc.Font = UIKit.FontBold
			cardObj.desc.TextColor3 = Color3.fromRGB(255, 240, 150)
		end
	end
	for _, pass in ipairs(Products.Passes) do
		player:GetAttributeChangedSignal("Pass_" .. pass.key):Connect(refresh)
	end
	panel.Opened:Connect(refresh)
	refresh()
end

return Controller
