--!strict
-- Curated phone dialogue. Players only ever choose from these preset questions; they never type to NPCs,
-- so nothing goes around Roblox chat filtering.
local Dialogue = {}

Dialogue.questions = {
	{ id = "flavor", label = "What do you like?" },
	{ id = "deadline", label = "When do you need it?" },
	{ id = "where", label = "Where should I deliver?" },
	{ id = "budget", label = "What can you pay?" },
} :: { { id: string, label: string } }

Dialogue.tagWords = {
	chocolate = "chocolate",
	salty = "a pinch of salt",
	sweet = "something nice and sweet",
	base = "simple classic cookies",
	rare = "fancy, special ingredients",
} :: { [string]: string }

return Dialogue
