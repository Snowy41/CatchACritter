-- Blends Atmosphere + ColorCorrection between zone presets based on the camera's Z position,
-- then layers the current weather on top (Workspace attribute "Weather"), fading smoothly.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Controller = {}

-- zMid: centre of the zone along the path (path runs towards -Z)
local PRESETS = {
	{ zMid = 0, density = 0.24, haze = 0.6, color = Color3.fromRGB(190, 222, 255), decay = Color3.fromRGB(120, 170, 230), tint = Color3.fromRGB(255, 251, 242), sat = 0.38 },
	{ zMid = -460, density = 0.24, haze = 0.6, color = Color3.fromRGB(195, 230, 255), decay = Color3.fromRGB(130, 185, 235), tint = Color3.fromRGB(252, 255, 240), sat = 0.42 },
	{ zMid = -900, density = 0.40, haze = 2.0, color = Color3.fromRGB(165, 215, 170), decay = Color3.fromRGB(80, 140, 100), tint = Color3.fromRGB(230, 255, 230), sat = 0.30 },
	{ zMid = -1360, density = 0.38, haze = 1.6, color = Color3.fromRGB(255, 175, 120), decay = Color3.fromRGB(170, 80, 40), tint = Color3.fromRGB(255, 232, 210), sat = 0.36 },
}

-- weather layer: added density/haze, tint multiplied in, saturation offset
local WEATHER = {
	Clear = { density = 0, haze = 0, tint = Color3.new(1, 1, 1), sat = 0 },
	Rain = { density = 0.16, haze = 1.2, tint = Color3.fromRGB(215, 225, 240), sat = -0.14 },
	Snowstorm = { density = 0.22, haze = 1.6, tint = Color3.fromRGB(228, 240, 255), sat = -0.1 },
	RainbowStorm = { density = 0.04, haze = 0.2, tint = Color3.fromRGB(255, 246, 255), sat = 0.12 },
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Controller.Start()
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not atm or not cc then
		return
	end
	local w = { density = 0, haze = 0, tint = Color3.new(1, 1, 1), sat = 0 } -- current (faded) weather layer
	RunService.RenderStepped:Connect(function(dt)
		local z = workspace.CurrentCamera.CFrame.Position.Z
		local a, b, t = PRESETS[1], PRESETS[1], 0
		for i = 1, #PRESETS - 1 do
			local p, q = PRESETS[i], PRESETS[i + 1]
			if z <= p.zMid and z >= q.zMid then
				a, b, t = p, q, (p.zMid - z) / (p.zMid - q.zMid)
				break
			end
			if z < q.zMid then
				a, b, t = q, q, 0
			end
		end
		t = t * t * (3 - 2 * t) -- ease so the change happens mostly around the gates

		local target = WEATHER[workspace:GetAttribute("Weather") or "Clear"] or WEATHER.Clear
		local k = math.min(1, dt * 0.8) -- weather fades in/out over a few seconds
		w.density = lerp(w.density, target.density, k)
		w.haze = lerp(w.haze, target.haze, k)
		w.tint = w.tint:Lerp(target.tint, k)
		w.sat = lerp(w.sat, target.sat, k)

		atm.Density = lerp(a.density, b.density, t) + w.density
		atm.Haze = lerp(a.haze, b.haze, t) + w.haze
		atm.Color = a.color:Lerp(b.color, t)
		atm.Decay = a.decay:Lerp(b.decay, t)
		local zt = a.tint:Lerp(b.tint, t)
		cc.TintColor = Color3.new(zt.R * w.tint.R, zt.G * w.tint.G, zt.B * w.tint.B)
		cc.Saturation = lerp(a.sat, b.sat, t) + w.sat
	end)
end

return Controller
