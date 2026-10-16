--!strict
-- Server-side baking: validates ingredients, times the mix and oven steps itself, and creates batches.
-- The client only draws the bars; it can never send a quality or a Craving score.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local CravingCalc = require(ReplicatedStorage.Shared.Modules.CravingCalc)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local MAX_INGREDIENTS = 8
local COOKIES_PER_BATCH = 6
local MIX_IDEAL = 4 -- seconds of mixing for a perfect result
local OVEN_BASE = 6 -- seconds, plus 0.5 per ingredient
local MAX_BATCHES_STORED = 30

type Session = {
	ingredients: { string },
	stage: "mixing" | "mixed" | "baking",
	t0: number,
	mixScore: number,
}

local sessions: { [Player]: Session } = {}

local BakingService = {}

local function score(elapsed: number, ideal: number): number
	return math.clamp(1 - math.abs(elapsed - ideal) / ideal, 0, 1)
end

local function recipeName(ids: { string }): string
	local unique: { [string]: boolean } = {}
	for _, id in ids do
		unique[id] = true
	end
	local list = {}
	for id in unique do
		table.insert(list, id)
	end
	table.sort(list)
	return Recipes.hidden[table.concat(list, "+")] or "Custom Cookies"
end

local function ovenIdeal(session: Session): number
	return OVEN_BASE + 0.5 * #session.ingredients
end

function BakingService:Init()
	Remotes.func("BakeStart").OnServerInvoke = function(player: Player, picked: any)
		local data = DataService:Get(player)
		if not data or sessions[player] or type(picked) ~= "table" then
			return false, "cannot start a bake right now"
		end
		if #picked < 1 or #picked > MAX_INGREDIENTS then
			return false, `pick 1 to {MAX_INGREDIENTS} ingredients`
		end

		local need: { [string]: number } = {}
		local hasBase = false
		for _, id in picked do
			if type(id) ~= "string" or not Ingredients[id] then
				return false, "unknown ingredient"
			end
			need[id] = (need[id] or 0) + 1
			if table.find(Ingredients[id].tags, "base") then
				hasBase = true
			end
		end
		if not hasBase then
			return false, "you need a base like flour"
		end
		for id, n in need do
			if (data.ingredients[id] or 0) < n then
				return false, `not enough {Ingredients[id].name}`
			end
		end
		if #data.batches >= MAX_BATCHES_STORED then
			return false, "storage is full, sell some cookies first"
		end

		for id, n in need do
			data.ingredients[id] -= n
		end
		DataService:Replicate(player)

		local ids: { string } = table.clone(picked)
		sessions[player] = { ingredients = ids, stage = "mixing", t0 = os.clock(), mixScore = 0 }
		return true, { mixIdeal = MIX_IDEAL, ovenIdeal = OVEN_BASE + 0.5 * #ids }
	end

	Remotes.func("MixStop").OnServerInvoke = function(player: Player)
		local s = sessions[player]
		if not s or s.stage ~= "mixing" then
			return false
		end
		s.mixScore = score(os.clock() - s.t0, MIX_IDEAL)
		s.stage = "mixed"
		return true, s.mixScore
	end

	Remotes.func("OvenStart").OnServerInvoke = function(player: Player)
		local s = sessions[player]
		if not s or s.stage ~= "mixed" then
			return false
		end
		s.stage = "baking"
		s.t0 = os.clock()
		return true
	end

	Remotes.func("OvenPull").OnServerInvoke = function(player: Player)
		local s = sessions[player]
		local data = DataService:Get(player)
		if not s or s.stage ~= "baking" or not data then
			return false
		end
		sessions[player] = nil

		local ovenScore = score(os.clock() - s.t0, ovenIdeal(s))
		local quality = s.mixScore * 0.4 + ovenScore * 0.6
		local result = CravingCalc.compute(s.ingredients, quality)

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

		local name = recipeName(s.ingredients)
		local batch = {
			id = data.nextBatchId,
			name = name,
			ingredients = s.ingredients,
			tags = tags,
			quality = quality,
			craving = result.score,
			effects = result.effects,
			count = COOKIES_PER_BATCH,
		}
		data.nextBatchId += 1
		table.insert(data.batches, batch)
		if name ~= "Custom Cookies" and not data.recipes[name] then
			data.recipes[name] = true
			EconomyService:AddXp(player, 25) -- discovery bonus
		end
		EconomyService:AddXp(player, math.floor(5 + quality * 15))
		DataService:Replicate(player)
		return true, batch
	end

	Players.PlayerRemoving:Connect(function(p)
		sessions[p] = nil
	end)
end

function BakingService:Start() end

return BakingService
