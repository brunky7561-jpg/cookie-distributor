--!strict
-- Studio-only test shortcut: "Dev: unlock everything" jumps to a late-game save so every phone app, property, vehicle and
-- recipe can be seen at once. Refused for everyone outside Studio unless their UserId is in DEV_USER_IDS.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)
local Properties = require(ReplicatedStorage.Shared.Config.Properties)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local DEV_USER_IDS: { [number]: boolean } = {}

local DevService = {}

function DevService:Boost(player: Player): boolean
	local data = PlayerDataService:Get(player)
	if not data or not (RunService:IsStudio() or DEV_USER_IDS[player.UserId]) then
		return false
	end
	data.level = math.max(data.level, 8)
	data.cash = math.max(data.cash, 25000)
	data.milestones.firstOrderDone = true
	for id in Recipes.catalog do
		data.recipes[id] = true
	end
	for id in Properties do
		data.properties[id] = true
	end
	for id in Vehicles.catalog do
		data.vehicles[id] = true
	end
	for id in Equipment.catalog do
		data.equipment[id] = true
	end
	for id in Ingredients do
		data.ingredients[id] = math.max(data.ingredients[id] or 0, 12)
	end
	data.contractNextAt = 0
	PlayerDataService:Replicate(player)
	return true
end

function DevService:Init()
	Remotes.func("DevBoost").OnServerInvoke = function(player: Player): boolean
		if not RateLimit.check(player, "DevBoost", 1) then
			return false
		end
		return DevService:Boost(player)
	end
end

function DevService:Start() end

return DevService
