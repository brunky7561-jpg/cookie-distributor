--!strict
local Types = require(script.Parent.Parent.Modules.Types)

local Recipes = {
	synergies = {
		{ a = "chocolate", b = "salty", multiplier = 1.3 },
		{ a = "energy", b = "sweet", multiplier = 1.2 },
	} :: { Types.Synergy },
	-- Hidden combos (discovered by experimenting): sorted ingredient ids -> name
	hidden = {
		["brown_sugar+butter+flour"] = "Classic Dough",
	} :: { [string]: string },
}

return Recipes
