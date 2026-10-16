do -- Milestone 3: phone apps, CrumbChat dialogue, PantryDash deliveries
	print("== M3: phone and PantryDash")
	local DM = shared("Modules.DeliveryMath")
	local Apps = shared("Config.Apps")
	local mat = node("Delivery Mat (Starter Apartment)", workspace)
	mat.ClassName = "Part"; mat.Position = Vector3.new(-41, 0.3, -57); mat.Size = Vector3.new(7, 0.3, 7)
	config.tagged.ReceivingArea = { mat }

	local p = newPlayer(51, "Shopper"); join(p)
	local d = state(p)
	local function order(items, prop) return call(p, "PantryOrder", items, prop or "apartment") end

	-- validation
	clock += 1
	expect(not (order({})), "empty cart refused"); clock += 1
	expect(not (order({ { id = "gold", qty = 1 } })), "unknown ingredient refused"); clock += 1
	expect(not (order({ { id = "flour", qty = 0 } })), "quantity 0 refused"); clock += 1
	expect(not (order({ { id = "flour", qty = 51 } })), "quantity 51 refused"); clock += 1
	expect(not (order({ { id = "flour", qty = 1.5 } })), "fractional quantity refused"); clock += 1
	expect(not (order({ { id = "flour", qty = 0 / 0 } })), "NaN quantity refused"); clock += 1
	expect(not (order("flour")), "non-table cart refused"); clock += 1
	expect(not (order({ { id = "flour", qty = 1 } }, "garage")), "property you do not own refused"); clock += 1
	expect(not (order({ { id = "flour", qty = 1 } }, {})), "bad property type refused"); clock += 1
	local ok, msg = order({ { id = "moon_sugar", qty = 1 } }); clock += 1
	expect(not ok and string.find(msg, "level"), "rare ingredient locked until level 5: " .. tostring(msg))
	ok, msg = order({ { id = "flour", qty = 50 } }); clock += 1
	expect(not ok and string.find(msg, "storage"), "over capacity refused with a warning before purchase: " .. tostring(msg))
	local cash0 = d.cash
	d.cash = 3
	ok, msg = order({ { id = "flour", qty = 2 } }); clock += 1
	expect(not ok and d.cash == 3, "not enough cash refused, nothing taken: " .. tostring(msg))
	d.cash = cash0

	-- quote and purchase: $20 of goods pays the $4 fee
	local q
	ok, q = call(p, "PantryQuote", { { id = "flour", qty = 10 }, { id = "butter", qty = 5 } }, "apartment"); clock += 1
	expect(ok and q.subtotal == 20 and q.fee == 4 and q.total == 24 and q.eta == 15, "quote: subtotal 20, fee 4, total 24, ETA 15s")
	local unitsBefore = DM.units(d)
	ok, msg = order({ { id = "flour", qty = 10 }, { id = "butter", qty = 5 } }); clock += 1
	expect(ok and d.cash == cash0 - 24, "charged exactly $24")
	expect(d.stats.supplies == 20 and d.stats.delivery == 4, "ledger: supplies 20, delivery fee 4")
	expect(#d.deliveries == 1 and d.ingredients.flour == 6, "inventory unchanged until the crate is collected")
	expect(DM.units(d) == unitsBefore + 15, "pending items count toward storage")

	-- free delivery over $30
	ok, q = call(p, "PantryQuote", { { id = "caramel", qty = 8 } }, "apartment"); clock += 1
	expect(ok and q.fee == 0, "orders of $30 or more ship free")

	-- courier arrives, crate appears
	tick(10)
	expect(workspace._children.DeliveryCrates ~= nil, "crate folder created")
	expect(next(workspace._children.DeliveryCrates._children) == nil, "no crate before the ETA")
	tick(10)
	local crate = workspace._children.DeliveryCrates._children["Supply Crate (Shopper)"]
	expect(crate ~= nil and crate:GetAttribute("OwnerUserId") == 51, "crate appears after the ETA, owned by the buyer")
	local prompt = crate._children.ProximityPrompt

	-- only the owner, only nearby, only once
	local thief = newPlayer(52, "Thief"); join(thief)
	prompt.Triggered:_fire(thief); settle()
	expect(#d.deliveries == 1, "another player cannot collect your crate")
	config.distance = 50; clock += 1
	prompt.Triggered:_fire(p); settle()
	expect(#d.deliveries == 1, "too far away: crate stays")
	config.distance = 0; clock += 1
	local flourBefore = d.ingredients.flour
	prompt.Triggered:_fire(p); settle()
	expect(#d.deliveries == 0 and d.ingredients.flour == flourBefore + 10 and d.ingredients.butter == 9, "owner collects: items added to the pantry")
	clock += 1
	prompt.Triggered:_fire(p); settle()
	expect(d.ingredients.flour == flourBefore + 10, "collecting again adds nothing (no duplication)")
	leave(thief)

	-- storage can be full at collect time
	d.cash = 500
	ok = order({ { id = "flour", qty = 5 } }); clock += 1
	tick(20)
	crate = workspace._children.DeliveryCrates._children["Supply Crate (Shopper)"]
	local used = DM.units({ ingredients = d.ingredients, deliveries = {} })
	d.ingredients.sea_salt = (d.ingredients.sea_salt or 0) + (DM.capacity(d) - used) + 5 -- overfill on purpose
	clock += 1
	crate._children.ProximityPrompt.Triggered:_fire(p); settle()
	expect(#d.deliveries == 1, "full storage: crate waits for room, nothing lost")
	d.ingredients.sea_salt = nil; clock += 1
	crate._children.ProximityPrompt.Triggered:_fire(p); settle()
	expect(#d.deliveries == 0, "after making room the crate can be collected")

	-- paid deliveries survive leaving the game
	ok = order({ { id = "white_sugar", qty = 3 } }); clock += 1
	leave(p)
	expect(workspace._children.DeliveryCrates._children["Supply Crate (Shopper)"] == nil, "leaving removes your crates from the world")
	local p2 = newPlayer(51, "Shopper"); join(p2)
	expect(#state(p2).deliveries == 1, "the paid delivery is still saved")
	tick(20)
	expect(workspace._children.DeliveryCrates._children["Supply Crate (Shopper)"] ~= nil, "crate reappears on rejoin once the courier arrives")
	-- pending limit
	local d2 = state(p2); d2.cash = 5000; d2.properties.garage = true -- more storage so the pending limit is what stops us
	for i = 1, 4 do clock += 1; call(p2, "PantryOrder", { { id = "flour", qty = 1 } }, "apartment") end
	clock += 1
	ok, msg = call(p2, "PantryOrder", { { id = "flour", qty = 1 } }, "apartment")
	expect(not ok and #d2.deliveries == 5, "at most 5 deliveries waiting: " .. tostring(msg))

	-- CrumbChat preset questions
	local fresh = newPlayer(53, "Chatter"); join(fresh)
	local oid = ordersOf(fresh)[1].id
	local r
	ok, r = call(fresh, "OrderAction", "ask", oid, "flavor"); clock += 1
	expect(ok and string.find(r, "chocolate"), "NPC answers the flavor question from curated text: " .. tostring(r))
	ok, r = call(fresh, "OrderAction", "ask", oid, "deadline"); clock += 1
	expect(ok and string.find(r, "rush"), "first order: no rush")
	ok, r = call(fresh, "OrderAction", "ask", oid, "where"); clock += 1
	expect(ok and string.find(r, "doorstep"), "destination question answered")
	expect(not (call(fresh, "OrderAction", "ask", oid, "Tell me your password")), "free-text questions are refused"); clock += 1
	expect(not (call(fresh, "OrderAction", "ask", oid, {})), "bad question type refused"); clock += 1

	-- history and app unlocks
	call(fresh, "OrderAction", "accept", oid); clock += 1
	T.bake(fresh, oid)
	call(fresh, "OrderAction", "deliver", oid); clock += 1
	expect(#state(fresh).history == 1 and state(fresh).history[1].customer == "Mrs. Park", "completed order recorded in history")
	local fd = shared("Modules.DataSchema").default()
	expect(Apps.byId.ledger.unlock(fd) == false, "Ledger starts locked")
	expect(not (call(fresh, "SeenApp", "ledger")) or state(fresh).milestones.firstOrderDone, "SeenApp respects unlocks"); clock += 1
	local seen = call(fresh, "SeenApp", "crumbchat"); clock += 1
	expect(seen and state(fresh).settings.seenApps.crumbchat, "opening an app marks it seen")
	expect(not (call(fresh, "SeenApp", "nope")), "unknown app id refused")
	leave(p2); leave(fresh)
end
