-- Carrying caught critters home, placing them on the plot's slots, selling them, income and the
-- coin pad. Signals: Deposited(player, slotIndex, entry), Collected(player, amount), Sold(player, entry, coins)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local CritterDefs = require(ReplicatedStorage.Shared.CritterDefs)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local CritterModels = require(ServerScriptService.Lib.CritterModels)
local DataService = require(script.Parent.DataService)
local FxService = require(script.Parent.FxService)
local PlotService = require(script.Parent.PlotService)

local BaseService = {}
BaseService.Priority = 20

BaseService.Deposited = Signal.new()
BaseService.Collected = Signal.new()
BaseService.Sold = Signal.new()

type Carry = { entry: Config.CritterEntry, model: Model, nest: string? }
local carrying: { [Player]: Carry } = {}
local lastFullWarning: { [Player]: number } = {}

function BaseService.incomeOf(entry: Config.CritterEntry): number
	local def = CritterDefs[entry.species]
	return Config.income(entry, def.baseIncome, def.baseKg)
end
local incomeOf = BaseService.incomeOf

-- Permanent income multiplier of a player (rebirths).
function BaseService.multiplierOf(player: Player): number
	local data = DataService.get(player)
	return 1 + Config.RebirthIncomeBonus * (data and data.rebirths or 0)
end

local function sellValue(player: Player, entry: Config.CritterEntry): number
	return math.max(5, math.floor(incomeOf(entry) * BaseService.multiplierOf(player) * Config.SellSeconds))
end

--------------------------------------------------------------------------- speed

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

local sellSlot -- forward declaration (defined below)

local function showOnSlot(plot: Model, index: number, entry: Config.CritterEntry, player: Player?)
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
		local mult = player and BaseService.multiplierOf(player) or 1
		inc.Text = ("+%s/s"):format(string.format("%.1f", incomeOf(entry) * mult))
		local s = Instance.new("UIStroke")
		s.Thickness = 2
		s.Parent = inc
		inc.Parent = plate
		plate.Size = UDim2.fromOffset(160, 66)
	end
	-- hold F to sell (only the owner sees it: Controllers/Prompts hides prompts of other plots)
	if player and model.PrimaryPart then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SellPrompt"
		prompt.ActionText = ("Sell  +%d"):format(sellValue(player, entry))
		prompt.ObjectText = CritterDefs[entry.species].displayName
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt:SetAttribute("OwnerUserId", player.UserId)
		prompt.Triggered:Connect(function(who)
			if who == player then
				sellSlot(player, index)
			end
		end)
		prompt.Parent = model.PrimaryPart
	end
	model.Parent = folder
end

-- Redraws one slot (e.g. after a weather mutation changed the critter).
function BaseService.rerenderSlot(player: Player, index: number)
	local plot = PlotService.getPlot(player)
	local data = DataService.get(player)
	local entry = data and data.base[tostring(index)]
	if plot and entry then
		showOnSlot(plot, index, entry, player)
	end
end

function BaseService.renderBase(player: Player)
	local plot = PlotService.getPlot(player)
	local data = DataService.get(player)
	if not plot or not data then
		return
	end
	displayFolder(plot):ClearAllChildren()
	for key, entry in pairs(data.base) do
		showOnSlot(plot, tonumber(key) :: number, entry, player)
	end
end

local function clearBase(plot: Model)
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

function BaseService.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

function BaseService.carriedNest(player: Player): string?
	local c = carrying[player]
	return c and c.nest
end

local function attachCarry(player: Player, entry: Config.CritterEntry): Model?
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local model = CritterModels.build(entry, { scale = 0.6, label = false, fx = false })
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

-- Puts a freshly caught critter on the player's head. Returns false if they can't take it.
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
	end
	local DexService = require(script.Parent.DexService) :: any -- lazy: DexService requires BaseService
	local isNew, found, total = DexService.register(player, entry)
	FxService.toPlayer(player, "CatchCard", BaseService.cardData(player, entry, {
		isNew = isNew,
		dexFound = found,
		dexTotal = total,
		fromNest = nestZone ~= nil,
	}))
	return true
end

