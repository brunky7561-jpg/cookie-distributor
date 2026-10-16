--!strict
-- Buying equipment. The server checks the id, what is already owned, the unlock and the price.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)

local EquipmentService = {}

-- Effective stats for this player's best equipment in each category.
function EquipmentService:Effects(player: Player): { [string]: number }
	local data = PlayerDataService:Get(player)
	return Equipment.effective(if data then data.equipment else {})
end

function EquipmentService:Init()
	Remotes.func("BuyEquipment").OnServerInvoke = function(player: Player, id: any)
		if not RateLimit.check(player, "BuyEquipment", 0.3) then
			return false, "slow down a little"
		end
		local data = PlayerDataService:Get(player)
		local def = if type(id) == "string" then Equipment.catalog[id] else nil
		if not data or not def or def.price <= 0 then
			return false, "that item is not for sale"
		end
		if data.equipment[def.id] then
			return false, "you already own that"
		end
		if def.requiresMilestone and not data.milestones[def.requiresMilestone] then
			return false, "finish your first order to unlock this"
		end
		if not EconomyService:TrySpend(player, def.price) then
			return false, `you need ${def.price}`
		end
		data.equipment[def.id] = true
		EconomyService:Record(player, "other", def.price)
		PlayerDataService:Replicate(player)
		return true, `Bought the {def.name}!`
	end
end

function EquipmentService:Start() end

return EquipmentService
