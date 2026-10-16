--!strict
-- Integrity audit. All game rules are enforced where the change happens; this is the safety net underneath them. Every
-- minute it checks each player's data for impossible values (NaN, infinity, negatives, empty batches), repairs them to the
-- nearest valid value, and counts what it fixed so a bug or exploit shows up in the metrics instead of in a player's save.
local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.PlayerDataService)

local IntegrityService = {}

IntegrityService.repairs = 0

local function bad(n: any): boolean
	return type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge
end

-- Returns the number of repairs made.
function IntegrityService:Audit(player: Player): number
	local data = PlayerDataService:Get(player)
	if not data then
		return 0
	end
	local fixed = 0
	local function fix(label: string)
		fixed += 1
		warn(`[Integrity] repaired {label} for {player.Name}`)
	end

	if bad(data.cash) or data.cash < 0 then
		data.cash = 0
		fix("cash")
	end
	for _, key in { "xp", "reputation" } do
		if bad((data :: any)[key]) or (data :: any)[key] < 0 then
			(data :: any)[key] = 0
			fix(key)
		end
	end
	if bad(data.level) or data.level < 1 then
		data.level = 1
		fix("level")
	end
	for id, n in data.ingredients do
		if bad(n) or n < 0 or n % 1 ~= 0 then
			data.ingredients[id] = if bad(n) or n < 0 then 0 else math.floor(n)
			fix(`ingredient {id}`)
		end
	end
	for i = #data.batches, 1, -1 do
		local b = data.batches[i]
		if bad(b.count) or b.count < 1 or b.count % 1 ~= 0 then
			table.remove(data.batches, i)
			fix("empty batch")
		end
	end
	for key, n in data.stats do
		if bad(n) or n < 0 then
			data.stats[key] = 0
			fix(`stat {key}`)
		end
	end
	if fixed > 0 then
		IntegrityService.repairs += fixed
		PlayerDataService:Replicate(player)
	end
	return fixed
end

function IntegrityService:Init() end

function IntegrityService:Start()
	task.spawn(function()
		while true do
			task.wait(60)
			for _, p in Players:GetPlayers() do
				IntegrityService:Audit(p)
			end
		end
	end)
end

return IntegrityService
