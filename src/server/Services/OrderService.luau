--!strict
-- Customer orders and their lifecycle: Available -> Accepted -> In Production -> Ready -> Delivered -> Paid.
-- The server owns every state change; the client only asks ("accept", "cancel", "assign", "deliver").
-- A seeded first order (no deadline) is offered to every new player so the first loop never needs admin help.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomerTemplates = require(ReplicatedStorage.Shared.Config.Customers)
local Dialogue = require(ReplicatedStorage.Shared.Config.Dialogue)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)

local TICK = 5 -- seconds between expiry checks
local SPAWN_EVERY = 30 -- seconds between new random orders per player
local MAX_ACTIVE_ORDERS = 3
local ORDER_LIFETIME = 600 -- seconds; random orders only, the first order never expires
local RECIPE_ID = "classic_chip"
local DESTINATION = "Starter Apartment doorstep"
local REL_LEVELS: { { points: number, name: string } } = {
	{ points = 0, name = "Stranger" },
	{ points = 10, name = "Customer" },
	{ points = 30, name = "Regular" },
	{ points = 70, name = "Fan" },
	{ points = 150, name = "Superfan" },
}

local ORDER_TEXT: { [string]: string } = {
	Neighbor = "Hi neighbor! I'm hosting book club. Could you bake {count} Classic Chip cookies for us?",
	Foodie = "Hi! I'd love {count} really well-made cookies. Quality matters to me.",
	BargainHunter = "Hey, got a deal on {count} cookies? Nothing fancy.",
	SweetTooth = "I NEED {count} cookies. The sweeter the better!",
	HealthNut = "Could I get {count} not-too-sweet cookies? Thanks!",
	Trendsetter = "Make me {count} cookies nobody has tried yet!",
	Grump = "{count} cookies. Don't disappoint me.",
}

local REACTIONS = {
	great = { "Oh wow. These are perfect.", "Okay, you've outdone yourself.", "I'm telling everyone about you." },
	ok = { "These are pretty good.", "Not bad at all.", "Thanks, that hits the spot." },
	bad = { "Hmm. Not really what I wanted.", "These aren't great.", "I expected better." },
}

export type OrderState = "Available" | "Accepted" | "In Production" | "Ready" | "Delivered" | "Paid"

type Order = {
	id: number,
	customerId: string,
	recipeId: string,
	count: number,
	offer: number,
	state: OrderState,
	deadline: number?, -- os.time(); nil = never expires
	destination: string,
	batchId: number?,
	isFirst: boolean,
}

local orders: { [Player]: { [number]: Order } } = {}
local nextOrderId = 1
local templatesById: { [string]: any } = {}
for _, t in CustomerTemplates do
	templatesById[t.id] = t
end

local OrderService = {}

local function relLevel(points: number): string
	local name = REL_LEVELS[1].name
	for _, entry in REL_LEVELS do
		if points >= entry.points then
			name = entry.name
		end
	end
	return name
end

local function customerState(data: any, id: string): any
	local s = data.customers[id]
	if not s then
		s = { rel = 0, memory = {} }
		data.customers[id] = s
	end
	return s
end

local function activeFor(player: Player): { [number]: Order }
	local t = orders[player]
	if not t then
		t = {}
		orders[player] = t
	end
	return t
end

local function view(order: Order): any
	local t = templatesById[order.customerId]
	local recipe = Recipes.catalog[order.recipeId]
	return {
		id = order.id,
		customerName = t.name,
		personality = t.personality,
		text = (ORDER_TEXT[t.personality] :: string):gsub("{count}", tostring(order.count)),
		count = order.count,
		recipeId = order.recipeId,
		recipeName = recipe.name,
		offer = order.offer,
		state = order.state,
		deadline = order.deadline,
		destination = order.destination,
		batchId = order.batchId,
		isFirst = order.isFirst,
	}
end

local function push(player: Player)
	local list: { any } = {}
	for _, o in activeFor(player) do
		table.insert(list, view(o))
	end
	table.sort(list, function(a: any, b: any)
		return a.id < b.id
	end)
	Remotes.event("OrdersUpdated"):FireClient(player, list)
end

local function notify(player: Player, text: string)
	Remotes.event("Notify"):FireClient(player, text)
end

local function newOrder(player: Player, t: any, count: number, isFirst: boolean)
	local order: Order = {
		id = nextOrderId,
		customerId = t.id,
		recipeId = RECIPE_ID,
		count = count,
		offer = math.floor(count * t.budget / 6 + 0.5) + 3,
		state = "Available",
		deadline = if isFirst then nil else os.time() + ORDER_LIFETIME,
		destination = DESTINATION,
		batchId = nil,
		isFirst = isFirst,
	}
	nextOrderId += 1
	activeFor(player)[order.id] = order
	push(player)
	notify(player, `New order from {t.name}! Open your phone (P).`)
end

local function countActive(player: Player): number
	local n = 0
	for _ in activeFor(player) do
		n += 1
	end
	return n
end

-- Offers the free starter order until the player has completed one.
local function ensureFirstOrder(player: Player)
	local data = PlayerDataService:Get(player)
	if not data or data.milestones.firstOrderDone then
		return
	end
	if countActive(player) == 0 then
		newOrder(player, templatesById.parkway, 6, true)
	end
