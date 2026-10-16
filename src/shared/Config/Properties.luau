--!strict
local Types = require(script.Parent.Parent.Modules.Types)

local Properties: { [string]: Types.PropertyDef } = {
	apartment = {
		id = "apartment",
		name = "Starter Apartment",
		price = 0,
		ovenSlots = 1,
		storage = 40, -- ingredient units
		dailyCost = 0,
		receivingName = "Delivery Mat (Starter Apartment)",
	},
	food_truck = { id = "food_truck", name = "Food Truck", price = 2500, ovenSlots = 1, storage = 40, dailyCost = 20 },
	garage = { id = "garage", name = "Garage Kitchen", price = 8000, ovenSlots = 3, storage = 100, dailyCost = 60 },
}

return Properties
