--!strict
-- Equipment the player can own. Within a category the highest tier owned is the one that counts.
-- Effects are absolute values; Equipment.effective merges the best item per category over the defaults.
export type EquipmentDef = {
	id: string,
	name: string,
	category: string,
	tier: number,
	price: number, -- 0 = starter equipment, never sold
	requiresMilestone: string?,
	description: string,
	effects: { [string]: number },
}

local Equipment = {}

Equipment.defaults = {
	bakeSlack = 0, -- seconds around the ideal oven moment that still score 100%
	mixTaps = 8, -- stirs needed to finish mixing
	mixMin = 3, -- minimum seconds of mixing the server enforces
	coolTime = 4, -- seconds the tray must rest
	maxBatchMult = 1, -- 2 = can bake double batches (12 cookies in the Large box)
} :: { [string]: number }

Equipment.starter = { "basic_oven", "mixing_bowl", "cooling_rack" }

Equipment.catalog = {
	basic_oven = {
		id = "basic_oven",
		name = "Basic Oven",
		category = "Baking",
		tier = 1,
		price = 0,
		description = "A small oven. You have to watch it closely.",
		effects = {},
	},
	convection_oven = {
		id = "convection_oven",
		name = "Convection Oven",
		category = "Baking",
		tier = 2,
		price = 150,
		requiresMilestone = "firstOrderDone",
		description = "Even heat gives you a wider window to pull the tray: forgives about half a second either way.",
		effects = { bakeSlack = 0.6 },
	},
	stand_mixer = {
		id = "stand_mixer",
		name = "Stand Mixer",
		category = "Mixing",
		tier = 2,
		price = 220,
		requiresMilestone = "firstOrderDone",
		description = "Mixes in half the taps and lets you bake double batches (12 cookies, Large box).",
		effects = { mixTaps = 4, mixMin = 1.5, maxBatchMult = 2 },
	},
	fan_rack = {
		id = "fan_rack",
		name = "Fan Cooling Rack",
		category = "Cooling",
		tier = 2,
		price = 120,
		requiresMilestone = "firstOrderDone",
		description = "Cools a tray in 2 seconds instead of 4, so you can keep a rhythm going.",
		effects = { coolTime = 2 },
	},
	mixing_bowl = {
		id = "mixing_bowl",
		name = "Mixing Bowl",
		category = "Mixing",
		tier = 1,
		price = 0,
		description = "A good old hand bowl.",
		effects = {},
	},
	cooling_rack = {
		id = "cooling_rack",
		name = "Cooling Rack",
		category = "Cooling",
		tier = 1,
		price = 0,
		description = "A simple wire rack.",
		effects = {},
	},
} :: { [string]: EquipmentDef }

-- owned: { [equipmentId]: true }
function Equipment.effective(owned: { [string]: boolean }): { [string]: number }
	local best: { [string]: EquipmentDef } = {}
	for id in owned do
		local def = Equipment.catalog[id]
		if def and (not best[def.category] or def.tier > best[def.category].tier) then
			best[def.category] = def
		end
	end
	local out: { [string]: number } = table.clone(Equipment.defaults)
	for _, def in best do
		for k, v in def.effects do
			out[k] = v
		end
	end
	return out
end

return Equipment
