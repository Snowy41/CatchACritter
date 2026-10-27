-- Studio only: plays the first KeyframeSequence / AnimationClip found inside each model in
-- Workspace.CritterLab.Import (e.g. an "Idle" exported from the Animation Editor or the FBX importer).
-- Unpublished animations are registered with KeyframeSequenceProvider for local preview.

local Controller = {}

function Controller.Start()
	local RunService = game:GetService("RunService")
	if not RunService:IsStudio() then return end
	local KSP = game:GetService("KeyframeSequenceProvider")
	local Lab = workspace:WaitForChild("CritterLab", 10)
	if not Lab then return end
	local Import = Lab:WaitForChild("Import")

	local function animate(model)
		if not model:IsA("Model") then return end
		task.wait(0.5) -- let the server place it first
		local clip = model:FindFirstChildWhichIsA("AnimationClip", true)
		local anim = model:FindFirstChildWhichIsA("Animation", true)
		local id
		if clip then
			local ok, res = pcall(function() return KSP:RegisterKeyframeSequence(clip) end)
			if ok then id = res else warn("[DevLabAnimator] register failed for " .. model.Name .. ": " .. tostring(res)) end
		elseif anim then
			id = anim.AnimationId
		end
		if not id or id == "" then return end
		local ctrl = model:FindFirstChildWhichIsA("Humanoid", true) or model:FindFirstChildWhichIsA("AnimationController", true)
		if not ctrl then ctrl = Instance.new("AnimationController"); ctrl.Parent = model end
		local animator = ctrl:FindFirstChildOfClass("Animator") or Instance.new("Animator", ctrl)
		local a = Instance.new("Animation"); a.AnimationId = id
		local track = animator:LoadAnimation(a)
		track.Looped = true
		track:Play(0.2)
		print(("[DevLabAnimator] playing %s on %s"):format(clip and clip.Name or anim.Name, model.Name))
	end

	for _, m in ipairs(Import:GetChildren()) do task.spawn(animate, m) end
	Import.ChildAdded:Connect(animate)
end

return Controller
