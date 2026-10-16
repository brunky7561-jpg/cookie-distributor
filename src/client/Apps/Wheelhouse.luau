--!strict
-- Wheelhouse: buy vehicles and spawn the one you own. Vehicles speed up PantryDash couriers; walking always works.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local UI = require(script.Parent.Parent.Modules.UI)

local Theme = UI.Theme

local Wheelhouse = {}
Wheelhouse.id = "wheelhouse"

function Wheelhouse.render(ctx: any)
	local state = ctx.state
	UI.label(ctx.content, `Cash: ${math.floor(state.cash)}   Level {state.level}`, { bold = true })
	UI.label(ctx.content, "Drive with W/A/S/D from the driver seat. Owning a vehicle also speeds up ingredient deliveries.", { size = 13 })
	for _, id in Vehicles.order do
		local def = Vehicles.catalog[id]
		local owned = state.vehicles[id] == true
		local card = UI.card(ctx.content, if owned then Theme.Mint else Theme.Buttercream)
		UI.label(card, def.name .. (if owned then "  (owned)" else ""), { bold = true })
		UI.label(card, def.blurb, { size = 13 })
		if owned then
			UI.button(card, "Spawn it near me", Theme.Butter, function()
				local ok, msg = Remotes.func("VehicleSpawn"):InvokeServer(id)
				ctx.say(tostring(msg))
				return ok
			end)
		elseif state.level < def.unlockLevel then
			UI.label(card, `Reach level {def.unlockLevel} to buy.`, { size = 13, color = Theme.Coral })
		elseif state.cash < def.price then
			UI.label(card, `Costs ${def.price}. You need ${math.ceil(def.price - state.cash)} more.`, { size = 13, color = Theme.Coral })
		else
			UI.button(card, `Buy for ${def.price}`, Theme.Butter, function()
				local ok, msg = Remotes.func("VehicleBuy"):InvokeServer(id)
				ctx.say(tostring(msg))
				ctx.rerender()
				return ok
			end)
		end
	end
	if next(state.vehicles) then
		UI.button(ctx.content, "Put my vehicle away", nil, function()
			Remotes.func("VehicleRemove"):InvokeServer()
		end)
	end
end

return Wheelhouse
