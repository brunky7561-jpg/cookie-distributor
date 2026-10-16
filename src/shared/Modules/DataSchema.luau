--!strict
-- Saved-data shape, migrations and sanitizing. Pure functions so they can be tested without Roblox.
-- Rules: never trust saved data. Anything missing, mistyped or unknown falls back to a safe default.
local Config = script.Parent.Parent.Config
local Equipment = require(Config.Equipment)
local Ingredients = require(Config.Ingredients)
local Properties = require(Config.Properties)
local Brand = require(Config.Brand)
local Market = require(Config.Market)
local Staff = require(Config.Staff)
local Vehicles = require(Config.Vehicles)
local Recipes = require(Config.Recipes)

local DataSchema = {}

DataSchema.VERSION = 2

local MAX_COUNT = 9999
local MAX_BATCHES = 30

function DataSchema.default(): any
	return {
		schemaVersion = DataSchema.VERSION,
		cash = 250,
		level = 1,
		xp = 0,
		reputation = 0,
		ingredients = { flour = 6, white_sugar = 4, butter = 4, chocolate_chips = 3 }, -- one small batch plus spare
		batches = {},
		recipes = { classic_chip = true, simple_sugar = true },
		recipeBook = {}, -- per recipe: { name, bakes, best, grade, custom }
		properties = { apartment = true },
		vehicles = {},
		contract = false, -- active contract offer or false
		contractNextAt = 0,
		contractWins = 0,
		contractLosses = 0,
		staff = {}, -- hired bakers: { id, recipeId, bakes, progress, status, unpaid }
		equipment = { basic_oven = true, mixing_bowl = true, cooling_rack = true },
		customers = {},
		nextBatchId = 1,
		milestones = {},
		stats = { gross = 0, supplies = 0, wages = 0, delivery = 0, other = 0, orders = 0, walkIn = 0 },
		deliveries = {}, -- paid PantryDash orders not yet collected: { id, items, propertyId, arriveAt }
		nextDeliveryId = 1,
		history = {}, -- last completed orders for the phone
		settings = { guidance = true, effects = true, seenApps = {}, textScale = 1, sfx = 0.6, brandName = "", brandColor = 1 },
	}
end

local function isNumber(v: any): boolean
	return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

local function num(v: any, default: number, lo: number, hi: number): number
	if isNumber(v) then
		return math.clamp(v, lo, hi)
	end
	return default
end

local function int(v: any, default: number, lo: number, hi: number): number
	return math.floor(num(v, default, lo, hi))
end

local function boolMap(v: any, allowed: ((string) -> boolean)?): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(v) == "table" then
		for k, val in v do
			if type(k) == "string" and val == true and (allowed == nil or allowed(k)) then
				out[k] = true
			end
		end
	end
	return out
end

local function stringList(v: any, maxLen: number): { string }
	local out: { string } = {}
	if type(v) == "table" then
		for _, s in v do
			if type(s) == "string" and #s <= 40 and #out < maxLen then
				table.insert(out, s)
			end
		end
	end
	return out
end

local function sanitizeBatch(b: any): any?
	if type(b) ~= "table" or not isNumber(b.id) then
		return nil
	end
	local count = int(b.count, 0, 0, 100)
	if count < 1 then
		return nil
	end
	local quality = num(b.quality, 0.5, 0, 1)
	return {
		id = int(b.id, 0, 0, 2 ^ 31),
		name = if type(b.name) == "string" then string.sub(b.name, 1, 40) else "Cookies",
		recipeId = if type(b.recipeId) == "string" then string.sub(b.recipeId, 1, 40) else nil,
		ingredients = stringList(b.ingredients, 20),
		tags = stringList(b.tags, 20),
		quality = quality,
		score = int(b.score, math.floor(quality * 100), 0, 100),
		grade = if type(b.grade) == "string" then string.sub(b.grade, 1, 20) else nil,
		feedback = if type(b.feedback) == "string" then string.sub(b.feedback, 1, 200) else nil,
		factors = if type(b.factors) == "table" then b.factors else nil,
		appeal = int(b.appeal, 0, 0, 100),
		effects = stringList(b.effects, 10),
		count = count,
		packaged = b.packaged == true,
		displayed = b.displayed == true,
		-- reservedFor is intentionally dropped: open orders are not saved, so no box may stay reserved
	}
end

