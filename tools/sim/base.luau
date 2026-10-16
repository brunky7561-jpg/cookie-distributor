-- Fake Roblox environment for running the server services with the real Luau interpreter.
-- Scenarios (m*.luau) are appended after this file and run in order. Each is wrapped in do ... end.
local clock = 1000
local realos = os
os = setmetatable({ clock = function() return clock end, time = function() return math.floor(clock) end }, { __index = realos })

warn = function(...) print("   warn:", ...) end

-- scheduler: coroutines that yield in task.wait are kept and resumed by settle() / tick()
local waiting, daemons = {}, {}
local daemonMode = false
task = {}
function task.spawn(fn, ...)
	local co = coroutine.create(fn)
	local ok, e = coroutine.resume(co, ...)
	if not ok then error(debug.traceback(co, tostring(e))) end
	if coroutine.status(co) == "suspended" then
		table.insert(if daemonMode then daemons else waiting, co)
	end
	return co
end
function task.wait(t) coroutine.yield() return t end
function task.delay() end
local function resumeAll(list)
	local current = table.clone(list)
	table.clear(list)
	for _, co in current do
		local ok, e = coroutine.resume(co)
		if not ok then error(debug.traceback(co, tostring(e))) end
		if coroutine.status(co) == "suspended" then table.insert(list, co) end
	end
end
local function settle() for _ = 1, 40 do if #waiting == 0 then return end clock += 1 resumeAll(waiting) end end
local function tick(dt) clock += dt resumeAll(daemons) settle() end

local function signal()
	local handlers = {}
	return {
		Connect = function(self, fn) table.insert(handlers, fn) return { Disconnect = function() end } end,
		_fire = function(self, ...) for _, h in handlers do task.spawn(h, ...) end end,
		_handlers = handlers,
	}
end

local function node(name, parent)
	local n = { Name = name, _children = {}, _attrs = {} }
	setmetatable(n, {
		__index = function(t, k)
			local c = rawget(t, "_children")[k]
			if c then return c end
			if k == "FindFirstChild" or k == "WaitForChild" then return function(self, nm) return self._children[nm] end end
			if k == "IsA" then return function(self, c) return self.ClassName == c or c == "BasePart" end end
			if k == "IsDescendantOf" then return function() return true end end
			if k == "SetAttribute" then return function(self, a, v) self._attrs[a] = v end end
			if k == "GetAttribute" then return function(self, a) return self._attrs[a] end end
			if k == "Destroy" then return function(self) self.Destroyed = true if self.Parent then self.Parent._children[self.Name] = nil end end end
			return nil
		end,
		__newindex = function(t, k, v)
			rawset(t, k, v)
			if k == "Parent" and v then v._children[t.Name] = t end
		end,
	})
	if parent then n.Parent = parent end
	return n
end
Instance = { new = function(cls)
	local o = node(cls); o.ClassName = cls
	if cls == "RemoteEvent" then o.sent = {}; function o:FireClient(p, ...) table.insert(self.sent, { p, ... }) end end
	if cls == "ProximityPrompt" then o.Triggered = signal() end
	if cls == "Part" then o.Position = Vector3.new(0, 0, 0); o.Size = Vector3.new(1, 1, 1) end
	if cls == "BindableEvent" then
		local s = signal(); o.Event = s
		function o:Fire(...) for _, h in s._handlers do h(...) end end
	end
	return o
end }

-- minimal math/UI globals so config and UI-building modules can load on the server side
local V3mt = {}
V3mt.__index = V3mt
V3mt.__add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, V3mt) end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3mt) end }
Color3 = { fromHex = function() return {} end, fromRGB = function() return {} end, new = function() return {} end }
UDim2 = { fromOffset = function() return {} end, fromScale = function() return {} end, new = function() return {} end }
Enum = setmetatable({}, { __index = function() return setmetatable({}, { __index = function(_, j) return j end }) end })

local RS = node("ReplicatedStorage")
local Shared = node("Shared", RS)
local players = {}
local Players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return players end }

-- DataStore: persists across joins; fail = number of upcoming calls that error; raw writes allowed for corruption tests
local storeData = {}
local function deepcopy(v) if type(v) ~= "table" then return v end local o = {} for k, x in v do o[k] = deepcopy(x) end return o end
local store = { fail = 0, calls = 0 }
function store:UpdateAsync(key, fn)
	self.calls += 1
	if self.fail > 0 then self.fail -= 1 error("DataStore request was added to queue (simulated failure)") end
	local new = fn(deepcopy(storeData[key]))
	if new ~= nil then storeData[key] = deepcopy(new) end
	return new
