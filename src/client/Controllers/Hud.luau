-- Player HUD: coins + speed (top left), speed shop (right), carry banner with a guide line home
-- and toasts (top). The catch button + timing bar live in Controllers/Catching.

local Controller = {}

function Controller.Start()

	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared:WaitForChild("Config"))
	local Icons = require(Shared:WaitForChild("Icons"))
	local UIKit = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UIKit"))
	local Bus = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Bus"))

	local Net = require(Shared:WaitForChild("Net"))
	local BuyUpgrade = Net.func("BuyUpgrade")
	local Notify = Net.event("Notify")

	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")

	local topLeft = UIKit.area(gui, "TopLeft", UDim2.fromOffset(300, 140), UDim2.fromOffset(44, 18), Vector2.new(0, 0))
	local right = UIKit.area(gui, "Right", UDim2.fromOffset(140, 170), UDim2.new(1, -22, 0.5, 0), Vector2.new(1, 0.5))
	local top = UIKit.area(gui, "Top", UDim2.fromOffset(560, 270), UDim2.new(0.5, 0, 0, 14), Vector2.new(0.5, 0))
	UIKit.autoScale({ topLeft, right, top })

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

	local coinPill = UIKit.pill(topLeft, {
		name = "Coins", size = UDim2.fromOffset(250, 60), icon = Icons.Coin, iconScale = 1.4,
		top = UIKit.Themes.Gold[1], bottom = UIKit.Themes.Gold[2], pattern = "Stars", patternTransparency = 0.8, patternTile = 40,
	})
	local coinText = pillText(coinPill.body, "0", 58, 0.64, true)
	UIKit.shineSweep(coinPill.body, 16, 3)
	if coinPill.icon then
		UIKit.glow(coinPill.holder, { size = UDim2.fromOffset(120, 120), position = UDim2.fromOffset(18, 30), color = Color3.fromRGB(255, 220, 90), transparency = 0.35, z = 1 })
		UIKit.bob(coinPill.icon, 6, 1.6)
	end
	UIKit.sparkles(coinPill.body, { rate = 0.8, z = 8, minSize = 10, maxSize = 18 })
	coinText.Size = UDim2.new(1, -150, 0.64, 0)
	local incomeText = UIKit.text(coinPill.body, {
		text = "+0/s", size = UDim2.new(0, 84, 0.4, 0), position = UDim2.new(1, -12, 0.5, 0), anchor = Vector2.new(1, 0.5),
		alignX = Enum.TextXAlignment.Right, color = Color3.fromRGB(200, 255, 170), strokeThickness = 2.5,
	})

	local speedPill = UIKit.pill(topLeft, {
		name = "Speed", size = UDim2.fromOffset(250, 50), position = UDim2.fromOffset(0, 78), icon = Icons.Speed, iconScale = 1.35,
		top = UIKit.Themes.Blue[1], bottom = UIKit.Themes.Blue[2], pattern = "Stars", patternTransparency = 0.8, patternTile = 36,
	})
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
			icon = style.icon, iconScale = 1.35, top = style.top, bottom = style.bottom, pattern = "Stars", patternTransparency = 0.84, patternTile = 34,
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
	Bus.Toast:Connect(toast) -- toasts from other controllers (e.g. Catching)
	-- server-wide banners (Effects) show at the top: slide the toasts below them meanwhile
	local function placeToasts()
		local active = player.PlayerGui:GetAttribute("AnnounceActive") == true
		UIKit.tween(toastHolder, 0.25, { Position = UDim2.fromOffset(0, active and 170 or 86) })
	end
	player.PlayerGui:GetAttributeChangedSignal("AnnounceActive"):Connect(placeToasts)

	--------------------------------------------------------------------------- right: speed shop

	-- One unit: tab ("SPEED") on the top edge, shoe icon on the face, gold price tag hanging off
	-- the bottom edge, outlined upgrade arrow when affordable. Everything is parented to the
	-- button root, so hover/press scaling moves the whole unit together.
	local shop = UIKit.button(right, {
		name = "SpeedShop", size = UDim2.fromOffset(112, 112), position = UDim2.new(0.5, 0, 0, 62),
		color = UIKit.Colors.Blue, radius = 26, depth = 7,
	})
	UIKit.icon(shop.face, Icons.Shoe, { size = UDim2.fromScale(0.8, 0.7), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5) })

	local tab = UIKit.pill(shop.root, {
		name = "Tab", size = UDim2.fromOffset(96, 28), position = UDim2.new(0.5, 0, 0, 0), anchor = Vector2.new(0.5, 0.5), radius = 11,
	})
	tab.holder.ZIndex = 6
	UIKit.text(tab.body, { text = "SPEED", bold = true, size = UDim2.new(1, -10, 0.7, 0), position = UDim2.new(0.5, 0, 0.5, 0), anchor = Vector2.new(0.5, 0.5), strokeThickness = 2 })

	local price = UIKit.pill(shop.root, {
		name = "Price", size = UDim2.fromOffset(96, 34), position = UDim2.new(0.5, 0, 1, 9), anchor = Vector2.new(0.5, 0.5),
		icon = Icons.Coin, iconScale = 1.35, radius = 13,
		top = UIKit.Themes.Gold[1], bottom = UIKit.Themes.Gold[2],
	})
	price.holder.ZIndex = 6
	local priceText = UIKit.valueText(price.body, { text = "25", inset = 30, height = 0.64 })

	local shopBurst = UIKit.sunburst(shop.root, { size = UDim2.fromOffset(230, 230), color = Color3.fromRGB(255, 250, 170), transparency = 0.25, z = 0 })
	shopBurst.Visible = false
	local upgradeIcon = UIKit.icon(shop.root, Icons.Upgrade, { size = UDim2.fromOffset(48, 48), position = UDim2.new(1, 12, 0, -12), anchor = Vector2.new(1, 0), z = 8 })
	upgradeIcon.Visible = false

	local function nextSpeedCost(): number?
		return Config.SpeedCosts[(player:GetAttribute("SpeedLevel") or 0) + 1]
	end
	local wasAffordable: boolean? = nil
	local shopStroke: UIStroke? = nil
	local function refreshShop()
		local cost = nextSpeedCost()
		priceText.Text = cost and formatNumber(cost) or "MAX"
		local affordable = cost ~= nil and (player:GetAttribute("Coins") or 0) >= cost
		priceText.TextColor3 = (affordable or not cost) and Color3.new(1, 1, 1) or Color3.fromRGB(255, 225, 225)
		if affordable ~= wasAffordable then
			wasAffordable = affordable
			UIKit.setButtonColor(shop, affordable and UIKit.Colors.Green or UIKit.Colors.Blue)
			upgradeIcon.Visible = affordable
			shopBurst.Visible = affordable
			if affordable and not shopStroke then
				shopStroke = UIKit.rainbowStroke(shop.face, { thickness = 4 })
			elseif not affordable and shopStroke then
				shopStroke:Destroy()
				shopStroke = nil
				local own = shop.face:FindFirstChildOfClass("UIStroke")
				if own then
					own.Enabled = true
				end
			end
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
			upgradeIcon.Position = UDim2.new(1, 12, 0, -12 - math.abs(math.sin(os.clock() * 4)) * 8)
		end
	end)

	--------------------------------------------------------------------------- top left: weather

	local WEATHER_UI = {
		Rain = { icon = Icons.Storm, name = "RAIN", top = Color3.fromRGB(110, 160, 230), bottom = Color3.fromRGB(50, 90, 170) },
		Snowstorm = { icon = Icons.Cloud, name = "SNOW", top = Color3.fromRGB(170, 215, 255), bottom = Color3.fromRGB(80, 140, 210) },
		RainbowStorm = { icon = Icons.Star, name = "RAINBOW", top = Color3.fromRGB(255, 140, 210), bottom = Color3.fromRGB(150, 90, 230) },
	}
	local weatherPill: any = nil
	local weatherText: TextLabel? = nil
	local shownWeather = "Clear"
	local function refreshWeather()
		local weather = workspace:GetAttribute("Weather") or "Clear"
		if weather ~= shownWeather then
			shownWeather = weather
			if weatherPill then
				weatherPill.holder:Destroy()
				weatherPill, weatherText = nil, nil
			end
			local ui = WEATHER_UI[weather]
			if ui then
				weatherPill = UIKit.pill(topLeft, {
					name = "Weather", size = UDim2.fromOffset(250, 46), position = UDim2.fromOffset(0, 136),
					icon = ui.icon, iconScale = 1.4, top = ui.top, bottom = ui.bottom, pattern = "Stars", patternTransparency = 0.8, patternTile = 34,
				})
				weatherText = pillText(weatherPill.body, ui.name, 52, 0.58, true)
				UIKit.pop(weatherPill.holder, 0.2)
			end
		end
		if weatherText then
			local left = math.max(0, (workspace:GetAttribute("WeatherEnds") or os.time()) - os.time())
			weatherText.Text = ("%s  %d:%02d"):format(WEATHER_UI[weather].name, left // 60, left % 60)
		end
	end
	workspace:GetAttributeChangedSignal("Weather"):Connect(refreshWeather)
	task.spawn(function()
		while true do
			refreshWeather()
			task.wait(0.5)
		end
	end)

	--------------------------------------------------------------------------- top: carry banner + guide line home

	local carry = UIKit.pill(top, {
		name = "Carry", size = UDim2.fromOffset(420, 62), position = UDim2.new(0.5, 22, 0, 6), anchor = Vector2.new(0.5, 0),
		icon = Icons.Home, iconScale = 1.4, top = UIKit.Themes.Green[1], bottom = UIKit.Themes.Green[2], pattern = "Stars", patternTransparency = 0.8, patternTile = 40,
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
		b.CurveSize0 = 8
		b.CurveSize1 = -8
		b.Parent = floor
		local core = b:Clone()
		core.Name = "GuideCore"
		core.Texture = ""
		core.Width0 = 0.6
		core.Width1 = 0.6
		core.Transparency = NumberSequence.new(0.1, 0.4)
		core.LightEmission = 0.25
		core.Color = ColorSequence.new(Color3.fromRGB(80, 220, 60))
		core.Parent = b
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

end

return Controller
