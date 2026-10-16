--!strict
-- Owns cash, XP and the ingredient shop. All amounts are validated here, never on the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)
local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)

local MAX_BUY = 50
local XP_PER_LEVEL = 100 -- level n needs n * XP_PER_LEVEL to reach n + 1
local RARE_UNLOCK_LEVEL = 5

local EconomyService = {}

function EconomyService:AddCash(player: Player, amount: number)
	local data = PlayerDataService:Get(player)
	if data then
		data.cash += amount
		PlayerDataService:Replicate(player)
	end
end

function EconomyService:TrySpend(player: Player, amount: number): boolean
	local data = PlayerDataService:Get(player)
	if not data or amount < 0 or data.cash < amount then
		return false
	end
	data.cash -= amount
	PlayerDataService:Replicate(player)
	return true
end

function EconomyService:AddXp(player: Player, amount: number)
	local data = PlayerDataService:Get(player)
	if not data then
		return
	end
	data.xp += amount
	while data.xp >= data.level * XP_PER_LEVEL do
		data.xp -= data.level * XP_PER_LEVEL
		data.level += 1
	end
	PlayerDataService:Replicate(player)
end

function EconomyService:Init()
	Remotes.func("BuyIngredient").OnServerInvoke = function(player: Player, id: any, qty: any)
		if not RateLimit.check(player, "BuyIngredient", 0.1) then
			return false, "slow down"
		end
		if type(id) ~= "string" or type(qty) ~= "number" or qty ~= qty then
			return false, "bad request"
		end
		qty = math.floor(qty)
		local ing = Ingredients[id]
		local data = PlayerDataService:Get(player)
		if not ing or not data or qty < 1 or qty > MAX_BUY then
			return false, "bad request"
		end
		if table.find(ing.tags, "rare") and data.level < RARE_UNLOCK_LEVEL then
			return false, `rare ingredients unlock at level {RARE_UNLOCK_LEVEL}`
		end
		if not EconomyService:TrySpend(player, ing.cost * qty) then
			return false, "not enough cash"
		end
		InventoryService:Add(player, id, qty)
		return true
	end
end

function EconomyService:Start() end

return EconomyService
