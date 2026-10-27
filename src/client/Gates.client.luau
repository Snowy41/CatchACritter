-- Zone gates are solid for everyone on the server; each client opens the gates its own player
-- is allowed through (character physics is client-owned, so this lets only that player pass).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function allowed(gate: Instance): boolean
	if gate:GetAttribute("Locked") then
		return false
	end
	local speed = player:GetAttribute("SpeedLevel") or 0
	local rebirth = player:GetAttribute("Rebirth") or 0
	return speed >= (gate:GetAttribute("RequiredSpeed") or 0) and rebirth >= (gate:GetAttribute("RequiredRebirth") or 0)
end

local function refresh(gate: Instance)
	if gate:IsA("BasePart") then
		gate.CanCollide = not allowed(gate)
		-- dim the shimmer of open gates
		local shimmer = gate.Parent and gate.Parent:FindFirstChild("GateShimmer")
		if shimmer and shimmer:IsA("BasePart") then
			shimmer.Transparency = allowed(gate) and 0.85 or 0.45
		end
	end
end

local function refreshAll()
	for _, gate in ipairs(CollectionService:GetTagged("ZoneGate")) do
		refresh(gate)
	end
end

CollectionService:GetInstanceAddedSignal("ZoneGate"):Connect(refresh)
player:GetAttributeChangedSignal("SpeedLevel"):Connect(refreshAll)
player:GetAttributeChangedSignal("Rebirth"):Connect(refreshAll)
refreshAll()
