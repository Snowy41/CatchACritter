-- Player HUD: coins + speed (top left), speed shop (right), catch button + timing bar (bottom),
-- carry banner with a guide line home and toasts (top). Icons: shared/Icons (Free Icon Pack).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local GREEN_LIGHT = Color3.fromRGB(150, 255, 120)

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local topLeft = UIKit.area(gui, "TopLeft", UDim2.fromOffset(300, 140), UDim2.fromOffset(44, 18), Vector2.new(0, 0))
local right = UIKit.area(gui, "Right", UDim2.fromOffset(140, 170), UDim2.new(1, -22, 0.5, 0), Vector2.new(1, 0.5))
local bottom = UIKit.area(gui, "Bottom", UDim2.fromOffset(520, 290), UDim2.new(0.5, 0, 1, -18), Vector2.new(0.5, 1))
local top = UIKit.area(gui, "Top", UDim2.fromOffset(560, 270), UDim2.new(0.5, 0, 0, 14), Vector2.new(0.5, 0))
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

-- text centred vertically inside a pill body, starting at x
local function pillText(body: Frame, text: string, x: number, heightScale: number, bold: boolean?)
	return UIKit.text(body, {
		text = text,
		bold = bold,
		size = UDim2.new(1, -x - 12, heightScale, 0),
		position = UDim2.new(0, x, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		alignX = Enum.TextXAlignment.Left,
	})
end

--------------------------------------------------------------------------- top left: coins + speed

local coinPill = UIKit.pill(topLeft, { name = "Coins", size = UDim2.fromOffset(250, 60), icon = Icons.Coin, iconScale = 1.4 })
local coinText = pillText(coinPill.body, "0", 58, 0.64, true)
coinText.Size = UDim2.new(1, -150, 0.64, 0)
local incomeText = UIKit.text(coinPill.body, {
	text = "+0/s", size = UDim2.new(0, 84, 0.4, 0), position = UDim2.new(1, -12, 0.5, 0), anchor = Vector2.new(1, 0.5),
	alignX = Enum.TextXAlignment.Right, color = GREEN_LIGHT, strokeThickness = 2.5,
})

local speedPill = UIKit.pill(topLeft, { name = "Speed", size = UDim2.fromOffset(196, 50), position = UDim2.fromOffset(0, 78), icon = Icons.Speed, iconScale = 1.35 })
local speedText = pillText(speedPill.body, "SPEED 0", 52, 0.6, true)

-- coins count up smoothly instead of jumping
local shownCoins = player:GetAttribute("Coins") or 0
local targetCoins = shownCoins
local function refreshStats()
	local coins = player:GetAttribute("Coins") or 0
	if coins > targetCoins and coinPill.icon then
		UIKit.pop(coinPill.icon, 0.25)
	end
	targetCoins = coins
	local ips = player:GetAttribute("IncomePerSecond") or 0
	incomeText.Text = ("+%s/s"):format(ips < 10 and string.format("%.1f", ips) or formatNumber(ips))
	speedText.Text = ("SPEED %d"):format(player:GetAttribute("SpeedLevel") or 0)
end
for _, a in ipairs({ "Coins", "IncomePerSecond", "SpeedLevel" }) do
	player:GetAttributeChangedSignal(a):Connect(refreshStats)
end
refreshStats()
RunService.RenderStepped:Connect(function(dt)
	if shownCoins ~= targetCoins then
		local diff = targetCoins - shownCoins
		local step = math.max(math.abs(diff) * math.min(1, dt * 8), 1)
		shownCoins = math.abs(diff) <= step and targetCoins or shownCoins + math.sign(diff) * step
		coinText.Text = formatNumber(shownCoins)
	end
end)
coinText.Text = formatNumber(shownCoins)

--------------------------------------------------------------------------- toasts (top)

local toastHolder = Instance.new("Frame")
toastHolder.BackgroundTransparency = 1
toastHolder.Size = UDim2.new(1, 0, 0, 180)
toastHolder.Position = UDim2.fromOffset(0, 86)
toastHolder.Parent = top
local list = Instance.new("UIListLayout")
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Padding = UDim.new(0, 10)
list.Parent = toastHolder

local TOAST = {
	info = { icon = Icons.Check, top = UIKit.PanelTop, bottom = UIKit.PanelBottom },
	success = { icon = Icons.Star, top = Color3.fromRGB(110, 220, 80), bottom = Color3.fromRGB(50, 145, 40) },
	warn = { icon = Icons.Warning, top = Color3.fromRGB(255, 120, 100), bottom = Color3.fromRGB(195, 55, 55) },
	coins = { icon = Icons.Coin, top = Color3.fromRGB(255, 205, 70), bottom = Color3.fromRGB(225, 135, 15) },
}

local function fadeOut(root: Instance, t: number)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Frame") then
			UIKit.tween(d, t, { BackgroundTransparency = 1 })
		elseif d:IsA("TextLabel") then
			UIKit.tween(d, t, { TextTransparency = 1 })
		elseif d:IsA("ImageLabel") then
			UIKit.tween(d, t, { ImageTransparency = 1 })
		elseif d:IsA("UIStroke") then
			UIKit.tween(d, t, { Transparency = 1 })
		end
	end
end

local function toast(text: string, kind: string?)
	local style = TOAST[kind or "info"] or TOAST.info
	local width = math.clamp(#text * 14 + 100, 220, 520)
	local wrap = Instance.new("Frame")
	wrap.BackgroundTransparency = 1
	wrap.Size = UDim2.fromOffset(width, 48)
	wrap.Parent = toastHolder
	local pill = UIKit.pill(wrap, {
		size = UDim2.fromOffset(width - 34, 44), position = UDim2.new(0.5, 17, 0, 0), anchor = Vector2.new(0.5, 0),
		icon = style.icon, iconScale = 1.35, top = style.top, bottom = style.bottom,
	})
	pillText(pill.body, text, 44, 0.62, true)
	UIKit.pop(pill.holder, 0.2)
	task.delay(2.3, function()
		fadeOut(wrap, 0.35)
		task.wait(0.4)
		wrap:Destroy()
	end)
end
Notify.OnClientEvent:Connect(toast)

--------------------------------------------------------------------------- right: speed shop

local shop = UIKit.button(right, {
	name = "SpeedShop", size = UDim2.fromOffset(112, 112), position = UDim2.new(0.5, 0, 0, 60),
	color = UIKit.Colors.Blue, radius = 24, depth = 7,
})
UIKit.icon(shop.face, Icons.Shoe, { size = UDim2.fromScale(0.74, 0.62), position = UDim2.fromScale(0.5, 0.38), anchor = Vector2.new(0.5, 0.5) })
local band = Instance.new("Frame")
band.Name = "Band"
band.BackgroundColor3 = UIKit.Ink
band.BackgroundTransparency = 0.35
band.BorderSizePixel = 0
band.Size = UDim2.new(1, -14, 0, 26)
band.Position = UDim2.new(0.5, 0, 1, -8)
band.AnchorPoint = Vector2.new(0.5, 1)
band.ZIndex = 5
UIKit.corner(band, 10)
band.Parent = shop.face
UIKit.text(band, { text = "SPEED", bold = true, size = UDim2.new(1, -8, 1, -4), position = UDim2.new(0.5, 0, 0.5, 0), anchor = Vector2.new(0.5, 0.5), z = 6, strokeThickness = 2 })
local upgradeIcon = UIKit.icon(shop.root, Icons.Upgrade, { size = UDim2.fromOffset(46, 46), position = UDim2.new(1, 10, 0, -14), anchor = Vector2.new(1, 0), z = 8 })
upgradeIcon.Visible = false

local price = UIKit.pill(right, { name = "Price", size = UDim2.fromOffset(104, 36), position = UDim2.new(0.5, 12, 0, 132), anchor = Vector2.new(0.5, 0), icon = Icons.Coin, iconScale = 1.3, radius = 14 })
local priceText = pillText(price.body, "50", 32, 0.62, true)

local function nextSpeedCost(): number?
	return Config.SpeedCosts[(player:GetAttribute("SpeedLevel") or 0) + 1]
end
local wasAffordable: boolean? = nil
local function refreshShop()
	local cost = nextSpeedCost()
	priceText.Text = cost and formatNumber(cost) or "MAX"
	local affordable = cost ~= nil and (player:GetAttribute("Coins") or 0) >= cost
	if affordable ~= wasAffordable then
		wasAffordable = affordable
		UIKit.setButtonColor(shop, affordable and UIKit.Colors.Green or UIKit.Colors.Blue)
		upgradeIcon.Visible = affordable
		if affordable then
			UIKit.pop(shop.face, 0.15)
		end
	end
end
player:GetAttributeChangedSignal("SpeedLevel"):Connect(refreshShop)
player:GetAttributeChangedSignal("Coins"):Connect(refreshShop)
refreshShop()

shop.face.Activated:Connect(function()
	local result = BuyUpgrade:InvokeServer("Speed")
	if result and not result.ok and result.message then
		toast(result.message, "warn")
	end
end)

RunService.RenderStepped:Connect(function()
	if upgradeIcon.Visible then
		upgradeIcon.Position = UDim2.new(1, 10, 0, -14 - math.abs(math.sin(os.clock() * 4)) * 8)
	end
end)

--------------------------------------------------------------------------- top: carry banner + guide line home

local carry = UIKit.pill(top, {
	name = "Carry", size = UDim2.fromOffset(420, 62), position = UDim2.new(0.5, 22, 0, 6), anchor = Vector2.new(0.5, 0),
	icon = Icons.Home, iconScale = 1.4, top = Color3.fromRGB(110, 220, 80), bottom = Color3.fromRGB(50, 145, 40),
})
local carryTitle = UIKit.text(carry.body, {
	text = "BRING IT HOME!", bold = true, size = UDim2.new(1, -80, 0.46, 0), position = UDim2.new(0, 64, 0.08, 0), alignX = Enum.TextXAlignment.Left,
})
local carryName = UIKit.text(carry.body, {
	text = "", size = UDim2.new(1, -80, 0.34, 0), position = UDim2.new(0, 64, 0.56, 0), alignX = Enum.TextXAlignment.Left, strokeThickness = 2.5,
})
carry.holder.Visible = false

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
	carry.holder.Visible = name ~= nil
	if name then
		local rarity = player:GetAttribute("CarryingRarity") or ""
		local r = Config.RarityByName[rarity]
		carryName.Text = ("%s %s"):format(rarity, name)
		carryName.TextColor3 = r and UIKit.lighter(r.color, 0.25) or Color3.new(1, 1, 1)
		UIKit.pop(carry.holder, 0.15)
	end
	setGuide(name ~= nil)
end
player:GetAttributeChangedSignal("Carrying"):Connect(refreshCarry)
player.CharacterAdded:Connect(function()
	task.wait(0.5)
	refreshCarry()
end)

--------------------------------------------------------------------------- bottom: catch button + timing bar

local catch = UIKit.button(bottom, {
	name = "Catch", size = UDim2.fromOffset(138, 138), position = UDim2.new(0.5, 0, 1, -78),
	color = UIKit.Colors.Green, radius = 69, depth = 8, shineInterval = 2.5,
})
UIKit.icon(catch.face, Icons.Paw, { size = UDim2.fromScale(0.58, 0.58), position = UDim2.fromScale(0.5, 0.4), anchor = Vector2.new(0.5, 0.5) })
local catchLabel = UIKit.text(catch.face, {
	text = "CATCH", bold = true, size = UDim2.new(0.78, 0, 0.22, 0), position = UDim2.new(0.5, 0, 1, -16), anchor = Vector2.new(0.5, 1), z = 6,
})
local keyHint = UIKit.pill(catch.root, { name = "Key", size = UDim2.fromOffset(34, 34), position = UDim2.new(1, 6, 0, 2), anchor = Vector2.new(1, 0), radius = 10 })
UIKit.text(keyHint.body, { text = "E", bold = true, size = UDim2.new(1, -8, 1, -8), position = UDim2.new(0.5, 0, 0.5, 0), anchor = Vector2.new(0.5, 0.5), strokeThickness = 2 })
keyHint.holder.ZIndex = 9
keyHint.holder.Visible = UserInputService.KeyboardEnabled
catch.root.Visible = false

local targetChip = UIKit.pill(bottom, { name = "Target", size = UDim2.fromOffset(260, 38), position = UDim2.new(0.5, 0, 1, -166), anchor = Vector2.new(0.5, 1), radius = 14 })
local targetText = UIKit.text(targetChip.body, { text = "", size = UDim2.new(1, -24, 0.62, 0), position = UDim2.new(0.5, 0, 0.5, 0), anchor = Vector2.new(0.5, 0.5), strokeThickness = 2.5 })
targetChip.holder.Visible = false

-- timing bar
local barRoot = UIKit.area(bottom, "TimingBar", UDim2.fromOffset(470, 96), UDim2.new(0.5, 0, 0, 0), Vector2.new(0.5, 0))
barRoot.Visible = false
local barTitle = UIKit.text(barRoot, { text = "TAP!", bold = true, size = UDim2.new(1, 0, 0, 36), position = UDim2.new() })
local track = UIKit.pill(barRoot, { name = "Track", size = UDim2.new(1, 0, 0, 42), position = UDim2.fromOffset(0, 46), radius = 21, top = Color3.fromRGB(26, 20, 50), bottom = Color3.fromRGB(56, 44, 96) })
local zone = Instance.new("Frame")
zone.Name = "Zone"
zone.BackgroundColor3 = Color3.new(1, 1, 1)
zone.Size = UDim2.new(0.3, 0, 1, -12)
zone.Position = UDim2.fromOffset(0, 6)
zone.ZIndex = 4
UIKit.corner(zone, 14)
UIKit.gradient(zone, Color3.fromRGB(170, 255, 130), Color3.fromRGB(70, 200, 60))
UIKit.stroke(zone, 2, Color3.fromRGB(210, 255, 200))
zone.Parent = track.body
local cursor = Instance.new("Frame")
cursor.Name = "Cursor"
cursor.BackgroundColor3 = Color3.new(1, 1, 1)
cursor.Size = UDim2.new(0, 14, 1, 20)
cursor.Position = UDim2.new(0, 0, 0, -10)
cursor.AnchorPoint = Vector2.new(0.5, 0)
cursor.ZIndex = 6
UIKit.corner(cursor, 7)
UIKit.stroke(cursor, 3)
cursor.Parent = track.body

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
	zone.Position = UDim2.new(a.zoneStart, 0, 0, 6)
	zone.Size = UDim2.new(a.zoneSize, 0, 1, -12)
	barTitle.Text = res.guaranteed and "EASY CATCH - TAP!" or "TAP ON GREEN!"
	barRoot.Visible = true
	UIKit.pop(barRoot, 0.12)
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

catch.face.Activated:Connect(press)
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
		cursor.Position = UDim2.new(cursorPos(active), 0, 0, -10)
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
	if shown and not catch.root.Visible then
		UIKit.pop(catch.face, 0.2)
	end
	catch.root.Visible = shown
	targetChip.holder.Visible = shown and not active
	highlight.Adornee = target
	if target then
		catchLabel.Text = active and "NOW!" or "CATCH"
		local rarity = target:GetAttribute("Rarity") or ""
		local mutation = target:GetAttribute("Mutation")
		targetText.Text = ("%s%s %s"):format(mutation and (mutation .. " ") or "", rarity, target.Name)
		local r = Config.RarityByName[rarity]
		targetText.TextColor3 = r and UIKit.lighter(r.color, 0.25) or Color3.new(1, 1, 1)
		highlight.OutlineColor = r and UIKit.lighter(r.color, 0.4) or Color3.new(1, 1, 1)
	end
end)
