-- Player HUD: coins + speed (top left), shop (right), catch button + timing bar (bottom),
-- carry banner with a guide line home and toasts (top). Icons: shared/Icons (Free Icon Pack).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Icons = require(Shared:WaitForChild("Icons"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestCatch = Remotes:WaitForChild("RequestCatch") :: RemoteFunction
local SubmitCatch = Remotes:WaitForChild("SubmitCatch") :: RemoteFunction
local BuyUpgrade = Remotes:WaitForChild("BuyUpgrade") :: RemoteFunction
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local topLeft = UIKit.area(gui, "TopLeft", UDim2.fromOffset(300, 140), UDim2.fromOffset(40, 18), Vector2.new(0, 0))
local right = UIKit.area(gui, "Right", UDim2.fromOffset(130, 150), UDim2.new(1, -20, 0.5, 0), Vector2.new(1, 0.5))
local bottom = UIKit.area(gui, "Bottom", UDim2.fromOffset(520, 280), UDim2.new(0.5, 0, 1, -16), Vector2.new(0.5, 1))
local top = UIKit.area(gui, "Top", UDim2.fromOffset(560, 260), UDim2.new(0.5, 0, 0, 14), Vector2.new(0.5, 0))
UIKit.autoScale({ topLeft, right, bottom, top })

local function formatNumber(n: number): string
	if n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

local function pop(obj: GuiObject)
	local s = obj:FindFirstChild("PopScale") :: UIScale?
	if not s then
		s = Instance.new("UIScale")
		s.Name = "PopScale"
		s.Parent = obj
	end
	local scale = s :: UIScale
	scale.Scale = 1.18
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

--------------------------------------------------------------------------- top left: coins + speed

local coinPill, coinIcon = UIKit.pill(topLeft, { name = "Coins", size = UDim2.fromOffset(230, 58), icon = Icons.Coin })
local coinText = UIKit.text(coinPill, { text = "0", bold = true, size = UDim2.new(1, -66, 0, 40), position = UDim2.fromOffset(52, 6), alignX = Enum.TextXAlignment.Left })
local incomeChip = UIKit.pill(coinPill, {
	name = "Income", size = UDim2.fromOffset(92, 24), position = UDim2.new(1, -6, 1, 10), anchor = Vector2.new(1, 1),
	top = Color3.fromRGB(110, 220, 80), bottom = Color3.fromRGB(60, 160, 50), radius = 10,
})
local incomeText = UIKit.text(incomeChip, { text = "+0/s", size = UDim2.new(1, -10, 1, -4), position = UDim2.fromOffset(5, 2), strokeThickness = 2 })

local speedPill = UIKit.pill(topLeft, { name = "Speed", size = UDim2.fromOffset(170, 46), position = UDim2.fromOffset(0, 80), icon = Icons.Speed })
local speedText = UIKit.text(speedPill, { text = "SPEED 0", bold = true, size = UDim2.new(1, -56, 0, 30), position = UDim2.fromOffset(46, 8), alignX = Enum.TextXAlignment.Left })

local lastCoins = player:GetAttribute("Coins") or 0
local function refreshStats()
	local coins = player:GetAttribute("Coins") or 0
	coinText.Text = formatNumber(coins)
	if coins > lastCoins and coinIcon then
		pop(coinIcon)
	end
	lastCoins = coins
	local ips = player:GetAttribute("IncomePerSecond") or 0
	incomeText.Text = ("+%s/s"):format(ips < 10 and string.format("%.1f", ips) or formatNumber(ips))
	speedText.Text = ("SPEED %d"):format(player:GetAttribute("SpeedLevel") or 0)
end
for _, a in ipairs({ "Coins", "IncomePerSecond", "SpeedLevel" }) do
	player:GetAttributeChangedSignal(a):Connect(refreshStats)
end
refreshStats()

--------------------------------------------------------------------------- toasts (top)

local toastHolder = Instance.new("Frame")
toastHolder.BackgroundTransparency = 1
toastHolder.Size = UDim2.new(1, 0, 0, 170)
toastHolder.Position = UDim2.fromOffset(0, 84)
toastHolder.Parent = top
local list = Instance.new("UIListLayout")
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Padding = UDim.new(0, 8)
list.Parent = toastHolder

local TOAST = {
	info = { icon = Icons.Check, top = UIKit.PanelTop, bottom = UIKit.PanelBottom },
	success = { icon = Icons.Star, top = Color3.fromRGB(110, 220, 80), bottom = Color3.fromRGB(55, 150, 45) },
	warn = { icon = Icons.Warning, top = Color3.fromRGB(255, 120, 100), bottom = Color3.fromRGB(200, 60, 60) },
	coins = { icon = Icons.Coin, top = Color3.fromRGB(255, 205, 70), bottom = Color3.fromRGB(230, 140, 20) },
}

local function toast(text: string, kind: string?)
	local style = TOAST[kind or "info"] or TOAST.info
	local width = math.clamp(#text * 15 + 90, 220, 520)
	local wrap = Instance.new("Frame")
	wrap.BackgroundTransparency = 1
	wrap.Size = UDim2.fromOffset(width, 46)
	wrap.Parent = toastHolder
	local pill = UIKit.pill(wrap, {
		size = UDim2.fromOffset(width - 30, 42), position = UDim2.new(0.5, 15, 0, 2), anchor = Vector2.new(0.5, 0),
		icon = style.icon, top = style.top, bottom = style.bottom,
	})
	UIKit.text(pill, { text = text, size = UDim2.new(1, -60, 1, -10), position = UDim2.fromOffset(46, 5), alignX = Enum.TextXAlignment.Left })
	pop(pill)
	task.delay(2.3, function()
		for _, d in ipairs(wrap:GetDescendants()) do
			if d:IsA("GuiObject") then
				TweenService:Create(d, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			end
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			elseif d:IsA("ImageLabel") then
				TweenService:Create(d, TweenInfo.new(0.35), { ImageTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			end
		end
		task.wait(0.4)
		wrap:Destroy()
	end)
end
Notify.OnClientEvent:Connect(toast)

--------------------------------------------------------------------------- right: shop

local shopFace, shopRoot = UIKit.button(right, {
	name = "Shop", size = UDim2.fromOffset(104, 104), position = UDim2.new(0.5, 0, 0, 52), color = UIKit.Colors.Blue, radius = 22,
})
UIKit.icon(shopFace, Icons.Shop, { size = UDim2.fromScale(0.78, 0.78), position = UDim2.fromScale(0.5, 0.42), anchor = Vector2.new(0.5, 0.5) })
local upgradeIcon = UIKit.icon(shopFace, Icons.Upgrade, { size = UDim2.fromOffset(44, 44), position = UDim2.new(1, 8, 0, -12), anchor = Vector2.new(1, 0), z = 6 })
UIKit.text(shopFace, { text = "SPEED", bold = true, size = UDim2.new(1, -8, 0, 24), position = UDim2.new(0.5, 0, 1, -4), anchor = Vector2.new(0.5, 1) })
local priceChip = UIKit.pill(right, {
	name = "Price", size = UDim2.fromOffset(96, 30), position = UDim2.new(0.5, 10, 0, 120), anchor = Vector2.new(0.5, 0),
	icon = Icons.Coin, radius = 12,
})
local priceText = UIKit.text(priceChip, { text = "50", bold = true, size = UDim2.new(1, -40, 1, -8), position = UDim2.fromOffset(32, 4), alignX = Enum.TextXAlignment.Left, strokeThickness = 2 })

local function nextSpeedCost(): number?
	return Config.SpeedCosts[(player:GetAttribute("SpeedLevel") or 0) + 1]
end
local function refreshShop()
	local cost = nextSpeedCost()
	priceText.Text = cost and formatNumber(cost) or "MAX"
end
player:GetAttributeChangedSignal("SpeedLevel"):Connect(refreshShop)
refreshShop()

shopFace.Activated:Connect(function()
	local result = BuyUpgrade:InvokeServer("Speed")
	if result and not result.ok and result.message then
		toast(result.message, "warn")
	end
end)

local shopScale = Instance.new("UIScale")
shopScale.Parent = shopRoot
RunService.RenderStepped:Connect(function()
	local cost = nextSpeedCost()
	local affordable = cost ~= nil and (player:GetAttribute("Coins") or 0) >= cost
	upgradeIcon.Visible = affordable
	shopScale.Scale = affordable and (1 + 0.05 * math.sin(os.clock() * 6)) or 1
	upgradeIcon.Position = UDim2.new(1, 8, 0, -12 - (affordable and math.abs(math.sin(os.clock() * 4)) * 6 or 0))
	UIKit.setButtonColor(shopRoot, affordable and UIKit.Colors.Green or UIKit.Colors.Blue)
end)

--------------------------------------------------------------------------- top: carry banner + guide line home

local carryPill = UIKit.pill(top, {
	name = "Carry", size = UDim2.fromOffset(430, 60), position = UDim2.new(0.5, 20, 0, 6), anchor = Vector2.new(0.5, 0),
	icon = Icons.Home, top = Color3.fromRGB(110, 220, 80), bottom = Color3.fromRGB(55, 150, 45),
})
local carryTitle = UIKit.text(carryPill, { text = "BRING IT HOME!", bold = true, size = UDim2.new(1, -90, 0, 26), position = UDim2.fromOffset(66, 6), alignX = Enum.TextXAlignment.Left })
local carryName = UIKit.text(carryPill, { text = "", size = UDim2.new(1, -90, 0, 20), position = UDim2.fromOffset(66, 33), alignX = Enum.TextXAlignment.Left, strokeThickness = 2 })
carryPill.Visible = false

local guide: Beam? = nil
local function setGuide(on: boolean)
	if guide then
		if guide.Attachment0 then
			guide.Attachment0:Destroy()
		end
		if guide.Attachment1 then
			guide.Attachment1:Destroy()
		end
		guide:Destroy()
		guide = nil
	end
	if not on then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local map = workspace:FindFirstChild("Map")
	local bases = map and map:FindFirstChild("Bases")
	local plot = bases and bases:FindFirstChild("Base_" .. tostring(player:GetAttribute("PlotId")))
	local floor = plot and plot:FindFirstChild("Floor")
	if not hrp or not floor then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, -2.5, 0)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 1, 0)
	a1.Parent = floor
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = 1.4
	b.Width1 = 1.4
	b.FaceCamera = true
	b.Color = ColorSequence.new(Color3.fromRGB(130, 240, 100))
	b.Transparency = NumberSequence.new(0.2)
	b.LightEmission = 1
	b.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = 3
	b.TextureSpeed = 2
	b.Segments = 20
	b.Parent = floor
	guide = b
end

local function refreshCarry()
	local name = player:GetAttribute("Carrying")
	carryPill.Visible = name ~= nil
	if name then
		local rarity = player:GetAttribute("CarryingRarity") or ""
		local r = Config.RarityByName[rarity]
		carryName.Text = ("%s %s"):format(rarity, name)
		carryName.TextColor3 = r and UIKit.lighter(r.color, 0.2) or Color3.new(1, 1, 1)
		pop(carryPill)
	end
	setGuide(name ~= nil)
end
player:GetAttributeChangedSignal("Carrying"):Connect(refreshCarry)
player.CharacterAdded:Connect(function()
	task.wait(0.5)
	refreshCarry()
end)

--------------------------------------------------------------------------- bottom: catch button + timing bar

local catchFace, catchRoot = UIKit.button(bottom, {
	name = "Catch", size = UDim2.fromOffset(132, 132), position = UDim2.new(0.5, 0, 1, -72), color = UIKit.Colors.Green, radius = 66, depth = 8,
})
UIKit.icon(catchFace, Icons.Paw, { size = UDim2.fromScale(0.6, 0.6), position = UDim2.fromScale(0.5, 0.4), anchor = Vector2.new(0.5, 0.5) })
local catchLabel = UIKit.text(catchFace, { text = "CATCH", bold = true, size = UDim2.new(0.86, 0, 0, 30), position = UDim2.new(0.5, 0, 1, -14), anchor = Vector2.new(0.5, 1) })
local keyHint = UIKit.text(catchRoot, { text = "E", bold = true, size = UDim2.fromOffset(30, 30), position = UDim2.new(1, 4, 0, -4), anchor = Vector2.new(1, 0), z = 6, strokeThickness = 2 })
keyHint.Visible = UserInputService.KeyboardEnabled
catchRoot.Visible = false

local targetChip = UIKit.pill(bottom, { name = "Target", size = UDim2.fromOffset(250, 36), position = UDim2.new(0.5, 0, 1, -158), anchor = Vector2.new(0.5, 1), radius = 12 })
local targetText = UIKit.text(targetChip, { text = "", size = UDim2.new(1, -20, 1, -8), position = UDim2.fromOffset(10, 4), strokeThickness = 2 })
targetChip.Visible = false

-- timing bar
local barRoot = UIKit.area(bottom, "TimingBar", UDim2.fromOffset(460, 92), UDim2.new(0.5, 0, 0, 0), Vector2.new(0.5, 0))
barRoot.Visible = false
local barTitle = UIKit.text(barRoot, { text = "TAP!", bold = true, size = UDim2.new(1, 0, 0, 34), position = UDim2.new() })
local track = UIKit.pill(barRoot, { name = "Track", size = UDim2.new(1, 0, 0, 40), position = UDim2.fromOffset(0, 44), radius = 20, top = Color3.fromRGB(30, 24, 56), bottom = Color3.fromRGB(52, 42, 90) })
local zone = Instance.new("Frame")
zone.Name = "Zone"
zone.BackgroundColor3 = Color3.new(1, 1, 1)
zone.Size = UDim2.new(0.3, 0, 1, -10)
zone.Position = UDim2.fromOffset(0, 5)
zone.ZIndex = 3
UIKit.corner(zone, 14)
UIKit.gradient(zone, Color3.fromRGB(160, 255, 120), Color3.fromRGB(70, 200, 60))
UIKit.stroke(zone, 2, Color3.fromRGB(200, 255, 190))
zone.Parent = track
local cursor = Instance.new("Frame")
cursor.Name = "Cursor"
cursor.BackgroundColor3 = Color3.new(1, 1, 1)
cursor.Size = UDim2.new(0, 12, 1, 18)
cursor.Position = UDim2.new(0, 0, 0, -9)
cursor.AnchorPoint = Vector2.new(0.5, 0)
cursor.ZIndex = 5
UIKit.corner(cursor, 6)
UIKit.stroke(cursor, 3)
cursor.Parent = track

local wildFolder = workspace:WaitForChild("WildCritters")
local target: Model? = nil
local highlight = Instance.new("Highlight")
highlight.FillTransparency = 1
highlight.OutlineColor = Color3.new(1, 1, 1)
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.Parent = workspace

type Active = { token: string, zoneStart: number, zoneSize: number, speed: number, t0: number, done: boolean }
local active: Active? = nil
local busy = false

local function cursorPos(a: Active): number
	local x = ((os.clock() - a.t0) * a.speed) % 2 -- ping-pong 0..1
	return x <= 1 and x or 2 - x
end

local function finishCatch(hit: boolean)
	local a = active
	if not a or a.done then
		return
	end
	a.done = true
	local result = SubmitCatch:InvokeServer(a.token, hit)
	active = nil
	barRoot.Visible = false
	busy = false
	if result and result.ok then
		if result.success then
			toast("CAUGHT!", "success")
		else
			toast("It got away!", "warn")
		end
	end
end

local function startCatch()
	if busy or active or not target then
		return
	end
	busy = true
	local res = RequestCatch:InvokeServer(target:GetAttribute("CritterId"))
	if not res or not res.ok then
		busy = false
		if res and res.reason then
			toast(res.reason, "warn")
		end
		return
	end
	local size = math.clamp(res.zone, 0.05, 1)
	local a: Active = {
		token = res.token,
		zoneStart = (size >= 1) and 0 or math.random() * (1 - size),
		zoneSize = size,
		speed = res.speed,
		t0 = os.clock(),
		done = false,
	}
	active = a
	zone.Position = UDim2.new(a.zoneStart, 0, 0, 5)
	zone.Size = UDim2.new(a.zoneSize, 0, 1, -10)
	barTitle.Text = res.guaranteed and "EASY CATCH - TAP!" or "TAP ON GREEN!"
	barRoot.Visible = true
	pop(barRoot)
	task.delay(Config.CatchTimeout - 1, function()
		if active == a then
			finishCatch(false)
		end
	end)
end

local function press()
	local a = active
	if a then
		if os.clock() - a.t0 < 0.3 then
			return -- the tap that opened the bar doesn't count as the answer
		end
		local x = cursorPos(a)
		finishCatch(x >= a.zoneStart and x <= a.zoneStart + a.zoneSize)
	else
		startCatch()
	end
end

catchFace.Activated:Connect(press)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		press()
	end
end)

RunService.RenderStepped:Connect(function()
	if active then
		cursor.Position = UDim2.new(cursorPos(active), 0, 0, -9)
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local best, bestD = nil, Config.CatchRange
	if hrp and not player:GetAttribute("Carrying") then
		for _, m in ipairs(wildFolder:GetChildren()) do
			if m:IsA("Model") and m.PrimaryPart then
				local d = (m.PrimaryPart.Position - hrp.Position).Magnitude
				if d < bestD then
					best, bestD = m, d
				end
			end
		end
	end
	if not active then
		target = best
	end
	local shown = target ~= nil
	if shown and not catchRoot.Visible then
		pop(catchRoot)
	end
	catchRoot.Visible = shown
	targetChip.Visible = shown and not active
	highlight.Adornee = target
	if target then
		catchLabel.Text = active and "NOW!" or "CATCH"
		local rarity = target:GetAttribute("Rarity") or ""
		local mutation = target:GetAttribute("Mutation")
		targetText.Text = ("%s%s %s"):format(mutation and (mutation .. " ") or "", rarity, target.Name)
		local r = Config.RarityByName[rarity]
		targetText.TextColor3 = r and UIKit.lighter(r.color, 0.2) or Color3.new(1, 1, 1)
		highlight.OutlineColor = r and UIKit.lighter(r.color, 0.4) or Color3.new(1, 1, 1)
	end
end)
