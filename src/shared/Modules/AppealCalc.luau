--!strict
-- Pure function: ingredient ids + bake quality -> Appeal score. Shared so UI can preview it.
local Ingredients = require(script.Parent.Parent.Config.Ingredients)
local Recipes = require(script.Parent.Parent.Config.Recipes)

local AppealCalc = {}

local DIMINISHING = 0.75 -- each repeat of the same ingredient adds 75% of the previous

function AppealCalc.compute(ingredientIds: { string }, quality: number): { score: number, effects: { string } }
	local seen: { [string]: number } = {}
	local tags: { [string]: boolean } = {}
	local effects: { [string]: boolean } = {}
	local total = 0

	for _, id in ingredientIds do
		local ing = Ingredients[id]
		if not ing then
			continue
		end
		local n = seen[id] or 0
		seen[id] = n + 1
		total += ing.appeal * DIMINISHING ^ n
		for _, t in ing.tags do
			tags[t] = true
		end
		for _, e in ing.sideEffects do
			effects[e] = true
		end
	end

	for _, syn in Recipes.synergies do
		if tags[syn.a] and tags[syn.b] then
			total *= syn.multiplier
		end
	end

	-- quality is 0..1; a perfect bake gets x1.2, a burnt one x0.5
	local mult = 0.5 + 0.7 * math.clamp(quality, 0, 1)
	local score = math.clamp(math.round(total * mult), 0, 100)

	local list = {}
	for e in effects do
		table.insert(list, e)
	end
	table.sort(list)
	return { score = score, effects = list }
end

return AppealCalc