end

local function spawnRandomOrder(player: Player)
	local data = PlayerDataService:Get(player)
	if not data or not data.milestones.firstOrderDone or countActive(player) >= MAX_ACTIVE_ORDERS then
		return
	end
	local busy = {}
	for _, o in activeFor(player) do
		busy[o.customerId] = true
	end
	local pool = {}
	for _, t in CustomerTemplates do
		if not busy[t.id] then
			table.insert(pool, t)
		end
	end
	if #pool > 0 then
		newOrder(player, pool[math.random(#pool)], math.random(2, 6), false)
	end
end

local function satisfaction(batch: any, t: any): number
	local taste = 0.6
	for _, tag in t.loves do
		if table.find(batch.tags, tag) then
			taste += 0.2
		end
	end
	for _, tag in t.hates do
		if table.find(batch.tags, tag) then
			taste -= 0.4
		end
	end
	taste = math.clamp(taste, 0, 1)

	local fit = 1
	if batch.appeal < t.appealMin then
		fit = math.clamp(1 - (t.appealMin - batch.appeal) / 30, 0, 1)
	elseif batch.appeal > t.appealMax then
		fit = math.clamp(1 - (batch.appeal - t.appealMax) / 30, 0, 1)
	end
	return 0.4 * taste + 0.3 * fit + 0.3 * batch.quality
end

local function getOrder(player: Player, orderId: any): Order?
	if type(orderId) ~= "number" then
		return nil
	end
	return activeFor(player)[orderId]
end

-- Removes an order without paying. Anything reserved for it goes back to stock.
local function drop(player: Player, order: Order)
	if order.batchId then
		InventoryService:Release(player, order.batchId)
		order.batchId = nil
	end
	activeFor(player)[order.id] = nil
end

local function penalize(player: Player, order: Order)
	local data = PlayerDataService:Get(player)
	if data and data.milestones.firstOrderDone and order.state ~= "Available" then
		local s = customerState(data, order.customerId)
		s.rel = math.max(0, s.rel - 1)
		PlayerDataService:Replicate(player)
	end
end

-- Curated answers to the preset questions. `questionId` must be one of Dialogue.questions.
local function answer(order: Order, questionId: any): string?
	local t = templatesById[order.customerId]
	if questionId == "flavor" then
		local words = {}
		for _, tag in t.loves do
			table.insert(words, Dialogue.tagWords[tag] or tag)
		end
		if #words == 0 then
			return "Surprise me! I like most things."
		end
		return `I'm really into {table.concat(words, " and ")}.`
	elseif questionId == "deadline" then
		if order.deadline then
			local minutes = math.max(1, math.ceil((order.deadline - os.time()) / 60))
			return `About {minutes} minute{if minutes == 1 then "" else "s"} from now would be great.`
		end
		return "No rush at all. Whenever you're ready!"
	elseif questionId == "where" then
		return `Bring them to the {order.destination}, please.`
	elseif questionId == "budget" then
		return `I can pay around ${order.offer}, more if they're really good.`
	end
	return nil
end

local function deliver(player: Player, order: Order): (boolean, any)
	local data = PlayerDataService:Get(player)
	if not data or order.state ~= "Ready" or not order.batchId then
		return false, "this order is not ready to hand over"
	end
	local batch = InventoryService:FindBatch(player, order.batchId)
	if not batch or batch.count < order.count then
		order.state = "Accepted"
		order.batchId = nil
		push(player)
		return false, "the cookies for this order are gone; bake or assign a new box"
	end

	-- State moves first and the order leaves the table in the same step, so a payout can never happen twice.
	order.state = "Delivered"
	activeFor(player)[order.id] = nil
	InventoryService:TakeCookies(player, batch.id, order.count)

	local t = templatesById[order.customerId]
	local state = customerState(data, t.id)
	local sat = satisfaction(batch, t)
	local pay = math.floor(order.offer * (0.5 + sat) + 0.5)
	local tip = 0
	if sat > 0.85 then
		tip = math.floor(order.offer * 0.2)
	end
	order.state = "Paid"
	EconomyService:AddCash(player, pay + tip)
	EconomyService:Record(player, "gross", pay + tip)
	data.stats.orders += 1
	EconomyService:AddXp(player, math.floor(10 + sat * 20))

	state.rel = math.max(0, state.rel + math.floor(sat * 10) - 4)
	table.insert(state.memory, { name = batch.name, quality = batch.quality, appeal = batch.appeal, sat = sat })
	if #state.memory > 5 then
		table.remove(state.memory, 1)
	end
	local wasFirst = not data.milestones.firstOrderDone
	data.milestones.firstOrderDone = true

	table.insert(data.history, 1, { customer = t.name, recipe = batch.name, pay = pay + tip, grade = batch.grade or "", t = os.time() })
	while #data.history > 10 do
		table.remove(data.history)
	end

	local pool = if sat > 0.75 then REACTIONS.great elseif sat > 0.45 then REACTIONS.ok else REACTIONS.bad
	PlayerDataService:Replicate(player)
	push(player)
	return true,
		{
			customerName = t.name,
			pay = pay,
			tip = tip,
			satisfaction = sat,
			reaction = pool[math.random(#pool)],
			relationship = relLevel(state.rel),
			grade = batch.grade,
			feedback = batch.feedback,
			states = { "Available", "Accepted", "In Production", "Ready", "Delivered", "Paid" },
			wasFirst = wasFirst,
		}
end

-- Called by BakingService --------------------------------------------------------------------------------

function OrderService:CanProduce(player: Player, orderId: number, recipeId: string): boolean
	local order = getOrder(player, orderId)
	return order ~= nil and order.state == "Accepted" and order.recipeId == recipeId
end

function OrderService:BeginProduction(player: Player, orderId: number): boolean
	local order = getOrder(player, orderId)
	if not order or order.state ~= "Accepted" then
		return false
	end
	order.state = "In Production"
	push(player)
	return true
end

-- Attach a finished batch. Returns false if the order was cancelled or expired meanwhile (batch stays in stock).
function OrderService:MarkReady(player: Player, orderId: number, batchId: number): boolean
	local order = getOrder(player, orderId)
	if not order or order.state ~= "In Production" then
		return false
	end
	if not InventoryService:Reserve(player, batchId, order.id) then
		return false
	end
	order.state = "Ready"
	order.batchId = batchId
	push(player)
	notify(player, `Your {order.count} cookies are ready. Open the phone to deliver them.`)
	return true
end

function OrderService:Init()
	Remotes.func("GetOrders").OnServerInvoke = function(player: Player)
		local list: { any } = {}
		for _, o in activeFor(player) do
			table.insert(list, view(o))
		end
		table.sort(list, function(a: any, b: any)
			return a.id < b.id
		end)
		return list
	end

	Remotes.func("OrderAction").OnServerInvoke = function(player: Player, action: any, orderId: any, extra: any)
		if not RateLimit.check(player, "OrderAction", 0.2) then
			return false, "slow down a little"
		end
		if type(action) ~= "string" then
			return false, "bad request"
		end
		local order = getOrder(player, orderId)
		if not order then
			return false, "that order is gone"
		end

		if action == "accept" then
			if order.state ~= "Available" then
				return false, "you already accepted this order"
			end
			order.state = "Accepted"
			push(player)
			return true, "Accepted. Walk to your kitchen counter and press E to bake."
		elseif action == "cancel" then
			if order.state == "Delivered" or order.state == "Paid" then
				return false, "that order is already finished"
			end
			local msg = if order.state == "Available"
				then "Declined. No penalty."
				else "Cancelled. Anything already baked stays in your stock. Backing out after accepting can cost goodwill later."
			penalize(player, order)
			drop(player, order)
			push(player)
			ensureFirstOrder(player) -- no-op once the first order has been completed
			return true, msg
		elseif action == "assign" then
			if order.state ~= "Accepted" then
				return false, "accept the order first"
			end
			if type(extra) ~= "number" then
				return false, "pick a box"
			end
			local batch = InventoryService:FindBatch(player, extra)
			if not batch or batch.reservedFor or batch.recipeId ~= order.recipeId then
				return false, "that box does not match this order"
			end
			if batch.count < order.count then
				return false, `this order needs {order.count} cookies; that box has {batch.count}`
			end
			if not InventoryService:Reserve(player, batch.id, order.id) then
				return false, "that box is already taken"
			end
			order.state = "Ready"
			order.batchId = batch.id
			push(player)
			return true, "Box set aside. Deliver it when you're ready."
		elseif action == "deliver" then
			return deliver(player, order)
		elseif action == "ask" then
			local reply = answer(order, extra)
			if not reply then
				return false, "unknown question"
			end
			return true, reply
		end
		return false, "unknown action"
	end
end

function OrderService:Start()
	PlayerDataService.Reset:Connect(function(player: Player)
		orders[player] = {}
		push(player)
		ensureFirstOrder(player)
	end)
	local function onJoin(player: Player)
		for _ = 1, 60 do
			if PlayerDataService:Get(player) or not player.Parent then
				break
			end
			task.wait(0.5)
		end
		if player.Parent then
			ensureFirstOrder(player)
		end
	end
	Players.PlayerAdded:Connect(function(p)
		task.spawn(onJoin, p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(onJoin, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		orders[p] = nil
	end)

	local elapsed = 0
	while true do
		task.wait(TICK)
		elapsed += TICK
		local spawnNow = elapsed >= SPAWN_EVERY
		if spawnNow then
			elapsed = 0
		end
		for _, player in Players:GetPlayers() do
			local changed = false
			for id, o in activeFor(player) do
				if o.deadline and os.time() >= o.deadline and o.state ~= "Ready" then
					penalize(player, o)
					drop(player, o)
					activeFor(player)[id] = nil
					changed = true
					notify(player, "An order expired. No big deal, new ones are coming.")
				end
			end
			if changed then
				push(player)
			end
			ensureFirstOrder(player)
			if spawnNow then
				spawnRandomOrder(player)
			end
		end
	end
end

return OrderService
