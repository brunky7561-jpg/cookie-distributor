do -- Milestone 5: properties, storefront, rent
	print("== M5: properties and storefront")
	local Properties = shared("Config.Properties")
	local p = newPlayer(71, "Owner"); join(p)
	local d = state(p)
	local function batch(id, count, q)
		S.InventoryService:AddBatch(p, { id = id, name = "Classic Chip", recipeId = "classic_chip", ingredients = {}, tags = {}, quality = q, score = q * 100, appeal = 50, effects = {}, count = count, packaged = true })
	end

	local ok, msg = call(p, "PropertyBuy", "food_truck"); clock += 1
	expect(not ok, "level gate refuses an early purchase: " .. tostring(msg))
	d.level = 3
	ok, msg = call(p, "PropertyBuy", "food_truck"); clock += 1
	expect(not ok and string.find(msg, "1500"), "cannot afford: " .. tostring(msg))
	expect(not d.properties.food_truck and d.cash == 250, "failed purchase changes nothing")
	d.cash = 2000
	ok, msg = call(p, "PropertyBuy", "food_truck"); clock += 1
	expect(ok and d.properties.food_truck and d.cash == 500, "bought the food truck for $1500")
	ok = call(p, "PropertyBuy", "food_truck"); clock += 1
	expect(not ok and d.cash == 500, "cannot buy twice")
	ok = call(p, "PropertyBuy", "nonsense"); clock += 1
	expect(not ok, "unknown property refused")
	local DM = shared("Modules.DeliveryMath")
	expect(DM.capacity(d) == 40 + 70, "storage adds up across properties")

	-- display case: 2 slots
	batch(1, 6, 0.9); batch(2, 6, 0.9); batch(3, 6, 0.9)
	ok = call(p, "DisplaySet", 1, true); clock += 1
	expect(ok, "batch 1 on display")
	ok = call(p, "DisplaySet", 2, true); clock += 1
	ok = call(p, "DisplaySet", 3, true); clock += 1
	expect(not ok, "third batch refused: case holds 2")
	expect(not S.InventoryService:Reserve(p, 1, 99), "a displayed batch cannot be promised to an order")
	ok = call(p, "DisplaySet", 1, false); clock += 1
	expect(ok and S.InventoryService:Reserve(p, 1, 99), "taking it off display frees it for orders")
	S.InventoryService:Release(p, 1)
	call(p, "DisplaySet", 1, true); clock += 1

	-- walk-ins: 3 per round, quality 0.9 classic => price 2.2*(1.4)*1 ≈ 3.1
	local cash0 = d.cash
	local sold = S.PropertyService:SellRound(p)
	expect(sold == 3, "a round sells up to the walk-in limit: " .. tostring(sold))
	expect(d.cash > cash0 and d.cash - cash0 <= 12, "walk-in income is modest: $" .. tostring(d.cash - cash0))
	local b1 = S.InventoryService:FindBatch(p, 1)
	expect(b1 and b1.count == 3, "stock goes down")
	S.PropertyService:SellRound(p); S.PropertyService:SellRound(p); S.PropertyService:SellRound(p)
	expect(S.InventoryService:FindBatch(p, 1) == nil and S.InventoryService:FindBatch(p, 2) == nil, "sold-out batches disappear")
	expect(S.InventoryService:FindBatch(p, 3) ~= nil, "undisplayed stock is untouched")
	expect(d.stats.walkIn >= 12, "walk-in sales are tracked")
	local per = shared("Modules.DataSchema")
	local clean = per.sanitize(per.default())
	expect(clean.stats.walkIn == 0, "schema has the walk-in counter")

	-- rent and closing
	d.cash = 5; d.batches = {}
	batch(5, 6, 0.9); call(p, "DisplaySet", 5, true); clock += 1
	expect(not S.PropertyService:ChargeRent(p) and S.PropertyService:IsClosed(p), "cannot pay rent: storefront closes")
	expect(S.PropertyService:SellRound(p) == 0 and d.cash == 5, "closed storefront makes no sales, loses nothing")
	d.cash = 100
	expect(S.PropertyService:ChargeRent(p) and d.cash == 80 and not S.PropertyService:IsClosed(p), "rent paid, reopens")
	expect(d.stats.other >= 1520, "rent and purchase appear as other costs")

	-- the apartment alone has no storefront
	local q = newPlayer(72, "Renter"); join(q)
	local dq = state(q)
	S.InventoryService:AddBatch(q, { id = 1, name = "x", quality = 0.5, score = 50, appeal = 1, effects = {}, ingredients = {}, tags = {}, count = 6, packaged = true })
	local ok2, m2 = call(q, "DisplaySet", 1, true)
	expect(not ok2 and string.find(m2, "Food Truck"), "no display case in the apartment: " .. tostring(m2))
	expect(S.PropertyService:ChargeRent(q), "no rent on the apartment")

	-- persistence
	S.PlayerDataService:SaveNow(p); leave(p); settle()
	local p3 = newPlayer(71, "Owner"); join(p3)
	local d3 = state(p3)
	expect(d3.properties.food_truck == true, "ownership persists")
	expect(d3.batches[1] and d3.batches[1].displayed == true, "display state persists")
	leave(p3); leave(q)
end
