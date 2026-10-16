--!strict
-- PantryDash: build a cart, pick a property, review subtotal, fee, ETA and storage, then order.
-- The same DeliveryMath the server uses draws the preview, so what you see is what the server will charge.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)
local Properties = require(ReplicatedStorage.Shared.Config.Properties)
local DeliveryMath = require(ReplicatedStorage.Shared.Modules.DeliveryMath)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local UI = require(script.Parent.Parent.Modules.UI)

local Theme = UI.Theme

local cart: { [string]: number } = {}
local destination = "apartment"

local PantryDash = {}
PantryDash.id = "pantrydash"

local function sortedIngredientIds(): { string }
	local ids = {}
	for id in Ingredients do
		table.insert(ids, id)
	end
	table.sort(ids, function(a: string, b: string)
		local ca: number, cb: number = Ingredients[a].cost, Ingredients[b].cost
		if ca ~= cb then
			return ca < cb
		end
		return a < b
	end)
	return ids
end

function PantryDash.render(ctx: any)
	local content = ctx.content
	local state = ctx.state

	-- destination: owned properties that can receive deliveries
	local ownedIds = {}
	for id in state.properties do
		local def = Properties[id]
		if def and def.receivingName then
			table.insert(ownedIds, id)
		end
	end
	table.sort(ownedIds)
	if not state.properties[destination] and #ownedIds > 0 then
		destination = ownedIds[1]
	end

	local summary = UI.card(content, Theme.Butter)
	local capacity = DeliveryMath.capacity(state)
	UI.label(summary, `Storage: {DeliveryMath.units(state)} / {capacity} items (including deliveries on the way)`, { size = 13 })

	for _, id in ownedIds do
		local def = Properties[id]
		UI.button(summary, `{if id == destination then "> " else ""}Deliver to: {def.name}`, if id == destination then Theme.Mint else Theme.Buttercream, function()
			destination = id
			ctx.rerender()
		end)
	end

	-- pending deliveries
	for _, d in state.deliveries do
		local left = d.arriveAt - os.time()
		local text = if left > 0 then `Arriving in {left}s` else "Arrived: collect the crate at your delivery mat"
		UI.label(summary, `Delivery #{d.id}: {text}`, { size = 13, bold = true })
	end

	-- cart
	for _, id in sortedIngredientIds() do
		local ing = Ingredients[id]
		local locked = table.find(ing.tags, "rare") ~= nil and state.level < DeliveryMath.RARE_UNLOCK_LEVEL
		local row = UI.row(content, 48)
		local name = UI.label(row, `{ing.name}  ${ing.cost}\nhave {state.ingredients[id] or 0}`, { size = 14 })
		name.Size = UDim2.new(0.5, 0, 0, 0)
		if locked then
			name.Text = `{ing.name}  ${ing.cost}\nunlocks at level {DeliveryMath.RARE_UNLOCK_LEVEL}`
		else
			local minus = UI.button(row, "-", Theme.Buttercream, function()
				local n = (cart[id] or 0) - 1
				cart[id] = if n > 0 then n else nil
				ctx.rerender()
			end)
			minus.Size = UDim2.fromOffset(44, 44)
			local qty = UI.label(row, tostring(cart[id] or 0), { bold = true, align = Enum.TextXAlignment.Center })
			qty.Size = UDim2.fromOffset(34, 44)
			local plus = UI.button(row, "+", Theme.Butter, function()
				cart[id] = math.min(DeliveryMath.MAX_QTY_PER_ITEM, (cart[id] or 0) + 1)
				ctx.rerender()
			end)
			plus.Size = UDim2.fromOffset(44, 44)
		end
	end

	-- quote
	local box = UI.card(content, Theme.Buttercream)
	local clean = DeliveryMath.normalize(cart)
	if not clean then
		UI.label(box, "Add items to see your total. Orders over $" .. DeliveryMath.FREE_DELIVERY_FROM .. " ship free; smaller ones pay a $" .. DeliveryMath.FEE .. " fee.", { size = 14 })
		return
	end
	local subtotal = DeliveryMath.subtotal(clean)
	UI.label(box, `Subtotal: ${subtotal}`)
	UI.label(box, `Delivery fee: ${DeliveryMath.fee(subtotal, state.vehicles)}`)
	UI.label(box, `Total: ${subtotal + DeliveryMath.fee(subtotal, state.vehicles)}   |   Cash now: ${math.floor(state.cash)}`, { bold = true })
	UI.label(box, `Arrives in about {DeliveryMath.eta(state.vehicles)} seconds at your delivery mat.`, { size = 13 })
	local quote, err = DeliveryMath.quote(state, clean, destination)
	if not quote then
		UI.label(box, tostring(err), { bold = true, color = Theme.Coral })
		UI.button(box, "Can't order yet", Color3.fromRGB(200, 192, 176))
		return
	end
	UI.label(box, `Cash after: ${math.floor(quote.cashAfter)}   |   Storage after: {quote.unitsAfter} / {quote.capacity}`, { size = 13 })
	UI.button(box, `Order delivery (${quote.total})`, Theme.Mint, function()
		local ok, res = Remotes.func("PantryOrder"):InvokeServer(clean, destination)
		if ok then
			table.clear(cart)
			ctx.say("Order placed! The courier is on the way.")
		else
			ctx.say(tostring(res))
		end
		ctx.rerender()
	end)
end

return PantryDash
