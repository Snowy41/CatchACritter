-- First 60 seconds (GDD): a newcomer who hasn't caught anything yet gets a glowing guide line
-- and a bouncing "CATCH ME!" sign on the nearest wild critter. No text walls, just arrows.
-- (Carrying home is guided by the HUD's beam to the plot; the shop button pulses once affordable.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Icons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Icons"))

local player = Players.LocalPlayer
local wildFolder = workspace:WaitForChild("WildCritters")

local beam: Beam? = nil
local a0: Attachment? = nil
local sign: BillboardGui? = nil
local target: Model? = nil

local function active(): boolean
	return player:GetAttribute("Newcomer") == true
		and (player:GetAttribute("TotalCatches") or 0) == 0
		and player:GetAttribute("Carrying") == nil
end

local function clear()
	if beam then
		beam:Destroy()
		beam = nil
	end
	if sign then
		sign:Destroy()
		sign = nil
	end
	target = nil
end

local function makeSign(model: Model)
	local g = Instance.new("BillboardGui")
	g.Name = "CatchMe"
	g.Size = UDim2.fromOffset(150, 110)
	g.StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.Adornee = model.PrimaryPart
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = Icons.Paw
	icon.Size = UDim2.fromOffset(60, 60)
	icon.Position = UDim2.new(0.5, 0, 0, 0)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Parent = g
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, 40)
	t.Position = UDim2.fromOffset(0, 62)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = "CATCH ME!"
	t.TextColor3 = Color3.fromRGB(150, 255, 120)
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Color3.fromRGB(20, 14, 36)
	s.Parent = t
	t.Parent = g
	g.Parent = player.PlayerGui
	return g
end

local function nearestCritter(from: Vector3): Model?
	local best, bestD = nil, math.huge
	for _, m in ipairs(wildFolder:GetChildren()) do
		if m:IsA("Model") and m.PrimaryPart and not m:GetAttribute("InNest") then
			local d = (m.PrimaryPart.Position - from).Magnitude
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

local lastPick = 0
RunService.RenderStepped:Connect(function()
	if not active() then
		if target then
			clear()
		end
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	-- re-pick the target twice a second (critters move, and others may catch it)
	if os.clock() - lastPick > 0.5 or not (target and target.Parent) then
		lastPick = os.clock()
		local best = nearestCritter(hrp.Position)
		if best ~= target then
			clear()
			target = best
			if best and best.PrimaryPart then
				if not a0 or a0.Parent ~= hrp then
					a0 = Instance.new("Attachment")
					a0.Name = "GuideStart"
					a0.Position = Vector3.new(0, -2.4, 0)
					a0.Parent = hrp
				end
				local a1 = best.PrimaryPart:FindFirstChild("GuideEnd") or Instance.new("Attachment")
				a1.Name = "GuideEnd"
				a1.Parent = best.PrimaryPart
				local b = Instance.new("Beam")
				b.Attachment0 = a0
				b.Attachment1 = a1 :: Attachment
				b.Width0 = 1.2
				b.Width1 = 1.2
				b.FaceCamera = true
				b.LightEmission = 1
				b.Color = ColorSequence.new(Color3.fromRGB(150, 255, 120))
				b.Transparency = NumberSequence.new(0.2)
				b.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				b.TextureMode = Enum.TextureMode.Wrap
				b.TextureLength = 3
				b.TextureSpeed = 2
				b.Segments = 20
				b.CurveSize0 = 6
				b.CurveSize1 = -6
				b.Parent = hrp
				-- solid glowing core under the sparkles so the line reads from far away
				local core = b:Clone()
				core.Name = "GuideCore"
				core.Texture = ""
				core.Width0 = 0.55
				core.Width1 = 0.55
				core.Transparency = NumberSequence.new(0.1, 0.4)
	core.LightEmission = 0.25
	core.Color = ColorSequence.new(Color3.fromRGB(80, 220, 60))
				core.Parent = b
				beam = b
				sign = makeSign(best)
			end
		end
	end
	if sign then
		local icon = sign:FindFirstChild("Icon") :: ImageLabel?
		if icon then
			icon.Position = UDim2.new(0.5, 0, 0, math.abs(math.sin(os.clock() * 4)) * -12 + 6)
		end
	end
end)
