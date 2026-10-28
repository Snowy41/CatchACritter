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

-- mini stud (Roblox stud look at critter scale). `topY` = the surface it sits on; the stud is
-- sunk 0.02 into it. Use R.studs for a proper grid - single studs read as random dots.
function R.stud(parent, pos: Vector3, color: Color3)
	return R.detail(parent, "Stud", Vector3.new(0.07, 0.13, 0.13), CFrame.new(pos + Vector3.new(0, 0.015, 0)) * UP, color, { Shape = Enum.PartType.Cylinder })
end

-- tight grid of mini studs (like a Lego plate) centred at (cx, topY, cz), same colour as the
-- surface below, spacing 0.24 (reference: CloverBun_Cool)
function R.studs(parent, cx: number, topY: number, cz: number, cols: number, rows: number, color: Color3)
	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			local x = cx + (i - (cols - 1) / 2) * 0.24
			local z = cz + (j - (rows - 1) / 2) * 0.24
			R.stud(parent, Vector3.new(x, topY, z), color)
		end
	end
end

-- Stud texture (shared/Textures.Stud, 4x4 studs per tile) on ONE chosen face of a part.
-- Placed by hand where it looks good (a back, a shell, a cap) - never on every part.
R.STUD_TEXTURE = "rbxassetid://126140038631266"
function R.studTexture(part: BasePart, face: Enum.NormalId?, tile: number?): Texture
	local t = Instance.new("Texture")
	t.Name = "StudTexture"
	t.Texture = R.STUD_TEXTURE
	t.Face = face or Enum.NormalId.Top
	t.StudsPerTileU = tile or 0.9
	t.StudsPerTileV = tile or 0.9
	t.Parent = part
	return t
end

--------------------------------------------------------------------------- validation
-- R.validate(model) -> { problems }   (empty = clean). Checks, in model space:
--  * zfight:   two parts with coplanar, overlapping, same-facing faces (flickering textures)
--  * loose:    parts not touching the rest of the model (floating pieces)
--  * mirror:   parts off the centre line without a mirrored twin (asymmetry); parts with the
--              attribute Asym = true are allowed (deliberately asymmetric faces)
--  * buried:   detail parts completely hidden inside another part (wasted / pointless)

local function corners(cf: CFrame, s: Vector3)
	local h = s / 2
	return cf, Vector3.new(h.X, h.Y, h.Z)
end

-- separating axis test for two oriented boxes, `tol` = gap still counted as touching
local function obbTouch(ca: CFrame, ha: Vector3, cb: CFrame, hb: Vector3, tol: number): boolean
	local A = { ca.RightVector, ca.UpVector, ca.LookVector }
	local B = { cb.RightVector, cb.UpVector, cb.LookVector }
	local ea = { ha.X, ha.Y, ha.Z }
	local eb = { hb.X, hb.Y, hb.Z }
	local d = cb.Position - ca.Position
	local axes = {}
	for i = 1, 3 do
		table.insert(axes, A[i])
		table.insert(axes, B[i])
		for j = 1, 3 do
			local c = A[i]:Cross(B[j])
			if c.Magnitude > 1e-4 then
				table.insert(axes, c.Unit)
			end
		end
	end
	for _, ax in ipairs(axes) do
		local ra, rb = 0, 0
		for i = 1, 3 do
			ra += ea[i] * math.abs(A[i]:Dot(ax))
			rb += eb[i] * math.abs(B[i]:Dot(ax))
		end
		if math.abs(d:Dot(ax)) > ra + rb + tol then
			return false
		end
	end
	return true
end

local function inside(ca: CFrame, ha: Vector3, cb: CFrame, hb: Vector3): boolean
	-- is box a completely inside box b?
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local p = cb:PointToObjectSpace(ca * Vector3.new(sx * ha.X, sy * ha.Y, sz * ha.Z))
				if math.abs(p.X) > hb.X - 0.005 or math.abs(p.Y) > hb.Y - 0.005 or math.abs(p.Z) > hb.Z - 0.005 then
					return false
				end
			end
		end
	end
	return true
end

