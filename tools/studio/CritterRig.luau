-- Studio-only dev tool (lives in ServerStorage.DevTools.CritterRig, copied there by hand / MCP).
-- Builds parts-only critters in the project's style and generates their KeyframeSequences.
--
--   local R = require(game.ServerStorage.DevTools.CritterRig)
--   local ctx = R.begin("Sprigfox")
--   local B = R.group(ctx, "Body")
--   local body = R.cham(B, "Body", Vector3.new(...), CFrame.new(...), color)
--   ...
--   R.finish(ctx, {
--       cores = { Body = body, Head = head, ... },
--       joints = { { "Body", "RootPart", pos }, { "Head", "Body", pos }, ... },
--       idle = function(joint, t, T) return CFrame end, idleLength = 2,
--   })
--
-- Model space: +Y up, front = -Z, root at the feet. Animations are written in model space
-- ("pitch the head down") and converted into each joint's own frame, so they also work on rigs
-- whose joints are rotated (older critters).

local R = {}

function R.begin(name: string)
	local M = Instance.new("Model")
	M.Name = name
	local root = R.part(M, "RootPart", Vector3.new(1, 0.4, 1), CFrame.new(0, 0.2, 0), Color3.new(1, 1, 1), { Transparency = 1, Anchored = true })
	return { M = M, root = root }
end

function R.group(ctx, joint: string): Model
	local G = Instance.new("Model")
	G.Name = joint .. "Group"
	G.Parent = ctx.M
	return G
end

function R.part(parent: Instance, name: string, size: Vector3, cf: any, color: Color3, opts: { [string]: any }?, class: string?): BasePart
	local p = Instance.new(class or "Part") :: BasePart
	p.Name = name
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	if opts then
		for k, v in pairs(opts) do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- small detail part: no shadow
function R.detail(parent, name, size, cf, color, opts, class)
	local p = R.part(parent, name, size, cf, color, opts, class)
	p.CastShadow = false
	return p
end

-- chamfered block: 3 overlapping boxes (name, name_Y, name_Z). Returns the main box.
function R.cham(parent, name: string, size: Vector3, cf: any, color: Color3, c: number?, opts: { [string]: any }?): BasePart
	local ch = c or math.min(size.X, size.Y, size.Z) * 0.18
	local base = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	local a = R.part(parent, name, Vector3.new(size.X, size.Y - 2 * ch, size.Z - 2 * ch), base, color, opts)
	R.part(parent, name .. "_Y", Vector3.new(size.X - 2 * ch, size.Y, size.Z - 2 * ch), base, color, opts)
	R.part(parent, name .. "_Z", Vector3.new(size.X - 2 * ch, size.Y - 2 * ch, size.Z), base, color, opts)
	return a
end

local FRONT = CFrame.Angles(0, math.rad(90), 0) -- cylinder axis X -> Z
local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> Y
R.FRONT = FRONT
R.UP = UP

-- disc facing the front (eyes, pupils, spots)
function R.disc(parent, name, dia: number, thick: number, pos: any, color: Color3, opts)
	local base = typeof(pos) == "Vector3" and CFrame.new(pos) or pos
	local o = { Shape = Enum.PartType.Cylinder }
	for k, v in pairs(opts or {}) do o[k] = v end
	return R.detail(parent, name, Vector3.new(thick, dia, dia), base * FRONT, color, o)
end

-- flat disc lying on a surface (pads, plates)
function R.flat(parent, name, dia: number, thick: number, pos: any, color: Color3, opts)
	local base = typeof(pos) == "Vector3" and CFrame.new(pos) or pos
	local o = { Shape = Enum.PartType.Cylinder }
	for k, v in pairs(opts or {}) do o[k] = v end
	return R.part(parent, name, Vector3.new(thick, dia, dia), base * UP, color, o)
end

function R.ball(parent, name, dia: number, pos: any, color: Color3, opts)
	local o = { Shape = Enum.PartType.Ball }
	for k, v in pairs(opts or {}) do o[k] = v end
	return R.part(parent, name, Vector3.new(dia, dia, dia), pos, color, o)
end

-- mini stud (Roblox stud look at critter scale) on a top face
function R.stud(parent, pos: Vector3, color: Color3)
	return R.detail(parent, "Stud", Vector3.new(0.07, 0.13, 0.13), CFrame.new(pos) * UP, color, { Shape = Enum.PartType.Cylinder })
end

