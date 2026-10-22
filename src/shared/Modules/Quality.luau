--!strict
-- Transparent 0-100 batch quality: recipe 35%, bake timing 28%, dough mixing 10%, ingredient freshness 12%, portion consistency 15%.
local Quality = {}

export type Factors = { recipe: number, bake: number, fresh: number, portion: number, dough: number? } -- each 0..1; dough is the mixing minigame (missing counts as perfect)

Quality.WEIGHTS = { recipe = 0.35, bake = 0.28, fresh = 0.12, portion = 0.15, dough = 0.10 }

-- 1 at the ideal moment, falling to 0 once you are a full IDEAL away. `slack` seconds either side still score 1
-- (better equipment forgives more).
function Quality.timing(elapsed: number, ideal: number, slack: number?): number
	local off = math.max(0, math.abs(elapsed - ideal) - (slack or 0))
	return math.clamp(1 - off / ideal, 0, 1)
end

function Quality.score(f: Factors): number
	local w = Quality.WEIGHTS
	local total = f.recipe * w.recipe + f.bake * w.bake + f.fresh * w.fresh + f.portion * w.portion + (f.dough or 1) * w.dough
	return math.clamp(math.floor(total * 100 + 0.5), 0, 100)
end

function Quality.grade(score: number): string
	if score >= 90 then
		return "Perfect Batch"
	elseif score >= 75 then
		return "Great"
	elseif score >= 50 then
		return "Good"
	end
	return "Needs Work"
end

-- One sentence that points at the weakest factor. bakeSigned > 0 means the tray stayed in too long.
function Quality.feedback(f: Factors, bakeSigned: number): string
	local order = {
		{ "bake", f.bake },
		{ "portion", f.portion },
		{ "fresh", f.fresh },
		{ "recipe", f.recipe },
		{ "dough", f.dough or 1 },
	}
	local weakest, value = "bake", 2
	for _, entry in order do
		if (entry[2] :: number) < value then
			weakest, value = entry[1] :: string, entry[2] :: number
		end
	end
	if value >= 0.9 then
		return "Golden edges and even sizes. A perfect little batch."
	end
	if weakest == "bake" then
		if bakeSigned > 0 then
			return "This batch baked a little long; pull the tray a touch sooner next time."
		end
		return "This batch came out a little early; give it a few more seconds in the oven."
	elseif weakest == "portion" then
		return "The cookies came out uneven; stop the portion bar right in the green zone."
	elseif weakest == "dough" then
		return "The dough was a little lumpy; stir right when the marker is in the green zone."
	elseif weakest == "fresh" then
		return "Some ingredients were past their best."
	end
	return "Something was off in the recipe."
end

return Quality
