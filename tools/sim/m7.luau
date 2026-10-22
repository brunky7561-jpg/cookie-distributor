do -- Milestone 7: vehicles
	print("== M7: vehicles")
	local DM = shared("Modules.DeliveryMath")
	local p = newPlayer(91, "Driver"); join(p)
	local d = state(p)
	d.cash = 5000
	local ok, msg = call(p, "VehicleBuy", "compact_car"); clock += 1
	expect(not ok and string.find(msg, "level 4"), "level gate: " .. tostring(msg))
	d.level = 4
	expect(DM.eta(d.vehicles) == 15 and DM.fee(10, d.vehicles) == 10, "no vehicle: normal ETA and fee")
	ok = call(p, "VehicleBuy", "compact_car"); clock += 1
	expect(ok and d.vehicles.compact_car and d.cash == 4200, "bought the compact car")
	expect(DM.eta(d.vehicles) == 10, "compact car: shorter courier ETA " .. DM.eta(d.vehicles))
	expect(DM.fee(10, d.vehicles) == 10, "compact car still pays the small-order fee")
	ok = call(p, "VehicleBuy", "compact_car"); clock += 1
	expect(not ok, "cannot buy twice")
	ok = call(p, "VehicleBuy", "tank"); clock += 1
	expect(not ok, "unknown vehicle refused")
	d.level = 6
	ok = call(p, "VehicleBuy", "delivery_van"); clock += 1
	expect(ok and DM.eta(d.vehicles) == 6 and DM.fee(10, d.vehicles) == 0, "van: ETA 6 s and no fee")

	-- the perk is real: a quote and a PantryDash order use it
	local q = DM.quote(d, { flour = 2 }, "apartment")
	expect(q and q.eta == 6 and q.fee == 0, "quote reflects vehicle perks")

	ok, msg = call(p, "VehicleSpawn", "compact_car"); clock += 1
	expect(not ok, "spawn needs a character in this sim (refused gracefully): " .. tostring(msg))
	local q2 = newPlayer(92, "Walker"); join(q2)
	ok = call(q2, "VehicleSpawn", "delivery_van"); clock += 1
	expect(not ok, "cannot spawn a vehicle you do not own")
	expect(DM.eta(state(q2).vehicles) == 15, "walking still works at the normal pace")

	S.PlayerDataService:SaveNow(p); leave(p); settle()
	local p3 = newPlayer(91, "Driver"); join(p3)
	expect(state(p3).vehicles.delivery_van == true, "vehicles persist")
	leave(p3); leave(q2)
end
