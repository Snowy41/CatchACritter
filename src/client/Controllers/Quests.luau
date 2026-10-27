-- Daily quests panel: three quest cards (icon, task, glossy progress bar, reward / pulsing CLAIM /
-- DONE stamp), a bonus-egg row with three pips, and a reset timer. Side button badge = quests
-- ready to claim. Hotkey Q.

local Controller = {}

local QUEST_ICONS = {
	Catch = "Paw", CatchUncommon = "Star", CatchRare = "Star", CatchWeather = "Storm",
	CatchFeatured = "Clock", CatchNest = "Exclaim", Collect = "Coin",
}

function Controller.Start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Icons = require(Shared:WaitForChild("Icons"))
	local Net = require(Shared:WaitForChild("Net"))
	local Quests = require(Shared:WaitForChild("Quests"))
	local Modules = script.Parent.Parent:WaitForChild("Modules")
	local Panel = require(Modules:WaitForChild("Panel"))
	local State = require(Modules:WaitForChild("State"))
	local UIKit = require(Modules:WaitForChild("UIKit"))

	local player = Players.LocalPlayer
	local ClaimQuest = Net.func("ClaimQuest")

	local panel = Panel.new({ name = "Quests", title = "DAILY QUESTS", icon = Icons.Quests, size = Vector2.new(640, 520) })
	local button = Panel.sideButton({ name = "Quests", label = "QUESTS", icon = Icons.Quests, color = UIKit.Colors.Gold, order = 1, hotkey = Enum.KeyCode.Q, onClick = panel.toggle })
	panel.bindButton(button)
	local c = panel.content

	-- top row: subtitle + reset timer chip
	UIKit.text(c, {
		text = "New tasks every day - no streaks to lose!", size = UDim2.new(1, -200, 0, 24), position = UDim2.fromOffset(2, 2),
		alignX = Enum.TextXAlignment.Left, strokeThickness = 2.5, color = Color3.fromRGB(220, 210, 255),
	})
	local timer = UIKit.pill(c, {
		name = "Timer", size = UDim2.fromOffset(160, 32), position = UDim2.new(1, 0, 0, 0), anchor = Vector2.new(1, 0), radius = 12,
		icon = Icons.Clock, iconScale = 1.35, top = Color3.fromRGB(110, 90, 190), bottom = Color3.fromRGB(70, 50, 140),
	})
	local timerText = UIKit.text(timer.body, { text = "", bold = true, size = UDim2.new(1, -40, 0.62, 0), position = UDim2.new(0, 32, 0.5, 0), anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left, strokeThickness = 2 })

	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Size = UDim2.new(1, 0, 0, 324)
	rows.Position = UDim2.fromOffset(0, 42)
	rows.Parent = c
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows

	-- bonus egg row
	local bonus = UIKit.inset(c, { name = "Bonus", size = UDim2.new(1, 0, 0, 62), position = UDim2.new(0, 0, 1, -64), color = Color3.fromRGB(70, 45, 130), transparency = 0.15 })
	UIKit.icon(bonus, Icons.Egg, { size = UDim2.fromOffset(70, 70), position = UDim2.new(0, -6, 0.5, 0), anchor = Vector2.new(0, 0.5), z = 6 })
	local bonusText = UIKit.text(bonus, { text = "", bold = true, size = UDim2.new(1, -230, 0, 26), position = UDim2.new(0, 72, 0.5, 0), anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left, z = 6 })
	local pips: { Frame } = {}
	for i = 1, 3 do
		local pip = Instance.new("Frame")
		pip.Name = "Pip" .. i
		pip.Size = UDim2.fromOffset(30, 30)
		pip.Position = UDim2.new(1, -150 + (i - 1) * 42, 0.5, 0)
		pip.AnchorPoint = Vector2.new(0, 0.5)
		pip.BackgroundColor3 = Color3.fromRGB(40, 28, 70)
		pip.ZIndex = 6
		UIKit.corner(pip, 15)
		UIKit.stroke(pip, 3)
		pip.Parent = bonus
		pips[i] = pip
	end
	local bonusStamp: any = nil

	local current: any = nil

	local function questCard(i: number, e: any)
		local def = Quests.ById[e.id]
		local complete = e.progress >= e.goal
		local card = UIKit.pill(rows, {
			name = "Quest" .. i, size = UDim2.new(1, 0, 0, 100), radius = 20,
			top = e.claimed and Color3.fromRGB(64, 110, 72) or (complete and Color3.fromRGB(96, 180, 74) or UIKit.PanelTop),
			bottom = e.claimed and Color3.fromRGB(38, 70, 44) or (complete and Color3.fromRGB(46, 118, 40) or UIKit.PanelBottom),
		})
		card.holder.LayoutOrder = i
		-- icon tile
		local tile = UIKit.inset(card.body, { name = "Tile", size = UDim2.fromOffset(76, 76), position = UDim2.new(0, 12, 0.5, 0), anchor = Vector2.new(0, 0.5), radius = 18, z = 4 })
		UIKit.icon(tile, Icons[QUEST_ICONS[e.id] or "Star"] or Icons.Star, { size = UDim2.fromScale(0.82, 0.82), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), z = 6 })
		-- task + bar
		UIKit.text(card.body, {
			text = def and def.text:format(e.goal) or e.id, bold = true, size = UDim2.new(1, -270, 0, 28), position = UDim2.fromOffset(102, 14),
			alignX = Enum.TextXAlignment.Left,
		})
		local bar = UIKit.progressBar(card.body, { size = UDim2.new(1, -270, 0, 26), position = UDim2.fromOffset(102, 56), radius = 12, colors = complete and UIKit.BarGreen or UIKit.BarGold })
		bar.set(e.progress / e.goal, ("%d / %d"):format(math.min(e.progress, e.goal), e.goal))
		-- right side
		local right = UDim2.new(1, -82, 0.5, 0)
		if e.claimed then
			UIKit.stamp(card.body, { text = "DONE!", position = right, size = UDim2.fromOffset(120, 42), slam = false })
		elseif complete then
			local b = Panel.actionButton(card.body, { name = "Claim", text = "CLAIM", size = UDim2.fromOffset(136, 54), position = right })
			UIKit.icon(b.root, Icons.Coin, { size = UDim2.fromOffset(38, 38), position = UDim2.new(0, -14, 0, -16), z = 8 })
			Panel.pulse(b.wrapper, true)
			b.face.Activated:Connect(function()
				Panel.pulse(b.wrapper, false)
				ClaimQuest:InvokeServer(i)
			end)
		else
			local reward = UIKit.pill(card.body, {
				name = "Reward", size = UDim2.fromOffset(132, 44), position = right, anchor = Vector2.new(0.5, 0.5),
				icon = Icons.Coin, iconScale = 1.35, radius = 15, top = Color3.fromRGB(255, 214, 70), bottom = Color3.fromRGB(225, 130, 15),
			})
			UIKit.text(reward.body, { text = tostring(e.reward), bold = true, size = UDim2.new(1, -46, 0.6, 0), position = UDim2.new(0, 36, 0.5, 0), anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left })
		end
	end

	local function render()
		for _, ch in ipairs(rows:GetChildren()) do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		local q = current
		if not q then
			return
		end
		local done = 0
		for i, e in ipairs(q.list) do
			if e.claimed then
				done += 1
			end
			questCard(i, e)
		end
		for i, pip in ipairs(pips) do
			local filled = i <= done
			pip.BackgroundColor3 = filled and Color3.fromRGB(150, 255, 120) or Color3.fromRGB(40, 28, 70)
		end
		if bonusStamp then
			bonusStamp.holder:Destroy()
			bonusStamp = nil
		end
		if q.bonusClaimed then
			bonusText.Text = "BONUS EGG IS IN YOUR NEST!"
			bonusStamp = UIKit.stamp(bonus, { text = "CLAIMED", position = UDim2.new(1, -86, 0.5, 0), size = UDim2.fromOffset(130, 40), slam = false, top = Color3.fromRGB(255, 214, 70), bottom = Color3.fromRGB(225, 130, 15) })
		else
			bonusText.Text = "FINISH ALL 3 FOR A BONUS EGG"
		end
	end

	State.observe("quests", function(q)
		current = q
		render()
	end)
	local function refreshBadge()
		button.setBadge(player:GetAttribute("QuestsReady") or 0)
	end
	player:GetAttributeChangedSignal("QuestsReady"):Connect(refreshBadge)
	refreshBadge()

	task.spawn(function()
		while true do
			if current and current.resetsAt then
				local left = math.max(0, current.resetsAt - os.time())
				timerText.Text = ("%dh %02dm"):format(left // 3600, (left % 3600) // 60)
			end
			task.wait(1)
		end
	end)
end

return Controller
