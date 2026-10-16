--!strict
-- Per-player saved data: DataStore with a simple session lock, schema versions, migrations, retries and logging.
-- Every profile that reaches the rest of the game has been through DataSchema.sanitize, so services can rely on its shape.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataSchema = require(ReplicatedStorage.Shared.Modules.DataSchema)
local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local STORE_NAME = "CookieDistributor_v1"
local LOCK_TIMEOUT = 120 -- seconds before a dead server's lock is ignored
local AUTOSAVE_INTERVAL = 60
local LOAD_ATTEMPTS = 4
local SAVE_ATTEMPTS = 3
local DEV_USER_IDS: { [number]: boolean } = {} -- add a UserId here to allow the dev reset outside Studio

export type Data = any

local PlayerDataService = {}

local store = DataStoreService:GetDataStore(STORE_NAME)
local profiles: { [Player]: Data } = {}
local unsaved: { [Player]: boolean } = {} -- profiles that failed to load: never overwrite the real save
local changedEvent = Instance.new("BindableEvent")
local resetEvent = Instance.new("BindableEvent")
PlayerDataService.Changed = changedEvent.Event :: RBXScriptSignal
PlayerDataService.Reset = resetEvent.Event :: RBXScriptSignal
PlayerDataService.errors = { load = 0, save = 0, malformed = 0 } -- read by the metrics/launch checks

local stateRemote = Remotes.event("StateUpdated")

local function key(player: Player): string
	return `Player_{player.UserId}`
end

-- Returns the profile, or nil plus a reason when the save must not be touched ("locked", "newer", "error").
local function load(player: Player): (Data?, string?)
	local reason = "error"
	for attempt = 1, LOAD_ATTEMPTS do
		local locked = false
		local ok, result = pcall(function()
			return store:UpdateAsync(key(player), function(old: any)
				if old ~= nil and type(old) ~= "table" then
					old = nil -- malformed record: start clean (the next save replaces it)
				end
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
			local raw = result.data
			if type(raw) == "table" and type(raw.schemaVersion) == "number" and raw.schemaVersion > DataSchema.VERSION then
				warn(`[PlayerDataService] {player.Name} has data from a newer version ({raw.schemaVersion}); not loading it`)
				return nil, "newer"
			end
			if raw ~= nil and type(raw) ~= "table" then
				PlayerDataService.errors.malformed += 1
				warn(`[PlayerDataService] malformed save for {player.Name}; using defaults`)
				raw = nil
			end
			return DataSchema.sanitize(DataSchema.migrate(raw)), nil
		end
		if ok and locked then
			reason = "locked"
			task.wait(3)
		elseif not ok then
			PlayerDataService.errors.load += 1
			warn(`[PlayerDataService] load attempt {attempt} for {player.Name} failed: {result}`)
			task.wait(2 ^ attempt)
		end
	end
	return nil, reason
end

local function save(player: Player, release: boolean): boolean
	local data = profiles[player]
	if not data or unsaved[player] then
		return false
	end
	local lastError: any = nil
	for attempt = 1, SAVE_ATTEMPTS do
		local ok, err = pcall(function()
			store:UpdateAsync(key(player), function(old: any)
				if type(old) == "table" and old.lock and old.lock.jobId ~= game.JobId then
					return nil -- another server took over; do not overwrite
				end
				return { data = data, lock = if release then nil else { jobId = game.JobId, time = os.time() } }
			end)
		end)
		if ok then
			return true
		end
		lastError = err
		PlayerDataService.errors.save += 1
		warn(`[PlayerDataService] save attempt {attempt} for {player.Name} failed: {err}`)
		if attempt < SAVE_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end
	warn(`[PlayerDataService] GAVE UP saving {player.Name}: {lastError}`)
	return false
end

function PlayerDataService:Get(player: Player): Data?
	return profiles[player]
end

-- True when this profile will be written back to the DataStore.
function PlayerDataService:IsPersistent(player: Player): boolean
	return profiles[player] ~= nil and not unsaved[player]
end

function PlayerDataService:SaveNow(player: Player): boolean
	return save(player, false)
end

-- Call after any change so the client UI and other services stay in sync.
function PlayerDataService:Replicate(player: Player)
	local data = profiles[player]
	if data then
		stateRemote:FireClient(player, data)
		changedEvent:Fire(player)
	end
end

local function onJoin(player: Player)
	local data, reason = load(player)
	if not player.Parent then
		return
	end
	if not data then
		warn(`[PlayerDataService] could not load {player.Name} ({reason}); using temporary data that will NOT be saved`)
		data = DataSchema.default()
		unsaved[player] = true
		Remotes.event("Notify"):FireClient(player, "We could not load your saved progress. You can play, but nothing will be saved this session.")
	end
	profiles[player] = data
	PlayerDataService:Replicate(player)
end

local function onLeave(player: Player)
	save(player, true)
	profiles[player] = nil
	unsaved[player] = nil
end

function PlayerDataService:Init()
	Remotes.func("GetState").OnServerInvoke = function(player: Player)
		return profiles[player]
	end

	-- Dev-only reset: Studio sessions and listed UserIds only. Normal players are refused on the server.
	Remotes.func("DevReset").OnServerInvoke = function(player: Player)
		if not RateLimit.check(player, "DevReset", 1) then
			return false
		end
		if not (RunService:IsStudio() or DEV_USER_IDS[player.UserId]) or not profiles[player] then
			return false
		end
		profiles[player] = DataSchema.default()
		resetEvent:Fire(player)
		PlayerDataService:Replicate(player)
		return true
	end
end

function PlayerDataService:Start()
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

return PlayerDataService
