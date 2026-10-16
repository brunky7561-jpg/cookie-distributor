do -- Milestone 9: settings, brand, accessibility
	print("== M9: settings and brand")
	local Brand = shared("Config.Brand")
	local Schema = shared("Modules.DataSchema")
	local p = newPlayer(111, "Designer"); join(p)
	local d = state(p)
	local ok, msg = call(p, "SettingSet", "textScale", 1.5); clock += 1
	expect(ok and d.settings.textScale == 1.5, "text size saved")
	ok = call(p, "SettingSet", "textScale", 3); clock += 1
	expect(not ok and d.settings.textScale == 1.5, "text size outside the list refused")
	ok = call(p, "SettingSet", "sfx", 0.3); clock += 1
	expect(ok and d.settings.sfx == 0.3, "volume saved")
	ok = call(p, "SettingSet", "sfx", 7); clock += 1
	expect(not ok and d.settings.sfx == 0.3, "bad volume refused")
	ok = call(p, "SettingSet", "sfx", 0 / 0); clock += 1
	expect(not ok, "NaN volume refused")
	ok = call(p, "SettingSet", "cash", 999999); clock += 1
	expect(not ok and d.cash == 250, "unknown setting refused; cash untouched")
	ok = call(p, "SettingSet", "guidance", false); clock += 1
	expect(ok and d.settings.guidance == false, "hints can be turned off")

	-- brand
	ok, msg = call(p, "BrandSet", "Sweet Dreams", 3); clock += 3
	expect(ok and d.settings.brandName == "Sweet Dreams" and d.settings.brandColor == 3, "brand saved: " .. tostring(msg))
	ok = call(p, "BrandSet", "x", 1); clock += 3
	expect(not ok, "too short refused")
	ok = call(p, "BrandSet", "<b>hi</b> there", 1); clock += 3
	expect(not ok, "symbols refused")
	ok = call(p, "BrandSet", "Fine Name", 99); clock += 3
	expect(not ok, "bad color refused")
	ok = call(p, "BrandSet", "badword bakery", 1); clock += 3
	expect(not ok and d.settings.brandName == "Sweet Dreams", "filtered name refused, old name kept")
	ok = call(p, "BrandSet", 42, 1); clock += 3
	expect(not ok, "non-string refused")
	ok = call(p, "BrandSet", "  Spaced    Out  ", 2); clock += 3
	expect(ok and d.settings.brandName == "Spaced Out", "whitespace tidied: " .. tostring(d.settings.brandName))
	config.filterFail = true
	ok, msg = call(p, "BrandSet", "Offline Name", 2); clock += 3
	expect(not ok and d.settings.brandName == "Spaced Out", "filter outage: refused, nothing saved")
	config.filterFail = nil

	-- schema hardening
	local dirty = Schema.sanitize({ schemaVersion = 2, settings = { textScale = 9, sfx = "loud", brandName = "<script>", brandColor = 99 } })
	expect(dirty.settings.textScale == 1 and dirty.settings.sfx == 0.6 and dirty.settings.brandName == "" and dirty.settings.brandColor == 5, "bad saved settings are repaired")

	S.PlayerDataService:SaveNow(p); leave(p); settle()
	local p2 = newPlayer(111, "Designer"); join(p2)
	expect(state(p2).settings.brandName == "Spaced Out" and state(p2).settings.textScale == 1.5, "settings persist")
	leave(p2)
end
