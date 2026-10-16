--!strict
-- CrumbChat: customer requests as chat threads. Accept or decline, ask preset questions, see the order's state,
-- and hand the cookies over. NPC answers come from the server (curated text only; players never type to NPCs).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dialogue = require(ReplicatedStorage.Shared.Config.Dialogue)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local UI = require(script.Parent.Parent.Modules.UI)

local Theme = UI.Theme
local STATES = { "Available", "Accepted", "In Production", "Ready", "Delivered", "Paid" }

local chat: { [number]: { { from: string, text: string } } } = {} -- per order, this session only
local receipt: any = nil

local function stateLine(current: string): string
	local parts = {}
	for _, s in STATES do
		table.insert(parts, if s == current then `[{s}]` else s)
	end
	return table.concat(parts, " > ")
end

local function matchingBoxes(state: any, order: any): { any }
	local found = {}
	for _, b in state.batches do
		if b.recipeId == order.recipeId and not b.reservedFor and b.count >= order.count then
			table.insert(found, b)
		end
	end
	return found
end

local function bubble(parent: Instance, who: string, text: string)
	local mine = who == "you"
	local box = UI.card(parent, if mine then Theme.Butter else Color3.fromRGB(255, 255, 255))
	UI.label(box, text, { size = 14, bold = mine })
end

local CrumbChat = {}
CrumbChat.id = "crumbchat"

function CrumbChat.render(ctx: any)
	local content = ctx.content
	local state = ctx.state

	local function act(action: string, orderId: number, extra: any?)
		local ok, res = Remotes.func("OrderAction"):InvokeServer(action, orderId, extra)
		if ok then
			if action == "deliver" and type(res) == "table" then
				receipt = res
				ctx.say(`{res.customerName}: "{res.reaction}"  +${res.pay + res.tip}`)
			elseif action == "ask" then
				local log = chat[orderId] or {}
				chat[orderId] = log
				table.insert(log, { from = "npc", text = tostring(res) })
			else
				ctx.say(tostring(res))
			end
		else
			ctx.say(tostring(res))
		end
		ctx.rerender()
	end

	if receipt then
		local card = UI.card(content, Theme.Mint)
		UI.label(card, `Receipt: {receipt.customerName}`, { bold = true, size = 17 })
		local tipText = if receipt.tip > 0 then " (+$" .. receipt.tip .. " tip)" else ""
		UI.label(card, "Delivered and paid  +$" .. receipt.pay .. tipText)
		UI.label(card, `Batch grade: {receipt.grade or "n/a"}`)
		UI.label(card, tostring(receipt.feedback or ""), { size = 14 })
		UI.label(card, `"{receipt.reaction}"  ({receipt.relationship})`, { size = 14 })
		UI.label(card, table.concat(receipt.states, " > "), { size = 12 })
		if receipt.wasFirst then
			UI.label(card, "First order complete! More customers will text you soon.", { bold = true })
		end
		UI.button(card, "Close receipt", Theme.Butter, function()
			receipt = nil
			ctx.rerender()
		end)
	end

	local shown = 0
	for _, o in ctx.orders do
		shown += 1
		local card = UI.card(content)
		UI.label(card, o.customerName, { bold = true, size = 17 })
		bubble(card, "npc", o.text)
		for _, m in chat[o.id] or {} do
			bubble(card, m.from, m.text)
		end
		UI.label(card, `{o.count}x {o.recipeName}  |  Pays about ${o.offer}  |  Deliver to: {o.destination}`, { size = 13 })
		if o.deadline then
			local left = math.max(0, o.deadline - os.time())
			UI.label(card, `Time left: {math.ceil(left / 60)} min`, { size = 13 })
		else
			UI.label(card, "No deadline. Take your time.", { size = 13 })
		end
		UI.label(card, stateLine(o.state), { size = 12, bold = true })

		-- preset follow-up questions (curated; the answer comes from the server)
		if o.state == "Available" or o.state == "Accepted" then
			for _, q in Dialogue.questions do
				UI.button(card, q.label, Theme.Blueberry, function()
					local log = chat[o.id] or {}
					chat[o.id] = log
					table.insert(log, { from = "you", text = q.label })
					act("ask", o.id, q.id)
				end)
			end
		end

		if o.state == "Available" then
			UI.button(card, "Accept", Theme.Mint, function()
				act("accept", o.id)
			end)
			UI.button(card, "Decline", Theme.Coral, function()
				act("cancel", o.id)
			end)
		elseif o.state == "Accepted" then
			UI.label(card, "Next: bake it at your kitchen counter (press E).", { size = 14, bold = true })
			for _, b in matchingBoxes(state, o) do
				UI.button(card, `Use stock box ({b.grade or "Good"}, {b.count} cookies)`, Theme.Butter, function()
					act("assign", o.id, b.id)
				end)
			end
			UI.button(card, "Cancel order", Theme.Coral, function()
				act("cancel", o.id)
			end)
		elseif o.state == "In Production" then
			UI.label(card, "Baking in progress. Finish at the kitchen station.", { size = 14, bold = true })
			UI.button(card, "Cancel order", Theme.Coral, function()
				act("cancel", o.id)
			end)
		elseif o.state == "Ready" then
			UI.button(card, "Hand over cookies", Theme.Mint, function()
				act("deliver", o.id)
			end)
		end
	end

	if shown == 0 and not receipt then
		UI.label(content, "No new requests yet. Customers text you every so often; keep an eye on this app.")
	end

	if #state.history > 0 then
		UI.label(content, "Recent orders", { bold = true, size = 16 })
		for _, h in state.history do
			UI.label(content, `{h.customer}: {h.recipe}  {h.grade}  +${h.pay}`, { size = 13 })
		end
	end
end

return CrumbChat
