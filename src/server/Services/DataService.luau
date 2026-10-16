--!strict
-- Per-player saved data with a simple session lock so two servers never write the same profile.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local STORE_NAME = "CookieDistributor_v1"
local LOCK_TIMEOUT = 120 -- seconds before a dead server's lock is ignored
local AUTOSAVE_INTERVAL = 60

export type Data = {
	cash: number,
	level: number,
	xp: number,
	ingredients: { [string]: number },
	batches: { any },
	recipes: { [string]: boolean },
	properties: { [string]: boolean },
	customers: { [string]: any },
	nextBatchId: number,
}

local DataService = {}

local store = DataStoreService:GetDataStore(STORE_NAME)
local profiles: { [Player]: Data } = {}
local unsaved: { [Player]: boolean } = {} -- profiles that failed to load: never overwrite the real save
local changedEvent = Instance.new("BindableEvent")
DataService.Changed = changedEvent.Event :: RBXScriptSignal

local stateRemote = Remotes.event("StateUpdated")

local function defaultData(): Data
	return {
		cash = 50,
		level = 1,
		xp = 0,
		ingredients = { flour = 4, butter = 2, white_sugar = 2 },
		batches = {},
		recipes = {},
		properties = { apartment = true },
		customers = {},
		nextBatchId = 1,
	}
end

local function reconcile(data: any): Data
	local defaults = defaultData() :: any
	for k, v in defaults do
		if data[k] == nil then
			data[k] = v
		end
	end
	return data
end

local function key(player: Player): string
	return `Player_{player.UserId}`
end

local function load(player: Player): Data?
	for attempt = 1, 4 do
		local locked = false
		local ok, result = pcall(function()
			return store:UpdateAsync(key(player), function(old: any)
				if old and old.lock and old.lock.jobId ~= game.JobId and os.time() - old.lock.time < LOCK_TIMEOUT then
					locked = true
					return nil
				end
				local record = old or {}
				record.lock = { jobId = game.JobId, time = os.time() }
				return record
			end)
		end)
		if ok and result then
			return reconcile(result.data or {})
		end
		if ok and locked then
			task.wait(3)
		elseif not ok then
			warn(`[DataService] load attempt {attempt} failed: {result}`)
			task.wait(2 ^ attempt)
		end
	end
	return nil
end

local function save(player: Player, release: boolean): boolean
	local data = profiles[player]
	if not data or unsaved[player] then
		return false
	end
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function(old: any)
			if old and old.lock and old.lock.jobId ~= game.JobId then
				return nil -- another server took over; do not overwrite
			end
			return { data = data, lock = if release then nil else { jobId = game.JobId, time = os.time() } }
		end)
	end)
	if not ok then
		warn(`[DataService] save failed for {player.Name}: {err}`)
	end
	return ok
end

function DataService:Get(player: Player): Data?
	return profiles[player]
end

-- Call after any change so the client UI and other services stay in sync.
function DataService:Replicate(player: Player)
	local data = profiles[player]
	if data then
		stateRemote:FireClient(player, data)
		changedEvent:Fire(player)
	end
end

local function onJoin(player: Player)
	local data = load(player)
	if not player.Parent then
		return
	end
	if not data then
		warn(`[DataService] could not load {player.Name}; using temporary data that will NOT be saved`)
		data = defaultData()
		unsaved[player] = true
	end
	profiles[player] = data
	DataService:Replicate(player)
end

local function onLeave(player: Player)
	save(player, true)
	profiles[player] = nil
	unsaved[player] = nil
end

function DataService:Init()
	Remotes.func("GetState").OnServerInvoke = function(player: Player)
		return profiles[player]
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(function(p)
		task.spawn(onJoin, p)
	end)
	Players.PlayerRemoving:Connect(onLeave)
	for _, p in Players:GetPlayers() do
		task.spawn(onJoin, p)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for p in profiles do
				task.spawn(save, p, false)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for p in profiles do
			task.spawn(save, p, true)
		end
		task.wait(3)
	end)
end

return DataService