end
local config = { studio = true, distance = 0, tagged = {} }
workspace = node("Workspace")
local services = {
	ReplicatedStorage = RS, Players = Players,
	DataStoreService = { GetDataStore = function() return store end },
	CollectionService = { GetTagged = function(_, tag) return config.tagged[tag] or {} end },
	RunService = { IsServer = function() return true end, IsStudio = function() return config.studio end },
}
game = { GetService = function(self, n) return services[n] or error("no service " .. n) end, JobId = "job", BindToClose = function() end }

MODS["Services.InteractionService"] = function() return { DistanceToPart = function() return config.distance end, IsNearStation = function() return true end, Init = function() end, Start = function() end } end

local ServicesFolder = node("Services")
local nodes = {}
for key in MODS do
	local top, rest = key:match("^(%a+)%.(.+)$")
	local cur = if top == "Shared" then Shared else ServicesFolder
	for part in rest:gmatch("[^.]+") do cur = cur._children[part] or node(part, cur) end
	cur._key = key
	nodes[key] = cur
end
local loaded = {}
function require(n)
	local key = n._key
	if not key then error("require of non-module " .. tostring(n.Name)) end
	if loaded[key] == nil then loaded[key] = MODS[key](n) end
	return loaded[key]
end
local function svc(name) return require(nodes["Services." .. name]) end
local function shared(path) return require(nodes["Shared." .. path]) end

local expectCount = 0
local function expect(cond, msg) if not cond then error("FAIL: " .. msg, 2) end expectCount += 1 print("ok  " .. msg) end

-- start every service the way Bootstrap does
local S = {}
local order = { "PlayerDataService" }
for key in MODS do
	local name = key:match("^Services%.(.+)$")
	if name and name ~= "PlayerDataService" and name ~= "InteractionService" and name ~= "WorldService" then table.insert(order, name) end
end
table.sort(order, function(a, b) if a == "PlayerDataService" then return true elseif b == "PlayerDataService" then return false end return a < b end)
for _, name in order do S[name] = svc(name) end
for _, name in order do S[name]:Init() end
daemonMode = true
for _, name in order do task.spawn(function() S[name]:Start() end) end
daemonMode = false

local R = RS._children.Remotes._children
local function newPlayer(id, name) return { UserId = id, Name = name or ("P" .. id), Parent = true, _name = name } end
local function join(p) table.insert(players, p) Players.PlayerAdded:_fire(p) settle() end
local function leave(p)
	Players.PlayerRemoving:_fire(p) settle()
	p.Parent = nil
	for i, x in players do if x == p then table.remove(players, i) break end end
end
local function call(p, name, ...) return R[name].OnServerInvoke(p, ...) end
local function sent(name) return R[name].sent end
local function lastSent(name, p)
	local list = R[name].sent
	for i = #list, 1, -1 do if list[i][1] == p then return list[i][2] end end
	return nil
end

T = {} -- helpers shared by scenarios
local function state(p) return S.PlayerDataService:Get(p) end
local function ordersOf(p) return lastSent("OrdersUpdated", p) or {} end
-- Runs a full perfect bake at the station. Returns the pack result.
function T.bake(p, orderId, box)
	local ok, info = call(p, "BakeStart", "classic_chip", orderId)
	if not ok then return false, info end
	clock += 3.5; call(p, "BakeStep", "mixDone"); clock += 0.5
	call(p, "BakeStep", "portionStart"); clock += 3; call(p, "BakeStep", "portionStop"); clock += 0.5
	call(p, "BakeStep", "ovenStart"); clock += 6; call(p, "BakeStep", "ovenPull"); clock += 0.5
	clock += 4.5; call(p, "BakeStep", "coolDone"); clock += 0.5
	return call(p, "BakeStep", "pack", box or "standard")
end
-- Like T.bake but with a recipe id, options and timing overrides: { late = seconds past ideal bake, cool = seconds to wait }
function T.bake2(p, recipeId, orderId, options, box, o)
	o = o or {}
	local ok, info = call(p, "BakeStart", recipeId, orderId, options)
	if not ok then return false, info end
	clock += (info.mixMin or 3) + 0.5; call(p, "BakeStep", "mixDone"); clock += 0.5
	call(p, "BakeStep", "portionStart"); clock += 3; call(p, "BakeStep", "portionStop"); clock += 0.5
	call(p, "BakeStep", "ovenStart"); clock += 6 + (o.late or 0); call(p, "BakeStep", "ovenPull"); clock += 0.5
	clock += o.cool or 4.6; local cok = call(p, "BakeStep", "coolDone"); clock += 0.5
	if not cok then return false, "cooling" end
	return call(p, "BakeStep", "pack", box or "standard")
end
T.state, T.ordersOf = state, ordersOf