-- upright spike (wedge, slope towards the back); yaw in degrees
function R.spike(parent, name, size: Vector3, pos: Vector3, color: Color3, yaw: number?)
	return R.detail(parent, name, size, CFrame.new(pos) * CFrame.Angles(0, math.rad(180 + (yaw or 0)), 0), color, nil, "WedgePart")
end

--------------------------------------------------------------------------- rig + animations

local function weldGroup(G: Instance, core: BasePart)
	for _, p in ipairs(G:GetDescendants()) do
		if p:IsA("BasePart") and p ~= core then
			local w = Instance.new("WeldConstraint")
			w.Part0 = core
			w.Part1 = p
			w.Parent = p
		end
	end
end

-- standard procedural animations (model space intents), per joint name
local STANDARD = {
	Run = {
		length = 0.44,
		fn = function(j: string, t: number, T: number, p: { [string]: number }): (Vector3, Vector3)
			local w = t / T * math.pi * 2
			local k = p.bounce or 1
			if j == "Body" then
				return Vector3.new(0, math.abs(math.sin(w)) * 0.14 * k, 0), Vector3.new(-0.1 + math.sin(w * 2) * 0.06, 0, math.sin(w) * 0.04)
			elseif j == "Head" then
				return Vector3.zero, Vector3.new(0.06 + math.sin(w * 2 + 0.6) * 0.07, 0, -math.sin(w) * 0.05)
			elseif j == "EarL" or j == "EarR" then
				return Vector3.zero, Vector3.new(0.45 + math.sin(w * 2) * 0.12, 0, (j == "EarL" and 1 or -1) * 0.1)
			elseif j == "Tail" then
				return Vector3.zero, Vector3.new(0.15, math.sin(w * 2) * 0.45, 0)
			elseif j == "WingL" or j == "WingR" then
				return Vector3.zero, Vector3.new(0, 0, (j == "WingL" and 1 or -1) * math.sin(w * 4) * 0.7)
			elseif j == "Sprout" then
				return Vector3.zero, Vector3.new(math.sin(w * 2) * 0.2, 0, 0)
			end
			return Vector3.zero, Vector3.zero
		end,
	},
	Happy = {
		length = 1.0,
		fn = function(j: string, t: number, T: number, p: { [string]: number }): (Vector3, Vector3)
			local u = t / T
			local w = u * math.pi * 2
			local hop = math.abs(math.sin(w * 2)) -- two hops
			if j == "Body" then
				return Vector3.new(0, hop * 0.45 * (p.bounce or 1), 0), Vector3.new(-hop * 0.08, math.sin(w) * 0.35, math.sin(w * 2) * 0.06)
			elseif j == "Head" then
				return Vector3.zero, Vector3.new(-0.12 * hop, 0, math.sin(w * 2) * 0.22)
			elseif j == "EarL" or j == "EarR" then
				return Vector3.zero, Vector3.new(-0.2 + math.sin(w * 4) * 0.25, 0, (j == "EarL" and 1 or -1) * 0.15 * hop)
			elseif j == "Tail" then
				return Vector3.zero, Vector3.new(-0.1, math.sin(w * 6) * 0.6, 0)
			elseif j == "WingL" or j == "WingR" then
				return Vector3.zero, Vector3.new(0, 0, (j == "WingL" and 1 or -1) * math.sin(w * 8) * 0.8)
			elseif j == "Sprout" then
				return Vector3.zero, Vector3.new(math.sin(w * 4) * 0.25, 0, math.sin(w * 4 + 1) * 0.2)
			end
			return Vector3.zero, Vector3.zero
		end,
	},
}
R.STANDARD = STANDARD

-- Converts a model-space intent (offset, euler rotation) into the joint's Transform space.
local function jointSpace(jointRot: CFrame, offset: Vector3, euler: Vector3): CFrame
	local rot = CFrame.Angles(euler.X, euler.Y, euler.Z)
	local localRot = jointRot:Inverse() * rot * jointRot
	return CFrame.new(jointRot:VectorToObjectSpace(offset)) * localRot
end

