-- "Next goal" bar under the top-left HUD: always shows what to work towards next with a progress
-- bar (next speed level and the zone it opens -> rebirth -> Critterdex). Players leave when they
-- don't know what to do next; this answers it at a glance.

local Controller = {}

function Controller.Start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared:WaitForChild("Config"))
	local Dex = require(Shared:WaitForChild("Dex"))
	local Icons = require(Shared:WaitForChild("Icons"))
	local Zones = require(Shared:WaitForChild("Zones"))
	local UIKit = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UIKit"))

	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "GoalHud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")
	-- same anchor + scale as the Hud's top-left area, so it lines up under the coin/speed pills
	local area = UIKit.area(gui, "TopLeft", UDim2.fromOffset(300, 260), UDim2.fromOffset(44, 18), Vector2.new(0, 0))
	UIKit.autoScale({ area })

	local pill = UIKit.pill(area, {
		name = "Goal", size = UDim2.fromOffset(250, 62), position = UDim2.fromOffset(0, 140), icon = Icons.Upgrade, iconScale = 1.25,
		top = UIKit.Themes.Purple[1], bottom = UIKit.Themes.Purple[2], pattern = "Stars", patternTransparency = 0.8, patternTile = 36,
	})
	local title = UIKit.text(pill.body, {
		text = "", bold = true, size = UDim2.new(1, -62, 0, 22), position = UDim2.fromOffset(48, 6), alignX = Enum.TextXAlignment.Left, strokeThickness = 2.5,
	})
	local track = Instance.new("Frame")
	track.BackgroundColor3 = Color3.fromRGB(20, 14, 40)
	track.Size = UDim2.new(1, -62, 0, 20)
	track.Position = UDim2.fromOffset(48, 33)
	track.ZIndex = 4
	UIKit.corner(track, 10)
	UIKit.stroke(track, 2.5)
	track.Parent = pill.body
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 5
	UIKit.corner(fill, 10)
	local fillGradient = UIKit.gradient(fill, Color3.fromRGB(255, 225, 90), Color3.fromRGB(240, 150, 20))
	fill.Parent = track
	local value = UIKit.text(track, { text = "", bold = true, size = UDim2.new(1, 0, 0.9, 0), position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), z = 6, strokeThickness = 2 })

	local function short(n: number): string
		if n >= 1e6 then
			return string.format("%.1fM", n / 1e6)
		elseif n >= 1e4 then
			return string.format("%.1fK", n / 1e3)
		end
		return tostring(math.floor(n))
	end

	local function zoneOpenedBy(speedLevel: number): string?
		for _, z in Zones.each() do
			if z.requiredSpeed == speedLevel and z.requiredRebirth == 0 then
				return string.upper(z.displayName)
			end
		end
		return nil
	end

	local ready = false
	local readyStroke: UIStroke? = nil
	local lastKey = ""
	local function refresh()
		local coins = player:GetAttribute("Coins") or 0
		local speed = player:GetAttribute("SpeedLevel") or 0
		local rebirth = player:GetAttribute("Rebirth") or 0
		local icon, text, have, need
		local nextCost = Config.SpeedCosts[speed + 1]
		local req = Config.Rebirths[rebirth + 1]
		if nextCost and not (req and speed >= req.speed and coins >= req.cost) then
			local zone = zoneOpenedBy(speed + 1)
			icon, text, have, need = Icons.Shoe, ("NEXT: SPEED %d%s"):format(speed + 1, zone and (" > " .. zone) or ""), coins, nextCost
		elseif req then
			icon, text = Icons.Rebirth, ("NEXT: REBIRTH %d"):format(rebirth + 1)
			if speed < req.speed then
				have, need = speed, req.speed
			else
				have, need = coins, req.cost
			end
		else
			icon, text, have, need = Icons.Book, "FILL YOUR CRITTERDEX", player:GetAttribute("DexFound") or 0, Dex.TotalEntries
		end
		if pill.icon then
			pill.icon.Image = icon
		end
		title.Text = text
		local p = math.clamp(have / math.max(need, 1), 0, 1)
		UIKit.tween(fill, 0.25, { Size = UDim2.fromScale(math.max(p, 0.04), 1) })
		local nowReady = p >= 1
		value.Text = nowReady and "READY!" or (short(have) .. " / " .. short(need))
		if nowReady ~= ready or text ~= lastKey then
			ready, lastKey = nowReady, text
			if nowReady and not readyStroke then
				readyStroke = UIKit.rainbowStroke(pill.body, { thickness = 3.5 })
			elseif not nowReady and readyStroke then
				readyStroke:Destroy()
				readyStroke = nil
				local own = pill.body:FindFirstChildOfClass("UIStroke")
				if own then
					own.Enabled = true
				end
			end
			fillGradient.Color = nowReady and ColorSequence.new(Color3.fromRGB(150, 255, 120), Color3.fromRGB(60, 190, 50))
				or ColorSequence.new(Color3.fromRGB(255, 225, 90), Color3.fromRGB(240, 150, 20))
			UIKit.pop(pill.holder, 0.12)
		end
	end
	for _, a in ipairs({ "Coins", "SpeedLevel", "Rebirth", "DexFound" }) do
		player:GetAttributeChangedSignal(a):Connect(refresh)
	end
	refresh()

	-- sit directly under the weather pill when there is weather, else under the speed pill
	local function place()
		local weather = workspace:GetAttribute("Weather")
		local y = (weather and weather ~= "Clear") and 196 or 140
		UIKit.tween(pill.holder, 0.3, { Position = UDim2.fromOffset(0, y) }, Enum.EasingStyle.Back)
	end
	workspace:GetAttributeChangedSignal("Weather"):Connect(place)
	place()

	-- gentle pulse while the goal is ready
	RunService.RenderStepped:Connect(function()
		if ready and pill.icon then
			pill.icon.Rotation = math.sin(os.clock() * 6) * 8
		elseif pill.icon then
			pill.icon.Rotation = 0
		end
	end)
end

return Controller
