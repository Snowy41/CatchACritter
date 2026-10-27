-- Zone guardians: sleep next to their nest, a wake-up meter fills while players are close,
-- then they chase the culprit. A bump knocks the player back (cartoon, no damage) and the
-- carried nest critter runs back to the nest. Bases (SafeZone) are always safe.
--
-- States: Sleeping -> Waking -> Chasing -> Returning -> Sleeping

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BaseService = require(script.Parent.BaseService)
local CritterService = require(script.Parent.CritterService)
local FxService = require(script.Parent.FxService)

local GuardianService = {}

type Guardian = {
	zone: string,
	def: Config.GuardianDef,
	model: Model,
	home: CFrame,
	nest: BasePart,
	state: string,
	meter: number,
	culprit: Player?,
	target: Player?,
	stateSince: number,
	pos: Vector3,
	yaw: number,
	gui: BillboardGui,
	bar: Frame,
	label: TextLabel,
}

local guardians: { Guardian } = {}
local safeZones: { BasePart } = {}
local knockbackRemote: RemoteEvent
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function hrpOf(player: Player?): BasePart?
	local char = player and player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function inSafeZone(pos: Vector3): boolean
	for _, z in ipairs(safeZones) do
		local l = z.CFrame:PointToObjectSpace(pos)
		local h = z.Size / 2
		if math.abs(l.X) <= h.X and math.abs(l.Y) <= h.Y and math.abs(l.Z) <= h.Z then
			return true
		end
	end
	return false
end

local function protected(g: Guardian, player: Player): boolean
	return g.def.protectNewcomers and player:GetAttribute("Newcomer") == true
end

--------------------------------------------------------------------------- visuals

local function meterGui(model: Model): (BillboardGui, Frame, TextLabel)
	local _, size = model:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "WakeMeter"
	gui.Size = UDim2.fromOffset(220, 84)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y + 1, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "State"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 50)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "Zzz"
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Color3.fromRGB(20, 14, 36)
	s.Parent = label
	label.Parent = gui
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(20, 56)
	track.Size = UDim2.new(1, -40, 0, 22)
	track.BackgroundColor3 = Color3.fromRGB(32, 24, 60)
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(1, 0)
	tc.Parent = track
	local ts = Instance.new("UIStroke")
	ts.Thickness = 3
	ts.Color = Color3.fromRGB(20, 14, 36)
	ts.Parent = track
	track.Parent = gui
	local bar = Instance.new("Frame")
	bar.Name = "Fill"
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = Color3.fromRGB(110, 220, 80)
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(1, 0)
	bc.Parent = bar
	bar.Parent = track
	gui.Parent = model.PrimaryPart
	return gui, bar, label
end

local function setState(g: Guardian, state: string)
	if g.state == "Chasing" and state ~= "Chasing" and g.target then
		FxService.toPlayer(g.target, "Chased", { on = false })
	end
	if state == "Waking" then
		FxService.toAll("GuardianWake", { pos = g.pos })
	end
	g.state = state
	g.stateSince = os.clock()
	g.model:SetAttribute("State", state)
	local anim = (state == "Sleeping") and "Sleep" or ((state == "Waking") and "Alert" or "Chase")
	g.model:SetAttribute("Anim", anim)
	g.model:SetAttribute("AnimSpeed", state == "Returning" and 0.7 or 1)
end

local function refreshGui(g: Guardian)
	local m = math.clamp(g.meter / 100, 0, 1)
	g.bar.Size = UDim2.fromScale(m, 1)
	g.bar.BackgroundColor3 = Color3.fromRGB(110, 220, 80):Lerp(Color3.fromRGB(255, 80, 70), m)
	if g.state == "Sleeping" then
		g.label.Text = m > 0.6 and "Zz..?" or "Zzz"
		g.label.TextColor3 = Color3.new(1, 1, 1)
	elseif g.state == "Waking" then
		g.label.Text = "!"
		g.label.TextColor3 = Color3.fromRGB(255, 215, 60)
	elseif g.state == "Chasing" then
		g.label.Text = "!!"
		g.label.TextColor3 = Color3.fromRGB(255, 90, 80)
	else
		g.label.Text = "Hmph"
		g.label.TextColor3 = Color3.fromRGB(200, 200, 210)
	end
	g.bar.Parent.Visible = g.state == "Sleeping" or g.state == "Waking"
