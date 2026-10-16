--!strict
-- Properties and the storefront. Buying is validated here (level, cash, not already owned). Owning a property raises
-- storage, adds a delivery mat, and from the food truck up adds a display case: batches you put on display are sold to
-- walk-in customers in rounds while you play. Rent is charged per "day"; if you cannot pay, the storefront simply
-- closes for that day - nothing is ever taken away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Properties = require(ReplicatedStorage.Shared.Config.Properties)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)

local SALE_ROUND = 20 -- seconds between walk-in rounds
local DAY = 600 -- seconds per rent day
local BASE_PRICE = 2.2 -- per cookie, before quality and recipe multipliers

local closed: { [Player]: boolean } = {}
local lastRent: { [Player]: number } = {}
local lastSale: { [Player]: number } = {}

local PropertyService = {}

local function notify(player: Player, text: string)
	Remotes.event("Notify"):FireClient(player, text)
end

local function ownedDisplaySlots(data: any): number
	local n = 0
	for id in data.properties do
		local def = Properties[id]
		if def and def.display then
			n += def.display
		end
	end
	return n
end

local function walkInCapacity(data: any): number
	local n = 0
	for id in data.properties do
		local def = Properties[id]
		if def and def.walkIn then
			n += def.walkIn
		end
	end
	return n
end

local function displayedBatches(data: any): { any }
	local out = {}
	for _, b in data.batches do
		if b.displayed then
			table.insert(out, b)
		end
	end
	return out
end

-- Price one walk-in customer pays for one cookie from this batch.
function PropertyService.walkInPrice(batch: any): number
	local recipe = if batch.recipeId then Recipes.catalog[batch.recipeId] else nil
	local mult = if recipe then recipe.priceMult or 1 else 1.1
	return math.floor(BASE_PRICE * mult * (0.5 + batch.quality) * 10 + 0.5) / 10
end

-- One round of walk-in sales. Returns cookies sold. Exposed so tests can drive it.
function PropertyService:SellRound(player: Player): number
	local data = PlayerDataService:Get(player)
	if not data or closed[player] then
		return 0
	end
	local budget = walkInCapacity(data)
	local sold, earned = 0, 0
	for _, b in displayedBatches(data) do
		while budget > 0 and b.count > 0 do
			b.count -= 1
			budget -= 1
			sold += 1
			earned += PropertyService.walkInPrice(b)
		end
		if b.count <= 0 then
			for i, x in data.batches do
				if x == b then
					table.remove(data.batches, i)
					break
				end
			end
		end
		if budget <= 0 then
			break
		end
	end
	if sold > 0 then
		earned = math.floor(earned)
		EconomyService:AddCash(player, earned)
		EconomyService:Record(player, "gross", earned)
		EconomyService:AddXp(player, math.ceil(sold / 2))
		data.stats.walkIn = (data.stats.walkIn or 0) + sold
		notify(player, `Walk-in customers bought {sold} cookies for ${earned}.`)
	end
	return sold
end

-- Charges rent for every owned property. Returns true if all rent was paid.
function PropertyService:ChargeRent(player: Player): boolean
	local data = PlayerDataService:Get(player)
	if not data then
		return true
	end
	local due = 0
	for id in data.properties do
		local def = Properties[id]
		if def then
			due += def.dailyCost
		end
	end
	if due == 0 then
		closed[player] = false
		return true
	end
	if EconomyService:TrySpend(player, due) then
		EconomyService:Record(player, "other", due)
		closed[player] = false
		notify(player, `Paid ${due} rent for your properties.`)
		return true
	end
	closed[player] = true
	notify(player, `You could not pay ${due} rent, so your storefront is closed until you can. Orders still work.`)
	PlayerDataService:Replicate(player)
	return false
end

function PropertyService:IsClosed(player: Player): boolean
	return closed[player] == true
end

local function describe(data: any, player: Player): any
	return {
		displaySlots = ownedDisplaySlots(data),
		displayed = #displayedBatches(data),
		closed = closed[player] == true,
	}
end

function PropertyService:Init()
	Remotes.func("PropertyBuy").OnServerInvoke = function(player: Player, propertyId: any): (boolean, string)
		if not RateLimit.check(player, "PropertyBuy", 0.5) then
			return false, "slow down a little"
		end
		local data = PlayerDataService:Get(player)
		local def = if type(propertyId) == "string" then Properties[propertyId] else nil
		if not data or not def then
			return false, "unknown property"
		end
		if data.properties[def.id] then
			return false, "you already own that"
		end
		if data.level < (def.unlockLevel or 1) then
			return false, `Reach level {def.unlockLevel} to buy the {def.name}.`
		end
		if not EconomyService:TrySpend(player, def.price) then
			return false, `You need ${def.price} for the {def.name}.`
		end
		data.properties[def.id] = true
		EconomyService:Record(player, "other", def.price)
		EconomyService:AddXp(player, 50)
		closed[player] = false
		PlayerDataService:Replicate(player)
		return true, `You bought the {def.name}!`
	end

	Remotes.func("DisplaySet").OnServerInvoke = function(player: Player, batchId: any, on: any): (boolean, string)
		if not RateLimit.check(player, "DisplaySet", 0.2) then
			return false, "slow down a little"
		end
		local data = PlayerDataService:Get(player)
		if not data or type(batchId) ~= "number" or type(on) ~= "boolean" then
			return false, "bad request"
		end
		local batch
		for _, b in data.batches do
			if b.id == batchId then
				batch = b
			end
		end
		if not batch then
			return false, "that batch is gone"
		end
		if on then
			if batch.displayed then
				return true, "already on display"
			end
			if batch.reservedFor then
				return false, "that box is promised to an order"
			end
			if #displayedBatches(data) >= ownedDisplaySlots(data) then
				return false, if ownedDisplaySlots(data) == 0 then "You need a Food Truck or bigger to run a display case." else "Your display case is full."
			end
			batch.displayed = true
		else
			batch.displayed = false
		end
		PlayerDataService:Replicate(player)
		return true, if on then "On display. Walk-in customers will buy it." else "Back in stock."
	end

	Remotes.func("StorefrontStatus").OnServerInvoke = function(player: Player)
		local data = PlayerDataService:Get(player)
		return if data then describe(data, player) else nil
	end

	Players.PlayerRemoving:Connect(function(p)
		closed[p] = nil
		lastRent[p] = nil
		lastSale[p] = nil
	end)
end

function PropertyService:Start()
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for _, p in Players:GetPlayers() do
				local data = PlayerDataService:Get(p)
				if data then
					lastRent[p] = lastRent[p] or now
					lastSale[p] = lastSale[p] or now
					if now - lastRent[p] >= DAY then
						lastRent[p] = now
						PropertyService:ChargeRent(p)
					end
					if now - lastSale[p] >= SALE_ROUND then
						lastSale[p] = now
						PropertyService:SellRound(p)
					end
				end
			end
		end
	end)
end

return PropertyService
