--!strict
-- Customers text you orders; you deliver batches and they react based on taste, Appeal and quality.
-- Delivery is a phone "hand over" for now. Walking to meetup spots comes with the world build.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomerTemplates = require(ReplicatedStorage.Shared.Config.Customers)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)

local ORDER_INTERVAL = 30 -- seconds between new orders per player
local MAX_ACTIVE_ORDERS = 3
local ORDER_LIFETIME = 300 -- seconds before an order expires
local REL_LEVELS = { { 0, "Stranger" }, { 10, "Customer" }, { 30, "Regular" }, { 70, "Fan" }, { 150, "Superfan" } }

local ORDER_TEXT: { [string]: string } = {
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

type Order = {
	id: number,
	customerId: string,
	count: number,
	offer: number,
	expires: number,
}

local orders: { [Player]: { [number]: Order } } = {}
local nextOrderId = 1
local templatesById: { [string]: any } = {}
for _, t in CustomerTemplates do
	templatesById[t.id] = t
end

local CustomerService = {}

local function relLevel(points: number): string
	local name = REL_LEVELS[1][2]
	for _, entry in REL_LEVELS do
		if points >= entry[1] then
			name = entry[2]
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
	return {
		id = order.id,
		customerName = t.name,
		personality = t.personality,
		text = (ORDER_TEXT[t.personality] :: string):gsub("{count}", tostring(order.count)),
		count = order.count,
		offer = order.offer,
		expires = order.expires,
	}
end

local function spawnOrder(player: Player)
	local data = PlayerDataService:Get(player)
	if not data then
		return
	end
	local active = activeFor(player)
	local activeCount, busy = 0, {}
	for _, o in active do
		activeCount += 1
		busy[o.customerId] = true
	end
	if activeCount >= MAX_ACTIVE_ORDERS then
		return
	end
	local pool = {}
	for _, t in CustomerTemplates do
		local s = customerState(data, t.id)
		if not busy[t.id] then
			table.insert(pool, t)
		end
	end
	if #pool == 0 then
		return
	end
	local t = pool[math.random(#pool)]
	local count = math.random(2, 6)
	local order: Order = {
		id = nextOrderId,
		customerId = t.id,
		count = count,
		offer = math.floor(count * t.budget / 6 + 0.5) + 3,
		expires = os.time() + ORDER_LIFETIME,
	}
	nextOrderId += 1
	active[order.id] = order
	Remotes.event("OrderReceived"):FireClient(player, view(order))
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

function CustomerService:Init()
	Remotes.func("DeliverOrder").OnServerInvoke = function(player: Player, orderId: any, batchId: any)
		local data = PlayerDataService:Get(player)
		local order = if type(orderId) == "number" then activeFor(player)[orderId] else nil
		if not data or not order or type(batchId) ~= "number" then
			return false, "that order is gone"
		end
		local index
		for i, b in data.batches do
			if b.id == batchId then
				index = i
			end
		end
		if not index then
			return false, "pick a batch to deliver"
		end
		local batch = data.batches[index]
		if batch.count < order.count then
			return false, `they want {order.count} cookies, that batch only has {batch.count}`
		end

		batch.count -= order.count
		if batch.count <= 0 then
			table.remove(data.batches, index)
		end
		activeFor(player)[orderId] = nil

		local t = templatesById[order.customerId]
		local state = customerState(data, t.id)
		local sat = satisfaction(batch, t)

		local pay = math.floor(order.offer * (0.5 + sat) + 0.5)
		if sat > 0.85 then
			pay += math.floor(order.offer * 0.2)
		end
		EconomyService:AddCash(player, pay)
		EconomyService:AddXp(player, math.floor(10 + sat * 20))

		state.rel = math.max(0, state.rel + math.floor(sat * 10) - 4)
		table.insert(state.memory, { name = batch.name, quality = batch.quality, appeal = batch.appeal, sat = sat })
		if #state.memory > 5 then
			table.remove(state.memory, 1)
		end

		local pool = if sat > 0.75 then REACTIONS.great elseif sat > 0.45 then REACTIONS.ok else REACTIONS.bad
		PlayerDataService:Replicate(player)
		return true, {
			customerName = t.name,
			pay = pay,
			satisfaction = sat,
			reaction = pool[math.random(#pool)],
			relationship = relLevel(state.rel),
		}
	end

	Remotes.func("DeclineOrder").OnServerInvoke = function(player: Player, orderId: any)
		local data = PlayerDataService:Get(player)
		local order = if type(orderId) == "number" then activeFor(player)[orderId] else nil
		if not data or not order then
			return false
		end
		activeFor(player)[orderId] = nil
		local state = customerState(data, order.customerId)
		state.rel = math.max(0, state.rel - 1)
		PlayerDataService:Replicate(player)
		return true
	end

	Players.PlayerRemoving:Connect(function(p)
		orders[p] = nil
	end)
end

function CustomerService:Start()
	while true do
		task.wait(ORDER_INTERVAL)
		for _, player in Players:GetPlayers() do
			local active = activeFor(player)
			for id, o in active do
				if os.time() >= o.expires then
					active[id] = nil
					local data = PlayerDataService:Get(player)
					if data then
						local s = customerState(data, o.customerId)
						s.rel = math.max(0, s.rel - 1)
					end
					Remotes.event("OrderExpired"):FireClient(player, id)
				end
			end
			spawnOrder(player)
		end
	end
end

return CustomerService
