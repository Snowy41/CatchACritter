-- Daily quests panel: three quest cards with progress bars and claim buttons, a bonus-egg row and
-- the time until new quests. Side button badge = quests ready to claim.

local Controller = {}

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

	local panel = Panel.new({ name = "Quests", title = "DAILY QUESTS", icon = Icons.Quests, size = Vector2.new(600, 470) })
	local button = Panel.sideButton({ name = "Quests", label = "QUESTS", icon = Icons.Quests, color = UIKit.Colors.Gold, order = 1, onClick = panel.toggle })

	local rows = Instance.new("Frame")
	rows.BackgroundTransparency = 1
	rows.Size = UDim2.new(1, 0, 1, -70)
	rows.Parent = panel.content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 14)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows

	local footer = UIKit.text(panel.content, {
		text = "", size = UDim2.new(1, 0, 0, 26), position = UDim2.new(0.5, 0, 1, -30), anchor = Vector2.new(0.5, 0), strokeThickness = 2.5,
		color = Color3.fromRGB(220, 210, 255),
	})
	local bonus = UIKit.pill(panel.content, {
		name = "Bonus", size = UDim2.new(1, -40, 0, 44), position = UDim2.new(0.5, 20, 1, -78), anchor = Vector2.new(0.5, 0),
		icon = Icons.Egg, iconScale = 1.35, radius = 14, top = Color3.fromRGB(120, 90, 190), bottom = Color3.fromRGB(70, 50, 130),
	})
	local bonusText = UIKit.text(bonus.body, { text = "", bold = true, size = UDim2.new(1, -70, 0.56, 0), position = UDim2.new(0, 46, 0.5, 0), anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left })

	local current: any = nil

	local function render()
		for _, c in ipairs(rows:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local q = current
		if not q then
			return
		end
		local done = 0
		for i, e in ipairs(q.list) do
			local def = Quests.ById[e.id]
			if e.claimed then
				done += 1
			end
			local complete = e.progress >= e.goal
			local card = UIKit.pill(rows, {
				name = "Quest" .. i, size = UDim2.new(1, 0, 0, 92), radius = 18,
				top = e.claimed and Color3.fromRGB(70, 120, 70) or (complete and Color3.fromRGB(110, 200, 80) or UIKit.PanelTop),
				bottom = e.claimed and Color3.fromRGB(40, 80, 45) or (complete and Color3.fromRGB(50, 130, 40) or UIKit.PanelBottom),
			})
			card.holder.LayoutOrder = i
			UIKit.text(card.body, {
				text = def and def.text:format(e.goal) or e.id, bold = true, size = UDim2.new(1, -190, 0, 28), position = UDim2.fromOffset(18, 12),
				alignX = Enum.TextXAlignment.Left,
			})
			-- progress bar
			local track = Instance.new("Frame")
			track.BackgroundColor3 = Color3.fromRGB(20, 14, 40)
			track.Size = UDim2.new(1, -190, 0, 22)
			track.Position = UDim2.fromOffset(18, 52)
			track.ZIndex = 4
			UIKit.corner(track, 11)
			UIKit.stroke(track, 2.5)
			track.Parent = card.body
			local fill = Instance.new("Frame")
			fill.BackgroundColor3 = Color3.new(1, 1, 1)
			fill.Size = UDim2.new(math.clamp(e.progress / e.goal, 0, 1), 0, 1, 0)
			fill.ZIndex = 5
			UIKit.corner(fill, 11)
			UIKit.gradient(fill, Color3.fromRGB(255, 225, 90), Color3.fromRGB(240, 150, 20))
			fill.Parent = track
			UIKit.text(track, { text = ("%d / %d"):format(math.min(e.progress, e.goal), e.goal), bold = true, size = UDim2.new(1, 0, 0.85, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), z = 6, strokeThickness = 2 })
			-- reward / claim
			if e.claimed then
				UIKit.icon(card.body, Icons.Check, { size = UDim2.fromOffset(56, 56), position = UDim2.new(1, -86, 0.5, 0), anchor = Vector2.new(0.5, 0.5) })
			elseif complete then
				local b = Panel.actionButton(card.body, { name = "Claim", text = "CLAIM", size = UDim2.fromOffset(130, 50), position = UDim2.new(1, -86, 0.5, -3), anchor = Vector2.new(0.5, 0.5) })
				UIKit.icon(b.root, Icons.Coin, { size = UDim2.fromOffset(34, 34), position = UDim2.new(0, -10, 0, -14), z = 8 })
				b.face.Activated:Connect(function()
					ClaimQuest:InvokeServer(i)
				end)
			else
				local reward = UIKit.pill(card.body, {
					name = "Reward", size = UDim2.fromOffset(124, 40), position = UDim2.new(1, -78, 0.5, 0), anchor = Vector2.new(0.5, 0.5),
					icon = Icons.Coin, iconScale = 1.3, radius = 13, top = Color3.fromRGB(255, 214, 70), bottom = Color3.fromRGB(225, 130, 15),
				})
				UIKit.text(reward.body, { text = tostring(e.reward), bold = true, size = UDim2.new(1, -44, 0.62, 0), position = UDim2.new(0, 34, 0.5, 0), anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left })
			end
		end
		bonusText.Text = q.bonusClaimed and "BONUS EGG CLAIMED!" or ("FINISH ALL 3: BONUS EGG  (%d/3)"):format(done)
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
				footer.Text = ("New quests in %dh %02dm"):format(left // 3600, (left % 3600) // 60)
			end
			task.wait(1)
		end
	end)
end

return Controller