local function sanitizeContract(v: any): any
	if type(v) ~= "table" or type(v.recipeId) ~= "string" or not Recipes.catalog[v.recipeId] then
		return false
	end
	local rival = nil
	for _, r in Market.rivals do
		if r.id == v.rivalId then
			rival = r.id
		end
	end
	if not rival then
		return false
	end
	return {
		rivalId = rival,
		recipeId = v.recipeId,
		count = int(v.count, Market.CONTRACT_COUNT, 1, 100),
		minScore = int(v.minScore, Market.CONTRACT_MIN_SCORE, 0, 100),
		pay = int(v.pay, 100, 0, 1e6),
		expiresAt = int(v.expiresAt, 0, 0, 2 ^ 40),
	}
end

local function sanitizeStaff(v: any): { any }
	local out = {}
	if type(v) == "table" then
		for _, e in v do
			if type(e) == "table" and type(e.id) == "string" and Staff.candidates[e.id] and #out < 3 then
				table.insert(out, {
					id = e.id,
					recipeId = if type(e.recipeId) == "string" and Recipes.catalog[e.recipeId] then e.recipeId else nil,
					bakes = int(e.bakes, 0, 0, 1e6),
					progress = num(e.progress, 0, 0, 1000),
					status = if type(e.status) == "string" then string.sub(e.status, 1, 90) else "Waiting for a recipe.",
					unpaid = e.unpaid == true,
				})
			end
		end
	end
	return out
end

local function sanitizeCustomers(v: any): { [string]: any }
	local out: { [string]: any } = {}
	if type(v) == "table" then
		for id, s in v do
			if type(id) == "string" and #id <= 40 and type(s) == "table" then
				local memory = {}
				if type(s.memory) == "table" then
					for _, m in s.memory do
						if type(m) == "table" and #memory < 5 then
							table.insert(memory, {
								name = if type(m.name) == "string" then string.sub(m.name, 1, 40) else "Cookies",
								quality = num(m.quality, 0.5, 0, 1),
								appeal = int(m.appeal, 0, 0, 100),
								sat = num(m.sat, 0.5, 0, 1),
							})
						end
					end
				end
				out[id] = { rel = int(s.rel, 0, 0, 100000), memory = memory }
			end
		end
	end
	return out
end

local function sanitizeDeliveries(v: any): { any }
	local out = {}
	if type(v) == "table" then
		for _, d in v do
			if type(d) == "table" and type(d.propertyId) == "string" and Properties[d.propertyId] and type(d.items) == "table" and #out < 10 then
				local items: { [string]: number } = {}
				local any = false
				for id, n in d.items do
					if type(id) == "string" and Ingredients[id] and isNumber(n) then
						local count = int(n, 0, 0, 100)
						if count > 0 then
							items[id] = count
							any = true
						end
					end
				end
				if any then
					table.insert(out, { id = int(d.id, 0, 0, 2 ^ 31), items = items, propertyId = d.propertyId, arriveAt = int(d.arriveAt, 0, 0, 2 ^ 40) })
				end
			end
		end
	end
	return out
end

local function sanitizeHistory(v: any): { any }
	local out = {}
	if type(v) == "table" then
		for _, h in v do
			if type(h) == "table" and #out < 10 then
				table.insert(out, {
					customer = if type(h.customer) == "string" then string.sub(h.customer, 1, 30) else "Customer",
					recipe = if type(h.recipe) == "string" then string.sub(h.recipe, 1, 40) else "Cookies",
					pay = int(h.pay, 0, 0, 1e9),
					grade = if type(h.grade) == "string" then string.sub(h.grade, 1, 20) else "",
					t = int(h.t, 0, 0, 2 ^ 40),
				})
			end
		end
	end
	return out
end

local function sanitizeRecipeBook(v: any): { [string]: any }
	local out: { [string]: any } = {}
	local customs = 0
	if type(v) == "table" then
		for key, e in v do
			if type(key) == "string" and type(e) == "table" then
				local custom = Recipes.parseCustomKey(key) ~= nil
				if (Recipes.catalog[key] ~= nil or custom) and (not custom or customs < Recipes.MAX_CUSTOM) then
					if custom then
						customs += 1
					end
					out[key] = {
						name = if type(e.name) == "string" then string.sub(e.name, 1, 60) else key,
						bakes = int(e.bakes, 0, 0, 100000),
						best = int(e.best, 0, 0, 100),
						grade = if type(e.grade) == "string" then string.sub(e.grade, 1, 20) else "",
						custom = custom,
					}
				end
			end
		end
	end
	return out
end

