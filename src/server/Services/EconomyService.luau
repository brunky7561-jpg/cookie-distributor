--!strict
-- Owns cash, XP and the ledger. Amounts are only ever changed here, never by the client.
local PlayerDataService = require(script.Parent.PlayerDataService)

local XP_PER_LEVEL = 100 -- level n needs n * XP_PER_LEVEL to reach n + 1

local EconomyService = {}

function EconomyService:AddCash(player: Player, amount: number)
	local data = PlayerDataService:Get(player)
	if data then
		data.cash += amount
		PlayerDataService:Replicate(player)
	end
end

-- Ledger bookkeeping: kind is one of gross, supplies, wages, delivery, other. Amounts are always positive.
function EconomyService:Record(player: Player, kind: string, amount: number)
	local data = PlayerDataService:Get(player)
	if data and data.stats[kind] ~= nil and amount > 0 then
		data.stats[kind] += math.floor(amount)
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

function EconomyService:Init() end

function EconomyService:Start() end

return EconomyService
