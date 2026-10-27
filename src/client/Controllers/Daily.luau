-- Daily reward calendar: six day cards + a big rainbow day-7 card. Claimed days get a check,
-- today's card glows, pulses and has the CLAIM button, future days are dimmed. A timer shows
-- when the next reward unlocks. Side button badge when a reward is waiting.

local Controller = {}

function Controller.Start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local DailyRewards = require(Shared:WaitForChild("DailyRewards"))
	local Icons = require(Shared:WaitForChild("Icons"))
	local Net = require(Shared:WaitForChild("Net"))
	local Modules = script.Parent.Parent:WaitForChild("Modules")
	local Bus = require(Modules:WaitForChild("Bus"))
	local Panel = require(Modules:WaitForChild("Panel"))
	local State = require(Modules:WaitForChild("State"))
	local UIKit = require(Modules:WaitForChild("UIKit"))

	local player = Players.LocalPlayer
	local ClaimDaily = Net.func("ClaimDaily")

	local panel = Panel.new({ name = "Daily", title = "DAILY REWARDS", icon = Icons.Calendar, size = Vector2.new(700, 420), theme = "Gold" })
	local button = Panel.sideButton({ name = "Daily", label = "REWARDS", icon = Icons.Gift, theme = "Green", order = 4, onClick = panel.toggle })
	panel.bindButton(button)
	local c = panel.content

	local area = Instance.new("Frame")
	area.BackgroundTransparency = 1
	area.Size = UDim2.new(1, 0, 1, -46)
	area.Parent = c
	local footer = UIKit.text(c, { text = "", bold = true, size = UDim2.new(1, 0, 0, 30), position = UDim2.new(0.5, 0, 1, -34), anchor = Vector2.new(0.5, 0), strokeThickness = 3 })

	local state: any = nil

	local function short(n: number): string
		if n >= 1e6 then
			return string.format("%.1fM", n / 1e6)
		elseif n >= 1e4 then
			return string.format("%.1fK", n / 1e3)
		end
		return tostring(math.floor(n))
	end

	local function render()
		for _, ch in ipairs(area:GetChildren()) do
			ch:Destroy()
		end
		if not state then
			return
		end
		local ips = player:GetAttribute("IncomePerSecond") or 0
		local cards = {}
		for i, r in ipairs(DailyRewards.Days) do
			local big = i == 7
			local claimed = i < state.next
			local isToday = i == state.next and state.available
			local future = not claimed and not isToday
			-- layout: 3x2 grid on the left, big day 7 on the right
			local col, rowN = (i - 1) % 3, (i - 1) // 3
			local size = big and UDim2.new(0.3, -6, 1, 0) or UDim2.new(0.7 / 3, -10, 0.5, -6)
			local pos = big and UDim2.new(0.7, 6, 0, 0) or UDim2.new(col * 0.7 / 3, 0, rowN * 0.5, rowN * 6)
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Size = size
			holder.Position = pos
			holder.Parent = area
			local theme = big and UIKit.Themes.Pink or (claimed and { Color3.fromRGB(120, 150, 130), Color3.fromRGB(70, 96, 80) } or (isToday and UIKit.Themes.Gold or UIKit.Themes.Orange))
			local p = UIKit.pill(holder, { size = UDim2.fromScale(1, 1), radius = 18, top = theme[1], bottom = theme[2], pattern = "Paws", patternTransparency = 0.84, patternTile = 46 })
			p.body.ClipsDescendants = true
			if big then
				local g = p.body:FindFirstChildOfClass("UIGradient")
				if g then
					g.Color = UIKit.Rainbow
					g.Rotation = 45
					UIKit.spinGradient(g, 30)
				end
				UIKit.rainbowStroke(p.body, { thickness = 4 })
				UIKit.sparkles(p.body, { rate = 4, z = 9 })
			end
			if isToday or big then
				UIKit.sunburst(p.body, { size = UDim2.fromOffset(big and 320 or 200, big and 320 or 200), position = UDim2.fromScale(0.5, 0.48), color = Color3.fromRGB(255, 255, 210), transparency = 0.4, z = 2 })
			end
			-- day ribbon
			UIKit.ribbon(p.body, { text = "DAY " .. i, size = UDim2.new(0.8, 0, 0, 30), position = UDim2.new(0.5, 0, 0, 20), color = big and Color3.fromRGB(255, 60, 110) or Color3.fromRGB(120, 70, 220), z = 6 })
			local icon = UIKit.icon(p.body, Icons[r.icon] or Icons.Gift, { size = UDim2.fromOffset(big and 120 or 62, big and 120 or 62), position = UDim2.fromScale(0.5, big and 0.42 or (isToday and 0.42 or 0.5)), anchor = Vector2.new(0.5, 0.5), z = 6 })
			if not future then
				UIKit.bob(icon, 6, 2)
			end
			local coins = DailyRewards.coins(r, ips)
			local text = r.egg and (coins > 0 and (r.egg:upper() .. " EGG + " .. short(coins)) or (r.egg:upper() .. " EGG")) or ("+" .. short(coins))
			UIKit.text(p.body, { text = text, bold = true, size = UDim2.new(1, -12, 0, big and 30 or 22), position = UDim2.new(0.5, 0, 1, big and -84 or (isToday and -50 or -10)), anchor = Vector2.new(0.5, 1), z = 6, strokeThickness = 3 })
			if future then
				local shade = Instance.new("Frame")
				shade.BackgroundColor3 = Color3.fromRGB(20, 14, 40)
				shade.BackgroundTransparency = 0.45
				shade.Size = UDim2.fromScale(1, 1)
				shade.ZIndex = 8
				UIKit.corner(shade, 18)
				shade.Parent = p.body
				if i == state.next then
					UIKit.text(shade, { text = "TOMORROW", bold = true, size = UDim2.new(1, -10, 0, 24), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), z = 9 })
				end
			end
			if claimed then
				UIKit.icon(p.body, Icons.Check, { size = UDim2.fromOffset(56, 56), position = UDim2.new(1, -8, 1, -8), anchor = Vector2.new(1, 1), z = 9 })
			end
			if isToday then
				UIKit.rainbowStroke(p.body, { thickness = 4 })
				local b = Panel.actionButton(p.body, { text = "CLAIM", size = UDim2.new(0.8, 0, 0, big and 52 or 40), position = UDim2.new(0.5, 0, 1, big and -36 or -26) })
				Panel.pulse(b.wrapper, true)
				b.face.Activated:Connect(function()
					local res = ClaimDaily:InvokeServer()
					if res and not res.ok and res.message then
						Bus.Toast:Fire(res.message, "warn")
					end
				end)
			end
			table.insert(cards, holder)
		end
		UIKit.staggerIn(cards, 0.05)
	end

	State.observe("daily", function(v)
		state = v
		if panel.isOpen() then
			render()
		end
		button.setBadge(v and v.available or false)
	end)
	panel.Opened:Connect(render)

	task.spawn(function()
		while true do
			if state then
				if state.available then
					footer.Text = "YOUR REWARD IS READY!"
				else
					local left = math.max(0, (state.nextAt or 0) - os.time())
					footer.Text = ("NEXT REWARD IN %02d:%02d:%02d"):format(left // 3600, (left % 3600) // 60, left % 60)
				end
			end
			task.wait(1)
		end
	end)
end

return Controller
