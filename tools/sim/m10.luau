do -- Milestone 10: release readiness
	print("== M10: integrity, migration, fuzz")
	local Schema = shared("Modules.DataSchema")
	local RL = shared("Modules.RateLimit")

	-- old saves keep working
	local v1 = Schema.sanitize(Schema.migrate({ schemaVersion = 1, cash = 321, level = 2, xp = 5, recipes = { ["Classic Chip Cookies"] = true } }))
	expect(v1.cash == 321 and v1.level == 2 and v1.recipes.classic_chip, "a v1 save migrates and keeps progress")
	expect(v1.schemaVersion == Schema.VERSION and #v1.staff == 0 and v1.contract == false and v1.settings.textScale == 1, "migrated save gets every newer field")
	local old2 = Schema.sanitize({ schemaVersion = 2, cash = 99 })
	expect(old2.cash == 99 and old2.vehicles ~= nil and old2.settings.brandColor == 1, "a milestone 2-4 save gains M5-M9 fields without a version bump")
	local roundtrip = Schema.sanitize(Schema.sanitize(Schema.default()))
	expect(roundtrip.cash == 250 and roundtrip.properties.apartment, "default data is stable under sanitize")

	-- hostile save contents
	local nasty = Schema.sanitize({ schemaVersion = 2, cash = 0 / 0, level = -4, ingredients = { flour = -5, ["__proto__"] = 9 }, batches = { 5, { count = 1e9 }, "x" }, staff = { { id = "bogus" } }, properties = { moon_base = true }, vehicles = { tank = true }, contract = { recipeId = "nope" }, settings = { textScale = {}, brandName = 123 } })
	expect(nasty.cash == 250 or nasty.cash >= 0, "NaN cash is repaired: " .. tostring(nasty.cash))
	expect(nasty.level >= 1 and #nasty.staff == 0 and not nasty.properties.moon_base and not nasty.vehicles.tank and nasty.contract == false, "unknown ids and junk are dropped")
	expect(nasty.settings.textScale == 1 and nasty.settings.brandName == "", "junk settings reset")

	-- live audit
	local p = newPlayer(121, "Auditor"); join(p)
	local d = state(p)
	d.cash = -50; d.xp = 0 / 0; d.ingredients.flour = -3; d.ingredients.butter = 2.5
	table.insert(d.batches, { id = 77, name = "x", count = 0, quality = 1, score = 1, appeal = 1, effects = {}, tags = {}, ingredients = {} })
	d.stats.gross = -9
	local fixed = S.IntegrityService:Audit(p)
	expect(fixed >= 6, "audit repaired " .. fixed .. " problems")
	expect(d.cash == 0 and d.xp == 0 and d.ingredients.flour >= 0 and d.ingredients.butter % 1 == 0 and d.stats.gross == 0, -- (the recovery kit may top up a broke player)
		 "values moved to the nearest valid number")
	expect(S.IntegrityService:Audit(p) == 0, "a clean profile needs no repairs")

	-- fuzz every remote with hostile arguments: nothing may error or mint money
	d.cash = 500
	local junk = { nil, 0, -1, 1e308, 0 / 0, "", "x", string.rep("a", 5000), true, false, {}, { 1, 2, 3 }, { flour = 1e9 }, { [1] = {} }, math.huge, -math.huge }
	local calls, errors = 0, 0
	for name, remote in R do
		if remote.OnServerInvoke and name ~= "DevReset" and name ~= "DevBoost" then
			for i = 1, #junk + 1 do
				for j = 1, #junk + 1, 5 do
					clock += 5
					calls += 1
					local ok, err = pcall(remote.OnServerInvoke, p, junk[i], junk[j], junk[(i + j) % #junk + 1])
					if not ok then
						errors += 1
						print("   FUZZ ERROR in " .. name .. ": " .. tostring(err))
					end
				end
			end
		end
	end
	expect(calls > 500, "fuzzed " .. calls .. " remote calls")
	expect(errors == 0, "no remote errored on hostile input (" .. errors .. " errors)")
	expect(d.cash <= 500, "fuzzing never created money: $" .. tostring(d.cash))
	expect(S.IntegrityService:Audit(p) == 0, "fuzzing left no impossible values behind")

	-- metrics (hammer one remote without waiting so the limiter has something to count)
	for _ = 1, 5 do pcall(R.SettingSet.OnServerInvoke, p, "sfx", 0.5) end
	local m = S.MetricsService:Snapshot()
	expect(m.players >= 1 and m.rateLimited > 0 and type(m.noisiestRemote) == "string", "metrics snapshot works; rate limiter counted rejections (" .. m.rateLimited .. ")")
	leave(p)
end
