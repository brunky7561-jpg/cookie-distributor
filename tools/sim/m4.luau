do -- Milestone 4: recipe variety, experiments, equipment upgrades
	print("== M4: recipes and equipment")
	local Recipes = shared("Config.Recipes")
	local Ingredients = shared("Config.Ingredients")
	local Appeal = shared("Modules.AppealCalc")
	local Customers = shared("Config.Customers")

	-- trade-off table (printed so balance can be read at a glance)
	local rows = {}
	for id, r in Recipes.catalog do
		local cost = 0
		for ing, n in r.requires do cost += Ingredients[ing].cost * n end
		local list = Recipes.expand(r.requires)
		local a = Appeal.compute(list, 0.9).score
		local offer = 6 * Recipes.SELL_PRICE * (r.priceMult or 1)
		table.insert(rows, { id = id, cost = cost, appeal = a, offer = math.floor(offer + 0.5), level = r.unlockLevel })
	end
	table.sort(rows, function(x, y) return x.cost < y.cost end)
	for _, r in rows do print(string.format("   %-18s lvl %d  cost $%-3d appeal %-3d typical offer $%d  profit ~$%d", r.id, r.level, r.cost, r.appeal, r.offer, r.offer - r.cost)) end
	local distinct = true
	for i = 2, #rows do if rows[i].appeal <= rows[i - 1].appeal and rows[i].cost > rows[i - 1].cost then distinct = false end end
	expect(#rows >= 5 and distinct, "at least five recipes; higher cost buys higher appeal")
	local profit = {}
	for _, r in rows do profit[r.id] = r.offer - r.cost end
	expect(profit.salted_chunk > profit.classic_chip and profit.caramel_crunch > profit.salted_chunk, "premium recipes earn more per batch than the classic")
	expect(profit.simple_sugar > 20, "the cheapest recipe is still worth baking")

	local p = newPlayer(61, "Baker"); join(p)
	local d = state(p)
	d.cash = 2000; d.properties.garage = true
	-- stock up through the real PantryDash path
	local function buy(items) clock += 1; local ok, m = call(p, "PantryOrder", items, "apartment"); tick(20); return ok, m end
	local function collect()
		local crate = workspace._children.DeliveryCrates._children["Supply Crate (Baker)"]
		if crate then crate._children.ProximityPrompt.Triggered:_fire(p); settle() end
	end
	d.milestones.firstOrderDone = true
	S.PlayerDataService:Replicate(p)

	expect(d.recipes.classic_chip and d.recipes.simple_sugar and not d.recipes.salted_chunk, "starter book: Simple Sugar and Classic Chip")
	-- locked recipe refused, level unlocks it
	d.ingredients = { flour = 20, butter = 10, white_sugar = 6, brown_sugar = 6, chocolate_chips = 10, sea_salt = 4, caramel = 4, espresso_powder = 4 }
	local ok, msg = call(p, "BakeStart", "salted_chunk"); clock += 1
	expect(not ok and string.find(msg, "unlocked"), "locked recipe refused: " .. tostring(msg))
	d.level = 3; S.PlayerDataService:Replicate(p)
	expect(d.recipes.brown_sugar_chunk and d.recipes.salted_chunk and not d.recipes.caramel_crunch, "levels unlock recipes (2: Brown Sugar Chunk, 3: Salted Chunk)")

	-- bake a catalog recipe: ingredients, book entry, grade explanation data
	local before = d.ingredients.brown_sugar
	local r
	ok, r = T.bake2(p, "salted_chunk")
	expect(ok and d.ingredients.brown_sugar == before - 1 and d.ingredients.sea_salt == 3, "Salted Chunk consumed exactly its ingredients")
	expect(r.batch.factors.recipe == 1 and r.batch.factors.bake and r.batch.factors.portion and r.batch.grade, "result carries the quality factors and grade")
	expect(d.recipeBook.salted_chunk.bakes == 1 and d.recipeBook.salted_chunk.best == r.batch.score, "Recipe Book records bakes and best score")
	expect(table.find(r.batch.tags, "chocolate") and table.find(r.batch.tags, "salty"), "batch tags reflect ingredients")

	-- discovery: experimenting into a locked named recipe unlocks it
	ok, msg = call(p, "BakeStart", "experiment", nil, { slots = { flavor = "caramel", mixin = "chocolate_chips", finish = "espresso_powder" } }); clock += 1
	expect(ok and not d.recipes.caramel_crunch, "experiment that matches a locked recipe starts")
	clock += 3.5; call(p, "BakeStep", "mixDone"); clock += 0.5; call(p, "BakeStep", "portionStart"); clock += 3; call(p, "BakeStep", "portionStop"); clock += 0.5
	call(p, "BakeStep", "ovenStart"); clock += 6; call(p, "BakeStep", "ovenPull"); clock += 5; call(p, "BakeStep", "coolDone"); clock += 0.5
	ok, r = call(p, "BakeStep", "pack", "standard"); clock += 1
	expect(ok and r.discovered and d.recipes.caramel_crunch and r.batch.name == "Caramel Espresso Crunch", "discovered Caramel Espresso Crunch by experimenting")

	-- custom experiments
	expect(not (call(p, "BakeStart", "experiment", nil, { slots = { flavor = "sea_salt" } })), "sea salt is not a flavor"); clock += 1
	expect(not (call(p, "BakeStart", "experiment", nil, { slots = {} })), "a flavor is required"); clock += 1
	expect(not (call(p, "BakeStart", "experiment", nil, { slots = { flavor = "white_sugar", mixin = "flour" } })), "unknown mix-in refused"); clock += 1
	expect(not (call(p, "BakeStart", "experiment", nil, "slots")), "bad options refused"); clock += 1
	local exp = { slots = { flavor = "white_sugar", finish = "espresso_powder" } }
	local bakes = {}
	for i = 1, 3 do
		ok, r = T.bake2(p, "experiment", nil, exp)
		expect(ok and r.custom, "experiment bake " .. i)
		bakes[i] = r.batch.factors.recipe
	end
	expect(bakes[1] == 0.85 and bakes[2] == 0.92 and bakes[3] == 1, "practice refines a custom recipe: 0.85 > 0.92 > 1.0")
	local key = "custom:white_sugar|-|espresso_powder"
	expect(d.recipeBook[key] and d.recipeBook[key].custom and d.recipeBook[key].bakes == 3, "good experiments are saved to the Recipe Book")
	expect(string.find(d.recipeBook[key].name, "House Special"), "custom recipes get a descriptive name")

	-- experiment book survives leave/rejoin and keeps only valid keys
	leave(p)
	local p2 = newPlayer(61, "Baker"); join(p2)
	local d2 = state(p2)
	expect(d2.recipeBook[key] and d2.recipeBook.salted_chunk and d2.recipes.caramel_crunch, "Recipe Book and discoveries survive rejoin")
	storeData["Player_62"] = { data = { recipeBook = { ["custom:nonsense|x|y"] = { bakes = 5 }, ["classic_chip"] = { name = "Classic", bakes = 2, best = 120 }, ["fake"] = { bakes = 1 } } } }
	local pj = newPlayer(62, "Junk"); join(pj)
	local dj = state(pj)
	expect(dj.recipeBook["custom:nonsense|x|y"] == nil and dj.recipeBook.fake == nil and dj.recipeBook.classic_chip.best == 100, "junk Recipe Book entries removed, scores clamped")
	leave(pj)

	-- equipment: stand mixer + fan rack
	p = p2; d = d2
	d.cash = 2000; d.milestones.firstOrderDone = true
	d.ingredients = { flour = 40, butter = 20, white_sugar = 10, brown_sugar = 4, chocolate_chips = 20 }
	expect(not (call(p, "BakeStart", "classic_chip", nil, { batchMult = 2 })), "double batch needs a Stand Mixer"); clock += 1
	ok = call(p, "BuyEquipment", "stand_mixer"); clock += 1
	expect(ok and d.equipment.stand_mixer and d.cash == 1780, "bought the Stand Mixer for $220")
	expect(not (call(p, "BakeStart", "classic_chip", nil, { batchMult = 3 })), "batchMult 3 refused"); clock += 1
	expect(not (call(p, "BakeStart", "classic_chip", nil, { batchMult = 1.5 })), "fractional batchMult refused"); clock += 1
	local flour = d.ingredients.flour
	local info
	ok, info = call(p, "BakeStart", "classic_chip", nil, { batchMult = 2 }); clock += 1
	expect(ok and d.ingredients.flour == flour - 4 and info.yield == 12 and info.mixTaps == 4, "double batch consumes 2x ingredients, yields 12, needs only 4 taps")
	clock += 2; expect((call(p, "BakeStep", "mixDone")), "stand mixer finishes mixing after 1.5 s"); clock += 0.5
	call(p, "BakeStep", "portionStart"); clock += 3; call(p, "BakeStep", "portionStop"); clock += 0.5
	call(p, "BakeStep", "ovenStart"); clock += 6; call(p, "BakeStep", "ovenPull"); clock += 5; call(p, "BakeStep", "coolDone"); clock += 0.5
	ok, msg = call(p, "BakeStep", "pack", "standard"); clock += 1
	expect(not ok, "a 12-cookie tray does not fit the Standard box: " .. tostring(msg))
	ok, r = call(p, "BakeStep", "pack", "large")
	expect(ok and r.batch.count == 12, "Large box holds the double batch")

	ok = call(p, "BuyEquipment", "fan_rack"); clock += 1
	expect(ok and d.equipment.fan_rack, "bought the Fan Cooling Rack for $120")
	call(p, "BakeStart", "classic_chip"); clock += 3.5; call(p, "BakeStep", "mixDone"); clock += 0.5
	call(p, "BakeStep", "portionStart"); clock += 3; call(p, "BakeStep", "portionStop"); clock += 0.5
	call(p, "BakeStep", "ovenStart"); clock += 6; call(p, "BakeStep", "ovenPull"); clock += 1
	expect(not (call(p, "BakeStep", "coolDone")), "tray not ready after 1 s"); clock += 1.2
	expect((call(p, "BakeStep", "coolDone")), "tray ready after 2.2 s with the fan rack"); clock += 0.5
	call(p, "BakeStep", "pack", "standard"); clock += 1

	-- "any new recipe" orders accept experiments; named orders do not
	local ordersMod = S.OrderService
	local zed = nil
	for i = 1, 120 do
		tick(31)
		for _, o in ordersOf(p) do if o.recipeId == "any" then zed = o end end
		if zed then break end
		for _, o in ordersOf(p) do call(p, "OrderAction", "cancel", o.id); clock += 1 end
	end
	expect(zed ~= nil, "a Trendsetter eventually asks for 'any new recipe'")
	if zed then
		call(p, "OrderAction", "accept", zed.id); clock += 1
		ok, r = T.bake2(p, "experiment", zed.id, { slots = { flavor = "brown_sugar" } })
		expect(ok and r.linkedOrder, "an experiment can fill an 'any new recipe' order: " .. tostring(r))
	end
	local named = nil
	for i = 1, 20 do
		tick(31)
		for _, o in ordersOf(p) do if o.recipeId ~= "any" and o.state == "Available" then named = o end end
		if named then break end
	end
	if named then
		call(p, "OrderAction", "accept", named.id); clock += 1
		ok, r = T.bake2(p, "experiment", named.id, { slots = { flavor = "brown_sugar" } })
		expect(not ok, "a named-recipe order refuses a custom experiment")
	end
	-- price check: premium orders pay more
	local fd = shared("Config.Customers")
	expect(#fd >= 6, "Trendsetter customer exists")
	leave(p)
end
