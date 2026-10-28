-- Studio only: previews the animations inside each model in Workspace.CritterLab.Import.
-- Models with several KeyframeSequences (Idle / Run / Happy ...) cycle through them, 4 s each,
-- with a small label showing which one plays. Unpublished animations are registered with
-- KeyframeSequenceProvider for local preview.

local Controller = {}

local ORDER = { Idle = 1, Run = 2, Happy = 3 }
local SHOW_SECONDS = 4

function Controller.Start()
	local RunService = game:GetService("RunService")
	if not RunService:IsStudio() then
		return
	end
	local KSP = game:GetService("KeyframeSequenceProvider")
	local Lab = workspace:WaitForChild("CritterLab", 10)
	if not Lab then
		return
	end
	local Import = Lab:WaitForChild("Import")

	local function label(model: Model): TextLabel?
		local root = model.PrimaryPart
		if not root then
			return nil
		end
		local g = Instance.new("BillboardGui")
		g.Name = "AnimLabel"
		g.Size = UDim2.fromOffset(160, 30)
		g.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		g.AlwaysOnTop = true
		g.LightInfluence = 0
		g.Adornee = root
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		local s = Instance.new("UIStroke")
		s.Thickness = 2
		s.Parent = t
		t.Parent = g
		g.Parent = game:GetService("Players").LocalPlayer.PlayerGui
		return t
	end

	local function animate(model)
		if not model:IsA("Model") then
			return
		end
		task.wait(0.5) -- let the server place it first
		local sequences = {}
		for _, c in ipairs(model:GetDescendants()) do
			if c:IsA("KeyframeSequence") or c:IsA("AnimationClip") then
				table.insert(sequences, c)
			end
		end
		table.sort(sequences, function(a, b)
			return (ORDER[a.Name] or 9) < (ORDER[b.Name] or 9)
		end)
		local ctrl = model:FindFirstChildWhichIsA("Humanoid", true) or model:FindFirstChildWhichIsA("AnimationController", true)
		if not ctrl then
			ctrl = Instance.new("AnimationController")
			ctrl.Parent = model
		end
		local animator = ctrl:FindFirstChildOfClass("Animator") or Instance.new("Animator", ctrl)
		local tracks = {}
		for _, seq in ipairs(sequences) do
			local ok, id = pcall(function()
				return KSP:RegisterKeyframeSequence(seq)
			end)
			if ok then
				local a = Instance.new("Animation")
				a.AnimationId = id
				local track = (animator :: Animator):LoadAnimation(a)
				track.Looped = true
				table.insert(tracks, { name = seq.Name, track = track })
			else
				warn("[DevLabAnimator] register failed for " .. model.Name .. ": " .. tostring(id))
			end
		end
		if #tracks == 0 then
			return
		end
		print(("[DevLabAnimator] %s: %d animations"):format(model.Name, #tracks))
		local text = #tracks > 1 and label(model) or nil
		local i = 0
		while model.Parent do
			i = i % #tracks + 1
			for j, t in ipairs(tracks) do
				if j ~= i then
					t.track:Stop(0.2)
				end
			end
			tracks[i].track:Play(0.2)
			if text then
				text.Text = string.upper(tracks[i].name)
			end
			if #tracks == 1 then
				return
			end
			task.wait(SHOW_SECONDS)
		end
	end

	for _, m in ipairs(Import:GetChildren()) do
		task.spawn(animate, m)
	end
	Import.ChildAdded:Connect(animate)
end

return Controller
