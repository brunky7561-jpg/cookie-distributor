--!strict
-- Server-side baking station. One session per player walks through Mix -> Portion -> Bake -> Cool -> Package.
-- The server times every step with os.clock; the client only draws bars and can never send a quality score.
-- Recipes are named combinations of slots (see Config/Recipes). Anything else is an experiment that is saved to the
-- Recipe Book when it turns out well, and gets better with practice.
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
	recipeId: string, -- catalog id, or "custom:..." for an experiment
	recipeName: string,
	custom: boolean,
	correctness: number, -- 0..1, the recipe factor of the quality score
	orderId: number?,
	ingredients: { string },
	yield: number,
	batchMult: number,
	mixTaps: number,
	mixMin: number,
	coolTime: number,
	bakeSlack: number, -- seconds of forgiveness from the oven the session started with
	stage: Stage,
	running: boolean, -- true while a timing bar is live (portion, bake)
	t0: number,
	mix: number, -- 0..1 from the dough minigame (1 when the client sent nothing, so a miss never blocks progress)
	portion: number,
	bake: number,
	bakeSigned: number,
	coolEnd: number,
}

local sessions: { [Player]: Session } = {}

local BakingService = {}

local function describe(s: Session): any
	return {
		stage = s.stage,
		running = s.running,
		recipeId = s.recipeId,
		recipeName = s.recipeName,
		orderId = s.orderId,
		yield = s.yield,
		batchMult = s.batchMult,
		mixTaps = s.mixTaps,
		mixMin = s.mixMin,
		bakeSlack = s.bakeSlack,
		coolRemaining = math.max(0, s.coolEnd - os.clock()),
		elapsed = if s.running then os.clock() - s.t0 else 0, -- lets a reopened UI resume its timing bar
	}
end

local function customCount(book: { [string]: any }): number
	local n = 0
	for _, e in book do
		if e.custom then
			n += 1
		end
	end
	return n
end

local function finish(player: Player, s: Session): (boolean, any)
	local data = PlayerDataService:Get(player)
	if not data then
		return false, "your data is still loading"
	end
	sessions[player] = nil

	-- Ingredients do not spoil yet, so freshness is full marks until a later milestone gives it meaning.
	local factors: Quality.Factors = { recipe = s.correctness, bake = s.bake, fresh = 1, portion = s.portion, dough = s.mix }
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

	local grade = Quality.grade(score)
	local feedback = Quality.feedback(factors, s.bakeSigned)
	if s.custom and s.correctness < 0.9 and feedback == "Golden edges and even sizes. A perfect little batch." then
		feedback = "A promising experiment. Bake it again to refine the recipe."
	end
	local batch = {
		id = InventoryService:NextBatchId(player),
		name = s.recipeName,
		recipeId = s.recipeId,
		ingredients = s.ingredients,
		tags = tags,
		quality = quality,
		score = score,
		grade = grade,
		feedback = feedback,
		factors = factors,
		appeal = appeal.score,
		effects = appeal.effects,
		count = s.yield,
		packaged = true,
	}
	InventoryService:AddBatch(player, batch)

	-- Recipe Book: practice, best score, and discoveries
	local entry = data.recipeBook[s.recipeId]
	local keepCustom = s.custom and (entry ~= nil or (score >= 50 and customCount(data.recipeBook) < Recipes.MAX_CUSTOM))
	if not s.custom or keepCustom then
		if not entry then
			entry = { name = s.recipeName, bakes = 0, best = 0, grade = "", custom = s.custom }
			data.recipeBook[s.recipeId] = entry
		end
		entry.bakes += 1
		if score >= entry.best then
			entry.best = score
			entry.grade = grade
		end
	end
	local newlyKnown = not s.custom and not data.recipes[s.recipeId]
	if not s.custom then
		data.recipes[s.recipeId] = true
	end
	if newlyKnown then
		Remotes.event("Notify"):FireClient(player, `Discovery! You worked out {s.recipeName}. It's in your Recipe Book now.`)
		EconomyService:AddXp(player, 40)
	elseif entry and entry.bakes == 1 then
		EconomyService:AddXp(player, 25) -- first time baking this recipe
	end
	EconomyService:AddXp(player, math.floor(5 + quality * 15))

	local linked = false
	if s.orderId then
		linked = OrderService:MarkReady(player, s.orderId, batch.id)
	end
	PlayerDataService:Replicate(player)
	return true, { batch = batch, linkedOrder = linked, orderId = s.orderId, discovered = newlyKnown, custom = s.custom }
