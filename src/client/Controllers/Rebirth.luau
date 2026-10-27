-- Rebirth panel: big "x1.0 -> x1.5" income display, requirement rows with progress bars and
-- checkmarks, RESETS / KEEPS / GAINS columns with icons, and a two-step REBIRTH button
-- (tap, then tap again to confirm). Side button badge when a rebirth is possible. Hotkey R.

local Controller = {}

function Controller.Start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared:WaitForChild("Config"))
	local Icons = require(Shared:WaitForChild("Icons"))
	local Net = require(Shared:WaitForChild("Net"))
	local Modules = script.Parent.Parent:WaitForChild("Modules")
	local Panel = require(Modules:WaitForChild("Panel"))
	local UIKit = require(Modules:WaitForChild("UIKit"))

	local player = Players.LocalPlayer
	local RebirthRemote = Net.func("Rebirth")
	local PINK = Color3.fromRGB(235, 90, 170)
	local GREY = Color3.fromRGB(110, 100, 140)

	local panel = Panel.new({
		name = "Rebirth", title = "REBIRTH", icon = Icons.Rebirth, size = Vector2.new(660, 560),
		headerTop = Color3.fromRGB(255, 140, 210), headerBottom = Color3.fromRGB(200, 60, 140),
	})
	local button = Panel.sideButton({ name = "Rebirth", label = "REBIRTH", icon = Icons.Rebirth, color = PINK, order = 3, hotkey = Enum.KeyCode.R, onClick = panel.toggle })
	panel.bindButton(button)
	local c = panel.content

	local function short(n: number): string
		if n >= 1e6 then
			return string.format("%.1fM", n / 1e6)
		elseif n >= 1e4 then
			return string.format("%.1fK", n / 1e3)
		end
		return tostring(math.floor(n))
	end

	--------------------------------------------------------------------------- hero: multiplier now -> next

	local hero = UIKit.inset(c, { name = "Hero", size = UDim2.new(1, 0, 0, 104), color = Color3.fromRGB(110, 40, 100), transparency = 0.3 })
	local levelText = UIKit.text(hero, { text = "", bold = true, size = UDim2.new(1, 0, 0, 24), position = UDim2.new(0.5, 0, 0, 8), anchor = Vector2.new(0.5, 0), z = 6, color = Color3.fromRGB(255, 200, 235) })
	local function medal(x: number, top: Color3, bottom: Color3)
		local m = UIKit.pill(hero, { size = UDim2.fromOffset(150, 56), position = UDim2.new(0.5, x, 0, 38), anchor = Vector2.new(0.5, 0), radius = 18, top = top, bottom = bottom })
		m.holder.ZIndex = 6
		local t = UIKit.text(m.body, { text = "", bold = true, size = UDim2.new(1, -16, 0.66, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5) })
		return m, t
	end
	local _, nowText = medal(-120, Color3.fromRGB(140, 130, 170), Color3.fromRGB(80, 70, 110))
	local nextMedal, nextText = medal(120, Color3.fromRGB(150, 255, 120), Color3.fromRGB(50, 170, 45))
	UIKit.icon(hero, Icons.Upgrade, { size = UDim2.fromOffset(54, 54), position = UDim2.new(0.5, 0, 0, 66), anchor = Vector2.new(0.5, 0.5), rotation = 90, z = 7 })
	UIKit.shineSweep(nextMedal.body, 18, 2)

	--------------------------------------------------------------------------- requirements

	UIKit.text(c, { text = "REQUIREMENTS", bold = true, size = UDim2.new(1, 0, 0, 22), position = UDim2.fromOffset(4, 114), alignX = Enum.TextXAlignment.Left, color = Color3.fromRGB(255, 210, 240) })
	local function reqRow(y: number, icon: string, label: string)
		local row = UIKit.pill(c, { size = UDim2.new(1, -36, 0, 48), position = UDim2.fromOffset(36, y), radius = 15, icon = icon, iconScale = 1.3 })
		UIKit.text(row.body, { text = label, bold = true, size = UDim2.new(0.34, 0, 0.5, 0), position = UDim2.new(0, 46, 0.5, 0), anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left })
		local bar = UIKit.progressBar(row.body, { size = UDim2.new(0.5, 0, 0, 24), position = UDim2.new(1, -58, 0.5, 0), anchor = Vector2.new(1, 0.5), radius = 12 })
		local check = UIKit.icon(row.body, Icons.Check, { size = UDim2.fromOffset(40, 40), position = UDim2.new(1, -28, 0.5, 0), anchor = Vector2.new(0.5, 0.5), z = 7 })
		local lock = UIKit.icon(row.body, Icons.Lock, { size = UDim2.fromOffset(34, 34), position = UDim2.new(1, -28, 0.5, 0), anchor = Vector2.new(0.5, 0.5), z = 7 })
		return bar, check, lock
	end
	local coinBar, coinCheck, coinLock = reqRow(142, Icons.Coin, "COINS")
	local speedBar, speedCheck, speedLock = reqRow(198, Icons.Speed, "SPEED LEVEL")

	--------------------------------------------------------------------------- resets / keeps / gains

	local function column(i: number, title: string, top: Color3, bottom: Color3, items: { { icon: string, text: string } })
		local w = 1 / 3
		local col = UIKit.inset(c, { name = title, size = UDim2.new(w, -8, 0, 150), position = UDim2.new(w * (i - 1), (i - 1) * 4, 0, 258), radius = 14 })
		local head = UIKit.pill(col, { size = UDim2.new(1, -16, 0, 28), position = UDim2.new(0.5, 0, 0, -4), anchor = Vector2.new(0.5, 0), radius = 10, top = top, bottom = bottom })
		head.holder.ZIndex = 6
		UIKit.text(head.body, { text = title, bold = true, size = UDim2.new(1, -10, 0.68, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), strokeThickness = 2 })
		local labels = {}
		for j, item in ipairs(items) do
			UIKit.icon(col, item.icon, { size = UDim2.fromOffset(30, 30), position = UDim2.fromOffset(10, 32 + (j - 1) * 36), z = 6 })
			labels[j] = UIKit.text(col, { text = item.text, size = UDim2.new(1, -54, 0, 22), position = UDim2.fromOffset(46, 36 + (j - 1) * 36), alignX = Enum.TextXAlignment.Left, z = 6, strokeThickness = 2.5 })
		end
		return labels
	end
	column(1, "RESETS", Color3.fromRGB(255, 120, 110), Color3.fromRGB(200, 50, 60), { { icon = Icons.Coin, text = "Coins" }, { icon = Icons.Shoe, text = "Speed level" } })
	column(2, "KEEPS", Color3.fromRGB(110, 180, 255), Color3.fromRGB(50, 110, 220), { { icon = Icons.Paw, text = "Critters" }, { icon = Icons.Book, text = "Critterdex" }, { icon = Icons.Egg, text = "Eggs & titles" } })
	local gains = column(3, "GAINS", Color3.fromRGB(150, 255, 120), Color3.fromRGB(50, 170, 45), {
		{ icon = Icons.Upgrade, text = "" }, { icon = Icons.Star, text = "" }, { icon = Icons.Medal, text = "New title" },
	})

	--------------------------------------------------------------------------- action

	local action, actionLabel = Panel.actionButton(c, { name = "Do", text = "REBIRTH", size = UDim2.fromOffset(260, 60), position = UDim2.new(0.5, 0, 1, -32), color = PINK, radius = 18 })
	local maxStamp = UIKit.stamp(c, { text = "MAX REBIRTH!", position = UDim2.new(0.5, 0, 1, -32), size = UDim2.fromOffset(240, 52), slam = false, top = Color3.fromRGB(255, 214, 70), bottom = Color3.fromRGB(225, 130, 15) })
	maxStamp.holder.Visible = false
	local armed = false

	local function status()
		local level = player:GetAttribute("Rebirth") or 0
		return level, Config.Rebirths[level + 1], player:GetAttribute("Coins") or 0, player:GetAttribute("SpeedLevel") or 0
	end

	local function refresh()
		local level, req, coins, speed = status()
		local mult = 1 + Config.RebirthIncomeBonus * level
		nowText.Text = ("x%.1f"):format(mult)
		if not req then
			levelText.Text = ("REBIRTH %d - INCOME"):format(level)
			nextText.Text = "MAX"
			coinBar.set(1, "DONE", UIKit.BarGreen)
			speedBar.set(1, "DONE", UIKit.BarGreen)
			coinCheck.Visible, coinLock.Visible, speedCheck.Visible, speedLock.Visible = true, false, true, false
			action.wrapper.Visible = false
			maxStamp.holder.Visible = true
			Panel.pulse(action.wrapper, false)
			button.setBadge(false)
			return
		end
		levelText.Text = ("REBIRTH %d  >  REBIRTH %d   (INCOME)"):format(level, level + 1)
		nextText.Text = ("x%.1f"):format(1 + Config.RebirthIncomeBonus * (level + 1))
		local coinsOk, speedOk = coins >= req.cost, speed >= req.speed
		coinBar.set(coins / req.cost, ("%s / %s"):format(short(math.min(coins, req.cost)), short(req.cost)), coinsOk and UIKit.BarGreen or UIKit.BarGold)
		speedBar.set(speed / req.speed, ("%d / %d"):format(math.min(speed, req.speed), req.speed), speedOk and UIKit.BarGreen or UIKit.BarGold)
		coinCheck.Visible, coinLock.Visible = coinsOk, not coinsOk
		speedCheck.Visible, speedLock.Visible = speedOk, not speedOk
		gains[1].Text = ("Income x%.1f"):format(1 + Config.RebirthIncomeBonus * (level + 1))
		gains[2].Text = ("+%d%% catch zone"):format(math.floor(Config.RebirthCatchBonus * 100 * (level + 1) + 0.5))
		local can = coinsOk and speedOk
		action.wrapper.Visible = true
		maxStamp.holder.Visible = false
		UIKit.setButtonColor(action, can and (armed and UIKit.Colors.Red or PINK) or GREY)
		actionLabel.Text = not can and "NOT READY" or (armed and "TAP AGAIN!" or "REBIRTH")
		Panel.pulse(action.wrapper, can)
		button.setBadge(can)
	end

	action.face.Activated:Connect(function()
		local _, req, coins, speed = status()
		if not req or coins < req.cost or speed < req.speed then
			return
		end
		if not armed then
			armed = true
			refresh()
			task.delay(3, function()
				armed = false
				refresh()
			end)
			return
		end
		armed = false
		local result = RebirthRemote:InvokeServer()
		if result and result.ok then
			panel.close()
		end
		refresh()
	end)

	for _, a in ipairs({ "Coins", "SpeedLevel", "Rebirth" }) do
		player:GetAttributeChangedSignal(a):Connect(refresh)
	end
	refresh()
end

return Controller
