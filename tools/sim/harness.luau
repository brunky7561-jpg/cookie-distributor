local clock = 1000
local realos = os
os = setmetatable({ clock = function() return clock end, time = function() return math.floor(clock) end }, { __index = realos })
task = {
	spawn = function(fn, ...) local co = coroutine.create(fn); local ok, e = coroutine.resume(co, ...); if not ok then error(e) end; return co end,
	wait = function(t) coroutine.yield() return t end,
	delay = function() end,
}
local function node(name, parent)
	local n = { Name = name, _children = {} }
	setmetatable(n, {
		__index = function(t, k)
			local c = rawget(t, "_children")[k]
			if c then return c end
			if k == "FindFirstChild" or k == "WaitForChild" then return function(self, nm) return self._children[nm] end end
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
	if cls == "RemoteEvent" then o.sent = {}; function o:FireClient(p, ...) table.insert(self.sent, { ... }) end end
	if cls == "BindableEvent" then o.Event = { Connect = function() end }; function o:Fire() end end
	return o
end }
local RS = node("ReplicatedStorage")
local Shared = node("Shared", RS)
local Players = { PlayerAdded = { Connect = function() end }, PlayerRemoving = { Connect = function() end }, GetPlayers = function() return {} end }
local store = { UpdateAsync = function(self, key, fn) return fn(nil) end }
local services = {
	ReplicatedStorage = RS, Players = Players,
	DataStoreService = { GetDataStore = function() return store end },
	RunService = { IsServer = function() return true end, IsStudio = function() return true end },
}
game = { GetService = function(self, n) return services[n] or error("no service " .. n) end, JobId = "job", BindToClose = function() end }

MODS["Services.InteractionService"] = function() return { IsNearStation = function() return true end, Init = function() end, Start = function() end } end

local ServicesFolder = node("Services")
local nodes = {}
for key in MODS do
	local top, rest = key:match("^(%a+)%.(.+)$")
	local cur = if top == "Shared" then Shared else ServicesFolder
	local parts = {}
	for part in rest:gmatch("[^.]+") do table.insert(parts, part) end
	for i, part in parts do
		cur = cur._children[part] or node(part, cur)
	end
	cur._key = key
	nodes[key] = cur
end
local loaded = {}
local realRequire = require
function require(n)
	local key = n._key
	if not key then error("require of non-module " .. tostring(n.Name)) end
	if loaded[key] == nil then loaded[key] = MODS[key](n) end
	return loaded[key]
end

local function svc(name) return require(nodes["Services." .. name]) end
local PDS = svc("PlayerDataService")
local Inv, Eco, Orders, Baking = svc("InventoryService"), svc("EconomyService"), svc("OrderService"), svc("BakingService")
for _, s in { PDS, Inv, Eco, Orders, Baking } do s:Init() end
local player = { UserId = 7, Name = "Tester", Parent = true }
services.Players.GetPlayers = function() return { player } end
local R = RS._children.Remotes._children
local function call(name, ...) return R[name].OnServerInvoke(player, ...) end
local function ordersSent() local s = R.OrdersUpdated.sent; return s[#s][1] end
local function expect(cond, msg) if not cond then error("FAIL: " .. msg, 2) end print("ok  " .. msg) end

PDS:Start()
coroutine.wrap(function() Orders:Start() end)()
local data = PDS:Get(player)
expect(data ~= nil, "profile loaded")
local list = ordersSent()
expect(#list == 1 and list[1].state == "Available" and list[1].isFirst, "first order seeded as Available")
local oid = list[1].id
expect(list[1].deadline == nil, "first order has no deadline")

-- cannot bake for an order before accepting it
local ok, msg = call("BakeStart", "classic_chip", oid)
expect(not ok, "cannot bake for unaccepted order: " .. tostring(msg))
ok, msg = call("OrderAction", "accept", oid)
clock += 1
expect(ok and ordersSent()[1].state == "Accepted", "accept -> Accepted")
-- cannot deliver early
ok, msg = call("OrderAction", "deliver", oid); clock += 1
expect(not ok, "cannot deliver before Ready: " .. tostring(msg))

local flourBefore = data.ingredients.flour
ok, msg = call("BakeStart", "classic_chip", oid); clock += 1
expect(ok, "BakeStart ok")
expect(data.ingredients.flour == flourBefore - 2 and data.ingredients.chocolate_chips == 1, "ingredients consumed once")
expect(ordersSent()[1].state == "In Production", "order -> In Production")
ok = call("BakeStart", "classic_chip", oid); clock += 1
expect(not ok, "second BakeStart refused, no double consume")
expect(data.ingredients.flour == flourBefore - 2, "flour unchanged after refused start")

ok, msg = call("BakeStep", "mixDone"); clock += 1
expect(not ok, "mix too fast refused: " .. tostring(msg))
clock += 3.5
ok = call("BakeStep", "mixDone"); clock += 1
expect(ok, "mix done")
ok = call("BakeStep", "ovenStart"); clock += 1
expect(not ok, "cannot skip portion")
call("BakeStep", "portionStart"); clock += 3.2
ok = call("BakeStep", "portionStop"); clock += 1
expect(ok, "portion stop")
call("BakeStep", "ovenStart"); clock += 6.4
ok, msg = call("BakeStep", "ovenPull"); clock += 0.5
expect(ok and msg.stage == "cool", "bake -> cool")
ok = call("BakeStep", "coolDone"); clock += 0.5
expect(not ok, "cannot skip cooling")
clock += 4
ok = call("BakeStep", "coolDone"); clock += 0.5
expect(ok, "cool done")
ok, msg = call("BakeStep", "pack", "small"); clock += 0.5
expect(not ok, "wrong box refused: " .. tostring(msg))
ok, msg = call("BakeStep", "pack", "standard"); clock += 0.5
expect(ok and msg.linkedOrder, "packed and linked")
local b = msg.batch
print("   batch:", b.grade, b.score, b.feedback, "appeal", b.appeal)
expect(ordersSent()[1].state == "Ready", "order -> Ready")
local cashBefore = data.cash
ok, msg = call("OrderAction", "deliver", oid); clock += 1
expect(ok and msg.pay > 0, "deliver paid " .. tostring(msg.pay) .. " tip " .. tostring(msg.tip))
expect(data.cash == cashBefore + msg.pay + msg.tip, "cash increased exactly once")
ok = call("OrderAction", "deliver", oid); clock += 1
expect(not ok, "second deliver refused (no double payout)")
expect(data.cash == cashBefore + msg.pay + msg.tip, "cash unchanged after second deliver")
expect(data.milestones.firstOrderDone == true, "firstOrderDone set")
expect(#data.batches == 0, "box fully used")
expect(#ordersSent() == 0, "no active orders after payout")

-- stock bake then assign
data.ingredients.flour = 4; data.ingredients.butter = 2; data.ingredients.white_sugar = 2; data.ingredients.chocolate_chips = 2
call("BakeStart", "classic_chip"); clock += 1; clock += 3.5
call("BakeStep", "mixDone"); clock += 0.5; call("BakeStep", "portionStart"); clock += 3; call("BakeStep", "portionStop"); clock += 0.5
call("BakeStep", "ovenStart"); clock += 6; call("BakeStep", "ovenPull"); clock += 4.5; call("BakeStep", "coolDone"); clock += 0.5
ok, msg = call("BakeStep", "pack", "standard")
expect(ok and not msg.linkedOrder and #data.batches == 1, "stock bake leaves a box")
print("   stock batch:", msg.batch.grade, msg.batch.score)
-- force a random order via the spawn tick
for i = 1, 8 do clock += 5; end

print("-- second player: cancel mid-production")
player = { UserId = 8, Name = "Two", Parent = true }
services.Players.GetPlayers = function() return { player } end
PDS:Start()
coroutine.wrap(function() Orders:Start() end)()
local d2 = PDS:Get(player)
expect(d2 ~= nil and d2 ~= data, "second profile")
local o2 = ordersSent()[1].id
call("OrderAction", "accept", o2); clock += 1
call("BakeStart", "classic_chip", o2); clock += 1
ok, msg = call("OrderAction", "cancel", o2); clock += 1
expect(ok, "cancel in production: " .. tostring(msg))
local re = ordersSent()
expect(#re == 1 and re[1].state == "Available" and re[1].id ~= o2, "first order re-offered after cancel")
clock += 3.5; call("BakeStep", "mixDone"); clock += 0.5; call("BakeStep", "portionStart"); clock += 3; call("BakeStep", "portionStop"); clock += 0.5
call("BakeStep", "ovenStart"); clock += 6; call("BakeStep", "ovenPull"); clock += 4.5; call("BakeStep", "coolDone"); clock += 0.5
ok, msg = call("BakeStep", "pack", "standard")
expect(ok and not msg.linkedOrder and #d2.batches == 1, "finished bake for cancelled order lands in stock")
call("OrderAction", "accept", re[1].id); clock += 1
ok, msg = call("OrderAction", "assign", re[1].id, d2.batches[1].id); clock += 1
expect(ok and ordersSent()[1].state == "Ready", "assign stock box -> Ready")
ok = call("OrderAction", "assign", re[1].id, d2.batches[1].id); clock += 1
expect(not ok, "cannot assign twice")
ok, msg = call("OrderAction", "deliver", re[1].id)
expect(ok, "delivered from stock")
ok = call("OrderAction", "accept", 99999); clock += 1
expect(not ok, "bogus order id refused")
ok = call("OrderAction", {}, "x"); clock += 1
expect(not ok, "bad action type refused")
ok = call("BakeStart", {}, {}); clock += 1
expect(not ok, "bad BakeStart args refused")
