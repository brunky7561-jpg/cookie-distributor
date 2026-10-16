--!strict
-- PropertyDesk: browse properties, preview what they give you, confirm the purchase, and manage the display case.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Properties = require(ReplicatedStorage.Shared.Config.Properties)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local UI = require(script.Parent.Parent.Modules.UI)

local Theme = UI.Theme
local previewing: string? = nil

local PropertyDesk = {}
PropertyDesk.id = "propertydesk"

function PropertyDesk.render(ctx: any)
	local state = ctx.state
	UI.label(ctx.content, `Cash: ${math.floor(state.cash)}   Level {state.level}`, { bold = true })

	local list: { any } = {}
	for _, def in Properties do
		table.insert(list, def)
	end
	table.sort(list, function(a: any, b: any)
		return a.price < b.price
	end)

	local slots = 0
	for _, def in list do
		local owned = state.properties[def.id] == true
		local card = UI.card(ctx.content, if owned then Theme.Mint else Theme.Buttercream)
		UI.label(card, def.name .. (if owned then "  (owned)" else ""), { bold = true })
		UI.label(card, def.blurb or "", { size = 13 })
		UI.label(card, `Storage {def.storage}   Display slots {def.display or 0}   Rent ${def.dailyCost}/day`, { size = 13 })
		if owned then
			slots += def.display or 0
		elseif (def.unlockLevel or 1) > state.level then
			UI.label(card, `Reach level {def.unlockLevel} to buy.`, { size = 13, color = Theme.Coral })
		elseif previewing == def.id then
			local after = state.cash - def.price
			UI.label(card, `Price ${def.price}. Cash after: ${math.floor(after)}.`, { bold = true, size = 14 })
			if after < 0 then
				UI.label(card, `You need ${math.ceil(-after)} more.`, { size = 13, color = Theme.Coral })
			else
				UI.button(card, "Confirm purchase", Theme.Butter, function()
					local ok, msg = Remotes.func("PropertyBuy"):InvokeServer(def.id)
					previewing = nil
					ctx.say(tostring(msg))
					ctx.rerender()
					return ok
				end)
			end
			UI.button(card, "Cancel", nil, function()
				previewing = nil
				ctx.rerender()
			end)
		else
			UI.button(card, `Preview (${def.price})`, nil, function()
				previewing = def.id
				ctx.rerender()
			end)
		end
	end

	UI.label(ctx.content, "Display case", { bold = true, size = 18 })
	if slots == 0 then
		UI.label(ctx.content, "Buy a Food Truck or bigger to sell to walk-in customers. They pay less than custom orders, but it is passive income.", { size = 13 })
		return
	end
	local used = 0
	for _, b in state.batches do
		if b.displayed then
			used += 1
		end
	end
	UI.label(ctx.content, `{used} / {slots} slots used. Walk-in rounds happen every 20 seconds.`, { size = 13 })
	for _, b in state.batches do
		local card = UI.card(ctx.content, if b.displayed then Theme.Mint else Theme.Buttercream)
		UI.label(card, `{b.name}  x{b.count}  ({b.grade or "?"})`, { bold = true, size = 14 })
		if b.reservedFor then
			UI.label(card, "Promised to an order", { size = 13 })
		else
			UI.button(card, if b.displayed then "Take off display" else "Put on display", nil, function()
				local ok, msg = Remotes.func("DisplaySet"):InvokeServer(b.id, not b.displayed)
				ctx.say(tostring(msg))
				ctx.rerender()
				return ok
			end)
		end
	end
end

return PropertyDesk
