-- Client-side world UI:
--  * egg countdowns (EggLabel billboards, driven by the egg model's HatchAt attribute)
--  * hides proximity prompts that belong to other players (attribute OwnerUserId)
--  * summoning circle labels (state, pads ready, cooldown) and per-pad species signs

local Controller = {}

function Controller.Start()
	local CollectionService = game:GetService("CollectionService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local CritterDefs = require(Shared:WaitForChild("CritterDefs"))

	local player = Players.LocalPlayer
	local INK = Color3.fromRGB(20, 14, 36)

	--------------------------------------------------------------------------- prompts of other players

	local function checkPrompt(p: Instance)
		if p:IsA("ProximityPrompt") then
			local owner = p:GetAttribute("OwnerUserId")
			if owner and owner ~= player.UserId then
				p.Enabled = false
				p:GetPropertyChangedSignal("Enabled"):Connect(function()
					if p.Enabled then
						p.Enabled = false
					end
				end)
			end
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		checkPrompt(d)
	end
	workspace.DescendantAdded:Connect(checkPrompt)

	--------------------------------------------------------------------------- labels

	local function label(parent: Instance, name: string, size: UDim2, pos: UDim2, color: Color3, bold: boolean): TextLabel
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.Size = size
		t.Position = pos
		t.Font = bold and Enum.Font.LuckiestGuy or Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = color
		t.Text = ""
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Color = INK
		s.Parent = t
		t.Parent = parent
		return t
	end

	local function fmt(seconds: number): string
		seconds = math.max(0, math.floor(seconds))
		if seconds >= 3600 then
			return ("%dh %02dm"):format(seconds // 3600, (seconds % 3600) // 60)
		end
		return ("%d:%02d"):format(seconds // 60, seconds % 60)
	end

	-- summoning circles: one billboard over the core, a species sign per pad
	type Circle = { model: Model, title: TextLabel, sub: TextLabel }
	local circles: { Circle } = {}
	local function setupCircle(model: Instance)
		if not model:IsA("Model") then
			return
		end
		local core = model:WaitForChild("Core", 10) :: BasePart?
		if not core then
			return
		end
		local g = Instance.new("BillboardGui")
		g.Name = "SummonLabel"
		g.Size = UDim2.fromOffset(260, 80)
		g.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
		g.MaxDistance = 140
		g.LightInfluence = 0
		g.Adornee = core
		g:SetAttribute("RefDistance", 16)
		local title = label(g, "Title", UDim2.new(1, 0, 0.55, 0), UDim2.new(), Color3.fromRGB(200, 170, 255), true)
		local sub = label(g, "Sub", UDim2.new(1, 0, 0.4, 0), UDim2.fromScale(0, 0.58), Color3.new(1, 1, 1), false)
		g.Parent = player:WaitForChild("PlayerGui")
		table.insert(circles, { model = model, title = title, sub = sub })
		for _, pad in ipairs(model:GetChildren()) do
			local species = pad:GetAttribute("Species")
			if pad:IsA("BasePart") and species then
				local pg = Instance.new("BillboardGui")
				pg.Name = "PadLabel"
				pg.Size = UDim2.fromOffset(170, 44)
				pg.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
				pg.MaxDistance = 80
				pg.LightInfluence = 0
				pg.Adornee = pad
				local t = label(pg, "Species", UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(240, 230, 255), true)
				local def = CritterDefs[species]
				t.Text = (def and def.displayName or species) .. " owner"
				pg.Parent = player.PlayerGui
			end
		end
	end
	for _, m in ipairs(CollectionService:GetTagged("SummonCircle")) do
		task.spawn(setupCircle, m)
	end
	CollectionService:GetInstanceAddedSignal("SummonCircle"):Connect(setupCircle)

	--------------------------------------------------------------------------- tick

	while true do
		local now = os.time()
		-- eggs in every base (ours and others, so friends can see timers too)
		local bases = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Bases")
		if bases then
			for _, plot in ipairs(bases:GetChildren()) do
				local nest = plot:FindFirstChild("EggNest")
				if nest then
					for _, egg in ipairs(nest:GetChildren()) do
						local hatchAt = egg:GetAttribute("HatchAt")
						local shell = egg:IsA("Model") and egg.PrimaryPart
						local g = shell and shell:FindFirstChild("EggLabel")
						local timer = g and g:FindFirstChild("Timer") :: TextLabel?
						if hatchAt and timer then
							local left = hatchAt - now
							timer.Text = left <= 0 and "READY!" or fmt(left)
							timer.TextColor3 = left <= 0 and Color3.fromRGB(150, 255, 120) or Color3.new(1, 1, 1)
						end
					end
				end
			end
		end
		for _, c in ipairs(circles) do
			local m = c.model
			local state = m:GetAttribute("State") or "Idle"
			if state == "Cooldown" then
				c.title.Text = "CIRCLE RESTING"
				c.sub.Text = "Ready again in " .. fmt((m:GetAttribute("CooldownEnds") or now) - now)
			elseif state == "Charging" then
				c.title.Text = "SUMMONING..."
				c.sub.Text = fmt((m:GetAttribute("ChargeEnds") or now) - now)
			else
				c.title.Text = "SUMMONING CIRCLE"
				c.sub.Text = ("%d / %d pads ready"):format(m:GetAttribute("Ready") or 0, m:GetAttribute("Needed") or 0)
			end
		end
		task.wait(0.5)
	end
end

return Controller
