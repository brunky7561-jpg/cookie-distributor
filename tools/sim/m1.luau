do -- Milestone 1: one complete cookie order
	print("== M1: first order")
	local p = newPlayer(7, "Tester")
	join(p)
	local data = state(p)
	expect(data ~= nil, "profile loaded")
	local list = ordersOf(p)
	expect(#list == 1 and list[1].state == "Available" and list[1].isFirst, "first order seeded as Available")
	local oid = list[1].id
	expect(list[1].deadline == nil, "first order has no deadline")

	local ok, msg = call(p, "BakeStart", "classic_chip", oid)
	expect(not ok, "cannot bake for unaccepted order: " .. tostring(msg))
	ok = call(p, "OrderAction", "accept", oid); clock += 1
	expect(ok and ordersOf(p)[1].state == "Accepted", "accept -> Accepted")
	ok = call(p, "OrderAction", "deliver", oid); clock += 1
	expect(not ok, "cannot deliver before Ready")

	local flourBefore = data.ingredients.flour
	ok = call(p, "BakeStart", "classic_chip", oid); clock += 1
	expect(ok, "BakeStart ok")
	expect(data.ingredients.flour == flourBefore - 2 and data.ingredients.chocolate_chips == 2, "ingredients consumed once")
	expect(ordersOf(p)[1].state == "In Production", "order -> In Production")
	ok = call(p, "BakeStart", "classic_chip", oid); clock += 1
	expect(not ok and data.ingredients.flour == flourBefore - 2, "second BakeStart refused, no double consume")
	ok = call(p, "BakeStep", "mixDone"); clock += 1
	expect(not ok, "mix too fast refused")
	clock += 3.5
	ok = call(p, "BakeStep", "mixDone"); clock += 1
	expect(ok, "mix done")
	ok = call(p, "BakeStep", "ovenStart"); clock += 1
	expect(not ok, "cannot skip portion")
	call(p, "BakeStep", "portionStart"); clock += 3.2
	expect((call(p, "BakeStep", "portionStop")), "portion stop"); clock += 1
	call(p, "BakeStep", "ovenStart"); clock += 6.4
	local _, info = call(p, "BakeStep", "ovenPull"); clock += 0.5
	expect(info.stage == "cool", "bake -> cool")
	expect(not call(p, "BakeStep", "coolDone"), "cannot skip cooling"); clock += 4.5
	expect((call(p, "BakeStep", "coolDone")), "cool done"); clock += 0.5
	ok, msg = call(p, "BakeStep", "pack", "small"); clock += 0.5
	expect(not ok, "wrong box refused: " .. tostring(msg))
	ok, msg = call(p, "BakeStep", "pack", "standard"); clock += 0.5
	expect(ok and msg.linkedOrder, "packed and linked")
	print("   batch:", msg.batch.grade, msg.batch.score, msg.batch.feedback, "appeal", msg.batch.appeal)
	expect(ordersOf(p)[1].state == "Ready", "order -> Ready")

	local cashBefore = data.cash
	ok, msg = call(p, "OrderAction", "deliver", oid); clock += 1
	expect(ok and msg.pay > 0, "deliver paid " .. tostring(msg.pay) .. " tip " .. tostring(msg.tip))
	expect(msg.pay + msg.tip >= 90 and msg.pay + msg.tip <= 150, "first payout: 6 Classic cookies at $15 each (about $90-150 with quality and tip)")
	expect(data.cash == cashBefore + msg.pay + msg.tip, "cash increased exactly once")
	local paid = data.cash
	expect(not call(p, "OrderAction", "deliver", oid), "second deliver refused")
	expect(data.cash == paid, "no double payout")
	expect(data.milestones.firstOrderDone == true and #data.batches == 0 and #ordersOf(p) == 0, "first order done, box used, no active orders")
	expect(data.stats.orders == 1 and data.stats.gross == msg.pay + msg.tip, "ledger: gross and order count recorded")

	-- second player: cancel mid-production, assign a stock box
	local q = newPlayer(8, "Two")
	join(q)
	local d2 = state(q)
	local o2 = ordersOf(q)[1].id
	call(q, "OrderAction", "accept", o2); clock += 1
	call(q, "BakeStart", "classic_chip", o2); clock += 1
	ok, msg = call(q, "OrderAction", "cancel", o2); clock += 1
	expect(ok, "cancel in production")
	local re = ordersOf(q)
	expect(#re == 1 and re[1].state == "Available" and re[1].id ~= o2, "first order re-offered after cancel")
	clock += 3.5; call(q, "BakeStep", "mixDone"); clock += 0.5
	call(q, "BakeStep", "portionStart"); clock += 3; call(q, "BakeStep", "portionStop"); clock += 0.5
	call(q, "BakeStep", "ovenStart"); clock += 6; call(q, "BakeStep", "ovenPull"); clock += 5; call(q, "BakeStep", "coolDone"); clock += 0.5
	ok, msg = call(q, "BakeStep", "pack", "standard")
	expect(ok and not msg.linkedOrder and #d2.batches == 1, "bake for a cancelled order lands in stock")
	call(q, "OrderAction", "accept", re[1].id); clock += 1
	ok = call(q, "OrderAction", "assign", re[1].id, d2.batches[1].id); clock += 1
	expect(ok and ordersOf(q)[1].state == "Ready", "assign stock box -> Ready")
	clock += 1
	expect(not call(q, "OrderAction", "assign", re[1].id, d2.batches[1].id), "cannot assign twice"); clock += 1
	local dok, dmsg = call(q, "OrderAction", "deliver", re[1].id); expect(dok, "delivered from stock: " .. tostring(dmsg)); clock += 1
	expect(not call(q, "OrderAction", "accept", 99999), "bogus order id refused"); clock += 1
	expect(not call(q, "OrderAction", {}, "x"), "bad action type refused"); clock += 1
	expect(not call(q, "BakeStart", {}, {}), "bad BakeStart args refused")
	leave(p); leave(q)
end
