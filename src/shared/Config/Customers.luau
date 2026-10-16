--!strict
local Types = require(script.Parent.Parent.Modules.Types)

local Customers: { Types.CustomerTemplate } = {
	{ id = "maya", name = "Maya", personality = "Foodie", loves = { "chocolate", "salty" }, hates = { "rare" }, cravingMin = 15, cravingMax = 40, budget = 30 },
	{ id = "leo", name = "Leo", personality = "SugarFiend", loves = { "sweet" }, hates = { "salty" }, cravingMin = 30, cravingMax = 70, budget = 25 },
	{ id = "dot", name = "Dot", personality = "BargainHunter", loves = { "base" }, hates = { "rare" }, cravingMin = 0, cravingMax = 30, budget = 12 },
	{ id = "hana", name = "Hana", personality = "HealthNut", loves = { "sweet" }, hates = { "intense" }, cravingMin = 0, cravingMax = 20, budget = 25 },
}

return Customers
