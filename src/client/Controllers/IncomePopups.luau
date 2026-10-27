-- Coin bubbles over the critters in your own base: every few seconds each critter pops a
-- "+N" with a coin icon that floats up and fades (N = its income for that interval).
-- Makes the base feel alive and shows at a glance which critters earn the most.

local Controller = {}

local INTERVAL = 3

function Controller.Start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")

	local Icons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Icons"))
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local INK = Color3.fromRGB(20, 14, 36)

	local function short(n: number): string
		if n >= 1e6 then
			return string.format("%.1fM", n / 1e6)
		elseif n >= 1e4 then
			return string.format("%.1fK", n / 1e3)
		elseif n >= 10 then
			return tostring(math.floor(n + 0.5))
		end
		return string.format("%.1f", n):gsub("%.0$", "")
	end

	local function pop(part: BasePart, amount: number)
		local g = Instance.new("BillboardGui")
		g.Name = "IncomePop"
		g.Size = UDim2.fromOffset(120, 40)
		g.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
		g.AlwaysOnTop = false
		g.LightInfluence = 0
		g.MaxDistance = 70
		g.Adornee = part
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Image = Icons.Coin
		icon.Size = UDim2.fromOffset(34, 34)
		icon.Position = UDim2.new(0, 6, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Parent = g
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -44, 1, 0)
		t.Position = UDim2.fromOffset(42, 0)
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextColor3 = Color3.fromRGB(255, 225, 70)
		t.Text = "+" .. short(amount)
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Color = INK
		s.Parent = t
		t.Parent = g
		g.Parent = player.PlayerGui
		local info = TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(g, info, { StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0) }):Play()
		task.delay(0.8, function()
			local fade = TweenInfo.new(0.6)
			TweenService:Create(t, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(s, fade, { Transparency = 1 }):Play()
			TweenService:Create(icon, fade, { ImageTransparency = 1 }):Play()
		end)
		task.delay(1.5, function()
			g:Destroy()
		end)
	end

	while true do
		task.wait(INTERVAL)
		local bases = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Bases")
		local plot = bases and bases:FindFirstChild("Base_" .. tostring(player:GetAttribute("PlotId")))
		local displays = plot and plot:FindFirstChild("CritterDisplays")
		if displays then
			local mult = workspace:GetAttribute("IncomeMultiplier") or 1
			for i, model in ipairs(displays:GetChildren()) do
				local root = model:IsA("Model") and model.PrimaryPart
				local plate = root and root:FindFirstChild("Nameplate")
				local income = plate and plate:FindFirstChild("Income") :: TextLabel?
				if root and income and (root.Position - camera.CFrame.Position).Magnitude < 80 then
					local rate = tonumber(string.match(income.Text, "[%d%.]+")) or 0
					if rate > 0 then
						task.delay(i * 0.18, pop, root, rate * mult * INTERVAL)
					end
				end
			end
		end
	end
end

return Controller
