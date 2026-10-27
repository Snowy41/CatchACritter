-- Points at lucky spawns (wild critters with the Lucky attribute: lucky, summoned and onboarding
-- Rares) that are off screen: an arrow on the screen edge in the rarity colour with the critter
-- and its distance, so the chase starts the moment the announcement drops.

local Controller = {}

function Controller.Start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared:WaitForChild("Config"))
	local Icons = require(Shared:WaitForChild("Icons"))
	local UIKit = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UIKit"))

	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local wild = workspace:WaitForChild("WildCritters")

	local gui = Instance.new("ScreenGui")
	gui.Name = "LuckyTracker"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4 -- above the side tiles
	gui.Parent = player:WaitForChild("PlayerGui")

	type Marker = { root: Frame, arrow: ImageLabel, label: TextLabel, glow: ImageLabel }
	local markers: { [Model]: Marker } = {}

	local function makeMarker(model: Model): Marker
		local r = Config.RarityByName[model:GetAttribute("Rarity") or ""]
		local color = r and r.color or Color3.new(1, 1, 1)
		local root = Instance.new("Frame")
		root.BackgroundTransparency = 1
		root.Size = UDim2.fromOffset(90, 90)
		root.AnchorPoint = Vector2.new(0.5, 0.5)
		root.Parent = gui
		local glow = UIKit.glow(root, { size = UDim2.fromScale(1.6, 1.6), color = color, transparency = 0.3, z = 1 })
		local arrow = UIKit.icon(root, Icons.Upgrade, { size = UDim2.fromOffset(58, 58), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), z = 3 })
		local label = UIKit.text(root, {
			text = "", bold = true, size = UDim2.fromOffset(180, 24), position = UDim2.new(0.5, 0, 1, 2), anchor = Vector2.new(0.5, 0), z = 4,
			color = UIKit.lighter(color, 0.35), strokeThickness = 3,
		})
		return { root = root, arrow = arrow, label = label, glow = glow }
	end

	RunService.RenderStepped:Connect(function()
		local seen: { [Model]: boolean } = {}
		local vp = camera.ViewportSize
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		for _, m in ipairs(wild:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("Lucky") and m.PrimaryPart then
				seen[m] = true
				local pos = m.PrimaryPart.Position
				local sp, onScreen = camera:WorldToViewportPoint(pos)
				local mk = markers[m]
				if onScreen and sp.Z > 0 then
					if mk then
						mk.root.Visible = false
					end
				else
					mk = mk or makeMarker(m)
					markers[m] = mk
					mk.root.Visible = true
					-- direction in screen space (flip when behind the camera)
					local center = vp / 2
					local dir = Vector2.new(sp.X, sp.Y) - center
					if sp.Z < 0 then
						dir = -dir
					end
					if dir.Magnitude < 1 then
						dir = Vector2.new(0, -1)
					end
					dir = dir.Unit
					local margin = 70
					local half = center - Vector2.new(margin, margin)
					local t = math.min(math.abs(half.X / (dir.X ~= 0 and dir.X or 1e-6)), math.abs(half.Y / (dir.Y ~= 0 and dir.Y or 1e-6)))
					local p = center + dir * t
					mk.root.Position = UDim2.fromOffset(p.X, p.Y)
					mk.arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
					local s = 1 + math.abs(math.sin(os.clock() * 5)) * 0.12
					mk.arrow.Size = UDim2.fromOffset(58 * s, 58 * s)
					local dist = hrp and math.floor((hrp.Position - pos).Magnitude) or 0
					mk.label.Text = ("%s  %dm"):format(string.upper(m:GetAttribute("Rarity") or ""), dist)
				end
			end
		end
		for m, mk in pairs(markers) do
			if not seen[m] then
				mk.root:Destroy()
				markers[m] = nil
			end
		end
	end)
end

return Controller
