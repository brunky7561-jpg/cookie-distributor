--!strict
-- Market: rotating events (see Config/Market), rival-backed contracts, and a lifetime-earnings leaderboard.
-- A contract is one big order at a time: deliver 12 cookies of one recipe at a minimum score before it expires. If you
-- let it expire, a rival wins it - there is no other penalty. The leaderboard is best-effort: if the ordered store is
-- unavailable the game simply shows an empty board.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Market = require(ReplicatedStorage.Shared.Config.Market)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)

local BOARD_NAME = "LifetimeGross_v1"
local BOARD_TTL = 60

local board: { { name: string, gross: number } } = {}
local boardAt = -math.huge

local MarketService = {}

local function notify(player: Player, text: string)
	Remotes.event("Notify"):FireClient(player, text)
end

-- Creates a contract if the player has none and the cooldown is over; expires an old one. Returns true if data changed.
function MarketService:Refresh(player: Player): boolean
	local data = PlayerDataService:Get(player)
	if not data or data.level < 2 then
		return false
	end
	local now = os.time()
	local changed = false
	local c = data.contract
	if c and now >= c.expiresAt then
		local rival = "A rival"
		for _, r in Market.rivals do
			if r.id == c.rivalId then
				rival = r.name
			end
		end
		data.contract = false
		data.contractLosses += 1
		data.contractNextAt = now + Market.CONTRACT_COOLDOWN
		notify(player, `{rival} won the contract you did not finish. More will come.`)
		changed = true
	end
	if not data.contract and now >= data.contractNextAt then
		local pool = {}
		for id in data.recipes do
			if Recipes.catalog[id] then
				table.insert(pool, id)
			end
		end
		table.sort(pool)
		if #pool > 0 then
			local recipeId = pool[math.random(#pool)]
			local recipe = Recipes.catalog[recipeId]
			local rival = Market.rivals[math.random(#Market.rivals)]
			local per = (Market.CONTRACT_COUNT * 45 / 6 + 3) * (recipe.priceMult or 1)
			data.contract = {
				rivalId = rival.id,
				recipeId = recipeId,
				count = Market.CONTRACT_COUNT,
				minScore = Market.CONTRACT_MIN_SCORE,
				pay = math.floor(per * Market.CONTRACT_PREMIUM + 0.5),
				expiresAt = now + Market.CONTRACT_LIFETIME,
			}
			notify(player, `New contract: {recipe.name} for ${data.contract.pay}. {rival.name} wants it too.`)
			changed = true
		end
	end
	if changed then
		PlayerDataService:Replicate(player)
	end
	return changed
end

-- Hands over matching cookies. Atomic: either the whole contract is filled or nothing changes.
function MarketService:Fulfil(player: Player): (boolean, string)
	local data = PlayerDataService:Get(player)
	if not data then
		return false, "loading"
	end
	MarketService:Refresh(player)
	local c = data.contract
	if not c then
		return false, "you have no contract right now"
	end
	local usable = {}
	local have = 0
	for _, b in data.batches do
		if b.recipeId == c.recipeId and b.score >= c.minScore and not b.displayed and not b.reservedFor then
			table.insert(usable, b)
			have += b.count
		end
	end
	if have < c.count then
		return false, `Need {c.count} {Recipes.catalog[c.recipeId].name} cookies at score {c.minScore}+ (not on display or promised). You have {have}.`
	end
	local left = c.count
	local tags = usable[1].tags
	for _, b in usable do
		if left <= 0 then
			break
		end
		local take = math.min(b.count, left)
		InventoryService:TakeCookies(player, b.id, take)
		left -= take
	end
	local pay = math.floor(c.pay * Market.eventMult(Market.currentEvent(os.time()), tags) + 0.5)
	data.contract = false
	data.contractWins += 1
	data.contractNextAt = os.time() + Market.CONTRACT_COOLDOWN
	data.reputation += Market.CONTRACT_REPUTATION
	EconomyService:AddCash(player, pay)
	EconomyService:Record(player, "gross", pay)
	EconomyService:AddXp(player, 60)
	PlayerDataService:Replicate(player)
	return true, `Contract complete! You earned ${pay} and {Market.CONTRACT_REPUTATION} reputation.`
end

local function pushScore(player: Player)
	local data = PlayerDataService:Get(player)
	if not data or not PlayerDataService:IsPersistent(player) then
		return
	end
	pcall(function()
		DataStoreService:GetOrderedDataStore(BOARD_NAME):SetAsync(tostring(player.UserId), data.stats.gross)
	end)
end

function MarketService:Board(): { { name: string, gross: number } }
	if os.clock() - boardAt < BOARD_TTL then
		return board
	end
	boardAt = os.clock()
	local ok, pages = pcall(function()
		return DataStoreService:GetOrderedDataStore(BOARD_NAME):GetSortedAsync(false, 10)
	end)
	if ok and pages then
		local out = {}
		local okp, items = pcall(function()
			return pages:GetCurrentPage()
		end)
		if okp then
			for _, item in items do
				local name = "Baker"
				local okn, n = pcall(function()
					return Players:GetNameFromUserIdAsync(tonumber(item.key) or 0)
				end)
				if okn and type(n) == "string" then
					name = n
				end
				table.insert(out, { name = name, gross = item.value })
			end
			board = out
		end
	end
	return board
end

function MarketService:Init()
	Remotes.func("MarketStatus").OnServerInvoke = function(player: Player): any
		if not RateLimit.check(player, "MarketStatus", 1) then
			return nil
		end
		MarketService:Refresh(player)
		local now = os.time()
		return { event = Market.currentEvent(now), secondsLeft = Market.secondsLeft(now), board = MarketService:Board() }
	end
	Remotes.func("ContractDeliver").OnServerInvoke = function(player: Player): (boolean, string)
		if not RateLimit.check(player, "ContractDeliver", 0.5) then
			return false, "slow down a little"
		end
		return MarketService:Fulfil(player)
	end
	Players.PlayerRemoving:Connect(pushScore)
end

function MarketService:Start()
	task.spawn(function()
		while true do
			task.wait(60)
			for _, p in Players:GetPlayers() do
				MarketService:Refresh(p)
				pushScore(p)
			end
		end
	end)
end

return MarketService
