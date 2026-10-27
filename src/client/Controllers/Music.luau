-- Background music per zone (APM library tracks from the Roblox Creator Store), crossfading when
-- the player moves between zones. Respects the "music" setting.

local Controller = {}

local TRACKS = {
	{ zMin = -240, id = "rbxassetid://1842285060" }, -- Home: "Funny Bone" (cheerful bounce)
	{ zMin = -680, id = "rbxassetid://1842285773" }, -- Meadow: "The Cactus Kid" (happy, mischievous)
	{ zMin = -1120, id = "rbxassetid://9048060966" }, -- Swamp: "Quietly Quizzical (b)"
	{ zMin = -math.huge, id = "rbxassetid://1835450912" }, -- Volcano: "Crazy Games"
}
local VOLUME = 0.35

function Controller.Start()
	local Players = game:GetService("Players")
	local SoundService = game:GetService("SoundService")
	local TweenService = game:GetService("TweenService")

	local Settings = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Settings"))
	local player = Players.LocalPlayer

	local sounds: { Sound } = {}
	for i, t in ipairs(TRACKS) do
		local s = Instance.new("Sound")
		s.Name = "Music" .. i
		s.SoundId = t.id
		s.Looped = true
		s.Volume = 0
		s.Parent = SoundService
		sounds[i] = s
	end

	local current = 0
	local function fadeTo(index: number)
		local enabled = Settings.get("music") ~= false
		for i, s in ipairs(sounds) do
			local target = (i == index and enabled) and VOLUME or 0
			if target > 0 and not s.IsPlaying then
				s:Play()
			end
			local tw = TweenService:Create(s, TweenInfo.new(1.5), { Volume = target })
			tw:Play()
			if target == 0 then
				tw.Completed:Once(function()
					if s.Volume == 0 then
						s:Stop()
					end
				end)
			end
		end
		current = index
	end

	Settings.Changed:Connect(function(k)
		if k == "music" then
			fadeTo(current)
		end
	end)

	while true do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local z = hrp.Position.Z
			for i, t in ipairs(TRACKS) do
				if z > t.zMin then
					if i ~= current then
						fadeTo(i)
					end
					break
				end
			end
		end
		task.wait(1)
	end
end

return Controller
