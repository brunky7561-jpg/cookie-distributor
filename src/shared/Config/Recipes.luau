--!strict
local Types = require(script.Parent.Parent.Modules.Types)

local Recipes = {
	synergies = {
		{ a = "chocolate", b = "salty", multiplier = 1.3 },
		{ a = "energy", b = "sweet", multiplier = 1.2 },
	} :: { Types.Synergy },
	-- Guided recipes. Milestone 1 ships one; free-form experiments and the Recipe Book arrive in Milestone 4.
	catalog = {
		classic_chip = {
			id = "classic_chip",
			name = "Classic Chip Cookies",
			yield = 6,
			slots = { base = "flour", flavor = "white_sugar", mixin = "chocolate_chips" },
			requires = { flour = 2, butter = 1, white_sugar = 1, chocolate_chips = 1 },
		},
	} :: { [string]: Types.RecipeDef },
	boxes = {
		{ id = "small", name = "Small box", size = 3 },
		{ id = "standard", name = "Standard box", size = 6 },
		{ id = "large", name = "Large box", size = 12 },
	} :: { Types.BoxDef },
}

return Recipes
