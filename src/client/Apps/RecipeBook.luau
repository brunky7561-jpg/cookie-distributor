--!strict
-- Recipe Book: everything you can bake, what it costs, how it fits customers, and your best result.
-- Locked recipes show only how to unlock them, so experimenting at the oven still feels like discovery.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AppealCalc = require(ReplicatedStorage.Shared.Modules.AppealCalc)
local Customers = require(ReplicatedStorage.Shared.Config.Customers)
local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local UI = require(script.Parent.Parent.Modules.UI)

local Theme = UI.Theme

local RecipeBook = {}
RecipeBook.id = "recipebook"

local function costOf(requires: { [string]: number }): number
	local total = 0
	for id, n in requires do
		total += Ingredients[id].cost * n
	end
	return total
end

local function tagsOf(requires: { [string]: number }): { string }
	local set: { [string]: boolean } = {}
	for id in requires do
		for _, t in Ingredients[id].tags do
			set[t] = true
		end
	end
	local list = {}
	for t in set do
		table.insert(list, t)
	end
	table.sort(list)
	return list
end

-- Customers who love something in this recipe and whose taste in Appeal fits it.
local function fans(tags: { string }, appeal: number): string
	local names = {}
	for _, c in Customers do
		local loves, hates = false, false
		for _, t in tags do
			if table.find(c.loves, t) then
				loves = true
			end
			if table.find(c.hates, t) then
				hates = true
			end
		end
		if loves and not hates and appeal >= c.appealMin - 8 and appeal <= c.appealMax + 8 then
			table.insert(names, c.name)
		end
	end
	return if #names > 0 then table.concat(names, ", ") else "no one in particular yet"
end

local function ingredientLine(state: any, requires: { [string]: number }): string
	local ids: { string } = {}
	for id in requires do
		table.insert(ids, id)
	end
	table.sort(ids)
	local parts = {}
	for _, id in ids do
		table.insert(parts, `{requires[id]}x {Ingredients[id].name} (have {state.ingredients[id] or 0})`)
	end
	return table.concat(parts, ", ")
end

local function recipeCard(ctx: any, name: string, requires: { [string]: number }, extra: string, entry: any?, blurb: string?)
	local state = ctx.state
	local card = UI.card(ctx.content)
	UI.label(card, name, { bold = true, size = 16 })
	if blurb then
		UI.label(card, blurb, { size = 13 })
	end
	UI.label(card, ingredientLine(state, requires), { size = 13 })
	local appeal = AppealCalc.compute(Recipes.expand(requires), 0.9).score
	local tags = tagsOf(requires)
	UI.label(card, `Cost about ${costOf(requires)}  |  Appeal about {appeal}  |  Tags: {table.concat(tags, ", ")}`, { size = 13 })
	UI.label(card, `Customers who like it: {fans(tags, appeal)}`, { size = 13 })
	if entry and entry.bakes > 0 then
		UI.label(card, `Best: {entry.best}/100 ({entry.grade})  |  Baked {entry.bakes} time{if entry.bakes == 1 then "" else "s"}`, { size = 13, bold = true })
	else
		UI.label(card, "Not baked yet", { size = 13 })
	end
	if extra ~= "" then
		UI.label(card, extra, { size = 13, color = Theme.Cocoa })
	end
end

function RecipeBook.render(ctx: any)
	local state = ctx.state
	UI.label(ctx.content, "Known recipes", { bold = true, size = 18 })

	local ids = {}
	for id in Recipes.catalog do
		table.insert(ids, id)
	end
	table.sort(ids, function(a: string, b: string)
		local ra, rb = Recipes.catalog[a], Recipes.catalog[b]
		local la: number, lb: number = ra.unlockLevel or 1, rb.unlockLevel or 1
		if la ~= lb then
			return la < lb
		end
		return a < b
	end)
	for _, id in ids do
		local r = Recipes.catalog[id]
		if state.recipes[id] then
			recipeCard(ctx, r.name, r.requires, "", state.recipeBook[id], r.blurb)
		else
			local card = UI.card(ctx.content, Color3.fromRGB(226, 218, 200))
			UI.label(card, "???", { bold = true, size = 16 })
			UI.label(card, `Reach level {r.unlockLevel or 1}, or discover it by experimenting at the oven.`, { size = 13 })
		end
	end

	local customs = {}
	for key, e in state.recipeBook do
		if e.custom then
			table.insert(customs, key)
		end
	end
	table.sort(customs)
	if #customs > 0 then
		UI.label(ctx.content, "Your experiments", { bold = true, size = 18 })
		for _, key in customs do
			local slots = Recipes.parseCustomKey(key)
			local e = state.recipeBook[key]
			if slots then
				local need = Recipes.requiresFor(slots)
				local practice = math.min(e.bakes, #Recipes.CUSTOM_CORRECTNESS - 1)
				recipeCard(ctx, e.name, need, `Practice {practice}/{#Recipes.CUSTOM_CORRECTNESS - 1}: more bakes refine the recipe.`, e, nil)
			end
		end
	end
	UI.label(ctx.content, "Experiment at the oven (Experiment button) to discover new recipes. Good results are saved here.", { size = 13 })
end

return RecipeBook
