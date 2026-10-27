-- Rotates every model tagged "Spinner" around its pivot. Attributes: SpinAxis ("X"/"Y"/"Z"), Speed (deg/s).
local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function(dt)
	for _, m in ipairs(CS:GetTagged("Spinner")) do
		if m:IsA("Model") then
			local axis = m:GetAttribute("SpinAxis") or "Y"
			local a = math.rad((m:GetAttribute("Speed") or 20) * dt)
			local rot = (axis == "X" and CFrame.Angles(a, 0, 0)) or (axis == "Z" and CFrame.Angles(0, 0, a)) or CFrame.Angles(0, a, 0)
			m:PivotTo(m:GetPivot() * rot)
		end
	end
end)
