--!strict
-- Recipes are built from slots on top of a fixed dough: flavor (required), mix-in and finish (optional).
-- Named recipes are known combinations of those slots. Any other valid combination is an experiment ("House Special").
local Types = require(script.Parent.Parent.Modules.Types)

local Recipes = {}

Recipes.synergies = {
	{ a = "chocolate", b = "salty", multiplier = 1.3 },
	{ a = "energy", b = "sweet", multiplier = 1.2 },
} :: { Types.Synergy }

Recipes.base = { flour = 2, butter = 1 } :: { [string]: number }

Recipes.slots = {
	flavor = { required = true, options = { "white_sugar", "brown_sugar", "caramel", "golden_honey" } },
	mixin = { required = false, options = { "chocolate_chips" } },
	finish = { required = false, options = { "sea_salt", "espresso_powder" } },
} :: { [string]: { required: boolean, options: { string } } }

Recipes.slotOrder = { "flavor", "mixin", "finish" }

Recipes.boxes = {
	{ id = "small", name = "Small box", size = 3 },
	{ id = "standard", name = "Standard box", size = 6 },
	{ id = "large", name = "Large box", size = 12 },
} :: { Types.BoxDef }

Recipes.YIELD = 6
Recipes.SELL_PRICE = 15 -- what one Classic Chip cookie is worth to a typical customer (priceMult scales it for other recipes)
Recipes.CUSTOM_CORRECTNESS = { 0.85, 0.92, 1 } -- recipe correctness after 0, 1, 2+ earlier bakes of the same experiment
Recipes.MAX_CUSTOM = 8

-- slots: { flavor: string?, mixin: string?, finish: string? }  ->  ingredient requirements
function Recipes.requiresFor(slots: { [string]: string }): { [string]: number }
	local out: { [string]: number } = table.clone(Recipes.base)
	for _, slot in Recipes.slotOrder do
		local id = slots[slot]
		if id then
			out[id] = (out[id] or 0) + 1
		end
	end
	return out
end

-- { flour = 2, butter = 1 } -> { "butter", "flour", "flour" } (sorted, for Appeal and tags)
function Recipes.expand(requires: { [string]: number }, times: number?): { string }
	local list = {}
	for id, n in requires do
		for _ = 1, n * (times or 1) do
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

function Recipes.keyFor(slots: { [string]: string }): string
	local parts = {}
	for _, slot in Recipes.slotOrder do
		table.insert(parts, slots[slot] or "-")
	end
	return table.concat(parts, "|")
end

-- Returns a clean slots table, or nil plus the reason it was refused.
function Recipes.validateSlots(raw: any): ({ [string]: string }?, string?)
	if type(raw) ~= "table" then
		return nil, "pick a flavor"
	end
	local out: { [string]: string } = {}
	for _, slot in Recipes.slotOrder do
		local def = Recipes.slots[slot]
		local id = raw[slot]
		if id == nil or id == "" then
			if def.required then
				return nil, `pick a {slot}`
			end
		elseif type(id) ~= "string" or not table.find(def.options, id) then
			return nil, `{tostring(id)} does not fit the {slot} slot`
		else
			out[slot] = id
		end
	end
	return out, nil
end

-- "custom:" keys come back from saved data; only well-formed ones survive.
function Recipes.parseCustomKey(key: any): { [string]: string }?
	if type(key) ~= "string" or string.sub(key, 1, 7) ~= "custom:" then
		return nil
	end
	local parts = string.split(string.sub(key, 8), "|")
	if #parts ~= #Recipes.slotOrder then
		return nil
	end
	local raw: { [string]: string } = {}
	for i, slot in Recipes.slotOrder do
		if parts[i] ~= "-" then
			raw[slot] = parts[i]
		end
	end
	local slots = Recipes.validateSlots(raw)
	return slots
end

Recipes.names = {
	white_sugar = "Sugar",
	brown_sugar = "Brown Sugar",
	caramel = "Caramel",
	golden_honey = "Golden Honey",
	chocolate_chips = "Chocolate",
	sea_salt = "Sea Salt",
	espresso_powder = "Espresso",
} :: { [string]: string }

function Recipes.customName(slots: { [string]: string }): string
	local parts = {}
	for _, slot in Recipes.slotOrder do
		local id = slots[slot]
		if id then
			table.insert(parts, Recipes.names[id] or id)
		end
	end
	return "House Special: " .. table.concat(parts, " + ")
end

local function def(id: string, name: string, slots: { [string]: string }, unlockLevel: number, priceMult: number, blurb: string): Types.RecipeDef
	return {
		id = id,
		name = name,
		yield = Recipes.YIELD,
		slots = slots,
		requires = Recipes.requiresFor(slots),
		unlockLevel = unlockLevel,
		priceMult = priceMult,
		blurb = blurb,
	}
end

Recipes.catalog = {
	simple_sugar = def("simple_sugar", "Simple Sugar Cookies", { flavor = "white_sugar" }, 1, 0.8, "Cheap and quick. Good for bargain shoppers."),
	classic_chip = def("classic_chip", "Classic Chip Cookies", { flavor = "white_sugar", mixin = "chocolate_chips" }, 1, 1, "Everyone's favorite. A safe bet."),
	brown_sugar_chunk = def("brown_sugar_chunk", "Brown Sugar Chunk", { flavor = "brown_sugar", mixin = "chocolate_chips" }, 2, 1.15, "Chewier and richer than the classic."),
	salted_chunk = def("salted_chunk", "Salted Chocolate Chunk", { flavor = "brown_sugar", mixin = "chocolate_chips", finish = "sea_salt" }, 3, 1.4, "Chocolate and salt are a famous pair. Foodies love it."),
	caramel_crunch = def("caramel_crunch", "Caramel Espresso Crunch", { flavor = "caramel", mixin = "chocolate_chips", finish = "espresso_powder" }, 4, 2.2, "Bold and expensive. Impresses critics, overwhelms the shy."),
	golden_honey = def("golden_honey", "Golden Honey Chip", { flavor = "golden_honey", mixin = "chocolate_chips" }, 6, 4.5, "A premium treat made with rare golden honey."),
} :: { [string]: Types.RecipeDef }

-- A named recipe that exactly matches these slots, if any.
function Recipes.matchCatalog(slots: { [string]: string }): Types.RecipeDef?
	local key = Recipes.keyFor(slots)
	for _, r in Recipes.catalog do
		if Recipes.keyFor(r.slots) == key then
			return r
		end
	end
	return nil
end

return Recipes
