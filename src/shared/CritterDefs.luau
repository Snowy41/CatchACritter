--!strict
-- Critter species. `template` is the model name in ServerStorage.CritterTemplates.

export type Species = {
	displayName: string,
	template: string,
	zones: { string },
	baseIncome: number, -- coins per second at Common, no mutation, average size
	baseKg: number, -- average weight shown on the nameplate
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

return CritterDefs
