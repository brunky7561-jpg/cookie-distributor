do -- Milestone 11: dev boost
	print("== M11: dev boost")
	local Apps = shared("Config.Apps")
	local p = newPlayer(131, "Tester"); join(p)
	local d = state(p)
	expect(not Apps.byId.marketpulse.unlock(d) and not Apps.byId.staffboard.unlock(d), "fresh save: late-game apps are locked")
	expect(call(p, "DevBoost"), "Studio: the boost works"); clock += 2
	local unlocked = 0
	for _, app in Apps.list do if app.unlock(d) then unlocked += 1 end end
	expect(unlocked == #Apps.list, "after the boost every phone app is unlocked (" .. unlocked .. "/" .. #Apps.list .. ")")
	expect(d.properties.corner_shop and d.vehicles.delivery_van and d.recipes.golden_honey and d.level >= 8, "properties, vehicles, recipes and level are all granted")
	expect(shared("Modules.DeliveryMath").units(d) <= shared("Modules.DeliveryMath").capacity(d), "boosted pantry fits in storage")
	config.studio = false
	clock += 2
	local before = d.cash
	d.cash = 5
	expect(not call(p, "DevBoost") and d.cash == 5, "outside Studio the boost is refused")
	config.studio = true
	d.cash = before
	leave(p)
end
