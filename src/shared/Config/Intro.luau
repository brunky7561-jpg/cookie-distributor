--!strict
-- Title screen and opening cutscene. Change the antagonist's name, lines and choices here; nothing else needs to move.
local Intro = {}

Intro.title = {
	name = "Cookie Empire",
	tagline = "Bake. Deliver. Grow.",
	playText = "Play",
	hint = "Tip: your phone (P) holds orders, ingredients and apps.",
}

Intro.antagonist = {
	name = "Madame Vex",
	role = "Head of the Cookie Council",
	portrait = "👩‍⚖️",
}

-- Spoken in order. "You" lines are shown with the player's side of the conversation.
Intro.lines = {
	{ speaker = "Madame Vex", text = "So you are the new baker in town. Nobody opens a bakery here without my permission." },
	{ speaker = "You", text = "I did not know I needed any. I just want to bake cookies." },
	{ speaker = "Madame Vex", text = "Everyone says that. Then they sell better cookies than mine, and I am forced to ruin them." },
	{ speaker = "Madame Vex", text = "Let us not be enemies yet. I am generous. I will give you a choice." },
	{ speaker = "Madame Vex", text = "Take your punishment for opening without a permit, or bake cookies for me. Which will it be?" },
}

Intro.choices = {
	{
		id = "bake",
		label = "Bake cookies for her",
		reply = "Wise. Your first order is waiting on your phone. Do not burn it.",
		closing = "You start with a customer's order already accepted.",
	},
	{
		id = "punish",
		label = "Take the punishment",
		reply = "Brave, or foolish. That will be a $50 fine. Now get to work, baker. I will be watching.",
		closing = "You paid the fine. Your first order is still waiting on your phone.",
	},
}

Intro.punishmentFee = 50 -- cash taken if you pick "punish" (never more than you have)
Intro.startButton = "Start baking!"
Intro.typeSpeed = 0.025 -- seconds per letter

return Intro
