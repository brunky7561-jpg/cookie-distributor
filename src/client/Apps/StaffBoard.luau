--!strict
-- StaffBoard: hire bakers, choose what they bake, and read exactly why each one is working or waiting.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local Staff = require(ReplicatedStorage.Shared.Config.Staff)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local UI = require(script.Parent.Parent.Modules.UI)

local Theme = UI.Theme
local picking: string? = nil -- staff id whose recipe list is open

local StaffBoard = {}
StaffBoard.id = "staffboard"

function StaffBoard.render(ctx: any)
	local state = ctx.state
	UI.label(ctx.content, `Cash: ${math.floor(state.cash)}   Staff {#state.staff}`, { bold = true })
	UI.label(ctx.content, "Each extra oven (Food Truck or bigger) fits one baker. Wages are paid every 10 minutes.", { size = 13 })

	UI.label(ctx.content, "Your team", { bold = true, size = 18 })
	if #state.staff == 0 then
		UI.label(ctx.content, "Nobody yet. Hire someone below.", { size = 13 })
	end
	for _, e in state.staff do
		local c = Staff.candidates[e.id]
		local card = UI.card(ctx.content, Theme.Mint)
		UI.label(card, `{c.name}  (skill {c.skill + (if e.bakes >= Staff.PROMOTE_EVERY then 1 else 0)}, {e.bakes} bakes)`, { bold = true })
		UI.label(card, e.status, { size = 13, color = if e.unpaid then Theme.Coral else nil })
		UI.label(card, `Bakes: {if e.recipeId then Recipes.catalog[e.recipeId].name else "nothing yet"}`, { size = 13 })
		if picking == e.id then
			local ids: { string } = {}
			for rid in Recipes.catalog do
				if state.recipes[rid] then
					table.insert(ids, rid)
				end
			end
			table.sort(ids)
			for _, rid in ids do
				do
					UI.button(card, Recipes.catalog[rid].name, nil, function()
						picking = nil
						local ok, msg = Remotes.func("StaffAssign"):InvokeServer(e.id, rid)
						ctx.say(tostring(msg))
						ctx.rerender()
						return ok
					end)
				end
			end
		else
			UI.button(card, "Choose recipe", Theme.Butter, function()
				picking = e.id
				ctx.rerender()
			end)
		end
		UI.button(card, "Let go", Theme.Coral, function()
			local _, msg = Remotes.func("StaffFire"):InvokeServer(e.id)
			ctx.say(tostring(msg))
			ctx.rerender()
		end)
	end

	UI.label(ctx.content, "Hire", { bold = true, size = 18 })
	for _, id in Staff.order do
		local c = Staff.candidates[id]
		local hired = false
		for _, e in state.staff do
			if e.id == id then
				hired = true
			end
		end
		if not hired then
			local card = UI.card(ctx.content)
			UI.label(card, `{c.name}  skill {c.skill}  wage ${c.wage}/day`, { bold = true })
			UI.label(card, `{c.blurb} One batch every {c.cycle}s.`, { size = 13 })
			UI.button(card, `Hire for ${c.wage}`, Theme.Butter, function()
				local ok, msg = Remotes.func("StaffHire"):InvokeServer(id)
				ctx.say(tostring(msg))
				ctx.rerender()
				return ok
			end)
		end
	end
end

return StaffBoard
