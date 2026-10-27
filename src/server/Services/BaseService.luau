-- Carrying caught critters home, placing them on the plot's slots, income and the coin pad.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CritterDefs = require(ReplicatedStorage.Shared.CritterDefs)
local Icons = require(ReplicatedStorage.Shared.Icons)
local CritterModels = require(script.Parent.CritterModels)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local BaseService = {}

local carrying: { [Player]: { entry: Config.CritterEntry, model: Model, nest: string? } } = {}
local lastFullWarning: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	(Remotes.Notify :: RemoteEvent):FireClient(player, text, kind or "info")
end
BaseService.notify = notify

local function incomeOf(entry: Config.CritterEntry): number
	local def = CritterDefs[entry.species]
	return Config.income(entry, def.baseIncome, def.baseKg)
end

function BaseService.walkSpeed(player: Player): number
	local data = DataService.get(player)
	local speed = Config.walkSpeed(data and data.speedLevel or 0)
	local carry = carrying[player]
	if carry then
		speed *= Config.RarityByName[carry.entry.rarity].carrySpeed
	end
	return speed
end

function BaseService.applyWalkSpeed(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = BaseService.walkSpeed(player)
	end
end

function BaseService.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

--------------------------------------------------------------------------- base displays

local function displayFolder(plot: Model): Folder
	local f = plot:FindFirstChild("CritterDisplays") :: Folder?
	if not f then
		f = Instance.new("Folder")
		f.Name = "CritterDisplays"
		f.Parent = plot
	end
	return f :: Folder
end

local function showOnSlot(plot: Model, index: number, entry: Config.CritterEntry)
	local slot = PlotService.slot(plot, index)
	if not slot then
		return
	end
	local folder = displayFolder(plot)
	local old = folder:FindFirstChild("Slot" .. index)
	if old then
		old:Destroy()
	end
	local model = CritterModels.build(entry)
	model.Name = "Slot" .. index
	local top = slot.Position + Vector3.new(0, slot.Size.Y / 2 + (model:GetAttribute("RootHeight") or 0.2), 0)
	local facing = (plot:FindFirstChild("Floor") :: BasePart).CFrame.LookVector -- towards the avenue
	model:PivotTo(CFrame.lookAt(top, top + facing))
	-- income tag under the nameplate
	local plate = model.PrimaryPart:FindFirstChild("Nameplate") :: BillboardGui?
	if plate then
		local inc = Instance.new("TextLabel")
		inc.Name = "Income"
		inc.Position = UDim2.new(0, 0, 1, 0)
		inc.Size = UDim2.new(1, 0, 0.45, 0)
		inc.BackgroundTransparency = 1
		inc.Font = Enum.Font.FredokaOne
		inc.TextScaled = true
		inc.TextColor3 = Color3.fromRGB(255, 215, 60)
		inc.Text = ("+%s/s"):format(string.format("%.1f", incomeOf(entry)))
		local s = Instance.new("UIStroke")
		s.Thickness = 2
		s.Parent = inc
		inc.Parent = plate
		plate.Size = UDim2.fromOffset(160, 66)
	end
	model.Parent = folder
end

function BaseService.renderBase(player: Player)
	local plot = PlotService.getPlot(player)
	local data = DataService.get(player)
	if not plot or not data then
		return
	end
	displayFolder(plot):ClearAllChildren()
	for key, entry in pairs(data.base) do
		showOnSlot(plot, tonumber(key) :: number, entry)
	end
end

function BaseService.clearBase(plot: Model)
	displayFolder(plot):ClearAllChildren()
	local pad = plot:FindFirstChild("CoinPad") :: BasePart?
	if pad then
		for _, n in ipairs({ "CoinDisplay", "LabelAnchor" }) do
			local d = pad:FindFirstChild(n)
			if d then
				d:Destroy()
			end
		end
	end
end

--------------------------------------------------------------------------- carrying

local function attachCarry(player: Player, entry: Config.CritterEntry): Model?
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local model = CritterModels.build(entry, { scale = 0.6, label = false })
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
		end
	end
	model:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.25, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model.Name = "CarriedCritter"
	model.Parent = char
	return model
end

-- Called by CritterService when a catch succeeds. Returns false if the player can't take it.
function BaseService.startCarry(player: Player, entry: Config.CritterEntry, nestZone: string?): boolean
	if carrying[player] then
		return false
	end
	local model = attachCarry(player, entry)
	if not model then
		return false
	end
	carrying[player] = { entry = entry, model = model, nest = nestZone }
	player:SetAttribute("Carrying", CritterDefs[entry.species].displayName)
	player:SetAttribute("CarryingRarity", entry.rarity)
	BaseService.applyWalkSpeed(player)
	local data = DataService.get(player)
	if data then
		data.totalCatches += 1
		player:SetAttribute("TotalCatches", data.totalCatches)
		data.dex[("%s/%s/%s"):format(entry.species, entry.rarity, entry.mutation or "None")] = true
	end
	return true
end

-- Removes the carried critter and returns it (used when a guardian knocks the player over).
function BaseService.takeCarry(player: Player): (Config.CritterEntry?, string?)
	local c = carrying[player]
	if not c then
		return nil, nil
	end
	BaseService.dropCarry(player)
	return c.entry, c.nest
end

function BaseService.carriedNest(player: Player): string?
	local c = carrying[player]
	return c and c.nest
end

function BaseService.dropCarry(player: Player)
	local c = carrying[player]
	if not c then
		return
	end
	carrying[player] = nil
	if c.model.Parent then
		c.model:Destroy()
	end
	player:SetAttribute("Carrying", nil)
	player:SetAttribute("CarryingRarity", nil)
	BaseService.applyWalkSpeed(player)
end

local function freeSlot(data: DataService.Data): number?
	for i = 1, data.slotsUnlocked do
		if not data.base[tostring(i)] then
			return i
		end
	end
	return nil
end

local function tryDeposit(player: Player)
	local c = carrying[player]
	local plot = PlotService.getPlot(player)
	local data = DataService.get(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not c or not plot or not data or not hrp or not PlotService.isInside(plot, hrp.Position) then
		return
	end
	local index = freeSlot(data)
	if not index then
		if os.clock() - (lastFullWarning[player] or 0) > 4 then
			lastFullWarning[player] = os.clock()
			notify(player, "Your base is full!", "warn")
		end
		return
	end
	data.base[tostring(index)] = c.entry
	BaseService.dropCarry(player)
	showOnSlot(plot, index, c.entry)
	notify(player, ("%s placed! +%s coins/s"):format(CritterDefs[c.entry.species].displayName, string.format("%.1f", incomeOf(c.entry))), "success")
end

--------------------------------------------------------------------------- income + coin pad

-- Floating display above a coin pad: spinning gold coin + billboard with icon and amount.
-- Lives on its own anchored part, so the pad's rotation (it is a cylinder) doesn't matter.
local function padGui(pad: BasePart): TextLabel
	local display = pad:FindFirstChild("CoinDisplay") :: Model?
	if not display then
		local m = Instance.new("Model")
		m.Name = "CoinDisplay"
		local base = pad.Position + Vector3.new(0, 3.2, 0)
		local coin = Instance.new("Part")
		coin.Name = "Coin"
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.45, 2.6, 2.6)
		coin.CFrame = CFrame.new(base) * CFrame.Angles(0, math.rad(90), 0)
		coin.Color = Color3.fromRGB(255, 200, 50)
		coin.Material = Enum.Material.SmoothPlastic
		coin.Reflectance = 0.15
		coin.Anchored = true
		coin.CanCollide = false
		coin.CanQuery = false
		coin.CanTouch = false
		coin.CastShadow = false
		coin.Parent = m
		local rim = coin:Clone()
		rim.Name = "Rim"
		rim.Size = Vector3.new(0.5, 2.0, 2.0)
		rim.Color = Color3.fromRGB(230, 150, 20)
		rim.Reflectance = 0
		rim.Parent = m
		m.PrimaryPart = coin
		m.WorldPivot = CFrame.new(base)
		m:SetAttribute("SpinAxis", "Y")
		m:SetAttribute("Speed", 90)
		CollectionService:AddTag(m, "Spinner")

		local anchor = Instance.new("Part")
		anchor.Name = "LabelAnchor"
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.CFrame = CFrame.new(base + Vector3.new(0, 2.6, 0))
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Parent = pad

		local g = Instance.new("BillboardGui")
		g.Name = "PadGui"
		g.Size = UDim2.fromOffset(190, 52)
		g.MaxDistance = 90
		g.LightInfluence = 0
		g.Adornee = anchor
		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Image = Icons.Coin
		icon.Size = UDim2.fromOffset(52, 52)
		icon.Parent = g
		local t = Instance.new("TextLabel")
		t.Name = "Amount"
		t.Position = UDim2.fromOffset(56, 4)
		t.Size = UDim2.new(1, -58, 1, -8)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextColor3 = Color3.fromRGB(255, 225, 90)
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Color = Color3.fromRGB(20, 14, 36)
		s.Parent = t
		t.Parent = g
		g.Parent = anchor
		m.Parent = pad
		display = m
	end
	local anchor = pad:FindFirstChild("LabelAnchor")
	return (anchor :: Instance):FindFirstChild("PadGui"):FindFirstChild("Amount") :: TextLabel
end

local function updatePad(player: Player)
	local plot = PlotService.getPlot(player)
	local data = DataService.get(player)
	local pad = plot and plot:FindFirstChild("CoinPad") :: BasePart?
	if pad and data then
		padGui(pad).Text = tostring(math.floor(data.pendingCoins))
	end
end

local function collect(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local amount = math.floor(data.pendingCoins)
	if amount <= 0 then
		return
	end
	data.pendingCoins -= amount
	data.coins += amount
	player:SetAttribute("Coins", data.coins)
	updatePad(player)
	notify(player, ("+%d coins"):format(amount), "coins")
end

local function hookPads()
	for _, pad in ipairs(CollectionService:GetTagged("CoinPad")) do
		if pad:IsA("BasePart") then
			pad.CanTouch = true
			local debounce: { [Player]: number } = {}
			pad.Touched:Connect(function(hit)
				local plr = Players:GetPlayerFromCharacter(hit.Parent)
				if not plr or (debounce[plr] and os.clock() - debounce[plr] < 0.5) then
					return
				end
				debounce[plr] = os.clock()
				local plot = PlotService.getPlot(plr)
				if plot and pad:IsDescendantOf(plot) then
					collect(plr)
				end
			end)
		end
	end
end

function BaseService.init()
	hookPads()
	-- deposit check (4x per second)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player in pairs(carrying) do
				tryDeposit(player)
			end
		end
	end)
	-- income
	task.spawn(function()
		while true do
			task.wait(Config.IncomeTick)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.get(player)
				if data then
					local total = 0
					for _, entry in pairs(data.base) do
						total += incomeOf(entry)
					end
					data.pendingCoins += total * Config.IncomeTick
					player:SetAttribute("IncomePerSecond", total)
					updatePad(player)
				end
			end
		end
	end)
end

function BaseService.onPlayerReady(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("SpeedLevel", data.speedLevel)
	player:SetAttribute("TotalCatches", data.totalCatches)
	BaseService.renderBase(player)
	updatePad(player)
end

function BaseService.onPlayerLeaving(player: Player)
	BaseService.dropCarry(player)
	lastFullWarning[player] = nil
	local plot = PlotService.getPlot(player)
	if plot then
		BaseService.clearBase(plot)
	end
end

return BaseService