-- Data for the client's catch / hatch reveal card.
function BaseService.cardData(player: Player, entry: Config.CritterEntry, extra: { [string]: any }?): { [string]: any }
	local d: { [string]: any } = {
		name = CritterDefs[entry.species].displayName,
		rarity = entry.rarity,
		mutation = entry.mutation,
		sizeKg = entry.sizeKg,
		income = incomeOf(entry) * BaseService.multiplierOf(player),
	}
	for k, v in pairs(extra or {}) do
		d[k] = v
	end
	return d
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

-- Removes the carried critter and returns it (used when a guardian knocks the player over).
function BaseService.takeCarry(player: Player): (Config.CritterEntry?, string?)
	local c = carrying[player]
	if not c then
		return nil, nil
	end
	BaseService.dropCarry(player)
	return c.entry, c.nest
end

local function freeSlot(data: DataService.Data): number?
	for i = 1, data.slotsUnlocked do
		if not data.base[tostring(i)] then
			return i
		end
	end
	return nil
end

function BaseService.hasFreeSlot(player: Player): boolean
	local data = DataService.get(player)
	return data ~= nil and freeSlot(data) ~= nil
end

-- Puts a critter straight into the first free slot (e.g. hatched from an egg). Returns the slot.
function BaseService.place(player: Player, entry: Config.CritterEntry): number?
	local plot = PlotService.getPlot(player)
	local data = DataService.get(player)
	local index = data and freeSlot(data)
	if not plot or not data or not index then
		return nil
	end
	data.base[tostring(index)] = entry
	showOnSlot(plot, index, entry, player)
	local slot = PlotService.slot(plot, index)
	if slot then
		FxService.toAll("Deposit", { pos = slot.Position + Vector3.new(0, slot.Size.Y / 2, 0), rarity = entry.rarity })
	end
	return index
end

function sellSlot(player: Player, index: number)
	local plot = PlotService.getPlot(player)
	local data = DataService.get(player)
	local entry = data and data.base[tostring(index)]
	if not plot or not data or not entry then
		return
	end
	local coins = sellValue(player, entry)
	data.base[tostring(index)] = nil
	local model = displayFolder(plot):FindFirstChild("Slot" .. index)
	if model then
		model:Destroy()
	end
	BaseService.addCoins(player, coins)
	local slot = PlotService.slot(plot, index)
	FxService.toPlayer(player, "Collect", { pos = slot and slot.Position or Vector3.zero, amount = coins })
	FxService.notify(player, ("Sold %s for %d coins"):format(CritterDefs[entry.species].displayName, coins), "coins")
	BaseService.Sold:Fire(player, entry, coins)
end
BaseService.sell = sellSlot

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
			FxService.notify(player, "Your base is full! Hold F on a critter to sell it", "warn")
		end
		return
	end
	data.base[tostring(index)] = c.entry
	BaseService.dropCarry(player)
	showOnSlot(plot, index, c.entry, player)
	local slot = PlotService.slot(plot, index)
	if slot then
		FxService.toAll("Deposit", { pos = slot.Position + Vector3.new(0, slot.Size.Y / 2, 0), rarity = c.entry.rarity })
	end
	FxService.notify(player, ("%s placed! +%s coins/s"):format(CritterDefs[c.entry.species].displayName, string.format("%.1f", incomeOf(c.entry) * BaseService.multiplierOf(player))), "success")
	BaseService.Deposited:Fire(player, index, c.entry)
end

--------------------------------------------------------------------------- income + coin pad

