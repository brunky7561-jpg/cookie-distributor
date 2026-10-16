--!strict
-- The city market: a rotating event that changes what customers pay, rival bakeries that compete for contracts, and the
-- contract rules. The event is a pure function of the clock, so every server and every player sees the same one.
local Market = {}

Market.EVENT_PERIOD = 900 -- seconds each event lasts

Market.events = {
	{ id = "choc_craze", name = "Chocolate Craze", desc = "Chocolate cookies pay 25% more.", tag = "chocolate", mult = 1.25 },
	{ id = "salty_week", name = "Salty-Sweet Week", desc = "Salty cookies pay 25% more.", tag = "salty", mult = 1.25 },
	{ id = "sweet_fest", name = "Sugar Festival", desc = "Sweet cookies pay 20% more.", tag = "sweet", mult = 1.2 },
	{ id = "quiet_day", name = "Quiet Day", desc = "Steady business. Normal prices.", tag = "", mult = 1 },
} :: { { id: string, name: string, desc: string, tag: string, mult: number } }

Market.rivals = {
	{ id = "sugar_rush", name = "Sugar Rush Bakery", blurb = "Loud, cheap and everywhere." },
	{ id = "golden_whisk", name = "The Golden Whisk", blurb = "Fancy and slow. Loves a big contract." },
	{ id = "crumb_co", name = "Crumb & Co.", blurb = "The old family shop on Main Street." },
} :: { { id: string, name: string, blurb: string } }

Market.CONTRACT_COUNT = 12
Market.CONTRACT_MIN_SCORE = 65
Market.CONTRACT_LIFETIME = 1200 -- seconds
Market.CONTRACT_COOLDOWN = 120
Market.CONTRACT_REPUTATION = 5
Market.CONTRACT_PREMIUM = 1.5 -- over the normal per-order offer

function Market.currentEvent(now: number): any
	local index = math.floor(now / Market.EVENT_PERIOD) % #Market.events + 1
	return Market.events[index]
end

function Market.secondsLeft(now: number): number
	return Market.EVENT_PERIOD - now % Market.EVENT_PERIOD
end

-- Payout multiplier for a batch with these tags under an event.
function Market.eventMult(event: any, tags: { string }?): number
	if event.tag ~= "" and tags and table.find(tags, event.tag) then
		return event.mult
	end
	return 1
end

return Market
