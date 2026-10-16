--!strict
-- Awards business milestones from saved data and keeps new players out of dead ends.
--  * Milestones: checked whenever a profile changes; each one is awarded once.
--  * Recovery: a player with no cash, no ingredients, no cookies and no order in progress gets a small
--    supply kit (at most one per RECOVERY_COOLDOWN), so a bad purchase can never end the game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AppsConfig = require(ReplicatedStorage.Shared.Config.Apps)
local Milestones = require(ReplicatedStorage.Shared.Config.Milestones)
local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)

local RECOVERY_COOLDOWN = 300 -- seconds
local RECOVERY_CASH_LIMIT = 10 -- only when this poor
local RECOVERY_KIT: { [string]: number } = { flour = 2, butter = 1, white_sugar = 1, chocolate_chips = 1 }

local lastKit: { [Player]: number } = {}
local checking: { [Player]: boolean } = {}

local ProgressService = {}

local function canBakeSomething(data: any): boolean
	for _, recipe in Recipes.catalog do
		local ok = true
		for id, n in recipe.requires do
			if (data.ingredients[id] or 0) < n then
				ok = false
			end
		end
		if ok then
			return true
		end
	end
	return false
end

function ProgressService:Check(player: Player)
	local data = PlayerDataService:Get(player)
	if not data or checking[player] then
		return
	end
	checking[player] = true
	local changed = false
	for _, m in Milestones.list do
		if not data.milestones[m.id] and m.done(data) then
			data.milestones[m.id] = true
			changed = true
			Remotes.event("Notify"):FireClient(player, `Milestone reached: {m.title}`)
		end
	end

	if data.cash <= RECOVERY_CASH_LIMIT and #data.batches == 0 and not canBakeSomething(data) then
		local now = os.clock()
		if now - (lastKit[player] or -math.huge) >= RECOVERY_COOLDOWN then
			lastKit[player] = now
			for id, n in RECOVERY_KIT do
				InventoryService:Add(player, id, n)
			end
			Remotes.event("Notify"):FireClient(player, "A neighbor left a basket of baking supplies on your doorstep. Back to work!")
			changed = true
		end
	end
	checking[player] = nil
	if changed then
		PlayerDataService:Replicate(player)
	end
end

function ProgressService:Init()
	-- The phone tells us an app was opened so its "NEW" badge goes away for good.
	Remotes.func("SeenApp").OnServerInvoke = function(player: Player, appId: any)
		if not RateLimit.check(player, "SeenApp", 0.2) then
			return false
		end
		local data = PlayerDataService:Get(player)
		local def = if type(appId) == "string" then AppsConfig.byId[appId] else nil
		if not data or not def or not def.unlock(data) then
			return false
		end
		if not data.settings.seenApps[def.id] then
			data.settings.seenApps[def.id] = true
			PlayerDataService:Replicate(player)
		end
		return true
	end
end

function ProgressService:Start()
	PlayerDataService.Changed:Connect(function(player: Player)
		ProgressService:Check(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastKit[p] = nil
		checking[p] = nil
	end)
end

return ProgressService