end

--------------------------------------------------------------------------- movement

local function groundY(g: Guardian, x: number, z: number): number
	local ignore: { Instance } = { g.model }
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end
	local wildFolder = workspace:FindFirstChild("WildCritters")
	if wildFolder then
		table.insert(ignore, wildFolder)
	end
	local map = workspace:FindFirstChild("Map")
	local gameplay = map and map:FindFirstChild("Gameplay")
	if gameplay then
		table.insert(ignore, gameplay)
	end
	rayParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(x, g.pos.Y + 30, z), Vector3.new(0, -80, 0), rayParams)
	return hit and hit.Position.Y or g.home.Position.Y
end

local function moveToward(g: Guardian, goal: Vector3, speed: number, dt: number): number
	local delta = Vector3.new(goal.X - g.pos.X, 0, goal.Z - g.pos.Z)
	local dist = delta.Magnitude
	if dist > 0.05 then
		local dir = delta.Unit
		local stepLen = math.min(dist, speed * dt)
		local nextPos = g.pos + dir * stepLen
		local y = groundY(g, nextPos.X, nextPos.Z)
		g.pos = Vector3.new(nextPos.X, y, nextPos.Z)
		local targetYaw = math.atan2(-dir.X, -dir.Z)
		local diff = (targetYaw - g.yaw + math.pi) % (2 * math.pi) - math.pi
		g.yaw += diff * math.min(1, dt * 6)
	end
	g.model:PivotTo(CFrame.new(g.pos + Vector3.new(0, g.model:GetAttribute("RootHeight") or 0.5, 0)) * CFrame.Angles(0, g.yaw, 0))
	return dist
end

--------------------------------------------------------------------------- behaviour

local function nearestPlayer(pos: Vector3, radius: number, g: Guardian): Player?
	local best, bestD = nil, radius
	for _, plr in ipairs(Players:GetPlayers()) do
		local hrp = hrpOf(plr)
		if hrp and not protected(g, plr) and not inSafeZone(hrp.Position) then
			local d = (hrp.Position - pos).Magnitude
			if d < bestD then
				best, bestD = plr, d
			end
		end
	end
	return best
end

local function bump(g: Guardian, player: Player)
	local hrp = hrpOf(player)
	if hrp then
		local away = Vector3.new(hrp.Position.X - g.pos.X, 0, hrp.Position.Z - g.pos.Z)
		away = away.Magnitude > 0.01 and away.Unit or Vector3.new(0, 0, 1)
		knockbackRemote:FireClient(player, away * g.def.knockback + Vector3.new(0, g.def.knockback * 0.6, 0))
	end
	FxService.toAll("Bonk", { userId = player.UserId })
	local entry, nest = BaseService.takeCarry(player)
	if entry then
		-- the critter scurries back: nest critters to their nest, wild ones just escape
		if nest then
			CritterService.returnToNest(nest, entry)
		end
		BaseService.notify(player, g.def.displayName .. " got you! Your critter ran away.", "warn")
	else
		BaseService.notify(player, g.def.displayName .. " bonked you!", "warn")
	end
end

