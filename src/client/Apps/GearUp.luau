--!strict
-- GearUp: equipment by category, what you own, what the next tier does, and a validated Buy button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local UI = require(script.Parent.Parent.Modules.UI)

local Theme = UI.Theme
local CATEGORIES = { "Baking", "Mixing", "Cooling" }

local GearUp = {}
GearUp.id = "gearup"

function GearUp.render(ctx: any)
	local state = ctx.state
	UI.label(ctx.content, `Cash: ${math.floor(state.cash)}`, { bold = true })

	for _, category in CATEGORIES do
		local items: { any } = {}
		for _, def in Equipment.catalog do
			if def.category == category then
				table.insert(items, def)
			end
		end
		table.sort(items, function(a: any, b: any)
			return a.tier < b.tier
		end)

		UI.label(ctx.content, category, { bold = true, size = 18 })
		for _, def in items do
			local card = UI.card(ctx.content, if state.equipment[def.id] then Theme.Mint else Theme.Buttercream)
			UI.label(card, `{def.name}  (tier {def.tier})`, { bold = true })
			UI.label(card, def.description, { size = 13 })
			if state.equipment[def.id] then
				UI.label(card, "Owned", { bold = true, size = 13 })
			elseif def.price <= 0 then
				UI.label(card, "Not for sale", { size = 13 })
			elseif def.requiresMilestone and not state.milestones[def.requiresMilestone] then
				UI.label(card, "Locked: deliver your first order", { size = 13, color = Theme.Coral })
			elseif state.cash < def.price then
				UI.label(card, `Costs ${def.price}. You need ${math.ceil(def.price - state.cash)} more.`, { size = 13, color = Theme.Coral })
			else
				UI.button(card, `Buy for ${def.price}`, Theme.Butter, function()
					local ok, res = Remotes.func("BuyEquipment"):InvokeServer(def.id)
					ctx.say(tostring(res))
					ctx.rerender()
					return ok
				end)
			end
		end
	end
end

return GearUp
