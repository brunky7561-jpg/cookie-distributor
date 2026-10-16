--!strict
local Types = require(script.Parent.Parent.Modules.Types)

local Ingredients: { [string]: Types.Ingredient } = {
	flour = { id = "flour", name = "Flour", category = "Base", cost = 1, appeal = 0, tags = { "base" }, sideEffects = {} },
	butter = { id = "butter", name = "Butter", category = "Fat", cost = 2, appeal = 1, tags = { "fat" }, sideEffects = {} },
	white_sugar = { id = "white_sugar", name = "White Sugar", category = "Sweetener", cost = 1, appeal = 2, tags = { "sweet" }, sideEffects = {} },
	brown_sugar = { id = "brown_sugar", name = "Brown Sugar", category = "Sweetener", cost = 2, appeal = 2, tags = { "sweet" }, sideEffects = {} },
	chocolate_chips = { id = "chocolate_chips", name = "Chocolate Chips", category = "Add-in", cost = 3, appeal = 6, tags = { "chocolate" }, sideEffects = {} },
	sea_salt = { id = "sea_salt", name = "Sea Salt", category = "Booster", cost = 1, appeal = 4, tags = { "salty" }, sideEffects = {} },
	caramel = { id = "caramel", name = "Caramel", category = "Sweetener", cost = 4, appeal = 8, tags = { "sweet" }, sideEffects = { "Crash" } },
	espresso_powder = { id = "espresso_powder", name = "Espresso Powder", category = "Booster", cost = 5, appeal = 10, tags = { "energy" }, sideEffects = { "Energized" } },
	golden_honey = { id = "golden_honey", name = "Golden Honey", category = "Rare", cost = 25, appeal = 15, tags = { "sweet", "rare" }, sideEffects = { "Cozy" } },
	moon_sugar = { id = "moon_sugar", name = "Moon Sugar", category = "Rare", cost = 40, appeal = 22, tags = { "rare", "intense" }, sideEffects = { "Sugar Rush" } },
}

return Ingredients
