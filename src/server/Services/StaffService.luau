--!strict
-- Employees. A baker bakes one assigned recipe on a fixed cycle using the pantry, so the result is predictable and the
-- Staff Board can always say exactly why a baker is idle. Wages are paid per day; if you cannot pay, the baker waits
-- (nobody is fired and nothing is lost) and resumes as soon as the wage is paid.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)
local Properties = require(ReplicatedStorage.Shared.Config.Properties)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local Staff = require(ReplicatedStorage.Shared.Config.Staff)
local AppealCalc = require(ReplicatedStorage.Shared.Modules.AppealCalc)
local Quality = require(ReplicatedStorage.Shared.Modules.Quality)
local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)

local STEP = 5
local lastPay: { [Player]: number } = {}

local StaffService = {}

local function slots(data: any): number
	local n = 0
	for id in data.properties do
		local def = Properties[id]
		if def then
			n += def.ovenSlots
		end
	end
	return math.max(0, n - 1) -- one oven is always yours
end

local function skillOf(entry: any): number
	local c = Staff.candidates[entry.id]
	return math.min(4, c.skill + (if entry.bakes >= Staff.PROMOTE_EVERY then 1 else 0))
end

local function cycleOf(entry: any): number
	return Staff.candidates[entry.id].cycle
end

function StaffService.slots(data: any): number
	return slots(data)
end

local function setStatus(entry: any, text: string): boolean
	if entry.status ~= text then
		entry.status = text
		return true
	end
	return false
end

local function bakeBatch(player: Player, data: any, entry: any)
	local recipe = Recipes.catalog[entry.recipeId]
	local list = Recipes.expand(recipe.requires)
	local score = math.min(100, Staff.BASE_SCORE + skillOf(entry) * Staff.PER_SKILL)
	local quality = score / 100
	local appeal = AppealCalc.compute(list, quality)
	local tagSet: { [string]: boolean } = {}
	for _, id in list do
		for _, t in Ingredients[id].tags do
			tagSet[t] = true
		end
	end
	local tags = {}
	for t in tagSet do
		table.insert(tags, t)
	end
	table.sort(tags)
	InventoryService:AddBatch(player, {
		id = InventoryService:NextBatchId(player),
		name = recipe.name,
		recipeId = recipe.id,
		ingredients = list,
		tags = tags,
		quality = quality,
		score = score,
		grade = Quality.grade(score),
		feedback = `Baked by {Staff.candidates[entry.id].name}.`,
		appeal = appeal.score,
		effects = appeal.effects,
		count = Recipes.YIELD,
		packaged = true,
		byStaff = true,
	})
end

-- Advances every baker by dt seconds. Exposed so tests can drive time.
function StaffService:Step(player: Player, dt: number)
	local data = PlayerDataService:Get(player)
	if not data or #data.staff == 0 then
		return
	end
	local changed = false
	for _, entry in data.staff do
		local c = Staff.candidates[entry.id]
		if entry.unpaid then
			if EconomyService:TrySpend(player, c.wage) then
				EconomyService:Record(player, "wages", c.wage)
				entry.unpaid = false
				changed = true
			else
				changed = setStatus(entry, `Waiting for wages (${c.wage}).`) or changed
				continue
			end
		end
		local recipe = if entry.recipeId then Recipes.catalog[entry.recipeId] else nil
		if not recipe then
			changed = setStatus(entry, "Needs a recipe. Assign one in the Staff Board.") or changed
		elseif not data.recipes[recipe.id] then
			changed = setStatus(entry, `You have not learned {recipe.name} yet.`) or changed
		elseif not InventoryService:HasRoomForBatch(player) then
			changed = setStatus(entry, "Storage is full. Sell or deliver some cookies.") or changed
		else
			local missing = InventoryService:Missing(player, recipe.requires)
			if missing then
				changed = setStatus(entry, `Waiting on ingredients: {missing}. Order more in PantryDash.`) or changed
			else
				entry.progress += dt
				if entry.progress >= cycleOf(entry) then
					do
						InventoryService:Consume(player, recipe.requires)
						bakeBatch(player, data, entry)
						entry.bakes += 1
						entry.progress = 0
						EconomyService:AddXp(player, 3)
						changed = setStatus(entry, `Finished a batch of {recipe.name}.`) or changed
					end
				else
					changed = setStatus(entry, `Baking {recipe.name}: {math.floor(entry.progress / cycleOf(entry) * 100)}%`) or changed
				end
			end
		end
	end
	if changed then
		PlayerDataService:Replicate(player)
	end