-- Writes a KeyframeSequence named `name` into the model. `fn(joint, t, T) -> (offset, euler)` in
-- model space. The pose tree mirrors the Motor6D tree of the model.
function R.keyframes(model: Model, name: string, length: number, fn, opts: { [string]: any }?)
	local o = opts or {}
	local old = model:FindFirstChild(name)
	if old and old:IsA("KeyframeSequence") then
		old:Destroy()
	end
	local root = model.PrimaryPart :: BasePart
	local pivot = model:GetPivot()
	-- joint tree + each joint's rotation in model space
	local children: { [BasePart]: { Motor6D } } = {}
	local jointRot: { [Motor6D]: CFrame } = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			children[d.Part0] = children[d.Part0] or {}
			table.insert(children[d.Part0], d)
			jointRot[d] = (pivot:Inverse() * d.Part0.CFrame * d.C0).Rotation
		end
	end
	local ks = Instance.new("KeyframeSequence")
	ks.Name = name
	ks.Loop = o.loop ~= false
	ks.Priority = o.priority or Enum.AnimationPriority.Idle
	local steps = math.max(8, math.floor(length * 24))
	for i = 0, steps do
		local t = i / steps * length
		local kf = Instance.new("Keyframe")
		kf.Time = t
		local rootPose = Instance.new("Pose")
		rootPose.Name = root.Name
		rootPose.Weight = 1
		rootPose.Parent = kf
		local function add(part: BasePart, pose: Pose)
			for _, m in ipairs(children[part] or {}) do
				local p = Instance.new("Pose")
				p.Name = m.Part1.Name
				p.Weight = 1
				p.EasingStyle = Enum.PoseEasingStyle.Linear
				local offset, euler = fn(m.Name, t, length)
				p.CFrame = jointSpace(jointRot[m], offset or Vector3.zero, euler or Vector3.zero)
				p.Parent = pose
				add(m.Part1, p)
			end
		end
		add(root, rootPose)
		kf.Parent = ks
	end
	ks.Parent = model
	return ks
end

-- Adds the standard Run + Happy animations (personality params: bounce = hop strength).
function R.standardAnims(model: Model, params: { [string]: number }?)
	for name, a in pairs(STANDARD) do
		R.keyframes(model, name, a.length, function(j, t, T)
			return a.fn(j, t, T, params or {})
		end, { priority = Enum.AnimationPriority.Movement })
	end
end

-- Welds groups to their cores, creates the Motor6D rig and the animations.
--   cores  = { [jointName] = corePart }   (the group named jointName .. "Group" is welded to it)
--   joints = { { jointName, parentJointName ("RootPart" for the body), pivotPos }, ... }
--   idle   = function(joint, t, T) -> (offsetVector3, eulerVector3) in model space
function R.finish(ctx, spec: { [string]: any }): Model
	local M = ctx.M
	for jointName, core in pairs(spec.cores) do
		local G = M:FindFirstChild(jointName .. "Group")
		if G then
			weldGroup(G, core)
		end
	end
	for _, j in ipairs(spec.joints) do
		local name, parentName, pos = j[1], j[2], j[3]
		local p0 = parentName == "RootPart" and ctx.root or spec.cores[parentName]
		local p1 = spec.cores[name]
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		local jc = CFrame.new(pos)
		m.C0 = p0.CFrame:Inverse() * jc
		m.C1 = p1.CFrame:Inverse() * jc
		m.Parent = p0
	end
	local ac = Instance.new("AnimationController")
	ac.Parent = M
	Instance.new("Animator").Parent = ac
	M.PrimaryPart = ctx.root
	M:SetAttribute("RootHeight", 0.2)
	M:SetAttribute("Species", M.Name)
	if spec.idle then
		R.keyframes(M, "Idle", spec.idleLength or 2, spec.idle)
	end
	R.standardAnims(M, spec.animParams)
	if spec.scale and spec.scale ~= 1 then
		M:ScaleTo(spec.scale)
		M:SetAttribute("RootHeight", 0.2 * spec.scale)
	end
	return M
end

-- Puts a finished model into the lab (Import, on a pedestal) and/or the templates.
function R.publish(model: Model, labPos: Vector3?)
	local T = game:GetService("ServerStorage"):FindFirstChild("CritterTemplates")
	local lab = workspace:FindFirstChild("CritterLab") and workspace.CritterLab:FindFirstChild("Import")
	if lab then
		local old = lab:FindFirstChild(model.Name)
		if old then
			old:Destroy()
		end
		local copy = model:Clone()
		copy.Parent = lab
		copy:PivotTo(CFrame.new(labPos or Vector3.new(2480, 2.6, -55)) * CFrame.new(0, copy:GetAttribute("RootHeight"), 0))
	end
	if T then
		local old = T:FindFirstChild(model.Name)
		if old then
			old:Destroy()
		end
		model:PivotTo(CFrame.new(0, model:GetAttribute("RootHeight"), 0))
		model.Parent = T
	end
end

return R
