--!strict
-- Server-side baking station. One session per player walks through Mix -> Portion -> Bake -> Cool -> Package.
-- The server times every step with os.clock; the client only draws bars and can never send a quality score.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Baking = require(ReplicatedStorage.Shared.Config.Baking)
local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local AppealCalc = require(ReplicatedStorage.Shared.Modules.AppealCalc)
local Quality = require(ReplicatedStorage.Shared.Modules.Quality)
local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local InteractionService = require(script.Parent.InteractionService)
local EquipmentService = require(script.Parent.EquipmentService)
local OrderService = require(script.Parent.OrderService)

type Stage = "mix" | "portion" | "bake" | "cool" | "package"

type Session = {
	recipeId: string,
	orderId: number?,
	ingredients: { string },
	bakeSlack: number, -- seconds of forgiveness from the oven the session started with
	stage: Stage,
	running: boolean, -- true while a timing bar is live (portion, bake)
	t0: number,
	portion: number,
	bake: number,
	bakeSigned: number,
	coolEnd: number,
}

local sessions: { [Player]: Session } = {}

local BakingService = {}

local function expand(requires: { [string]: number }): { string }
	local list = {}
	for id, n in requires do
		for _ = 1, n do
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

local function describe(s: Session): any
	return {
		stage = s.stage,
		running = s.running,
		recipeId = s.recipeId,
		orderId = s.orderId,
		bakeSlack = s.bakeSlack,
		coolRemaining = math.max(0, s.coolEnd - os.clock()),
		elapsed = if s.running then os.clock() - s.t0 else 0, -- lets a reopened UI resume its timing bar
	}
end

local function finish(player: Player, s: Session): (boolean, any)
	local data = PlayerDataService:Get(player)
	local recipe = Recipes.catalog[s.recipeId]
	if not data then
		return false, "your data is still loading"
	end
	sessions[player] = nil

	-- Ingredients have no spoilage yet, and the guided recipe is always followed exactly, so those two factors
	-- are full marks until freshness (Milestone 2+) and free-form recipes (Milestone 4) exist.
	local factors: Quality.Factors = { recipe = 1, bake = s.bake, fresh = 1, portion = s.portion }
	local score = Quality.score(factors)
	local quality = score / 100
	local appeal = AppealCalc.compute(s.ingredients, quality)

	local tagSet: { [string]: boolean } = {}
	for _, id in s.ingredients do
		for _, t in Ingredients[id].tags do
			tagSet[t] = true
		end
	end
	local tags = {}
	for t in tagSet do
		table.insert(tags, t)
	end
	table.sort(tags)

	local batch = {
		id = InventoryService:NextBatchId(player),
		name = recipe.name,
		recipeId = recipe.id,
		ingredients = s.ingredients,
		tags = tags,
		quality = quality,
		score = score,
		grade = Quality.grade(score),
		feedback = Quality.feedback(factors, s.bakeSigned),
		factors = factors,
		appeal = appeal.score,
		effects = appeal.effects,
		count = recipe.yield,
		packaged = true,
	}
	InventoryService:AddBatch(player, batch)

	if not data.recipes[recipe.id] then
		data.recipes[recipe.id] = true
		EconomyService:AddXp(player, 25) -- first time baking this recipe
	end
	EconomyService:AddXp(player, math.floor(5 + quality * 15))

	local linked = false
	if s.orderId then
		linked = OrderService:MarkReady(player, s.orderId, batch.id)
	end
	PlayerDataService:Replicate(player)
	return true, { batch = batch, linkedOrder = linked, orderId = s.orderId }
end

