--!strict
-- The only place that adds or removes ingredients and packaged batches. Every change is checked here so
-- ingredients are consumed exactly once and cookies are handed over exactly once.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)
local PlayerDataService = require(script.Parent.PlayerDataService)

local MAX_BATCHES_STORED = 30

local InventoryService = {}

function InventoryService:Count(player: Player, id: string): number
	local data = PlayerDataService:Get(player)
	return if data then data.ingredients[id] or 0 else 0
end

-- Returns nil if the player has everything, otherwise a short sentence naming what is missing.
function InventoryService:Missing(player: Player, need: { [string]: number }): string?
	local data = PlayerDataService:Get(player)
	if not data then
		return "your data is still loading"
	end
	for id, n in need do
		local have = data.ingredients[id] or 0
		if have < n then
			local ing = Ingredients[id]
			return `you need {n} {if ing then ing.name else id} but only have {have}`
		end
	end
	return nil
end

-- All-or-nothing: either every ingredient is removed or none are.
function InventoryService:Consume(player: Player, need: { [string]: number }): boolean
	local data = PlayerDataService:Get(player)
	if not data or InventoryService:Missing(player, need) then
		return false
	end
	for id, n in need do
		data.ingredients[id] -= n
	end
	PlayerDataService:Replicate(player)
	return true
end

function InventoryService:Add(player: Player, id: string, qty: number)
	local data = PlayerDataService:Get(player)
	if data and Ingredients[id] and qty > 0 then
		data.ingredients[id] = (data.ingredients[id] or 0) + qty
		PlayerDataService:Replicate(player)
	end
end

function InventoryService:HasRoomForBatch(player: Player): boolean
	local data = PlayerDataService:Get(player)
	return data ~= nil and #data.batches < MAX_BATCHES_STORED
end

function InventoryService:AddBatch(player: Player, batch: any)
	local data = PlayerDataService:Get(player)
	if data then
		table.insert(data.batches, batch)
		PlayerDataService:Replicate(player)
	end
end

function InventoryService:FindBatch(player: Player, batchId: number): any?
	local data = PlayerDataService:Get(player)
	if not data then
		return nil
	end
	for _, b in data.batches do
		if b.id == batchId then
			return b
		end
	end
	return nil
end

function InventoryService:Reserve(player: Player, batchId: number, orderId: number): boolean
	local batch = InventoryService:FindBatch(player, batchId)
	if not batch or batch.reservedFor then
		return false
	end
	batch.reservedFor = orderId
	PlayerDataService:Replicate(player)
	return true
end

function InventoryService:Release(player: Player, batchId: number)
	local batch = InventoryService:FindBatch(player, batchId)
	if batch then
		batch.reservedFor = nil
		PlayerDataService:Replicate(player)
	end
end

-- Removes qty cookies from a batch (deleting the batch when empty). Returns false if there are not enough.
function InventoryService:TakeCookies(player: Player, batchId: number, qty: number): boolean
	local data = PlayerDataService:Get(player)
	if not data then
		return false
	end
	for i, b in data.batches do
		if b.id == batchId then
			if b.count < qty then
				return false
			end
			b.count -= qty
			b.reservedFor = nil
			if b.count <= 0 then
				table.remove(data.batches, i)
			end
			PlayerDataService:Replicate(player)
			return true
		end
	end
	return false
end

function InventoryService:NextBatchId(player: Player): number
	local data = PlayerDataService:Get(player)
	if not data then
		return 0
	end
	local id = data.nextBatchId
	data.nextBatchId += 1
	return id
end

function InventoryService:Init() end

function InventoryService:Start() end

return InventoryService