function R.validate(model: Model): { string }
	local O = model:GetPivot()
	local parts = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= model.PrimaryPart and p.Name ~= "RarityRing" then
			table.insert(parts, p)
		end
	end
	local info = {}
	for i, p in ipairs(parts) do
		local cf = O:ToObjectSpace(p.CFrame)
		local s = p.Size
		if p:IsA("Part") and p.Shape == Enum.PartType.Ball then
			s = Vector3.one * math.min(s.X, s.Y, s.Z)
		end
		info[i] = { p = p, cf = cf, h = s / 2, visible = p.Transparency < 0.95 }
	end
	local problems = {}
	-- z-fighting: axis-aligned faces (model space) of two visible parts on the same plane, same
	-- facing direction, overlapping area. Cylinders/balls: only their flat caps / none.
	local function faces(it)
		local out = {}
		local p, cf, h = it.p, it.cf, it.h
		local isBall = p:IsA("Part") and p.Shape == Enum.PartType.Ball
		local isCyl = p:IsA("Part") and p.Shape == Enum.PartType.Cylinder
		if isBall or p:IsA("WedgePart") or p:IsA("CornerWedgePart") then
			return out
		end
		local axes = { { cf.RightVector, h.X, "X" }, { cf.UpVector, h.Y, "Y" }, { cf.LookVector, h.Z, "Z" } }
		local ext = Vector3.new(
			math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z,
			math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z,
			math.abs(cf.RightVector.Z) * h.X + math.abs(cf.UpVector.Z) * h.Y + math.abs(cf.LookVector.Z) * h.Z
		)
		local pos = cf.Position
		for _, a in ipairs(axes) do
			if isCyl and a[3] ~= "X" then
				continue
			end
			for wi, w in ipairs({ Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }) do
				local dd = a[1]:Dot(w)
				if math.abs(math.abs(dd) - 1) < 0.002 then
					for _, sgn in ipairs({ 1, -1 }) do
						local nd = dd * sgn
						local plane = (pos + a[1] * a[2] * sgn):Dot(w)
						local lo, hi = pos - ext, pos + ext
						local rect
						if wi == 1 then rect = { lo.Y, hi.Y, lo.Z, hi.Z }
						elseif wi == 2 then rect = { lo.X, hi.X, lo.Z, hi.Z }
						else rect = { lo.X, hi.X, lo.Y, hi.Y } end
						table.insert(out, { axis = wi, dir = nd > 0 and 1 or -1, plane = plane, rect = rect })
					end
				end
			end
		end
		return out
	end
	local allFaces = {}
	for i, it in ipairs(info) do
		if it.visible then
			for _, f in ipairs(faces(it)) do
				f.i = i
				table.insert(allFaces, f)
			end
		end
	end
	local reported = {}
	for a = 1, #allFaces do
		for b = a + 1, #allFaces do
			local f, g = allFaces[a], allFaces[b]
			if f.i ~= g.i and f.axis == g.axis and f.dir == g.dir and math.abs(f.plane - g.plane) < 0.004 then
				local ox = math.min(f.rect[2], g.rect[2]) - math.max(f.rect[1], g.rect[1])
				local oy = math.min(f.rect[4], g.rect[4]) - math.max(f.rect[3], g.rect[3])
				if ox > 0.01 and oy > 0.01 then
					local key = math.min(f.i, g.i) .. "/" .. math.max(f.i, g.i)
					if not reported[key] then
						reported[key] = true
						table.insert(problems, ("zfight: %s.%s <> %s.%s"):format(info[f.i].p.Parent.Name, info[f.i].p.Name, info[g.i].p.Parent.Name, info[g.i].p.Name))
					end
				end
			end
		end
	end
	-- connectivity (all visible parts must form one connected piece)
	local adj = {}
	for i = 1, #info do
		adj[i] = {}
	end
	for i = 1, #info do
		for j = i + 1, #info do
			if obbTouch(info[i].cf, info[i].h, info[j].cf, info[j].h, 0.01) then
				table.insert(adj[i], j)
				table.insert(adj[j], i)
			end
		end
	end
	local comp = {}
	local comps = {}
	for i = 1, #info do
		if not comp[i] then
			local id = #comps + 1
			local members = {}
			local stack = { i }
			comp[i] = id
			while #stack > 0 do
				local k = table.remove(stack)
				table.insert(members, k)
				for _, n in ipairs(adj[k]) do
					if not comp[n] then
						comp[n] = id
						table.insert(stack, n)
					end
				end
			end
			comps[id] = members
		end
	end
	local biggest = 1
	for id, m in ipairs(comps) do
		if #m > #comps[biggest] then
			biggest = id
		end
	end
	for id, m in ipairs(comps) do
		if id ~= biggest then
			local names = {}
			for _, k in ipairs(m) do
				table.insert(names, info[k].p.Parent.Name .. "." .. info[k].p.Name)
			end
			table.insert(problems, "loose: " .. table.concat(names, ", "))
		end
	end
	-- mirror symmetry
	for i, it in ipairs(info) do
		local pos = it.cf.Position
		if math.abs(pos.X) > 0.03 and not it.p:GetAttribute("Asym") and not it.p.Parent:GetAttribute("Asym") then
			local found = false
			for j, jt in ipairs(info) do
				if j ~= i then
					local q = jt.cf.Position
					if math.abs(q.X + pos.X) < 0.03 and math.abs(q.Y - pos.Y) < 0.03 and math.abs(q.Z - pos.Z) < 0.03 and (jt.h - it.h).Magnitude < 0.03 then
						found = true
						break
					end
				end
			end
			if not found then
				table.insert(problems, ("mirror: %s.%s at x=%.2f has no twin"):format(it.p.Parent.Name, it.p.Name, pos.X))
			end
		end
	end
	-- buried details
	for i, it in ipairs(info) do
		if it.visible and it.h.Magnitude < 0.5 then
			for j, jt in ipairs(info) do
				if j ~= i and jt.visible and jt.p.Transparency < 0.05 and jt.h.Magnitude > it.h.Magnitude and inside(it.cf, it.h, jt.cf, jt.h) then
					table.insert(problems, ("buried: %s.%s hidden inside %s"):format(it.p.Parent.Name, it.p.Name, jt.p.Name))
					break
				end
			end
		end
	end
	local _ = corners
	return problems
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
