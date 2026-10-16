do -- Milestone 6: employees
	print("== M6: staff")
	local Staff = shared("Config.Staff")
	local p = newPlayer(81, "Boss"); join(p)
	local d = state(p)
	d.cash = 1000; d.level = 4
	local ok, msg = call(p, "StaffHire", "sam"); clock += 1
	expect(not ok and string.find(msg, "second oven"), "no slot without a second oven: " .. tostring(msg))
	d.properties.food_truck = true
	ok, msg = call(p, "StaffHire", "sam"); clock += 1
	expect(ok and #d.staff == 1 and d.cash == 970, "hired Sam, first day's wage paid")
	ok = call(p, "StaffHire", "rosa"); clock += 1
	expect(not ok and #d.staff == 1, "all ovens staffed")
	ok = call(p, "StaffHire", "bogus"); clock += 1
	expect(not ok, "unknown candidate refused")

	expect(string.find(d.staff[1].status, "recipe"), "status explains: needs a recipe")
	ok = call(p, "StaffAssign", "sam", "golden_honey"); clock += 1
	expect(not ok, "cannot assign an unlearned recipe")
	ok = call(p, "StaffAssign", "sam", "classic_chip"); clock += 1
	expect(ok and d.staff[1].recipeId == "classic_chip", "assigned classic chip")

	-- ingredients: starter pantry has one batch worth
	local flour0 = d.ingredients.flour
	local batches0 = #d.batches
	S.StaffService:Step(p, 50)
	expect(string.find(d.staff[1].status, "Baking"), "status shows progress: " .. d.staff[1].status)
	expect(#d.batches == batches0, "no batch yet")
	S.StaffService:Step(p, 55)
	expect(#d.batches == batches0 + 1, "a batch after one cycle")
	local b = d.batches[#d.batches]
	expect(b.count == 6 and b.score == 60 and b.byStaff, "deterministic skill-1 quality: score " .. tostring(b.score))
	expect(d.ingredients.flour == flour0 - 2, "ingredients consumed")

	-- run out of ingredients
	d.ingredients.flour = 0
	S.StaffService:Step(p, 10)
	expect(string.find(d.staff[1].status, "ingredients"), "blocked reason names ingredients: " .. d.staff[1].status)
	local n = #d.batches
	S.StaffService:Step(p, 500)
	expect(#d.batches == n, "no baking while blocked")
	d.ingredients.flour = 10
	S.StaffService:Step(p, 105)
	expect(#d.batches == n + 1, "resumes when restocked")

	-- storage full
	for i = 1, 40 do
		if #d.batches >= 30 then break end
		S.InventoryService:AddBatch(p, { id = 500 + i, name = "x", quality = 0.5, score = 50, appeal = 1, effects = {}, ingredients = {}, tags = {}, count = 1, packaged = true })
	end
	S.StaffService:Step(p, 5)
	expect(string.find(d.staff[1].status, "Storage"), "blocked reason: storage full")
	d.batches = {}

	-- wages
	local cash0 = d.cash
	S.StaffService:PayDay(p)
	expect(d.cash == cash0 - 30 and d.stats.wages == 60, "wages paid and recorded")
	d.cash = 5
	S.StaffService:PayDay(p)
	expect(d.staff[1].unpaid and string.find(d.staff[1].status, "wages"), "cannot pay: baker waits, status explains")
	local n2 = #d.batches
	S.StaffService:Step(p, 500)
	expect(#d.batches == n2, "unpaid baker does not bake")
	d.cash = 100
	S.StaffService:Step(p, 5)
	expect(not d.staff[1].unpaid and d.cash == 70, "paying wages resumes work")
	expect(#d.staff == 1, "nobody was fired")

	-- promotion after enough bakes
	d.staff[1].bakes = 10
	d.ingredients.flour = 10; d.ingredients.butter = 10; d.ingredients.white_sugar = 10; d.ingredients.chocolate_chips = 10
	d.staff[1].progress = 0
	S.StaffService:Step(p, 105)
	local last = d.batches[#d.batches]
	expect(last and last.score == 70, "promoted baker makes better cookies: " .. tostring(last and last.score))

	-- persistence and fire
	S.PlayerDataService:SaveNow(p); leave(p); settle()
	local p2 = newPlayer(81, "Boss"); join(p2)
	local d2 = state(p2)
	expect(#d2.staff == 1 and d2.staff[1].recipeId == "classic_chip" and d2.staff[1].bakes >= 10, "staff persist")
	ok = call(p2, "StaffFire", "sam"); clock += 1
	expect(ok and #d2.staff == 0, "can let someone go")
	leave(p2)
end
