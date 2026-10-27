-- Blends Atmosphere + ColorCorrection between zone presets based on the camera's Z position.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local atm = Lighting:FindFirstChildOfClass("Atmosphere")
local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
if not atm or not cc then return end

-- zMid: centre of the zone along the path (path runs towards -Z)
local PRESETS = {
	{zMid = 0,     density = 0.24, haze = 0.6, color = Color3.fromRGB(190, 222, 255), decay = Color3.fromRGB(120, 170, 230), tint = Color3.fromRGB(255, 251, 242), sat = 0.38},
	{zMid = -460,  density = 0.24, haze = 0.6, color = Color3.fromRGB(195, 230, 255), decay = Color3.fromRGB(130, 185, 235), tint = Color3.fromRGB(252, 255, 240), sat = 0.42},
	{zMid = -900,  density = 0.40, haze = 2.0, color = Color3.fromRGB(165, 215, 170), decay = Color3.fromRGB(80, 140, 100),  tint = Color3.fromRGB(230, 255, 230), sat = 0.30},
	{zMid = -1360, density = 0.38, haze = 1.6, color = Color3.fromRGB(255, 175, 120), decay = Color3.fromRGB(170, 80, 40),   tint = Color3.fromRGB(255, 232, 210), sat = 0.36},
}
local function lerp(a, b, t) return a + (b - a) * t end
RunService.RenderStepped:Connect(function()
	local z = workspace.CurrentCamera.CFrame.Position.Z
	local a, b, t = PRESETS[1], PRESETS[1], 0
	for i = 1, #PRESETS - 1 do
		local p, q = PRESETS[i], PRESETS[i + 1]
		if z <= p.zMid and z >= q.zMid then a, b, t = p, q, (p.zMid - z) / (p.zMid - q.zMid) break end
		if z < q.zMid then a, b, t = q, q, 0 end
	end
	-- ease so the change happens mostly around the gates
	t = t * t * (3 - 2 * t)
	atm.Density = lerp(a.density, b.density, t)
	atm.Haze = lerp(a.haze, b.haze, t)
	atm.Color = a.color:Lerp(b.color, t)
	atm.Decay = a.decay:Lerp(b.decay, t)
	cc.TintColor = a.tint:Lerp(b.tint, t)
	cc.Saturation = lerp(a.sat, b.sat, t)
end)
