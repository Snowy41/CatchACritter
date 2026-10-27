-- Welcome-back screen: "While you were away your critters earned X coins!" with a big COLLECT
-- button. Opens once when the server reports a welcome-back reward (State "welcome").

local Controller = {}

function Controller.Start()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Icons = require(Shared:WaitForChild("Icons"))
	local Net = require(Shared:WaitForChild("Net"))
	local Modules = script.Parent.Parent:WaitForChild("Modules")
	local Panel = require(Modules:WaitForChild("Panel"))
	local State = require(Modules:WaitForChild("State"))
	local UIKit = require(Modules:WaitForChild("UIKit"))

	local ClaimWelcome = Net.func("ClaimWelcome")

	local panel = Panel.new({ name = "WelcomeBack", title = "WELCOME BACK!", icon = Icons.Gift, size = Vector2.new(476, 290), theme = "Green" })
	local c = panel.content
	local awayText = UIKit.text(c, { text = "", size = UDim2.new(1, 0, 0, 30), position = UDim2.fromOffset(0, 10), strokeThickness = 2.5, color = Color3.fromRGB(225, 215, 255) })
	UIKit.sunburst(c, { size = UDim2.fromOffset(240, 240), position = UDim2.new(0.5, -110, 0, 112), color = Color3.fromRGB(255, 230, 120), transparency = 0.3, z = 4 })
	local coin = UIKit.icon(c, Icons.Coin, { size = UDim2.fromOffset(96, 96), position = UDim2.new(0.5, -110, 0, 64), anchor = Vector2.new(0.5, 0) })
	local amountText = UIKit.text(c, {
		text = "0", bold = true, size = UDim2.new(0, 260, 0, 74), position = UDim2.new(0.5, -50, 0, 74), alignX = Enum.TextXAlignment.Left,
		color = Color3.fromRGB(255, 225, 90),
	})
	UIKit.text(c, { text = "Your critters kept working while you were gone!", size = UDim2.new(1, 0, 0, 24), position = UDim2.fromOffset(0, 176), strokeThickness = 2.5 })
	local collect = Panel.actionButton(c, { text = "COLLECT", size = UDim2.fromOffset(230, 62), position = UDim2.new(0.5, 0, 1, -40), anchor = Vector2.new(0.5, 0.5) })

	local function formatAway(seconds: number): string
		if seconds >= 3600 then
			return ("%dh %02dm"):format(seconds // 3600, (seconds % 3600) // 60)
		end
		return ("%d minutes"):format(math.max(1, seconds // 60))
	end

	local pending: any = nil
	local shown = false
	State.observe("welcome", function(w)
		pending = w
		if w and not shown then
			shown = true
			awayText.Text = ("You were away for %s"):format(formatAway(w.seconds or 0))
			task.wait(2.5) -- let the world load first
			panel.open()
			-- count the amount up
			local t0 = os.clock()
			while panel.isOpen() and os.clock() - t0 < 1.2 do
				amountText.Text = tostring(math.floor(w.amount * math.min(1, (os.clock() - t0) / 1.1)))
				task.wait()
			end
			amountText.Text = tostring(w.amount)
			UIKit.pop(coin, 0.3)
		end
	end)

	local busy = false
	local function claim()
		if busy or not pending then
			return
		end
		busy = true
		pending = nil
		ClaimWelcome:InvokeServer()
		busy = false
		panel.close()
	end
	collect.face.Activated:Connect(claim)
	-- closing without the button still collects: the reward is never lost
	panel.Closed:Connect(function()
		if pending then
			task.spawn(claim)
		end
	end)
end

return Controller