end

-- Pays one day of wages for every baker; unpaid bakers wait.
function StaffService:PayDay(player: Player)
	local data = PlayerDataService:Get(player)
	if not data then
		return
	end
	for _, entry in data.staff do
		if not entry.unpaid then
			local c = Staff.candidates[entry.id]
			if EconomyService:TrySpend(player, c.wage) then
				EconomyService:Record(player, "wages", c.wage)
			else
				entry.unpaid = true
				setStatus(entry, `Waiting for wages (${c.wage}).`)
				Remotes.event("Notify"):FireClient(player, `You could not pay {c.name}. They will wait until you can.`)
			end
		end
	end
	PlayerDataService:Replicate(player)
end

function StaffService:Init()
	Remotes.func("StaffHire").OnServerInvoke = function(player: Player, candidateId: any): (boolean, string)
		if not RateLimit.check(player, "StaffHire", 0.5) then
			return false, "slow down a little"
		end
		local data = PlayerDataService:Get(player)
		local c = if type(candidateId) == "string" then Staff.candidates[candidateId] else nil
		if not data or not c then
			return false, "unknown candidate"
		end
		for _, e in data.staff do
			if e.id == c.id then
				return false, `{c.name} already works for you.`
			end
		end
		if #data.staff >= slots(data) then
			return false, if slots(data) == 0 then "You need a second oven (own a Food Truck or bigger) before you can hire." else "All your ovens are staffed."
		end
		if not EconomyService:TrySpend(player, c.wage) then
			return false, `Hiring {c.name} costs ${c.wage} for the first day.`
		end
		EconomyService:Record(player, "wages", c.wage)
		table.insert(data.staff, { id = c.id, recipeId = nil, bakes = 0, progress = 0, status = "Needs a recipe. Assign one in the Staff Board.", unpaid = false })
		lastPay[player] = lastPay[player] or os.clock()
		PlayerDataService:Replicate(player)
		return true, `{c.name} is on the team. Pick what they bake.`
	end

	Remotes.func("StaffFire").OnServerInvoke = function(player: Player, candidateId: any): (boolean, string)
		if not RateLimit.check(player, "StaffFire", 0.5) then
			return false, "slow down a little"
		end
		local data = PlayerDataService:Get(player)
		if not data then
			return false, "loading"
		end
		for i, e in data.staff do
			if e.id == candidateId then
				table.remove(data.staff, i)
				PlayerDataService:Replicate(player)
				return true, "They have left. No hard feelings."
			end
		end
		return false, "that person does not work for you"
	end

	Remotes.func("StaffAssign").OnServerInvoke = function(player: Player, candidateId: any, recipeId: any): (boolean, string)
		if not RateLimit.check(player, "StaffAssign", 0.3) then
			return false, "slow down a little"
		end
		local data = PlayerDataService:Get(player)
		local recipe = if type(recipeId) == "string" then Recipes.catalog[recipeId] else nil
		if not data or not recipe then
			return false, "unknown recipe"
		end
		if not data.recipes[recipe.id] then
			return false, "you have not learned that recipe yet"
		end
		for _, e in data.staff do
			if e.id == candidateId then
				if e.recipeId ~= recipe.id then
					e.recipeId = recipe.id
					e.progress = 0
					e.status = `Assigned to {recipe.name}.`
				end
				PlayerDataService:Replicate(player)
				return true, `{Staff.candidates[e.id].name} will bake {recipe.name}.`
			end
		end
		return false, "that person does not work for you"
	end

	Players.PlayerRemoving:Connect(function(p)
		lastPay[p] = nil
	end)
end

function StaffService:Start()
	task.spawn(function()
		while true do
			task.wait(STEP)
			local now = os.clock()
			for _, p in Players:GetPlayers() do
				StaffService:Step(p, STEP)
				local data = PlayerDataService:Get(p)
				if data and #data.staff > 0 then
					lastPay[p] = lastPay[p] or now
					if now - lastPay[p] >= Staff.DAY then
						lastPay[p] = now
						StaffService:PayDay(p)
					end
				end
			end
		end
	end)
end

return StaffService
