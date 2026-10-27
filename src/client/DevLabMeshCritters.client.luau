-- Studio only. Rebuilds the Blender critters (skinned EditableMesh + Bones) on the client, puts each
-- on the display reserved for it (Display attribute Reserved = model name), spins it and plays "Idle".
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local RS = game:GetService("ReplicatedStorage")
local KSP = game:GetService("KeyframeSequenceProvider")
local dataFolder = RS:WaitForChild("DevLabData", 10)
local Lab = workspace:WaitForChild("CritterLab", 10)
if not dataFolder or not Lab then return end
local Builder = require(dataFolder:WaitForChild("SkinnedMeshBuilder"))

local CRITTERS = { -- data module -> model name
	{data = "CloverBunData", name = "CloverBun_Blender"},
}

local spinning = {}
for _, c in ipairs(CRITTERS) do
	local mod = dataFolder:FindFirstChild(c.data)
	local display
	for _, d in ipairs(Lab.Displays:GetChildren()) do if d:GetAttribute("Reserved") == c.name then display = d end end
	if mod and display then
		local ok, model = pcall(Builder.build, require(mod), c.name)
		if ok then
			local tt = display.Turntable
			local top = tt.Position.Y + tt.Size.X / 2
			model:PivotTo(CFrame.new(tt.Position.X, top + model.PrimaryPart.Size.Y / 2 + 0.02, tt.Position.Z) * CFrame.Angles(0, math.pi, 0))
			model.Parent = Lab
			local label = display:FindFirstChild("Nameplate") and display.Nameplate:FindFirstChild("Text", true)
			if label then label.Text = ("%s  (%.1f studs)"):format(c.name, model.PrimaryPart.Size.Y) end
			local id = KSP:RegisterKeyframeSequence(model.Idle)
			local anim = Instance.new("Animation"); anim.AnimationId = id
			local track = model.AnimationController.Animator:LoadAnimation(anim)
			track.Looped = true; track:Play(0.2)
			table.insert(spinning, {model = model, angle = math.pi, speed = math.rad(display:GetAttribute("SpinSpeed") or 25)})
			print("[DevLabMeshCritters] built + playing Idle on " .. c.name)
		else
			warn("[DevLabMeshCritters] build failed for " .. c.name .. ": " .. tostring(model))
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	for _, s in ipairs(spinning) do
		if s.model.Parent then
			s.angle += s.speed * dt
			s.model:PivotTo(CFrame.new(s.model:GetPivot().Position) * CFrame.Angles(0, s.angle, 0))
		end
	end
end)