-- Floating display above a coin pad: spinning gold coin + billboard with icon and amount.
-- Lives on its own anchored part, so the pad's rotation (it is a cylinder) doesn't matter.
local function padLabel(pad: BasePart): TextLabel
	local anchor = pad:FindFirstChild("LabelAnchor") :: BasePart?
	if not anchor then
		local m = Instance.new("Model")
		m.Name = "CoinDisplay"
		local base = pad.Position + Vector3.new(0, 3.2, 0)
		local function coinPart(name: string, size: Vector3, color: Color3, refl: number): Part
			local p = Instance.new("Part")
			p.Name = name
			p.Shape = Enum.PartType.Cylinder
			p.Size = size
			p.CFrame = CFrame.new(base) * CFrame.Angles(0, math.rad(90), 0)
			p.Color = color
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = refl
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Parent = m
			return p
		end
		m.PrimaryPart = coinPart("Coin", Vector3.new(0.45, 2.6, 2.6), Color3.fromRGB(255, 200, 50), 0.15)
		coinPart("Rim", Vector3.new(0.5, 2, 2), Color3.fromRGB(230, 150, 20), 0)
		m:SetAttribute("SpinAxis", "Y")
		m:SetAttribute("Speed", 90)
		CollectionService:AddTag(m, "Spinner")
		m.Parent = pad

		local a = Instance.new("Part")
		a.Name = "LabelAnchor"
		a.Transparency = 1
		a.Size = Vector3.new(0.2, 0.2, 0.2)
		a.CFrame = CFrame.new(base + Vector3.new(0, 2.6, 0))
		a.Anchored = true
		a.CanCollide = false
		a.CanQuery = false
		a.CanTouch = false
		a.Parent = pad
		local g = Instance.new("BillboardGui")
		g.Name = "PadGui"
		g.Size = UDim2.fromOffset(190, 52)
		g.MaxDistance = 90
		g.LightInfluence = 0
		g.Adornee = a
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
		g.Parent = a
		anchor = a
	end
	return ((anchor :: BasePart):FindFirstChild("PadGui") :: BillboardGui):FindFirstChild("Amount") :: TextLabel
end

local function updatePad(player: Player)
	local plot = PlotService.getPlot(player)
	local data = DataService.get(player)
	local pad = plot and plot:FindFirstChild("CoinPad") :: BasePart?
	if pad and data then
		padLabel(pad).Text = tostring(math.floor(data.pendingCoins))
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
	local plot = PlotService.getPlot(player)
	local pad = plot and plot:FindFirstChild("CoinPad") :: BasePart?
	FxService.toPlayer(player, "Collect", { pos = pad and pad.Position or Vector3.zero, amount = amount })
	BaseService.Collected:Fire(player, amount)
end

-- Income per second without weather (welcome-back reward, quest rewards).
function BaseService.baseIncome(player: Player): number
	local data = DataService.get(player)
	local total = 0
	for _, entry in pairs(data and data.base or {}) do
		total += incomeOf(entry)
	end
	return total * BaseService.multiplierOf(player)
end

-- Adds coins directly (rewards, refunds). Positive amounts only.
function BaseService.addCoins(player: Player, amount: number)
	local data = DataService.get(player)
	if data and amount > 0 then
		data.coins += amount
		player:SetAttribute("Coins", data.coins)
	end
end

-- Spends coins if the player has enough. Returns true on success.
function BaseService.spendCoins(player: Player, amount: number): boolean
	local data = DataService.get(player)
	if not data or data.coins < amount then
		return false
	end
	data.coins -= amount
	player:SetAttribute("Coins", data.coins)
	return true
end

--------------------------------------------------------------------------- lifecycle

function BaseService.Start()
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
					local mult = (workspace:GetAttribute("IncomeMultiplier") or 1) * BaseService.multiplierOf(player) -- Rain weather, rebirths
					data.pendingCoins += total * mult * Config.IncomeTick
					player:SetAttribute("IncomePerSecond", total * mult)
					updatePad(player)
				end
			end
		end
	end)
end

function BaseService.PlayerAdded(player: Player, data: DataService.Data)
	player:SetAttribute("Coins", data.coins)
	player:SetAttribute("SpeedLevel", data.speedLevel)
	player:SetAttribute("TotalCatches", data.totalCatches)
	-- first session: Meadow guardians stay asleep for this player (GDD onboarding rule)
	player:SetAttribute("Newcomer", data.sessions <= 1)
	BaseService.renderBase(player)
	updatePad(player)
	local function onCharacter(character: Model)
		BaseService.dropCarry(player) -- a new character never carries the old critter
		character:WaitForChild("Humanoid", 10)
		BaseService.applyWalkSpeed(player)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function BaseService.PlayerRemoving(player: Player)
	BaseService.dropCarry(player)
	lastFullWarning[player] = nil
	local plot = PlotService.getPlot(player)
	if plot then
		clearBase(plot)
	end
end

return BaseService
