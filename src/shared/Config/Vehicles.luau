--!strict
-- Vehicles speed up PantryDash couriers (a driver of yours does the run) and can also be driven around the map.
-- Walking always works: nothing in the game requires a vehicle.
local Vehicles = {}

Vehicles.catalog = {
	compact_car = {
		id = "compact_car",
		name = "Compact Car",
		blurb = "Zippy and cheap. Couriers arrive about a third faster.",
		price = 800,
		unlockLevel = 4,
		speed = 42,
		seats = 2,
		etaMult = 0.65,
		freeDelivery = false,
		color = { 255, 120, 90 },
	},
	delivery_van = {
		id = "delivery_van",
		name = "Delivery Van",
		blurb = "Bigger and slower to drive, but couriers arrive in under half the time and never charge a fee.",
		price = 2500,
		unlockLevel = 6,
		speed = 34,
		seats = 4,
		etaMult = 0.4,
		freeDelivery = true,
		color = { 240, 220, 170 },
	},
} :: { [string]: { id: string, name: string, blurb: string, price: number, unlockLevel: number, speed: number, seats: number, etaMult: number, freeDelivery: boolean, color: { number } } }

Vehicles.order = { "compact_car", "delivery_van" }

-- Best owned vehicle effect on deliveries: { etaMult, freeDelivery }.
function Vehicles.deliveryPerks(owned: { [string]: boolean }): (number, boolean)
	local mult, free = 1, false
	for id in owned do
		local v = Vehicles.catalog[id]
		if v then
			mult = math.min(mult, v.etaMult)
			free = free or v.freeDelivery
		end
	end
	return mult, free
end

return Vehicles