function BakingService:Init()
	Remotes.func("BakeStatus").OnServerInvoke = function(player: Player)
		local s = sessions[player]
		return if s then describe(s) else nil
	end

	Remotes.func("BakeStart").OnServerInvoke = function(player: Player, recipeId: any, orderId: any)
		if not RateLimit.check(player, "BakeStart", 0.5) then
			return false, "slow down a little"
		end
		local data = PlayerDataService:Get(player)
		if not data or type(recipeId) ~= "string" then
			return false, "cannot start a bake right now"
		end
		if sessions[player] then
			return false, "you already have a bake in progress"
		end
		local recipe = Recipes.catalog[recipeId]
		if not recipe then
			return false, "unknown recipe"
		end
		if not InteractionService:IsNearStation(player, "BakeStation") then
			return false, "walk up to your kitchen counter or oven first"
		end
		if not InventoryService:HasRoomForBatch(player) then
			return false, "storage is full, deliver or use some cookies first"
		end
		if orderId ~= nil then
			if type(orderId) ~= "number" or not OrderService:CanProduce(player, orderId, recipeId) then
				return false, "that order cannot be baked for right now"
			end
		end
		local missing = InventoryService:Missing(player, recipe.requires)
		if missing then
			return false, `Not enough ingredients: {missing}. Order more with PantryDash on your phone (P).`
		end

		-- Everything is validated above and nothing yields below, so these steps cannot be interrupted.
		InventoryService:Consume(player, recipe.requires)
		if orderId ~= nil then
			OrderService:BeginProduction(player, orderId :: number)
		end
		local s: Session = {
			recipeId = recipeId,
			orderId = orderId :: number?,
			ingredients = expand(recipe.requires),
			bakeSlack = EquipmentService:Effects(player).bakeSlack,
			stage = "mix",
			running = false,
			t0 = os.clock(),
			portion = 0,
			bake = 0,
			bakeSigned = 0,
			coolEnd = 0,
		}
		sessions[player] = s
		return true, describe(s)
	end

	Remotes.func("BakeStep").OnServerInvoke = function(player: Player, action: any, arg: any)
		if not RateLimit.check(player, "BakeStep", 0.15) then
			return false, "slow down a little"
		end
		local s = sessions[player]
		if not s or type(action) ~= "string" then
			return false, "no bake in progress"
		end
		local now = os.clock()

		if action == "mixDone" and s.stage == "mix" then
			if now - s.t0 < Baking.MIX_MIN then
				return false, "keep stirring a little longer"
			end
			s.stage = "portion"
			s.running = false
			return true, describe(s)
		elseif action == "portionStart" and s.stage == "portion" and not s.running then
			s.running = true
			s.t0 = now
			return true, describe(s)
		elseif action == "portionStop" and s.stage == "portion" and s.running then
			s.portion = Quality.timing(now - s.t0, Baking.PORTION_IDEAL)
			s.stage = "bake"
			s.running = false
			local info = describe(s)
			info.portionScore = s.portion
			return true, info
		elseif action == "ovenStart" and s.stage == "bake" and not s.running then
			s.running = true
			s.t0 = now
			return true, describe(s)
		elseif action == "ovenPull" and s.stage == "bake" and s.running then
			local elapsed = now - s.t0
			s.bake = Quality.timing(elapsed, Baking.BAKE_IDEAL, s.bakeSlack)
			s.bakeSigned = elapsed - Baking.BAKE_IDEAL
			s.stage = "cool"
			s.running = false
			s.coolEnd = now + Baking.COOL_TIME
			local info = describe(s)
			info.bakeScore = s.bake
			return true, info
		elseif action == "coolDone" and s.stage == "cool" then
			if now < s.coolEnd then
				return false, "the tray is still cooling"
			end
			s.stage = "package"
			return true, describe(s)
		elseif action == "pack" and s.stage == "package" then
			local recipe = Recipes.catalog[s.recipeId]
			local box
			for _, b in Recipes.boxes do
				if b.id == arg then
					box = b
				end
			end
			if not box then
				return false, "pick a box"
			end
			if box.size ~= recipe.yield then
				return false, `That box holds {box.size}; this tray has {recipe.yield} cookies.`
			end
			return finish(player, s)
		end
		return false, "that step does not fit right now"
	end

	PlayerDataService.Reset:Connect(function(p)
		sessions[p] = nil
	end)
	Players.PlayerRemoving:Connect(function(p)
		sessions[p] = nil
	end)
end

function BakingService:Start() end

return BakingService
