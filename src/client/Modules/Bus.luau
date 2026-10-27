-- Client-side event bus between controllers (no remotes involved).
--   Toast(text, kind)        -> Hud shows a toast
--   CatchState(state, data)  -> "start" | "hit" | "perfect" | "near" | "miss" | "end" (Catching -> effects)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Signal"))

return {
	Toast = Signal.new(),
	CatchState = Signal.new(),
}
