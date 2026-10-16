do -- Milestone 8: market events, contracts, leaderboard
	print("== M8: market")
	local Market = shared("Config.Market")
	local ev1 = Market.currentEvent(0)
	local ev2 = Market.currentEvent(Market.EVENT_PERIOD)
	expect(ev1.id ~= ev2.id, "events rotate over time")
	expect(Market.currentEvent(100).id == Market.currentEvent(800).id, "the same event for the whole period")
	expect(Market.eventMult(Market.events[1], { "chocolate", "sweet" }) == 1.25 and Market.eventMult(Market.events[1], { "salty" }) == 1, "event bonus only for the matching tag")

	local p = newPlayer(101, "Dealer"); join(p)
	local d = state(p)
	d.level = 1
	expect(not S.MarketService:Refresh(p), "no contracts before level 2")
	d.level = 2
	d.milestones.firstOrderDone = true
	clock += 200
	expect(S.MarketService:Refresh(p) and d.contract, "a contract appears at level 2")
	local c = d.contract
	expect(c.count == 12 and c.pay > 0 and c.expiresAt > os.time(), "contract has size, pay and a deadline")

	local ok, msg = call(p, "ContractDeliver"); clock += 1
	expect(not ok and string.find(msg, "have 0"), "cannot deliver with no stock: " .. tostring(msg))

	local function stock(id, count, score, extra)
		local b = { id = id, name = "Cookies", recipeId = c.recipeId, quality = score / 100, score = score, appeal = 50, effects = {}, ingredients = {}, tags = {}, count = count, packaged = true }
		for k, v in extra or {} do b[k] = v end
		S.InventoryService:AddBatch(p, b)
	end
	stock(1, 6, 50) -- too low
	stock(2, 6, 80, { displayed = true }) -- on display
	stock(3, 6, 80)
	ok, msg = call(p, "ContractDeliver"); clock += 1
	expect(not ok, "low-score and displayed cookies do not count")
	stock(4, 6, 90)
	local cash0 = d.cash
	local rep0 = d.reputation
	ok, msg = call(p, "ContractDeliver"); clock += 1
	expect(ok, "contract filled: " .. tostring(msg))
	expect(d.cash >= cash0 + c.pay and d.reputation == rep0 + 5, "paid cash and reputation")
	expect(d.contract == false and d.contractWins == 1, "contract cleared and counted")
	expect(S.InventoryService:FindBatch(p, 1) ~= nil and S.InventoryService:FindBatch(p, 2) ~= nil, "unused batches untouched")
	expect(S.InventoryService:FindBatch(p, 3) == nil and S.InventoryService:FindBatch(p, 4) == nil, "delivered batches consumed")
	ok = call(p, "ContractDeliver"); clock += 1
	expect(not ok, "cannot cash in twice")

	-- cooldown, then a new one; letting it expire loses to a rival without penalty
	expect(not S.MarketService:Refresh(p), "cooldown before the next contract")
	clock += 130
	expect(S.MarketService:Refresh(p) and d.contract, "new contract after the cooldown")
	local cash1 = d.cash
	clock += Market.CONTRACT_LIFETIME + 5
	S.MarketService:Refresh(p)
	expect(d.contractLosses == 1 and d.cash == cash1, "expired: a rival won, no cash lost")

	-- leaderboard failure is harmless
	local board = S.MarketService:Board()
	expect(type(board) == "table", "leaderboard returns a table even when the store is unavailable")
	local info = R.MarketStatus.OnServerInvoke(p)
	expect(info and info.event and info.secondsLeft > 0, "market status works")

	-- persistence
	S.PlayerDataService:SaveNow(p); leave(p); settle()
	local p2 = newPlayer(101, "Dealer"); join(p2)
	expect(state(p2).contractWins == 1 and state(p2).contractLosses == 1, "contract record persists")
	leave(p2)
end
