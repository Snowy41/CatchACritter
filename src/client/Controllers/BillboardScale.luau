-- Makes every BillboardGui behave like a world-space sign: it shrinks with distance instead of
-- keeping a constant pixel size on screen. Billboards are still designed in pixels (their Size as
-- authored = how they look at REF_DISTANCE studs); each frame this sets Size = design * s and a
-- UIScale of s, with s = REF_DISTANCE / distance, so text, strokes, corners and layouts all scale.
-- Opt out per billboard with the attribute ScreenSpace = true; override the reference distance
-- with the attribute RefDistance (number).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Controller = {}

local REF_DISTANCE = 16
local MIN_SCALE, MAX_SCALE = 0.05, 1.6

type Entry = { design: UDim2, written: UDim2?, scale: UIScale }

local tracked: { [BillboardGui]: Entry } = {}

local function anchorPosition(g: BillboardGui): Vector3?
	local a = g.Adornee or g.Parent
	local pos: Vector3
	if a and a:IsA("BasePart") then
		pos = a.Position
	elseif a and a:IsA("Attachment") then
		pos = a.WorldPosition
	elseif a and a:IsA("Model") then
		pos = a:GetPivot().Position
	else
		return nil
	end
	return pos + g.StudsOffsetWorldSpace
end

local function track(g: Instance)
	if not g:IsA("BillboardGui") or tracked[g] or g:GetAttribute("ScreenSpace") then
		return
	end
	local scale = g:FindFirstChild("DistanceScale") :: UIScale?
	if not scale then
		scale = Instance.new("UIScale")
		;(scale :: UIScale).Name = "DistanceScale"
		;(scale :: UIScale).Parent = g
	end
	local entry: Entry = { design = g.Size, written = nil, scale = scale :: UIScale }
	tracked[g] = entry
	-- a Size set by anyone else (server or other scripts) becomes the new design size
	g:GetPropertyChangedSignal("Size"):Connect(function()
		if g.Size ~= entry.written then
			entry.design = g.Size
		end
	end)
	g.Destroying:Connect(function()
		tracked[g] = nil
	end)
end

local function watch(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		track(d)
	end
	root.DescendantAdded:Connect(track)
end

function Controller.Start()
	local camera = workspace.CurrentCamera
	watch(workspace)
	watch(Players.LocalPlayer:WaitForChild("PlayerGui"))

	RunService.RenderStepped:Connect(function()
		local camPos = camera.CFrame.Position
		for g, e in pairs(tracked) do
			if g.Enabled and g.Parent then
				local pos = anchorPosition(g)
				if pos then
					local dist = (pos - camPos).Magnitude
					local ref = g:GetAttribute("RefDistance")
					local s = math.clamp((typeof(ref) == "number" and ref or REF_DISTANCE) / math.max(dist, 0.1), MIN_SCALE, MAX_SCALE)
					local d = e.design
					local size = UDim2.new(d.X.Scale, d.X.Offset * s, d.Y.Scale, d.Y.Offset * s)
					e.written = size
					g.Size = size
					e.scale.Scale = s
				end
			end
		end
	end)
end

return Controller
