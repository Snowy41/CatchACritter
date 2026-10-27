-- Rebirth panel: requirements with progress, what resets / what stays / what you gain, and a
-- two-step REBIRTH button (tap, then confirm). Side button badge when a rebirth is possible.

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

	local panel = Panel.new({
		name = "Rebirth", title = "REBIRTH", icon = Icons.Rebirth, size = Vector2.new(600, 470),
		headerTop = Color3.fromRGB(255, 130, 200), headerBottom = Color3.fromRGB(200, 60, 140),
	})
	local button = Panel.sideButton({ name = "Rebirth", label = "REBIRTH", icon = Icons.Rebirth, color = Color3.fromRGB(235, 90, 170), order = 3, onClick = panel.toggle })

	local c = panel.content
	local levelText = UIKit.text(c, { text = "", bold = true, size = UDim2.new(1, 0, 0, 34), position = UDim2.fromOffset(0, 4) })

	local function reqRow(y: number, icon: string)
		local row = UIKit.pill(c, { size = UDim2.new(1, -40, 0, 50), position = UDim2.fromOffset(40, y), radius = 14, icon = icon, iconScale = 1.3 })
		local label = UIKit.text(row.body, { text = "", bold = true, size = UDim2.new(0.5, 0, 0.52, 0), position = UDim2.new(0, 48, 0.5, 0), anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left })
		local track = Instance.new("Frame")
		track.BackgroundColor3 = Color3.fromRGB(20, 14, 40)
		track.Size = UDim2.new(0.42, 0, 0, 22)
		track.Position = UDim2.new(1, -16, 0.5, 0)
		track.AnchorPoint = Vector2.new(1, 0.5)
		track.ZIndex = 4
		UIKit.corner(track, 11)
		UIKit.stroke(track, 2.5)
		track.Parent = row.body
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = Color3.new(1, 1, 1)
		fill.ZIndex = 5
		UIKit.corner(fill, 11)
		UIKit.gradient(fill, Color3.fromRGB(150, 255, 120), Color3.fromRGB(60, 190, 50))
		fill.Parent = track
		local value = UIKit.text(track, { text = "", bold = true, size = UDim2.new(1, 0, 0.85, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), z = 6, strokeThickness = 2 })
		return label, fill, value
	end
	local coinLabel, coinFill, coinValue = reqRow(50, Icons.Coin)
	local speedLabel, speedFill, speedValue = reqRow(110, Icons.Speed)

	local function column(x: number, title: string, color: Color3)
		UIKit.text(c, { text = title, bold = true, color = color, size = UDim2.new(0.5, -10, 0, 26), position = UDim2.new(x, 0, 0, 176) })
		return UIKit.text(c, { text = "", size = UDim2.new(0.5, -10, 0, 120), position = UDim2.new(x, 0, 0, 206), strokeThickness = 2.5 })
	end
	local resetText = column(0, "RESETS", Color3.fromRGB(255, 140, 130))
	local gainText = column(0.5, "YOU GET", Color3.fromRGB(150, 255, 130))
	resetText.TextScaled = false
	resetText.TextSize = 20
	resetText.TextYAlignment = Enum.TextYAlignment.Top
	gainText.TextScaled = false
	gainText.TextSize = 20
	gainText.TextYAlignment = Enum.TextYAlignment.Top

	local action, actionLabel = Panel.actionButton(c, {
		name = "Do", text = "REBIRTH", size = UDim2.fromOffset(220, 56), position = UDim2.new(0.5, 0, 1, -34), anchor = Vector2.new(0.5, 0.5),
		color = Color3.fromRGB(235, 90, 170),
	})
	local armed = false

	local function status()
		local level = player:GetAttribute("Rebirth") or 0
		local req = Config.Rebirths[level + 1]
		local coins = player:GetAttribute("Coins") or 0
		local speed = player:GetAttribute("SpeedLevel") or 0
		return level, req, coins, speed
	end

	local function refresh()
		local level, req, coins, speed = status()
		local mult = 1 + Config.RebirthIncomeBonus * level
		levelText.Text = ("REBIRTH %d  -  INCOME x%.1f"):format(level, mult)
		if not req then
			coinLabel.Text, speedLabel.Text = "MAX REBIRTH", "MAX REBIRTH"
			coinFill.Size, speedFill.Size = UDim2.fromScale(1, 1), UDim2.fromScale(1, 1)
			coinValue.Text, speedValue.Text = "DONE", "DONE"
			action.root.Visible = false
			button.setBadge(false)
			return
		end
		coinLabel.Text = "COINS"
		coinFill.Size = UDim2.fromScale(math.clamp(coins / req.cost, 0, 1), 1)
		coinValue.Text = ("%d / %d"):format(math.min(coins, req.cost), req.cost)
		speedLabel.Text = "SPEED LEVEL"
		speedFill.Size = UDim2.fromScale(math.clamp(speed / req.speed, 0, 1), 1)
		speedValue.Text = ("%d / %d"):format(math.min(speed, req.speed), req.speed)
		resetText.Text = "Coins\nSpeed level"
		gainText.Text = ("Income x%.1f (forever)\n+%d%% easier catching\nTitle & new zones\nKeep critters, Dex, eggs"):format(
			1 + Config.RebirthIncomeBonus * (level + 1), math.floor(Config.RebirthCatchBonus * 100 + 0.5))
		local can = coins >= req.cost and speed >= req.speed
		action.root.Visible = true
		UIKit.setButtonColor(action, can and Color3.fromRGB(235, 90, 170) or Color3.fromRGB(110, 100, 140))
		actionLabel.Text = armed and "SURE?" or "REBIRTH"
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
