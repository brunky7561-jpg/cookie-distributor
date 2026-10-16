--!strict
-- Properties: where you bake, store supplies and (from the food truck up) sell to walk-in customers.
-- display = how many batches the display case holds; walkIn = max cookies a walk-in crowd buys per sales round.
local Types = require(script.Parent.Parent.Modules.Types)

local Properties: { [string]: Types.PropertyDef } = {
	apartment = {
		id = "apartment",
		name = "Starter Apartment",
		blurb = "Your first kitchen. No storefront, no rent.",
		price = 0,
		unlockLevel = 1,
		ovenSlots = 1,
		storage = 40, -- ingredient units
		dailyCost = 0,
		display = 0,
		walkIn = 0,
		receivingName = "Delivery Mat (Starter Apartment)",
	},
	food_truck = {
		id = "food_truck",
		name = "Food Truck",
		blurb = "A truck with a small display case. Walk-in customers buy a few cookies each round.",
		price = 1500,
		unlockLevel = 3,
		ovenSlots = 1,
		storage = 70,
		dailyCost = 20,
		display = 2,
		walkIn = 3,
		receivingName = "Delivery Mat (Food Truck)",
		plotName = "Food Truck Plot",
	},
	garage = {
		id = "garage",
		name = "Garage Kitchen",
		blurb = "Lots of storage and a bigger display case. Rent is higher.",
		price = 4000,
		unlockLevel = 5,
		ovenSlots = 3,
		storage = 140,
		dailyCost = 60,
		display = 4,
		walkIn = 5,
		receivingName = "Delivery Mat (Garage Kitchen)",
		plotName = "Garage Kitchen Plot",
	},
	corner_shop = {
		id = "corner_shop",
		name = "Corner Cookie Shop",
		blurb = "A real storefront with a big display case and steady foot traffic.",
		price = 9000,
		unlockLevel = 7,
		ovenSlots = 3,
		storage = 220,
		dailyCost = 120,
		display = 6,
		walkIn = 8,
		receivingName = "Delivery Mat (Corner Cookie Shop)",
		plotName = "Corner Cookie Shop Plot",
	},
}

return Properties
