-- Big animated title card when the player enters a zone: spinning sunburst, "NOW ENTERING"
-- ribbon, the zone name in its colour and what lives there (rarities, guardian).
-- Shown when the zone changes (not again for the same zone within 20 s).

local Controller = {}

-- z ranges along the path (path runs towards -Z); data for the cards
local ZONES = {
	{ name = "Home", zMax = math.huge, zMin = -240, color = Color3.fromRGB(120, 220, 255), sub = "Your base - bring critters here!" },
	{ name = "Meadow", zMax = -240, zMin = -680, color = Color3.fromRGB(130, 235, 90) },
	{ name = "Swamp", zMax = -680, zMin = -1120, color = Color3.fromRGB(70, 220, 180) },
	{ name = "Volcano", zMax = -1120, zMin = -1600, color = Color3.fromRGB(255, 120, 40) },
	{ name = "Crystal Cave", zMax = -1600, zMin = -math.huge, color = Color3.fromRGB(170, 140, 255), sub = "Coming soon!" },
}

function Controller.Start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared:WaitForChild("Config"))
	local Zones = require(Shared:WaitForChild("Zones"))
	local Modules = script.Parent.Parent:WaitForChild("Modules")
	local UIKit = require(Modules:WaitForChild("UIKit"))
	local Panel = require(Modules:WaitForChild("Panel"))
	local VFX = require(Modules:WaitForChild("VFX"))
	local Sounds = require(Shared:WaitForChild("Sounds"))

	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "ZoneTitle"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	local area = UIKit.area(gui, "Card", UDim2.fromOffset(700, 260), UDim2.fromScale(0.5, 0.4), Vector2.new(0.5, 0.5))
	UIKit.autoScale({ area })

	local function subtitleFor(zoneName: string): string?
		local def = Zones.get(zoneName)
		if not def then
			return nil
		end
		local rarities = {}
		for _, r in ipairs(Config.Rarities) do
			if def.rarityWeights[r.name] then
				table.insert(rarities, r.name)
			end
		end
		local s = table.concat(rarities, " & ") .. " critters"
		if def.guardian then
			s ..= "  -  beware the " .. def.guardian.displayName .. "!"
		end
		return s
	end

	local current: string? = nil
	local pending: any = nil -- zone card waiting for menus to close
	local lastShown: { [string]: number } = {}
	local showing: Frame? = nil

	local function show(z)
		if showing then
			showing:Destroy()
		end
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.Parent = area
		showing = holder
		local burst = UIKit.sunburst(holder, { size = UDim2.fromOffset(520, 520), color = z.color, transparency = 0.45, speed = 30, z = 1 })
		local ribbon = UIKit.ribbon(holder, { text = "NOW ENTERING", size = UDim2.fromOffset(260, 44), position = UDim2.new(0.5, 0, 0, 40), color = Color3.fromRGB(255, 70, 110), z = 5 })
		local title = UIKit.text(holder, {
			text = string.upper(z.name), bold = true, size = UDim2.new(1, 0, 0, 96), position = UDim2.new(0.5, 0, 0, 72), anchor = Vector2.new(0.5, 0),
			color = z.color, z = 6, strokeThickness = 6,
		})
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new(UIKit.lighter(z.color, 0.55), z.color)
		g.Parent = title
		local sub = UIKit.text(holder, {
			text = z.sub or subtitleFor(z.name) or "", size = UDim2.new(1, 0, 0, 30), position = UDim2.new(0.5, 0, 0, 176), anchor = Vector2.new(0.5, 0),
			z = 6, strokeThickness = 3,
		})
		UIKit.sparkles(holder, { rate = 8, z = 7, minSize = 16, maxSize = 34 })
		-- animate in: title slams down, ribbon pops, sunburst grows
		local ts = Instance.new("UIScale")
		ts.Scale = 2.2
		ts.Parent = title
		UIKit.tween(ts, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		UIKit.pop(ribbon.holder, 0.4)
		burst.Size = UDim2.fromOffset(0, 0)
		UIKit.tween(burst, 0.6, { Size = UDim2.fromOffset(520, 520) }, Enum.EasingStyle.Back)
		sub.TextTransparency = 1
		UIKit.tween(sub, 0.5, { TextTransparency = 0 })
		VFX.sound(Sounds.Whoosh, 0.5, 0.9)
		task.delay(2.8, function()
			if showing ~= holder then
				return
			end
			for _, d in ipairs(holder:GetDescendants()) do
				if d:IsA("TextLabel") then
					UIKit.tween(d, 0.4, { TextTransparency = 1 })
				elseif d:IsA("ImageLabel") then
					UIKit.tween(d, 0.4, { ImageTransparency = 1 })
				elseif d:IsA("UIStroke") then
					UIKit.tween(d, 0.4, { Transparency = 1 })
				end
			end
			task.wait(0.45)
			holder:Destroy()
			if showing == holder then
				showing = nil
			end
		end)
	end

	while true do
		task.wait(0.4)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local zPos = hrp.Position.Z
			for _, z in ipairs(ZONES) do
				if zPos <= z.zMax and zPos > z.zMin then
					if z.name ~= current then
						local first = current == nil
						current = z.name
						if not first and os.clock() - (lastShown[z.name] or -100) > 20 then
							lastShown[z.name] = os.clock()
							pending = z
						end
					end
					break
				end
			end
		end
		-- never cover an open menu; show the card once it is closed (if still in that zone)
		if pending and not Panel.anyOpen() then
			if pending.name == current then
				show(pending)
			end
			pending = nil
		end
	end
end

return Controller
