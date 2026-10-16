do -- Milestone 2: save/load, progression, equipment
	print("== M2: persistence and progression")
	local P = S.PlayerDataService
	local p = newPlayer(21, "Saver")
	join(p)
	local d = state(p)
	expect(d.cash == 250 and d.schemaVersion == 2, "new profile: $250 and schema 2")
	expect(d.ingredients.flour == 6 and d.ingredients.butter == 4 and d.ingredients.white_sugar == 4 and d.ingredients.chocolate_chips == 3, "starter pantry matches the roadmap")
	expect(d.equipment.basic_oven and d.equipment.mixing_bowl and d.equipment.cooling_rack, "starter equipment owned")

	-- first order, then progress persists across leave/rejoin
	local oid = ordersOf(p)[1].id
	call(p, "OrderAction", "accept", oid); clock += 1
	T.bake(p, oid)
	local _, rcpt = call(p, "OrderAction", "deliver", oid); clock += 1
	local cashAfter = d.cash
	expect(d.milestones.firstOrderDone and d.milestones.savedForUpgrade == nil or d.milestones.savedForUpgrade, "milestone flags set by ProgressService")
	leave(p)
	local p2 = newPlayer(21, "Saver")
	join(p2)
	local d2 = state(p2)
	expect(d2.cash == cashAfter, "cash survives leave/rejoin")
	expect(d2.milestones.firstOrderDone == true and d2.stats.orders == 1, "milestones and stats survive")
	expect(d2.recipes.classic_chip and d2.ingredients.flour == 4, "recipe and inventory survive")

	-- equipment purchase rules
	d2.cash = 100
	local ok, msg = call(p2, "BuyEquipment", "convection_oven"); clock += 1
	expect(not ok and d2.cash == 100, "cannot buy without enough cash: " .. tostring(msg))
	d2.cash = 400
	expect(not call(p2, "BuyEquipment", "basic_oven"), "starter items are not for sale"); clock += 1
	expect(not call(p2, "BuyEquipment", {}), "bad item id refused"); clock += 1
	ok = call(p2, "BuyEquipment", "convection_oven"); clock += 1
	expect(ok and d2.cash == 250 and d2.equipment.convection_oven, "bought convection oven for $150")
	expect(not call(p2, "BuyEquipment", "convection_oven") and d2.cash == 250, "cannot buy twice"); clock += 1
	expect(d2.milestones.firstUpgrade == true, "firstUpgrade milestone awarded")
	local _, info = call(p2, "BakeStart", "classic_chip"); clock += 1
	expect(info.bakeSlack == 0.6, "bake session carries the oven's forgiveness")
	call(p2, "BakeStep", "mixDone"); clock += 4; call(p2, "BakeStep", "mixDone"); clock += 0.5
	call(p2, "BakeStep", "portionStart"); clock += 3; call(p2, "BakeStep", "portionStop"); clock += 0.5
	call(p2, "BakeStep", "ovenStart"); clock += 6.5 -- 0.5 s late
	local _, r = call(p2, "BakeStep", "ovenPull")
	expect(r.bakeScore == 1, "convection oven forgives a 0.5 s late pull")

	-- old v1 save is migrated; malformed fields get safe defaults
	local K = "Player_31"
	local legacy = { data = { cash = 77, level = 3, xp = 5, ingredients = { flour = 2, ghost_ingredient = 5 }, batches = {}, recipes = { ["Classic Dough"] = true }, properties = { apartment = true }, customers = {}, nextBatchId = 4, milestones = { firstOrderDone = true } } }
	storeData[K] = legacy
	local p3 = newPlayer(31, "Legacy"); join(p3)
	local d3 = state(p3)
	expect(d3.cash == 77 and d3.level == 3 and d3.schemaVersion == 2, "v1 save migrated, values kept")
	expect(d3.ingredients.ghost_ingredient == nil and d3.ingredients.flour == 2, "unknown ingredient ids dropped")
	expect(d3.equipment.basic_oven and d3.stats.orders == 0 and d3.settings.guidance == true, "new fields get defaults")
	leave(p3)

	storeData["Player_32"] = { data = { cash = "lots", level = -5, ingredients = "none", batches = { { id = 1, count = 3, quality = 5, reservedFor = 9 }, "junk", { id = "x" } }, equipment = { gold_oven = true }, stats = { orders = -4 } } }
	local p4 = newPlayer(32, "Broken"); join(p4)
	local d4 = state(p4)
	expect(d4.cash == 250 and d4.level == 1 and type(d4.ingredients) == "table", "malformed numbers/tables fall back to defaults")
	expect(#d4.batches == 1 and d4.batches[1].quality == 1 and d4.batches[1].reservedFor == nil, "bad batches dropped, good one clamped, reservation cleared")
	expect(d4.equipment.gold_oven == nil and d4.stats.orders == 0, "unknown equipment and negative stats cleaned")
	leave(p4)
	storeData["Player_33"] = "garbage"
	local p5 = newPlayer(33, "Garbage"); join(p5)
	expect(state(p5) ~= nil and state(p5).cash == 250, "non-table record loads as defaults")
	leave(p5)

	-- a save from a newer version is never overwritten
	storeData["Player_34"] = { data = { schemaVersion = 99, cash = 5 } }
	local p6 = newPlayer(34, "Future"); join(p6)
	expect(state(p6).cash == 250 and not P:IsPersistent(p6), "newer-version save: play with temporary data, not persistent")
	leave(p6)
	expect(storeData["Player_34"].data.schemaVersion == 99 and storeData["Player_34"].data.cash == 5, "newer save left untouched on leave")

	-- simulated DataStore failure: load retries, save retries, errors counted
	local before = P.errors.save
	store.fail = 2
	local p7 = newPlayer(35, "Flaky"); join(p7)
	expect(state(p7) ~= nil and P:IsPersistent(p7), "load succeeded after 2 simulated failures")
	state(p7).cash = 999
	store.fail = 2
	leave(p7)
	expect(storeData["Player_35"].data.cash == 999, "save succeeded on retry after failures")
	expect(P.errors.save >= before + 2, "save errors were counted")
	local p8 = newPlayer(36, "Down"); store.fail = 100; join(p8)
	expect(state(p8) ~= nil and not P:IsPersistent(p8), "store down: temporary profile, nothing saved")
	store.fail = 0
	leave(p8)
	expect(storeData["Player_36"] == nil or storeData["Player_36"].data == nil, "temporary profile never overwrote the real save")

	-- rapid exit and lock
	local p9 = newPlayer(37, "Rapid"); join(p9)
	state(p9).cash = 321
	leave(p9)
	local p10 = newPlayer(37, "Rapid"); join(p10)
	expect(state(p10).cash == 321, "rapid leave/rejoin keeps the latest cash")
	leave(p10)

	-- recovery for a broke player
	local b = newPlayer(41, "Broke"); join(b)
	local db = state(b)
	db.cash = 2; db.ingredients = {}
	S.PlayerDataService:Replicate(b); settle()
	expect((db.ingredients.flour or 0) >= 2, "broke player with no ingredients gets a supply kit")
	local flour = db.ingredients.flour
	db.ingredients = {}; S.PlayerDataService:Replicate(b)
	expect((db.ingredients.flour or 0) == 0, "kit has a cooldown (no infinite supplies)")
	clock += 301; S.PlayerDataService:Replicate(b)
	expect((db.ingredients.flour or 0) >= 2, "kit is available again after the cooldown")

	-- dev reset
	local dr = state(b); dr.cash = 5000
	expect(call(b, "DevReset") and state(b).cash == 250, "dev reset works in Studio")
	config.studio = false
	expect(not call(b, "DevReset"), "dev reset refused outside Studio for normal players")
	config.studio = true
	expect(#ordersOf(b) == 1 and ordersOf(b)[1].isFirst, "dev reset re-offers the first order")
	leave(b)

	-- goals
	local Milestones = shared("Config.Milestones")
	local fresh = shared("Modules.DataSchema").default()
	expect(Milestones.next(fresh).id == "firstOrderDone", "new players' first goal is the first order")
	fresh.milestones.firstOrderDone = true
	expect(Milestones.next(fresh).id == "savedForUpgrade" or Milestones.next(fresh).id == "firstUpgrade", "goals advance with progress")
end