local function update(g: Guardian, dt: number)
	local now = os.clock()
	local def = g.def
	if g.state == "Sleeping" then
		local fill = 0
		for _, plr in ipairs(Players:GetPlayers()) do
			local hrp = hrpOf(plr)
			if hrp and not protected(g, plr) then
				local d = (hrp.Position - g.nest.Position).Magnitude
				if d < def.wakeRadius then
					local closeness = 1 + (1 - d / def.wakeRadius) -- up to 2x right next to the nest
					local running = hrp.AssemblyLinearVelocity.Magnitude > 12
					fill += (def.wakeIdle + (running and def.wakeRunning or 0)) * closeness
				end
			end
		end
		if fill > 0 then
			g.meter += fill * dt
		else
			g.meter = math.max(0, g.meter - def.wakeDecay * dt)
		end
		if g.meter >= 100 then
			g.meter = 100
			setState(g, "Waking")
		end
	elseif g.state == "Waking" then
		if now - g.stateSince > 1.3 then
			local target = g.culprit
			if not (target and hrpOf(target) and not inSafeZone((hrpOf(target) :: BasePart).Position)) then
				target = nearestPlayer(g.pos, def.wakeRadius * 2, g)
			end
			if target then
				g.target = target
				setState(g, "Chasing")
				FxService.toPlayer(target, "Chased", { on = true, name = def.displayName })
				BaseService.notify(target, def.displayName .. " is awake - RUN home!", "warn")
			else
				g.meter = 60
				setState(g, "Sleeping")
			end
		end
	elseif g.state == "Chasing" then
		local hrp = hrpOf(g.target)
		local tooFar = (g.pos - g.home.Position).Magnitude > def.chaseLeash
		if not hrp or inSafeZone(hrp.Position) or tooFar or now - g.stateSince > def.chaseTime then
			g.target = nil
			setState(g, "Returning")
		else
			local dist = moveToward(g, hrp.Position, def.chaseSpeed, dt)
			if dist < def.bumpRange then
				bump(g, g.target :: Player)
				g.target = nil
				setState(g, "Returning")
			end
		end
	elseif g.state == "Returning" then
		local dist = moveToward(g, g.home.Position, def.returnSpeed, dt)
		if dist < 0.6 then
			-- settle facing the nest again
			g.pos = g.home.Position
			local look = (g.nest.Position - g.home.Position) * Vector3.new(1, 0, 1)
			g.yaw = math.atan2(-look.X, -look.Z)
			moveToward(g, g.pos, 0, 0)
			g.meter = 35
			g.culprit = nil
			setState(g, "Sleeping")
		end
	end
	refreshGui(g)
end

-- Called by CritterService when someone snatches a critter out of a nest.
function GuardianService.onNestCaught(player: Player, zone: string)
	for _, g in ipairs(guardians) do
		if g.zone == zone and not protected(g, player) then
			g.culprit = player
			if g.state == "Sleeping" then
				g.meter = math.min(100, g.meter + g.def.wakeOnCatch)
			end
		end
	end
end

function GuardianService.init()
	knockbackRemote = FxService.remote("Knockback")

	for _, z in ipairs(CollectionService:GetTagged("SafeZone")) do
		if z:IsA("BasePart") then
			table.insert(safeZones, z)
		end
	end
	local nestByZone: { [string]: BasePart } = {}
	for _, n in ipairs(CollectionService:GetTagged("NestSpot")) do
		if n:IsA("BasePart") then
			nestByZone[n:GetAttribute("Zone")] = n
		end
	end
	local templates = ServerStorage:WaitForChild("GuardianTemplates")
	local folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = workspace
	for _, spot in ipairs(CollectionService:GetTagged("GuardianSpot")) do
		local zone = spot:GetAttribute("Zone")
		local def = zone and Config.Guardians[zone]
		local nest = zone and nestByZone[zone]
		local template = def and templates:FindFirstChild(def.template) :: Model?
		if spot:IsA("BasePart") and def and nest and template then
			local model = template:Clone()
			local ground = spot.Position - Vector3.new(0, spot.Size.Y / 2, 0)
			local look = (nest.Position - ground) * Vector3.new(1, 0, 1)
			local yaw = math.atan2(-look.X, -look.Z)
			local home = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
			model:PivotTo(home + Vector3.new(0, model:GetAttribute("RootHeight") or 0.5, 0))
			CollectionService:AddTag(model, "AnimatedCritter")
			model:SetAttribute("Species", def.template)
			model.Parent = folder
			local gui, bar, label = meterGui(model)
			local g: Guardian = {
				zone = zone,
				def = def,
				model = model,
				home = home,
				nest = nest,
				state = "Sleeping",
				meter = 0,
				culprit = nil,
				target = nil,
				stateSince = os.clock(),
				pos = ground,
				yaw = yaw,
				gui = gui,
				bar = bar,
				label = label,
			}
			setState(g, "Sleeping")
			refreshGui(g)
			table.insert(guardians, g)
		end
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 20 then
			return
		end
		for _, g in ipairs(guardians) do
			update(g, acc)
		end
		acc = 0
	end)
end

return GuardianService
