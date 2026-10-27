-- Cartoon knockback when a guardian bumps the local player (no damage, kid-friendly).
-- The character is client-owned, so the push has to be applied here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RuntimeRemotes")
local knockback = remotes:WaitForChild("Knockback") :: RemoteEvent

knockback.OnClientEvent:Connect(function(velocity: Vector3)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		return
	end
	hum:ChangeState(Enum.HumanoidStateType.FallingDown)
	hrp.AssemblyLinearVelocity = velocity
	-- a short spin sells the "bonk"
	hrp.AssemblyAngularVelocity = Vector3.new(0, 8, 0)
	task.delay(0.9, function()
		if hum.Parent then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end)