end

function BakingService:Init()
	Remotes.func("BakeStatus").OnServerInvoke = function(player: Player)
		local s = sessions[player]
		return if s then describe(s) else nil
	end

	Remotes.func("BakeStart").OnServerInvoke = function(player: Player, recipeId: any, orderId: any, options: any): (boolean, any)
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
		local opts: { [string]: any } = if type(options) == "table" then options else {}
		local effects = EquipmentService:Effects(player)

		local mult = opts.batchMult
		if mult == nil then
			mult = 1
		end
		if mult ~= 1 and mult ~= 2 then
			return false, "pick a single or a double batch"
		end
		if mult > effects.maxBatchMult then
			return false, "you need a Stand Mixer to bake double batches"
		end

		-- work out which recipe this is
		local recipe: any
		local custom = false
		if recipeId == "experiment" then
			local slots, err = Recipes.validateSlots(opts.slots)
			if not slots then
				return false, err
			end
			recipe = Recipes.matchCatalog(slots)
			if not recipe then
				custom = true
				local key = "custom:" .. Recipes.keyFor(slots)
				recipe = {
					id = key,
					name = Recipes.customName(slots),
					requires = Recipes.requiresFor(slots),
				}
				if not data.recipeBook[key] and customCount(data.recipeBook) >= Recipes.MAX_CUSTOM then
					return false, "Your Recipe Book has no room for more experiments."
				end
			end
		else
			recipe = Recipes.catalog[recipeId]
			if not recipe then
				return false, "unknown recipe"
			end
			if not data.recipes[recipeId] then
				return false, "you have not unlocked that recipe yet"
			end
		end

		if not InteractionService:IsNearStation(player, "BakeStation") then
			return false, "walk up to your kitchen counter or oven first"
		end
		if not InventoryService:HasRoomForBatch(player) then
			return false, "storage is full, deliver or use some cookies first"
		end
		if orderId ~= nil then
			if type(orderId) ~= "number" or not OrderService:CanProduce(player, orderId, recipe.id, custom) then
				return false, "that order cannot be baked for right now"
			end
		end
		local need: { [string]: number } = {}
		for id, n in recipe.requires do
			need[id] = n * mult
		end
		local missing = InventoryService:Missing(player, need)
		if missing then
			return false, `Not enough ingredients: {missing}. Order more with PantryDash on your phone (P).`
		end

		-- Everything is validated above and nothing yields below, so these steps cannot be interrupted.
		InventoryService:Consume(player, need)
		if orderId ~= nil then
			OrderService:BeginProduction(player, orderId)
		end
		local book = data.recipeBook[recipe.id]
		local correctness = 1
		if custom then
			local bakes = if book then book.bakes else 0
			correctness = Recipes.CUSTOM_CORRECTNESS[math.min(bakes + 1, #Recipes.CUSTOM_CORRECTNESS)]
		end
		local s: Session = {
			recipeId = recipe.id,
			recipeName = recipe.name,
			custom = custom,
			correctness = correctness,
			orderId = orderId,
			ingredients = Recipes.expand(recipe.requires, mult),
			yield = Recipes.YIELD * mult,
			batchMult = mult,
			mixTaps = effects.mixTaps,
			mixMin = effects.mixMin,
			coolTime = effects.coolTime,
			bakeSlack = effects.bakeSlack,
			stage = "mix",
			running = false,
			t0 = os.clock(),
			mix = 1,
			portion = 0,
			bake = 0,
			bakeSigned = 0,
			coolEnd = 0,
		}
		sessions[player] = s
		return true, describe(s)
	end

	Remotes.func("BakeStep").OnServerInvoke = function(player: Player, action: any, arg: any): (boolean, any)
		if not RateLimit.check(player, "BakeStep", 0.15) then
			return false, "slow down a little"
		end
		local s = sessions[player]
		if not s or type(action) ~= "string" then
			return false, "no bake in progress"
		end
		local now = os.clock()

		if action == "mixDone" and s.stage == "mix" then
			if now - s.t0 < s.mixMin then
				return false, "keep stirring a little longer"
			end
			if type(arg) == "number" and arg == arg then
				s.mix = math.clamp(arg, 0, 1)
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
			s.coolEnd = now + s.coolTime
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
			local box
			for _, b in Recipes.boxes do
				if b.id == arg then
					box = b
				end
			end
			if not box then
				return false, "pick a box"
			end
			if box.size ~= s.yield then
				return false, `That box holds {box.size}; this tray has {s.yield} cookies.`
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
