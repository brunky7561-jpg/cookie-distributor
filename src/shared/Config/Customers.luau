--!strict
local Types = require(script.Parent.Parent.Modules.Types)

local Customers: { Types.CustomerTemplate } = {
	{ id = "maya", name = "Maya", personality = "Foodie", loves = { "chocolate", "salty" }, hates = { "rare" }, appealMin = 15, appealMax = 40, budget = 30 },
	{ id = "leo", name = "Leo", personality = "SweetTooth", loves = { "sweet" }, hates = { "salty" }, appealMin = 30, appealMax = 70, budget = 25 },
	{ id = "dot", name = "Dot", personality = "BargainHunter", loves = { "base" }, hates = { "rare" }, appealMin = 0, appealMax = 30, budget = 12 },
	{ id = "hana", name = "Hana", personality = "HealthNut", loves = { "sweet" }, hates = { "intense" }, appealMin = 0, appealMax = 20, budget = 25 },
}

return Customers
