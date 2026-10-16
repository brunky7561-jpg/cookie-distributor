--!strict
-- MarketPulse: today's market event, your contract against a rival bakery, and the top earners.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Market = require(ReplicatedStorage.Shared.Config.Market)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local UI = require(script.Parent.Parent.Modules.UI)

local Theme = UI.Theme

local cached: any = nil
local cachedAt = 0

local MarketPulse = {}
MarketPulse.id = "marketpulse"

function MarketPulse.render(ctx: any)
	local state = ctx.state
	if cached == nil or os.clock() - cachedAt > 20 then
		local fresh = Remotes.func("MarketStatus"):InvokeServer()
		if fresh then
			cached = fresh
			cachedAt = os.clock()
		end
	end
	local info = cached

	if info then
		local ev = UI.card(ctx.content, Theme.Butter)
		UI.label(ev, `Today: {info.event.name}`, { bold = true })
		UI.label(ev, info.event.desc, { size = 13 })
		UI.label(ev, `Changes in about {math.ceil(info.secondsLeft / 60)} min.`, { size = 13 })
	end

	UI.label(ctx.content, "Contract", { bold = true, size = 18 })
	local c = state.contract
	if c then
		local rival = "A rival"
		for _, r in Market.rivals do
			if r.id == c.rivalId then
				rival = r.name
			end
		end
		local card = UI.card(ctx.content)
		UI.label(card, `{c.count} x {Recipes.catalog[c.recipeId].name}, score {c.minScore}+`, { bold = true })
		UI.label(card, `Pays ${c.pay} and reputation. {rival} wants it too.`, { size = 13 })
		UI.label(card, `Expires in about {math.max(1, math.ceil((c.expiresAt - os.time()) / 60))} min.`, { size = 13 })
		UI.label(card, "Cookies on display or promised to an order do not count.", { size = 13 })
		UI.button(card, "Deliver from my stock", Theme.Butter, function()
			local ok, msg = Remotes.func("ContractDeliver"):InvokeServer()
			ctx.say(tostring(msg))
			ctx.rerender()
			return ok
		end)
	else
		UI.label(ctx.content, "No contract right now. A new one will appear soon.", { size = 13 })
	end
	UI.label(ctx.content, `You have won {state.contractWins} and lost {state.contractLosses} to rivals.`, { size = 13 })

	UI.label(ctx.content, "Top earners", { bold = true, size = 18 })
	if info and #info.board > 0 then
		for i, row in info.board do
			UI.label(ctx.content, `{i}. {row.name}  ${row.gross}`, { size = 14 })
		end
	else
		UI.label(ctx.content, "The board is empty or unavailable right now.", { size = 13 })
	end
end

return MarketPulse
