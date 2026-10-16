--!strict
-- Hireable bakers. A baker works one recipe at a time and bakes a batch every `cycle` seconds while the pantry has the
-- ingredients and storage has room. Quality is deterministic: score = base + skill * perSkill, never random.
local Staff = {}

Staff.candidates = {
	sam = { id = "sam", name = "Sam", blurb = "Eager and cheap. Plain but decent batches.", skill = 1, wage = 30, cycle = 100 },
	rosa = { id = "rosa", name = "Rosa", blurb = "Steady hands and good timing.", skill = 2, wage = 70, cycle = 80 },
	ike = { id = "ike", name = "Ike", blurb = "A veteran pastry chef. Fast and precise.", skill = 3, wage = 130, cycle = 60 },
} :: { [string]: { id: string, name: string, blurb: string, skill: number, wage: number, cycle: number } }

Staff.order = { "sam", "rosa", "ike" }
Staff.BASE_SCORE = 50
Staff.PER_SKILL = 10 -- skill 1 => 60, 2 => 70, 3 => 80 (the player can still reach 100 by hand)
Staff.PROMOTE_EVERY = 10 -- bakes needed per extra skill point, up to +1 (max skill 4)
Staff.DAY = 600 -- seconds between wage payments

return Staff
