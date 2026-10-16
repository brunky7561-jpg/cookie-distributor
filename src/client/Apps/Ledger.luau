--!strict
-- Ledger: gross income, supply cost, wages, delivery cost and net profit, always shown separately.
local UI = require(script.Parent.Parent.Modules.UI)

local Theme = UI.Theme

local Ledger = {}
Ledger.id = "ledger"

function Ledger.render(ctx: any)
	local s = ctx.state.stats
	local costs = s.supplies + s.wages + s.delivery + s.other
	local net = s.gross - costs
	local card = UI.card(ctx.content)
	UI.label(card, "Business summary", { bold = true, size = 17 })
	UI.label(card, `Orders completed: {s.orders}`)
	UI.label(card, `Gross income: ${s.gross}`)
	UI.label(card, `Ingredient costs: ${s.supplies}`)
	UI.label(card, `Delivery fees: ${s.delivery}`)
	UI.label(card, `Wages: ${s.wages}`)
	UI.label(card, `Equipment and other: ${s.other}`)
	UI.label(card, `Net profit: {if net < 0 then "-" else ""}${math.abs(net)}`, { bold = true, size = 17, color = if net < 0 then Theme.Coral else Theme.Cocoa })
	UI.label(ctx.content, "Cash on hand is separate: it also includes your starting $250.", { size = 13 })
end

return Ledger
