-- Critterdex panel: page tabs on the left (zones, mutations, titles), entry cards on the right.
-- Found entries show the critter in a viewport; missing ones are a dark silhouette with "???".
-- Completed pages are claimed here (coins + title); earned titles are equipped in the TITLES tab.
-- Side button badge = pages ready to claim.

local Controller = {}

function Controller.Start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

	local panel = Panel.new({
		name = "Critterdex", title = "CRITTERDEX", icon = Icons.Book, size = Vector2.new(720, 500),
		headerTop = Color3.fromRGB(190, 130, 255), headerBottom = Color3.fromRGB(120, 60, 210),
	})
	local button = Panel.sideButton({ name = "Dex", label = "DEX", icon = Icons.Book, color = UIKit.Colors.Purple, order = 2, onClick = panel.toggle })

	local VARIANT_COLORS: { [string]: Color3 } = {
		Normal = Color3.fromRGB(150, 140, 190),
		Shiny = Color3.fromRGB(255, 235, 130), Giant = Color3.fromRGB(255, 160, 100), Tiny = Color3.fromRGB(160, 200, 255),
		Golden = Color3.fromRGB(255, 195, 40), Frozen = Color3.fromRGB(150, 215, 255), Rainbow = Color3.fromRGB(255, 120, 220),
	}

	-- layout: tabs (left), page (right)
	local tabs = Instance.new("ScrollingFrame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.BorderSizePixel = 0
	tabs.Size = UDim2.new(0, 190, 1, 0)
	tabs.ScrollBarThickness = 6
	tabs.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabs.CanvasSize = UDim2.new()
	tabs.ZIndex = 4
	tabs.Parent = panel.content
	local tabList = Instance.new("UIListLayout")
	tabList.Padding = UDim.new(0, 8)
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Parent = tabs
	local tabPad = Instance.new("UIPadding")
	tabPad.PaddingTop = UDim.new(0, 6)
	tabPad.PaddingLeft = UDim.new(0, 4)
	tabPad.PaddingRight = UDim.new(0, 10)
	tabPad.Parent = tabs

	local page = Instance.new("Frame")
	page.Name = "Page"
	page.BackgroundTransparency = 1
	page.Size = UDim2.new(1, -206, 1, 0)
	page.Position = UDim2.fromOffset(206, 0)
	page.Parent = panel.content

	local progressText = UIKit.text(panel.content, {
		text = "", bold = true, size = UDim2.new(0, 220, 0, 24), position = UDim2.new(1, -40, 0, -34), anchor = Vector2.new(1, 0),
		alignX = Enum.TextXAlignment.Right, color = Color3.fromRGB(220, 200, 255), strokeThickness = 2.5,
	})

	local dex: any = { found = {}, claimed = {} }
	local titles: any = { owned = {}, equipped = nil }
	local selected = Dex.Pages[1] and Dex.Pages[1].id or "Titles"

	local function variantOf(key: string): (string, string)
		local species, variant = string.match(key, "^([^:]+):(.+)$")
		return species or key, variant or "Normal"
	end

	local function viewport(parent: Instance, species: string, found: boolean)
		local vf = Instance.new("ViewportFrame")
		vf.BackgroundTransparency = 1
		vf.Size = UDim2.new(1, -12, 1, -50)
		vf.Position = UDim2.fromOffset(6, 6)
		vf.ZIndex = 5
		vf.Ambient = found and Color3.fromRGB(200, 200, 200) or Color3.new(0, 0, 0)
		vf.LightColor = found and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
		vf.LightDirection = Vector3.new(-1, -2, -1)
		vf.Parent = parent
		local template = previews and previews:FindFirstChild(CritterDefs[species] and CritterDefs[species].template or species)
		if not template then
			UIKit.icon(vf, Icons.Question, { size = UDim2.fromScale(0.6, 0.6), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5) })
			return
		end
		local model = template:Clone()
		if not found then
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Color = Color3.fromRGB(25, 20, 45)
					d.Material = Enum.Material.SmoothPlastic
				elseif d:IsA("Decal") or d:IsA("Texture") or d:IsA("ParticleEmitter") or d:IsA("PointLight") then
					d:Destroy()
				end
			end
		end
		model:PivotTo(CFrame.new())
		model.Parent = vf
		local cf, size = model:GetBoundingBox()
		local cam = Instance.new("Camera")
		cam.FieldOfView = 40
		local dist = size.Magnitude * 0.95
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.55, dist * 0.35, -dist * 0.8), cf.Position)
		cam.Parent = vf
		vf.CurrentCamera = cam
	end

	local function clearPage()
		for _, c in ipairs(page:GetChildren()) do
			c:Destroy()
		end
	end

	local function renderTitles()
		clearPage()
		UIKit.text(page, { text = "YOUR TITLES", bold = true, size = UDim2.new(1, 0, 0, 30), alignX = Enum.TextXAlignment.Left })
		local scroll = Instance.new("ScrollingFrame")
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.Size = UDim2.new(1, 0, 1, -40)
		scroll.Position = UDim2.fromOffset(0, 40)
		scroll.ScrollBarThickness = 6
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new()
		scroll.Parent = page
		local l = Instance.new("UIListLayout")
		l.Padding = UDim.new(0, 8)
		l.Parent = scroll
		local any = false
		for id, t in pairs(Titles) do
			if titles.owned[id] then
				any = true
				local row = UIKit.pill(scroll, { name = id, size = UDim2.new(1, -12, 0, 54), radius = 14, icon = Icons.Medal, iconScale = 1.2 })
				row.holder.Position = UDim2.fromOffset(18, 0)
				UIKit.text(row.body, { text = t.text, bold = true, color = t.color, size = UDim2.new(1, -190, 0.55, 0), position = UDim2.new(0, 46, 0.5, 0), anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left })
				local equipped = titles.equipped == id
				local b = Panel.actionButton(row.body, {
					text = equipped and "WORN" or "WEAR", size = UDim2.fromOffset(110, 40), position = UDim2.new(1, -66, 0.5, -2), anchor = Vector2.new(0.5, 0.5),
					color = equipped and UIKit.Colors.Gold or UIKit.Colors.Blue,
				})
				b.face.Activated:Connect(function()
					SetTitle:InvokeServer(if equipped then nil else id)
				end)
			end
		end
		if not any then
			UIKit.text(scroll, { text = "Complete Critterdex pages to earn titles!", size = UDim2.new(1, -12, 0, 28), strokeThickness = 2.5, color = Color3.fromRGB(210, 200, 240) })
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
			text = (p.kind == "Zone" and p.title or (string.upper(p.title) .. " CRITTERS")) .. ("  %d/%d"):format(foundCount, #p.keys),
			bold = true, size = UDim2.new(1, 0, 0, 30), alignX = Enum.TextXAlignment.Left,
		})
		local grid = Instance.new("ScrollingFrame")
		grid.BackgroundTransparency = 1
		grid.BorderSizePixel = 0
		grid.Size = UDim2.new(1, 0, 1, -118)
		grid.Position = UDim2.fromOffset(0, 40)
		grid.ScrollBarThickness = 6
		grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
		grid.CanvasSize = UDim2.new()
		grid.Parent = page
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.fromOffset(150, 170)
		gl.CellPadding = UDim2.fromOffset(12, 12)
		gl.Parent = grid
		local gp = Instance.new("UIPadding")
		gp.PaddingTop = UDim.new(0, 4)
		gp.PaddingLeft = UDim.new(0, 4)
		gp.Parent = grid
		for _, key in ipairs(p.keys) do
			local species, variant = variantOf(key)
			local found = dex.found[key] == true
			local vc = VARIANT_COLORS[variant] or Color3.fromRGB(150, 140, 190)
			local card = Instance.new("Frame")
			card.BackgroundColor3 = Color3.new(1, 1, 1)
			card.ZIndex = 4
			UIKit.corner(card, 16)
			UIKit.gradient(card, found and vc:Lerp(UIKit.PanelTop, 0.55) or Color3.fromRGB(50, 44, 80), found and UIKit.PanelBottom or Color3.fromRGB(28, 22, 48))
			UIKit.stroke(card, 3)
			card.Parent = grid
			viewport(card, species, found)
			UIKit.text(card, {
				text = found and CritterDefs[species].displayName or "???", bold = true, size = UDim2.new(1, -12, 0, 22),
				position = UDim2.new(0.5, 0, 1, -46), anchor = Vector2.new(0.5, 0), z = 6, strokeThickness = 2.5,
			})
			UIKit.text(card, {
				text = string.upper(variant), size = UDim2.new(1, -12, 0, 18), position = UDim2.new(0.5, 0, 1, -22), anchor = Vector2.new(0.5, 0),
				z = 6, strokeThickness = 2, color = found and vc or Color3.fromRGB(150, 140, 180),
			})
		end
		-- reward bar
		local done = foundCount == #p.keys
		local claimed = dex.claimed[p.id] == true
		local bar = UIKit.pill(page, {
			name = "Reward", size = UDim2.new(1, -30, 0, 60), position = UDim2.new(0, 30, 1, -66), radius = 16, icon = Icons.Gift, iconScale = 1.35,
			top = claimed and Color3.fromRGB(70, 120, 70) or (done and Color3.fromRGB(110, 200, 80) or UIKit.PanelTop),
			bottom = claimed and Color3.fromRGB(40, 80, 45) or (done and Color3.fromRGB(50, 130, 40) or UIKit.PanelBottom),
		})
		local title = p.rewardTitle and Titles[p.rewardTitle]
		UIKit.text(bar.body, {
			text = ("%d coins%s"):format(p.rewardCoins, title and ("  +  title \"" .. title.text .. "\"") or ""),
			bold = true, size = UDim2.new(1, -200, 0.48, 0), position = UDim2.new(0, 50, 0.5, 0), anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left,
		})
		if claimed then
			UIKit.icon(bar.body, Icons.Check, { size = UDim2.fromOffset(52, 52), position = UDim2.new(1, -60, 0.5, 0), anchor = Vector2.new(0.5, 0.5) })
		elseif done then
			local b = Panel.actionButton(bar.body, { text = "CLAIM", size = UDim2.fromOffset(120, 44), position = UDim2.new(1, -74, 0.5, -3), anchor = Vector2.new(0.5, 0.5) })
			b.face.Activated:Connect(function()
				ClaimDexPage:InvokeServer(p.id)
			end)
		else
			UIKit.icon(bar.body, Icons.Lock, { size = UDim2.fromOffset(44, 44), position = UDim2.new(1, -60, 0.5, 0), anchor = Vector2.new(0.5, 0.5) })
		end
	end

	local function renderTabs()
		for _, c in ipairs(tabs:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local function tab(id: string, label: string, sub: string, order: number, ready: boolean)
			local active = id == selected
			local b = UIKit.button(tabs, {
				name = id, size = UDim2.new(1, 0, 0, 50), color = active and UIKit.Colors.Purple or Color3.fromRGB(80, 70, 130), radius = 14, depth = 4,
				anchor = Vector2.new(0, 0),
			})
			b.root.LayoutOrder = order
			UIKit.text(b.face, { text = label, bold = true, size = UDim2.new(1, -60, 0.46, 0), position = UDim2.new(0, 12, 0.5, 0), anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left, z = 6 })
			UIKit.text(b.face, { text = sub, size = UDim2.new(0, 50, 0.4, 0), position = UDim2.new(1, -10, 0.5, 0), anchor = Vector2.new(1, 0.5), alignX = Enum.TextXAlignment.Right, z = 6, strokeThickness = 2, color = Color3.fromRGB(230, 220, 255) })
			if ready then
				UIKit.icon(b.root, Icons.Exclaim, { size = UDim2.fromOffset(30, 30), position = UDim2.new(1, 6, 0, -8), anchor = Vector2.new(1, 0), z = 9 })
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
			tab(p.id, string.upper(p.title), ("%d/%d"):format(n, #p.keys), i, n == #p.keys and not dex.claimed[p.id])
		end
		tab("Titles", "TITLES", "", #Dex.Pages + 1, false)
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
		progressText.Text = ("FOUND %d / %d"):format(Dex.count(dex.found), Dex.TotalEntries)
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
