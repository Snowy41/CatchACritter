-- Settings panel: music, sound effects, camera shake (on/off toggles) and effect quality
-- (High/Low). Saved on the server (Modules/Settings).

local Controller = {}

function Controller.Start()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Icons = require(Shared:WaitForChild("Icons"))
	local Modules = script.Parent.Parent:WaitForChild("Modules")
	local Panel = require(Modules:WaitForChild("Panel"))
	local Settings = require(Modules:WaitForChild("Settings"))
	local UIKit = require(Modules:WaitForChild("UIKit"))

	local panel = Panel.new({ name = "Settings", title = "SETTINGS", icon = Icons.Settings, size = Vector2.new(470, 312), theme = "Navy" })
	local button = Panel.sideButton({ name = "Settings", label = "SETTINGS", icon = Icons.Settings, theme = "Navy", order = 6, onClick = panel.toggle })
	panel.bindButton(button)
	local c = panel.content
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 12)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = c

	local function row(order: number, iconOn: string, iconOff: string?, label: string)
		local r = UIKit.pill(c, {
			name = label, size = UDim2.new(1, -24, 0, 66), radius = 18, icon = iconOn, iconScale = 1.15,
			top = UIKit.Themes.Navy[1], bottom = UIKit.Themes.Navy[2], pattern = "Paws", patternTransparency = 0.88, patternTile = 50,
		})
		r.holder.LayoutOrder = order
		r.holder.Position = UDim2.fromOffset(24, 0)
		UIKit.text(r.body, { text = label, bold = true, size = UDim2.new(1, -230, 0.5, 0), position = UDim2.new(0, 56, 0.5, 0), anchor = Vector2.new(0, 0.5), alignX = Enum.TextXAlignment.Left })
		return r, iconOn, iconOff
	end

	-- on/off toggle with a sliding knob
	local function toggle(key: string, order: number, iconOn: string, iconOff: string?, label: string)
		local r = row(order, iconOn, iconOff, label)
		local track = Instance.new("TextButton")
		track.Text = ""
		track.AutoButtonColor = false
		track.Size = UDim2.fromOffset(110, 44)
		track.Position = UDim2.new(1, -18, 0.5, 0)
		track.AnchorPoint = Vector2.new(1, 0.5)
		track.BackgroundColor3 = Color3.new(1, 1, 1)
		track.ZIndex = 5
		UIKit.corner(track, 22)
		UIKit.stroke(track, 3)
		local grad = UIKit.gradient(track, UIKit.Themes.Green[1], UIKit.Themes.Green[2])
		track.Parent = r.body
		local stateText = UIKit.text(track, { text = "ON", bold = true, size = UDim2.new(0.5, 0, 0.6, 0), position = UDim2.new(0.28, 0, 0.5, 0), anchor = Vector2.new(0.5, 0.5), z = 6, strokeThickness = 2.5 })
		local knob = Instance.new("Frame")
		knob.Size = UDim2.fromOffset(36, 36)
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.BackgroundColor3 = Color3.new(1, 1, 1)
		knob.ZIndex = 7
		UIKit.corner(knob, 18)
		UIKit.stroke(knob, 3)
		knob.Parent = track
		local function refresh(animate: boolean)
			local on = Settings.get(key) ~= false
			grad.Color = on and ColorSequence.new(UIKit.Themes.Green[1], UIKit.Themes.Green[2]) or ColorSequence.new(Color3.fromRGB(150, 140, 170), Color3.fromRGB(90, 80, 110))
			stateText.Text = on and "ON" or "OFF"
			stateText.Position = UDim2.new(on and 0.3 or 0.7, 0, 0.5, 0)
			local pos = UDim2.new(on and 1 or 0, on and -24 or 24, 0.5, 0)
			if animate then
				UIKit.tween(knob, 0.18, { Position = pos }, Enum.EasingStyle.Back)
			else
				knob.Position = pos
			end
			if r.icon and iconOff then
				r.icon.Image = on and iconOn or iconOff
			end
		end
		track.Activated:Connect(function()
			UIKit.ripple(track, track.AbsolutePosition + track.AbsoluteSize / 2)
			Settings.set(key, not (Settings.get(key) ~= false))
		end)
		Settings.Changed:Connect(function(k)
			if k == key then
				refresh(true)
			end
		end)
		refresh(false)
	end

	-- two-option switch (quality)
	local function choice(key: string, order: number, icon: string, label: string, options: { string })
		local r = row(order, icon, nil, label)
		local buttons = {}
		for i, opt in ipairs(options) do
			local b, l = Panel.actionButton(r.body, {
				text = string.upper(opt), size = UDim2.fromOffset(78, 40), position = UDim2.new(1, -18 - (#options - i) * 84 - 39, 0.5, -2), radius = 12,
			})
			buttons[opt] = { b = b, l = l }
			b.face.Activated:Connect(function()
				Settings.set(key, opt)
			end)
		end
		local function refresh()
			for opt, x in pairs(buttons) do
				UIKit.setButtonColor(x.b, Settings.get(key) == opt and UIKit.Colors.Green or Color3.fromRGB(110, 100, 140))
			end
		end
		Settings.Changed:Connect(function(k)
			if k == key then
				refresh()
			end
		end)
		refresh()
	end

	toggle("music", 1, Icons.MusicOn, Icons.MusicOff, "MUSIC")
	toggle("sfx", 2, Icons.SoundOn, Icons.SoundOff, "SOUND EFFECTS")
	toggle("shake", 3, Icons.Speed, nil, "CAMERA SHAKE")
	choice("quality", 4, Icons.Star, "EFFECTS", { "High", "Low" })
end

return Controller