-- Brings data from any older version up to VERSION. Unknown future versions are not handled here.
function DataSchema.migrate(raw: any): any
	if type(raw) ~= "table" then
		return DataSchema.default()
	end
	local from = if isNumber(raw.schemaVersion) then raw.schemaVersion else 1
	if from < 2 then
		-- v1 (milestones 0 and 1): no equipment, stats, settings or reputation; recipe names instead of ids
		raw.equipment = raw.equipment or { basic_oven = true, mixing_bowl = true, cooling_rack = true }
		raw.stats = raw.stats or { gross = 0, supplies = 0, wages = 0, delivery = 0, other = 0, orders = 0, walkIn = 0 }
		raw.settings = raw.settings or {}
		raw.reputation = raw.reputation or 0
		raw.recipes = { classic_chip = true, simple_sugar = true }
	end
	raw.schemaVersion = DataSchema.VERSION
	return raw
end

-- Returns a fresh, fully valid table built only from fields we know about.
function DataSchema.sanitize(raw: any): any
	local d = DataSchema.default()
	if type(raw) ~= "table" then
		return d
	end

	d.cash = num(raw.cash, d.cash, 0, 1e9)
	d.level = int(raw.level, 1, 1, 1000)
	d.xp = int(raw.xp, 0, 0, 1e9)
	d.reputation = int(raw.reputation, 0, 0, 1e9)
	d.nextBatchId = int(raw.nextBatchId, 1, 1, 2 ^ 31)

	if type(raw.ingredients) == "table" then
		local ing: { [string]: number } = {}
		for id, n in raw.ingredients do
			if type(id) == "string" and Ingredients[id] and isNumber(n) then
				local count = int(n, 0, 0, MAX_COUNT)
				if count > 0 then
					ing[id] = count
				end
			end
		end
		d.ingredients = ing
	end

	local batches = {}
	if type(raw.batches) == "table" then
		for _, b in raw.batches do
			local clean = sanitizeBatch(b)
			if clean and #batches < MAX_BATCHES then
				table.insert(batches, clean)
				d.nextBatchId = math.max(d.nextBatchId, clean.id + 1)
			end
		end
	end
	d.batches = batches

	d.recipes = boolMap(raw.recipes, function(id)
		return Recipes.catalog[id] ~= nil
	end)
	d.recipes.classic_chip = true -- the starter recipes can never be lost
	d.recipes.simple_sugar = true
	d.recipeBook = sanitizeRecipeBook(raw.recipeBook)
	d.properties = boolMap(raw.properties, function(id)
		return Properties[id] ~= nil
	end)
	d.properties.apartment = true
	d.equipment = boolMap(raw.equipment, function(id)
		return Equipment.catalog[id] ~= nil
	end)
	for _, id in Equipment.starter do
		d.equipment[id] = true
	end
	d.milestones = boolMap(raw.milestones)
	d.customers = sanitizeCustomers(raw.customers)

	local stats = if type(raw.stats) == "table" then raw.stats else {}
	for k in d.stats do
		d.stats[k] = int(stats[k], 0, 0, 1e12)
	end
	local settings = if type(raw.settings) == "table" then raw.settings else {}
	d.settings.guidance = settings.guidance ~= false
	d.settings.effects = settings.effects ~= false
	d.settings.seenApps = boolMap(settings.seenApps)
	d.settings.textScale = if table.find(Brand.TEXT_SCALES, settings.textScale) then settings.textScale else 1
	d.settings.sfx = num(settings.sfx, 0.6, 0, 1)
	d.settings.brandName = Brand.cleanName(settings.brandName) or ""
	d.settings.brandColor = int(settings.brandColor, 1, 1, #Brand.COLORS)
	d.deliveries = sanitizeDeliveries(raw.deliveries)
	d.nextDeliveryId = int(raw.nextDeliveryId, 1, 1, 2 ^ 31)
	for _, dl in d.deliveries do
		d.nextDeliveryId = math.max(d.nextDeliveryId, dl.id + 1)
	end
	d.history = sanitizeHistory(raw.history)
	d.contract = sanitizeContract(raw.contract)
	d.contractNextAt = int(raw.contractNextAt, 0, 0, 2 ^ 40)
	d.contractWins = int(raw.contractWins, 0, 0, 1e9)
	d.contractLosses = int(raw.contractLosses, 0, 0, 1e9)
	d.staff = sanitizeStaff(raw.staff)
	d.vehicles = boolMap(raw.vehicles, function(id)
		return Vehicles.catalog[id] ~= nil
	end)
	return d
end

return DataSchema
