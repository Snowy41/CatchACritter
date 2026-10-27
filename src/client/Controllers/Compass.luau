-- Path compass at the top centre: the zones as coloured segments from home to the Crystal Cave,
-- a pin for the player, star markers for lucky spawns and a lock on zones not unlocked yet.

local Controller = {}

local SEGMENTS = {
	{ name = "HOME", z0 = 120, z1 = -240, color = Color3.fromRGB(110, 200, 255) },
	{ name = "MEADOW", z0 = -240, z1 = -680, color = Color3.fromRGB(120, 225, 80), speed = 0 },
	{ name = "SWAMP", z0 = -680, z1 = -1120, color = Color3.fromRGB(60, 200, 160), speed = 1 },
	{ name = "VOLCANO", z0 = -1120, z1 = -1600, color = Color3.fromRGB(255, 120, 40), speed = 2 },
	{ name = "CAVE", z0 = -1600, z1 = -1860, color = Color3.fromRGB(170, 140, 255), rebirth = 1 },
}

function Controller.Start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared:WaitForChild("Config"))
	local Icons = require(Shared:WaitForChild("Icons"))
	local UIKit = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UIKit"))

	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Compass"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")
	local area = UIKit.area(gui, "Compass", UDim2.fromOffset(600, 60), UDim2.new(0.5, 0, 0, 6), Vector2.new(0.5, 0))
	UIKit.autoScale({ area })

	local bar = UIKit.pill(area, { name = "Bar", size = UDim2.new(1, 0, 0, 30), position = UDim2.fromOffset(0, 18), radius = 15, top = Color3.fromRGB(40, 30, 80), bottom = Color3.fromRGB(24, 16, 52) })
	local total = SEGMENTS[1].z0 - SEGMENTS[#SEGMENTS].z1
	local segFrames = {}
	local locks = {}
	for i, s in ipairs(SEGMENTS) do
		local f = Instance.new("Frame")
		f.Name = s.name
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.Position = UDim2.new((SEGMENTS[1].z0 - s.z0) / total, 2, 0, 3)
		f.Size = UDim2.new((s.z0 - s.z1) / total, -4, 1, -6)
		f.ZIndex = 3
		UIKit.corner(f, 11)
		UIKit.gradient(f, UIKit.lighter(s.color, 0.2), s.color:Lerp(Color3.new(0, 0, 0), 0.25))
		f.Parent = bar.body
		UIKit.text(f, { text = s.name, bold = true, size = UDim2.new(1, -6, 0.7, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), z = 4, strokeThickness = 2 })
		segFrames[i] = f
		local lock = UIKit.icon(f, Icons.Lock, { size = UDim2.fromOffset(24, 24), position = UDim2.new(1, -4, 0.5, 0), anchor = Vector2.new(1, 0.5), z = 5 })
		lock.Visible = false
		locks[i] = lock
	end

	-- player pin + lucky markers
	local pin = UIKit.icon(area, Icons.Pin, { size = UDim2.fromOffset(34, 34), position = UDim2.new(0, 0, 0, 22), anchor = Vector2.new(0.5, 1), z = 8 })
	local markers: { [Model]: ImageLabel } = {}
	local wild = workspace:WaitForChild("WildCritters")

	local function frac(z: number): number
		return math.clamp((SEGMENTS[1].z0 - z) / total, 0, 1)
	end

	local function refreshLocks()
		local speed = player:GetAttribute("SpeedLevel") or 0
		local rebirth = player:GetAttribute("Rebirth") or 0
		for i, s in ipairs(SEGMENTS) do
			local locked = (s.speed and speed < s.speed) or (s.rebirth and rebirth < s.rebirth) or s.name == "CAVE"
			locks[i].Visible = locked == true
			segFrames[i].BackgroundTransparency = locked and 0.45 or 0
		end
	end
	player:GetAttributeChangedSignal("SpeedLevel"):Connect(refreshLocks)
	player:GetAttributeChangedSignal("Rebirth"):Connect(refreshLocks)
	refreshLocks()

	local currentSeg = 0
	RunService.RenderStepped:Connect(function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local f = frac(hrp.Position.Z)
			pin.Position = UDim2.new(f, 0, 0, 24 + math.sin(os.clock() * 4) * 2)
			for i, s in ipairs(SEGMENTS) do
				if hrp.Position.Z <= s.z0 and hrp.Position.Z > s.z1 and currentSeg ~= i then
					currentSeg = i
					for j, sf in ipairs(segFrames) do
						local st = sf:FindFirstChildOfClass("UIStroke")
						if j == i and not st then
							UIKit.stroke(sf, 2.5, Color3.new(1, 1, 1))
						elseif j ~= i and st then
							st:Destroy()
						end
					end
					UIKit.pop(segFrames[i], 0.15)
				end
			end
		end
		-- lucky spawns
		local seen = {}
		for _, m in ipairs(wild:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("Lucky") and m.PrimaryPart then
				seen[m] = true
				local mk = markers[m]
				if not mk then
					local r = Config.RarityByName[m:GetAttribute("Rarity") or ""]
					mk = UIKit.icon(area, Icons.Star, { size = UDim2.fromOffset(26, 26), anchor = Vector2.new(0.5, 0.5), z = 7 })
					mk.ImageColor3 = r and UIKit.lighter(r.color, 0.4) or Color3.new(1, 1, 1)
					markers[m] = mk
				end
				mk.Position = UDim2.new(frac(m.PrimaryPart.Position.Z), 0, 0, 33)
				mk.Rotation = (os.clock() * 90) % 360
			end
		end
		for m, mk in pairs(markers) do
			if not seen[m] then
				mk:Destroy()
				markers[m] = nil
			end
		end
	end)
end

return Controller
