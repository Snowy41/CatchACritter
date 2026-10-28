-- Critterdex panel: overall progress on top, page tabs on the left (zones, mutations, titles) with
-- mini progress bars, entry cards on the right. Found entries show the critter spinning in a 3D
-- viewport; missing ones are a dark silhouette with a "?". Completed pages are claimed here (coins +
-- title); earned titles are worn from the TITLES tab, with a live nametag preview.
-- Side button badge = pages ready to claim. Hotkey C.

local Controller = {}

function Controller.Start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local CritterDefs = require(Shared:WaitForChild("CritterDefs"))
	local Dex = require(Shared:WaitForChild("Dex"))
	local Icons = require(Shared:WaitForChild("Icons"))
	local Net = require(Shared:WaitForChild("Net"))
	local Titles = require(Shared:WaitForChild("Titles"))
	local Modules = script.Parent.Parent:WaitForChild("Modules")
	local Panel = require(Modules:WaitForChild("Panel"))
	local State = require(Modules:WaitForChild("State"))
	local UIKit = require(Modules:WaitForChild("UIKit"))

	local player = Players.LocalPlayer
	local ClaimDexPage = Net.func("ClaimDexPage")
	local SetTitle = Net.func("SetTitle")
	local previews = ReplicatedStorage:WaitForChild("CritterPreviews", 30)

	local panel = Panel.new({ name = "Critterdex", title = "CRITTERDEX", icon = Icons.Book, size = Vector2.new(736, 490), theme = "Purple" })
	local button = Panel.sideButton({ name = "Dex", label = "INDEX", icon = Icons.Book, theme = "Purple", order = 2, hotkey = Enum.KeyCode.C, onClick = panel.toggle })
	panel.bindButton(button)
	local c = panel.content

	local VARIANT_COLORS: { [string]: Color3 } = {
		Normal = Color3.fromRGB(70, 165, 255),
		Shiny = Color3.fromRGB(255, 235, 130), Giant = Color3.fromRGB(255, 160, 100), Tiny = Color3.fromRGB(160, 200, 255),
		Golden = Color3.fromRGB(255, 195, 40), Frozen = Color3.fromRGB(150, 215, 255), Rainbow = Color3.fromRGB(255, 120, 220),
		Lava = Color3.fromRGB(255, 110, 40), Ghost = Color3.fromRGB(200, 225, 255),
	}

	-- top row: hint + overall progress
	UIKit.text(c, {
		text = "Catch every critter and every mutation!", size = UDim2.new(1, -340, 0, 26), position = UDim2.fromOffset(2, 4),
		alignX = Enum.TextXAlignment.Left, strokeThickness = 2.5, color = Color3.fromRGB(220, 210, 255),
	})
	local overall = UIKit.progressBar(c, { name = "Overall", size = UDim2.fromOffset(300, 30), position = UDim2.new(1, 0, 0, 2), anchor = Vector2.new(1, 0), radius = 14, colors = UIKit.BarPurple })

	-- tabs (left)
	local tabs = Instance.new("ScrollingFrame")
	tabs.Name = "Tabs"
	tabs.Size = UDim2.new(0, 210, 1, -46)
	tabs.Position = UDim2.fromOffset(0, 46)
	tabs.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabs.CanvasSize = UDim2.new()
	tabs.ZIndex = 4
	UIKit.styleScroll(tabs)
	tabs.Parent = c
	local tabList = Instance.new("UIListLayout")
	tabList.Padding = UDim.new(0, 8)
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Parent = tabs
	local tabPad = Instance.new("UIPadding")
	tabPad.PaddingTop = UDim.new(0, 8)
	tabPad.PaddingLeft = UDim.new(0, 6)
	tabPad.PaddingRight = UDim.new(0, 6)
	tabPad.PaddingBottom = UDim.new(0, 8)
	tabPad.Parent = tabs

	local page = UIKit.inset(c, { name = "Page", size = UDim2.new(1, -224, 1, -46), position = UDim2.fromOffset(224, 46), radius = 18 })

	local dex: any = { found = {}, claimed = {} }
	local titles: any = { owned = {}, equipped = nil }
	local selected = Dex.Pages[1] and Dex.Pages[1].id or "Titles"

	-- spinning previews of the visible page
	type Spin = { cam: Camera, center: Vector3, dist: number, phase: number }
	local spins: { Spin } = {}
	RunService.RenderStepped:Connect(function()
		if not panel.isOpen() then
			return
		end
		local t = os.clock()
		for _, s in ipairs(spins) do
			local a = t * 0.9 + s.phase
			local offset = Vector3.new(math.sin(a) * s.dist, s.dist * 0.3, math.cos(a) * s.dist)
			s.cam.CFrame = CFrame.lookAt(s.center + offset, s.center)
		end
	end)

	local function variantOf(key: string): (string, string)
		local species, variant = string.match(key, "^([^:]+):(.+)$")
		return species or key, variant or "Normal"
	end

	local function viewport(parent: Instance, species: string, found: boolean, phase: number)
		local vf = Instance.new("ViewportFrame")
		vf.BackgroundTransparency = 1
		vf.Size = UDim2.new(1, -16, 1, -62)
		vf.Position = UDim2.fromOffset(8, 8)
		vf.ZIndex = 6
		vf.Ambient = found and Color3.fromRGB(210, 210, 210) or Color3.new(0, 0, 0)
		vf.LightColor = found and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
		vf.LightDirection = Vector3.new(-1, -2, -1)
		vf.Parent = parent
		local def = CritterDefs[species]
		local template = previews and previews:FindFirstChild(def and def.template or species)
		if template then
			local model = template:Clone()
			if not found then
				for _, d in ipairs(model:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Color = Color3.fromRGB(22, 16, 40)
						d.Material = Enum.Material.SmoothPlastic
					elseif d:IsA("Decal") or d:IsA("Texture") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("BillboardGui") then
						d:Destroy()
					end
				end
			end
			model:PivotTo(CFrame.new())
			model.Parent = vf
			local cf, size = model:GetBoundingBox()
			local cam = Instance.new("Camera")
			cam.FieldOfView = 38
			cam.Parent = vf
			vf.CurrentCamera = cam
			local dist = size.Magnitude * 1.3
			cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.55, dist * 0.35, -dist * 0.8), cf.Position)
			if found then
				table.insert(spins, { cam = cam, center = cf.Position, dist = dist, phase = phase })
			end
		end
		if not found then
			UIKit.icon(parent, Icons.Question, { size = UDim2.fromOffset(52, 52), position = UDim2.new(0.5, 0, 0.42, 0), anchor = Vector2.new(0.5, 0.5), z = 8 })
		end
	end

	local function clearPage()
		table.clear(spins)
		for _, ch in ipairs(page:GetChildren()) do
			if not ch:IsA("UICorner") and not ch:IsA("UIStroke") then
				ch:Destroy()
			end
		end
	end

	local function scrollIn(parent: Instance, pos: UDim2, size: UDim2): ScrollingFrame
		local scroll = Instance.new("ScrollingFrame")
		scroll.Size = size
		scroll.Position = pos
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new()
		scroll.ZIndex = 5
		UIKit.styleScroll(scroll)
		scroll.Parent = parent
		return scroll
	end

	local function renderTitles()
		clearPage()
		UIKit.text(page, { text = "YOUR TITLES", bold = true, size = UDim2.new(1, -24, 0, 30), position = UDim2.fromOffset(14, 12), alignX = Enum.TextXAlignment.Left, z = 6 })
		-- nametag preview
		local preview = UIKit.inset(page, { name = "Preview", size = UDim2.new(1, -28, 0, 92), position = UDim2.fromOffset(14, 48), color = Color3.fromRGB(120, 190, 255), transparency = 0.55, z = 5 })
		UIKit.text(preview, { text = player.DisplayName, bold = true, size = UDim2.new(1, 0, 0, 32), position = UDim2.new(0.5, 0, 0, 8), anchor = Vector2.new(0.5, 0), z = 7 })
		UIKit.text(preview, { text = "@" .. player.Name, size = UDim2.new(1, 0, 0, 20), position = UDim2.new(0.5, 0, 0, 42), anchor = Vector2.new(0.5, 0), z = 7, strokeThickness = 2, color = Color3.fromRGB(225, 218, 255) })
		local worn = titles.equipped and Titles[titles.equipped]
		UIKit.text(preview, {
			text = worn and worn.text or "(no title)", size = UDim2.new(1, 0, 0, 22), position = UDim2.new(0.5, 0, 0, 64), anchor = Vector2.new(0.5, 0), z = 7,
			strokeThickness = 2, color = worn and worn.color or Color3.fromRGB(170, 160, 200),
		})
		local scroll = scrollIn(page, UDim2.fromOffset(10, 152), UDim2.new(1, -20, 1, -162))
		local l = Instance.new("UIListLayout")
		l.Padding = UDim.new(0, 8)
		l.Parent = scroll
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 22)
		pad.PaddingRight = UDim.new(0, 6)
		pad.PaddingTop = UDim.new(0, 4)
		pad.Parent = scroll
		local ids = {}
		for id in pairs(Titles) do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			local oa, ob = titles.owned[a] and 0 or 1, titles.owned[b] and 0 or 1
			if oa ~= ob then
				return oa < ob
			end
			return Titles[a].text < Titles[b].text
		end)
		for _, id in ipairs(ids) do
			local t = Titles[id]
			local owned = titles.owned[id] == true
			local row = UIKit.pill(scroll, { name = id, size = UDim2.new(1, 0, 0, 52), radius = 14, icon = owned and Icons.Medal or Icons.Lock, iconScale = 1.2 })
			UIKit.text(row.body, {
				text = owned and t.text or "???", bold = true, color = owned and t.color or Color3.fromRGB(140, 130, 170),
				size = UDim2.new(1, -180, 0.5, 0), position = UDim2.new(0, 44, 0.5, 0), anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left,
			})
			if owned then
				local equipped = titles.equipped == id
				local b = Panel.actionButton(row.body, {
					text = equipped and "WORN" or "WEAR", size = UDim2.fromOffset(104, 38), position = UDim2.new(1, -62, 0.5, -2),
					color = equipped and UIKit.Colors.Gold or UIKit.Colors.Blue,
				})
				b.face.Activated:Connect(function()
					SetTitle:InvokeServer(if equipped then nil else id)
				end)
			end
		end
	end

	local function renderPage(p: Dex.Page)
		clearPage()
		local foundCount = 0
		for _, k in ipairs(p.keys) do
			if dex.found[k] then
				foundCount += 1
			end
		end
		UIKit.text(page, {
			text = p.kind == "Zone" and (string.upper(p.title) .. " CRITTERS") or (string.upper(p.title) .. " MUTATION"),
			bold = true, size = UDim2.new(1, -180, 0, 30), position = UDim2.fromOffset(14, 12), alignX = Enum.TextXAlignment.Left, z = 6,
		})
		local pb = UIKit.progressBar(page, { size = UDim2.fromOffset(150, 26), position = UDim2.new(1, -14, 0, 14), anchor = Vector2.new(1, 0), z = 6, colors = UIKit.BarPurple })
		pb.set(foundCount / math.max(1, #p.keys), ("%d / %d"):format(foundCount, #p.keys))

		local grid = scrollIn(page, UDim2.fromOffset(10, 52), UDim2.new(1, -20, 1, -136))
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.fromOffset(156, 180)
		gl.CellPadding = UDim2.fromOffset(12, 12)
		gl.Parent = grid
		local gp = Instance.new("UIPadding")
		gp.PaddingTop = UDim.new(0, 4)
		gp.PaddingLeft = UDim.new(0, 4)
		gp.Parent = grid
		local cards: { GuiObject } = {}
		for i, key in ipairs(p.keys) do
			local species, variant = variantOf(key)
			local found = dex.found[key] == true
			local vc = VARIANT_COLORS[variant] or Color3.fromRGB(150, 140, 190)
			local card = Instance.new("Frame")
			card.Name = key
			card.BackgroundColor3 = Color3.new(1, 1, 1)
			card.ZIndex = 5
			UIKit.corner(card, 18)
			UIKit.gradient(card, found and vc or Color3.fromRGB(48, 40, 78), found and vc:Lerp(Color3.new(0, 0, 0), 0.45) or Color3.fromRGB(26, 20, 46))
			UIKit.stroke(card, 3)
			card.Parent = grid
			card.ClipsDescendants = true
			table.insert(cards, card)
			if found and (variant == "Golden" or variant == "Rainbow" or variant == "Shiny") then
				UIKit.rainbowStroke(card, { thickness = 4 })
				UIKit.sparkles(card, { rate = 2, z = 9 })
			end
			if found then
				UIKit.pattern(card, "Paws", { radius = 18, transparency = 0.84, tile = 60, z = 5 })
				UIKit.sunburst(card, { size = UDim2.fromOffset(230, 230), position = UDim2.new(0.5, 0, 0.36, 0), color = vc:Lerp(Color3.new(1, 1, 1), 0.5), transparency = 0.45, speed = 18, z = 5 })
			end
			-- floor glow under found critters
			if found then
				local glow = Instance.new("Frame")
				glow.BackgroundColor3 = vc
				glow.BackgroundTransparency = 0.6
				glow.Size = UDim2.new(0.7, 0, 0, 16)
				glow.Position = UDim2.new(0.5, 0, 1, -66)
				glow.AnchorPoint = Vector2.new(0.5, 0.5)
				glow.ZIndex = 5
				UIKit.corner(glow, 8)
				glow.Parent = card
			end
			viewport(card, species, found, i * 0.9)
			local nameplate = Instance.new("Frame")
			nameplate.BackgroundColor3 = Color3.fromRGB(16, 10, 32)
			nameplate.BackgroundTransparency = 0.25
			nameplate.Size = UDim2.new(1, -12, 0, 48)
			nameplate.Position = UDim2.new(0.5, 0, 1, -6)
			nameplate.AnchorPoint = Vector2.new(0.5, 1)
			nameplate.ZIndex = 6
			UIKit.corner(nameplate, 12)
			nameplate.Parent = card
			UIKit.text(nameplate, {
				text = found and CritterDefs[species].displayName or "???", bold = true, size = UDim2.new(1, -10, 0, 22),
				position = UDim2.new(0.5, 0, 0, 3), anchor = Vector2.new(0.5, 0), z = 7, strokeThickness = 2.5,
			})
			UIKit.text(nameplate, {
				text = string.upper(variant), size = UDim2.new(1, -10, 0, 17), position = UDim2.new(0.5, 0, 0, 27), anchor = Vector2.new(0.5, 0),
				z = 7, strokeThickness = 2, color = found and vc or Color3.fromRGB(140, 130, 170),
			})
		end

		UIKit.staggerIn(cards, 0.05)
		-- reward bar
		local done = foundCount == #p.keys
		local claimed = dex.claimed[p.id] == true
		local bar = UIKit.pill(page, {
			name = "Reward", size = UDim2.new(1, -60, 0, 64), position = UDim2.new(0, 46, 1, -74), radius = 18, icon = Icons.Gift, iconScale = 1.35,
			top = claimed and Color3.fromRGB(120, 150, 130) or (done and UIKit.Themes.Green[1] or UIKit.Themes.Navy[1]),
			bottom = claimed and Color3.fromRGB(70, 96, 80) or (done and UIKit.Themes.Green[2] or UIKit.Themes.Navy[2]),
			pattern = "Stars", patternTransparency = 0.86, patternTile = 40,
		})
		bar.holder.ZIndex = 6
		local title = p.rewardTitle and Titles[p.rewardTitle]
		UIKit.text(bar.body, { text = "PAGE REWARD", size = UDim2.new(0, 200, 0, 18), position = UDim2.fromOffset(54, 7), alignX = Enum.TextXAlignment.Left, strokeThickness = 2, color = Color3.fromRGB(220, 210, 255) })
		UIKit.icon(bar.body, Icons.Coin, { size = UDim2.fromOffset(28, 28), position = UDim2.fromOffset(52, 28), z = 6 })
		UIKit.text(bar.body, { text = tostring(p.rewardCoins), bold = true, size = UDim2.new(0, 60, 0, 24), position = UDim2.fromOffset(84, 31), alignX = Enum.TextXAlignment.Left })
		if title then
			local chip = UIKit.pill(bar.body, { size = UDim2.fromOffset(150, 28), position = UDim2.fromOffset(154, 29), radius = 10, icon = Icons.Medal, iconScale = 1.3, top = Color3.fromRGB(70, 56, 120), bottom = Color3.fromRGB(40, 30, 80) })
			UIKit.text(chip.body, { text = title.text, bold = true, color = title.color, size = UDim2.new(1, -40, 0.64, 0), position = UDim2.new(0, 30, 0.5, 0), anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left, strokeThickness = 2 })
		end
		if claimed then
			UIKit.stamp(bar.body, { text = "CLAIMED", position = UDim2.new(1, -78, 0.5, 0), size = UDim2.fromOffset(126, 40), slam = false })
		elseif done then
			local b = Panel.actionButton(bar.body, { text = "CLAIM", size = UDim2.fromOffset(130, 48), position = UDim2.new(1, -78, 0.5, -3) })
			Panel.pulse(b.wrapper, true)
			UIKit.rainbowStroke(b.face, { thickness = 3.5 })
			UIKit.sparkles(bar.body, { rate = 3, z = 9 })
			b.face.Activated:Connect(function()
				Panel.pulse(b.wrapper, false)
				ClaimDexPage:InvokeServer(p.id)
			end)
		else
			UIKit.icon(bar.body, Icons.Lock, { size = UDim2.fromOffset(46, 46), position = UDim2.new(1, -78, 0.5, 0), anchor = Vector2.new(0.5, 0.5) })
		end
	end

	local function renderTabs()
		for _, ch in ipairs(tabs:GetChildren()) do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		local function tab(id: string, label: string, found: number?, total: number?, order: number, ready: boolean, claimed: boolean, accent: Color3)
			local active = id == selected
			local b = UIKit.button(tabs, {
				name = id, size = UDim2.new(1, 0, 0, 58), color = active and UIKit.Colors.Purple or Color3.fromRGB(74, 62, 124), radius = 16, depth = 4,
				anchor = Vector2.new(0, 0),
			})
			b.root.LayoutOrder = order
			local dot = Instance.new("Frame")
			dot.BackgroundColor3 = accent
			dot.Size = UDim2.fromOffset(14, 14)
			dot.Position = UDim2.new(0, 12, 0, 13)
			dot.ZIndex = 6
			UIKit.corner(dot, 7)
			UIKit.stroke(dot, 2)
			dot.Parent = b.face
			UIKit.text(b.face, { text = label, bold = true, size = UDim2.new(1, -90, 0, 22), position = UDim2.new(0, 32, 0, 9), alignX = Enum.TextXAlignment.Left, z = 6 })
			if found and total then
				local mini = UIKit.progressBar(b.face, { size = UDim2.new(1, -24, 0, 14), position = UDim2.new(0, 12, 1, -20), radius = 7, stroke = 2, z = 6, colors = found == total and UIKit.BarGreen or UIKit.BarPurple })
				mini.label.Visible = false
				mini.set(found / math.max(1, total))
				UIKit.text(b.face, { text = ("%d/%d"):format(found, total), bold = true, size = UDim2.new(0, 50, 0, 18), position = UDim2.new(1, -10, 0, 11), anchor = Vector2.new(1, 0), alignX = Enum.TextXAlignment.Right, z = 6, strokeThickness = 2 })
			end
			if ready then
				UIKit.rainbowStroke(b.face, { thickness = 3.5 })
				UIKit.icon(b.root, Icons.Exclaim, { size = UDim2.fromOffset(32, 32), position = UDim2.new(1, 8, 0, -10), anchor = Vector2.new(1, 0), z = 9 })
			elseif claimed then
				UIKit.icon(b.root, Icons.Check, { size = UDim2.fromOffset(28, 28), position = UDim2.new(1, 6, 0, -8), anchor = Vector2.new(1, 0), z = 9 })
			end
			b.face.Activated:Connect(function()
				selected = id
				renderTabs()
			end)
		end
		for i, p in ipairs(Dex.Pages) do
			local n = 0
			for _, k in ipairs(p.keys) do
				if dex.found[k] then
					n += 1
				end
			end
			local accent = p.kind == "Zone" and Color3.fromRGB(140, 214, 88) or (VARIANT_COLORS[p.title] or Color3.new(1, 1, 1))
			tab(p.id, string.upper(p.title), n, #p.keys, i, n == #p.keys and not dex.claimed[p.id], dex.claimed[p.id] == true, accent)
		end
		tab("Titles", "TITLES", nil, nil, #Dex.Pages + 1, false, false, Color3.fromRGB(255, 215, 80))
		if selected == "Titles" then
			renderTitles()
		elseif Dex.PageById[selected] then
			renderPage(Dex.PageById[selected])
		end
	end

	local function refresh()
		local ready = 0
		for _, p in ipairs(Dex.Pages) do
			if Dex.pageDone(p, dex.found) and not dex.claimed[p.id] then
				ready += 1
			end
		end
		button.setBadge(ready)
		local found = Dex.count(dex.found)
		overall.set(found / math.max(1, Dex.TotalEntries), ("FOUND %d / %d"):format(found, Dex.TotalEntries))
		if panel.isOpen() then
			renderTabs()
		end
	end

	State.observe("dex", function(v)
		if v then
			dex = v
			refresh()
		end
	end)
	State.observe("titles", function(v)
		if v then
			titles = v
			if panel.isOpen() and selected == "Titles" then
				renderTitles()
			end
		end
	end)
	panel.Opened:Connect(renderTabs)
end

return Controller
