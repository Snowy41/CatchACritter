--!strict
-- Critter species. `template` is the model name in ServerStorage.CritterTemplates.

export type Species = {
	displayName: string,
	template: string,
	zones: { string },
	baseIncome: number, -- coins per second at Common, no mutation, average size
	baseKg: number, -- average weight shown on the nameplate
	-- limited event critter (GDD "Limited critters"): only spawns between these unix times
	limited: { from: number, to: number }?,
}

local CritterDefs: { [string]: Species } = {
	CloverBun = {
		displayName = "Clover Bun",
		template = "CloverBun",
		zones = { "Meadow" },
		baseIncome = 1,
		baseKg = 1.8,
	},
	Buzzpup = {
		displayName = "Buzzpup",
		template = "Buzzpup",
		zones = { "Meadow" },
		baseIncome = 1.4,
		baseKg = 1.2,
	},
}

-- false for limited critters outside their event window
local function isAvailable(id: string, now: number?): boolean
	local def = CritterDefs[id]
	local l = def and def.limited
	if not l then
		return def ~= nil
	end
	local t = now or os.time()
	return t >= l.from and t < l.to
end

return setmetatable(CritterDefs, { __index = { isAvailable = isAvailable } }) :: any
