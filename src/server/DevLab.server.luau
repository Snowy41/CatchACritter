-- Critter Lab: Studio-only test area at X=2500 (players can't reach it in live servers).
--  * Models inside Workspace.CritterLab.Import are placed on the display pedestals and spin.
--    Model attributes (optional): Spin (bool, default true), PlayAnimation (name of an Animation
--    inside the model, default: first one found).
--  * Workspace attribute DevStartInLab = true -> you spawn in the lab when testing in Studio.
--  * Green pads teleport between the lab and the map.
local RunService = game:GetService("RunService")
local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Lab = workspace:WaitForChild("CritterLab")
if not RunService:IsStudio() then
	Lab:Destroy()
	return
end

local Import = Lab:WaitForChild("Import")
local Displays = Lab:WaitForChild("Displays")
local LabSpawn = Lab:WaitForChild("LabSpawn")
local MapSpawn = workspace:FindFirstChild("SpawnLocation", true)

-- spawn choice
local function applySpawn()
	local inLab = workspace:GetAttribute("DevStartInLab") == true
	LabSpawn.Enabled = inLab
	if MapSpawn and MapSpawn ~= LabSpawn then MapSpawn.Enabled = not inLab end
end
applySpawn()
workspace:GetAttributeChangedSignal("DevStartInLab"):Connect(applySpawn)

-- teleport pads (lab -> map exists in the lab; map -> lab is created here, Studio only)
local toLab = Instance.new("Part")
toLab.Name = "DevTeleportToLab"; toLab.Anchored = true; toLab.Size = Vector3.new(8, 0.6, 8)
toLab.CFrame = CFrame.new(-14, 0.7, 80); toLab.Color = Color3.fromRGB(77, 163, 255); toLab.Material = Enum.Material.Neon
toLab:SetAttribute("Destination", "Lab"); CS:AddTag(toLab, "DevTeleport"); toLab.Parent = workspace
local DEST = {
	Lab = function() return LabSpawn.CFrame + Vector3.new(0, 4, 0) end,
	Map = function() return (MapSpawn and MapSpawn.CFrame or CFrame.new(0, 5, 30)) + Vector3.new(0, 4, 0) end,
}
local cooldown = {}
local function hookPad(pad)
	pad.Touched:Connect(function(hit)
		local char = hit.Parent
		local plr = Players:GetPlayerFromCharacter(char)
		if not plr or (cooldown[plr] and os.clock() - cooldown[plr] < 2) then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local dest = DEST[pad:GetAttribute("Destination")]
		if hrp and dest then cooldown[plr] = os.clock(); char:PivotTo(dest()) end
	end)
end
for _, p in ipairs(CS:GetTagged("DevTeleport")) do hookPad(p) end
CS:GetInstanceAddedSignal("DevTeleport"):Connect(hookPad)

-- display arrangement
local slots = {}
for i = 1, #Displays:GetChildren() do slots[i] = Displays:FindFirstChild("Display" .. i) end
local occupied = {}  -- display -> model
local angle = {}     -- model -> current yaw

local function playAnimation(model)
	local wanted = model:GetAttribute("PlayAnimation")
	local anim
	for _, a in ipairs(model:GetDescendants()) do
		if a:IsA("Animation") and (wanted == nil or a.Name == wanted) then anim = a break end
	end
	if not anim then return end
	local ctrl = model:FindFirstChildWhichIsA("Humanoid", true) or model:FindFirstChildWhichIsA("AnimationController", true)
	if not ctrl then
		ctrl = Instance.new("AnimationController"); ctrl.Parent = model
	end
	local animator = ctrl:FindFirstChildOfClass("Animator") or Instance.new("Animator", ctrl)
	local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
	if ok and track then track.Looped = true; track:Play() end
end

local function placeOnDisplay(model)
	if not model:IsA("Model") then return end
	for _, d in ipairs(slots) do
		if not occupied[d] and not d:GetAttribute("Reserved") then
			occupied[d] = model
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then p.Anchored = (p == model.PrimaryPart) or (model.PrimaryPart == nil) end
			end
			local top = d.Turntable.Position + Vector3.new(0, d.Turntable.Size.X / 2, 0)
			local _, size = model:GetBoundingBox()
			local bboxCf = model:GetBoundingBox()
			local pivotToBottom = model:GetPivot().Position.Y - (bboxCf.Position.Y - size.Y / 2)
			model:PivotTo(CFrame.new(top + Vector3.new(0, pivotToBottom + 0.05, 0)) * CFrame.Angles(0, math.pi, 0))
			angle[model] = math.pi
			local plate = d:FindFirstChild("Nameplate")
			local label = plate and plate:FindFirstChild("Text", true)
			if label then label.Text = model.Name .. string.format("  (%.1f studs)", size.Y) end
			playAnimation(model)
			return
		end
	end
	warn("[DevLab] no free display for " .. model.Name)
end

for _, m in ipairs(Import:GetChildren()) do placeOnDisplay(m) end
Import.ChildAdded:Connect(function(m) task.wait(0.1); placeOnDisplay(m) end)
Import.ChildRemoved:Connect(function(m)
	for d, om in pairs(occupied) do if om == m then occupied[d] = nil; angle[m] = nil end end
end)

RunService.Heartbeat:Connect(function(dt)
	for d, m in pairs(occupied) do
		if m.Parent and m:GetAttribute("Spin") ~= false then
			local speed = math.rad(d:GetAttribute("SpinSpeed") or 25)
			angle[m] = (angle[m] or 0) + speed * dt
			local p = m:GetPivot()
			m:PivotTo(CFrame.new(p.Position) * CFrame.Angles(0, angle[m], 0))
		end
	end
end)
