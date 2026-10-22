--!strict
-- PantryDash rules in one pure place: the client uses it for the live preview, the server uses it to authorize.
local Config = script.Parent.Parent.Config
local Ingredients = require(Config.Ingredients)
local Properties = require(Config.Properties)
local Vehicles = require(Config.Vehicles)

local DeliveryMath = {}

DeliveryMath.ETA = 15 -- seconds until the courier arrives
DeliveryMath.FEE = 10
DeliveryMath.FREE_DELIVERY_FROM = 150
DeliveryMath.MAX_QTY_PER_ITEM = 50
DeliveryMath.MAX_UNITS_PER_ORDER = 60
DeliveryMath.MAX_PENDING = 5
DeliveryMath.RARE_UNLOCK_LEVEL = 5

function DeliveryMath.eta(vehicles: { [string]: boolean }?): number
	local mult = Vehicles.deliveryPerks(vehicles or {})
	return math.max(4, math.floor(DeliveryMath.ETA * mult + 0.5))
end

function DeliveryMath.subtotal(items: { [string]: number }): number
	local total = 0
	for id, n in items do
		total += Ingredients[id].cost * n
	end
	return total
end

function DeliveryMath.fee(subtotal: number, vehicles: { [string]: boolean }?): number
	local _, free = Vehicles.deliveryPerks(vehicles or {})
	if free or subtotal <= 0 or subtotal >= DeliveryMath.FREE_DELIVERY_FROM then
		return 0
	end
	return DeliveryMath.FEE
end

-- Ingredient capacity: the sum of storage over owned properties.
function DeliveryMath.capacity(data: any): number
	local cap = 0
	for id in data.properties do
		local def = Properties[id]
		if def then
			cap += def.storage
		end
	end
	return cap
end

-- Units on hand plus units already paid for and still on their way.
function DeliveryMath.units(data: any): number
	local n = 0
	for _, count in data.ingredients do
		n += count
	end
	for _, d in data.deliveries do
		for _, count in d.items do
			n += count
		end
	end
	return n
end

-- Accepts either { {id=, qty=}, ... } or { [id] = qty }. Returns a clean { [id] = qty } map, or nil plus a reason.
function DeliveryMath.normalize(raw: any): ({ [string]: number }?, string?)
	if type(raw) ~= "table" then
		return nil, "your cart is empty"
	end
	local out: { [string]: number } = {}
	local function add(id: any, qty: any): string?
		if type(id) ~= "string" or not Ingredients[id] then
			return "unknown ingredient"
		end
		if type(qty) ~= "number" or qty ~= qty or qty < 1 or qty > DeliveryMath.MAX_QTY_PER_ITEM or math.floor(qty) ~= qty then
			return "quantities must be whole numbers from 1 to 50"
		end
		out[id] = (out[id] or 0) + qty
		return nil
	end
	local count = 0
	for k, v in raw do
		count += 1
		if count > 30 then
			return nil, "too many items"
		end
		local err
		if type(v) == "table" then
			err = add(v.id, v.qty)
		else
			err = add(k, v)
		end
		if err then
			return nil, err
		end
	end
	local units = 0
	for id, qty in out do
		if qty > DeliveryMath.MAX_QTY_PER_ITEM then
			return nil, "quantities must be whole numbers from 1 to 50"
		end
		units += qty
	end
	if units == 0 then
		return nil, "your cart is empty"
	end
	if units > DeliveryMath.MAX_UNITS_PER_ORDER then
		return nil, `one delivery can carry up to {DeliveryMath.MAX_UNITS_PER_ORDER} items`
	end
	return out, nil
end

export type Quote = {
	items: { [string]: number },
	propertyId: string,
	subtotal: number,
	fee: number,
	total: number,
	eta: number,
	cashAfter: number,
	unitsAfter: number,
	capacity: number,
}

-- Full check against saved data. Returns a quote, or nil plus a message the player can act on.
function DeliveryMath.quote(data: any, items: { [string]: number }, propertyId: any): (Quote?, string?)
	local def = if type(propertyId) == "string" then Properties[propertyId] else nil
	if not def or not data.properties[def.id] or not def.receivingName then
		return nil, "pick one of your properties to receive the delivery"
	end
	if #data.deliveries >= DeliveryMath.MAX_PENDING then
		return nil, "you have several deliveries waiting; collect a crate first"
	end
	for id in items do
		if table.find(Ingredients[id].tags, "rare") and data.level < DeliveryMath.RARE_UNLOCK_LEVEL then
			return nil, `{Ingredients[id].name} unlocks at level {DeliveryMath.RARE_UNLOCK_LEVEL}`
		end
	end
	local added = 0
	for _, n in items do
		added += n
	end
	local capacity = DeliveryMath.capacity(data)
	local unitsAfter = DeliveryMath.units(data) + added
	if unitsAfter > capacity then
		return nil, `Not enough storage: this would make {unitsAfter} items but you can hold {capacity}.`
	end
	local subtotal = DeliveryMath.subtotal(items)
	local fee = DeliveryMath.fee(subtotal, data.vehicles)
	local total = subtotal + fee
	if data.cash < total then
		return nil, `You need ${total} but have ${math.floor(data.cash)}.`
	end
	return {
		items = items,
		propertyId = def.id,
		subtotal = subtotal,
		fee = fee,
		total = total,
		eta = DeliveryMath.eta(data.vehicles),
		cashAfter = data.cash - total,
		unitsAfter = unitsAfter,
		capacity = capacity,
	},
		nil
end

return DeliveryMath
