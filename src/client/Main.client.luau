-- Client entry point: loads every ModuleScript in Controllers and calls its Start().
-- Controller contract: return a table with Start(): () (may yield, e.g. WaitForChild).
-- Shared client helpers live in Modules (UIKit, VFX).

local controllers = script.Parent:WaitForChild("Controllers")

for _, m in ipairs(controllers:GetChildren()) do
	if m:IsA("ModuleScript") then
		task.spawn(function()
			local ok, controller = pcall(require, m)
			if not ok or typeof(controller) ~= "table" then
				warn(("[Client] failed to load %s: %s"):format(m.Name, tostring(controller)))
				return
			end
			if controller.Start then
				local started, err = pcall(controller.Start)
				if not started then
					warn(("[Client] %s.Start failed: %s"):format(m.Name, tostring(err)))
				end
			end
		end)
	end
end
