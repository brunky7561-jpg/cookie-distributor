-- M12: client-side smoke test. The real client controllers run against a stub UI tree wired straight to the server services.
do
	local P = newPlayer(9100, "Clicker")
	P.Character = nil
	join(P)
	local U = SIM_U
	local baseEnv = getfenv()

	-- UI tree --------------------------------------------------------------
	local function sig()
		local hs = {}
		return { Connect = function(self, fn) table.insert(hs, fn) return { Disconnect = function() end } end, _hs = hs,
			_fire = function(self, ...) for _, h in hs do task.spawn(h, ...) end end }
	end
	local SIGNALS = { Activated = true, MouseButton1Click = true, MouseButton1Down = true, MouseEnter = true, MouseLeave = true, FocusLost = true, Changed = true, InputBegan = true, InputEnded = true, ChildAdded = true }
	local G
	local gmt = {}
	local function descendants(o, out)
		for _, k in o._kids do table.insert(out, k) descendants(k, out) end
		return out
	end
	local methods = {
		GetChildren = function(self) return table.clone(self._kids) end,
		GetDescendants = function(self) return descendants(self, {}) end,
		FindFirstChild = function(self, n) for _, k in self._kids do if k.Name == n then return k end end return nil end,
		FindFirstChildOfClass = function(self, c) for _, k in self._kids do if k.ClassName == c then return k end end return nil end,
		IsA = function(self, c) return self.ClassName == c or c == "Instance" or (c == "GuiObject" and (self.ClassName:find("Frame") or self.ClassName:find("Text") or self.ClassName:find("Image")) ~= nil) end,
		ClearAllChildren = function(self) for _, k in self._kids do k.Parent = nil end self._kids = {} end,
		Destroy = function(self) self.Parent = nil end,
		SetAttribute = function(self, a, v) self._attrs[a] = v end,
		GetAttribute = function(self, a) return self._attrs[a] end,
	}
	methods.WaitForChild = function(self, n) return methods.FindFirstChild(self, n) or G("Folder", n) end
	gmt.__index = function(t, k)
		local m = methods[k]
		if m then return m end
		if SIGNALS[k] then local s = sig() rawset(t, k, s) return s end
		for _, kid in rawget(t, "_kids") do if kid.Name == k then return kid end end
		if k == "Event" and t.ClassName == "BindableEvent" then local s = sig() rawset(t, "Event", s) return s end
		if k == "Fire" and t.ClassName == "BindableEvent" then
			return function(self, ...) for _, h in self.Event._hs do task.spawn(h, ...) end end
		end
		if k == "Parent" then return rawget(t, "_parent") end
		if type(k) == "string" and k:sub(1, 1) == "_" then return nil end
		if k == "Text" or k == "Name" then return "" end
		local v = U() rawset(t, k, v) return v
	end
	gmt.__newindex = function(t, k, v)
		if k == "Parent" then
			local old = rawget(t, "_parent")
			if old and rawget(old, "_kids") then local i = table.find(old._kids, t) if i then table.remove(old._kids, i) end end
			rawset(t, "_parent", v)
			if v then table.insert(v._kids, t) end
		else
			-- mirror engine limits that have bitten before
			if k == "TextSize" and type(v) == "number" and (v > 100 or v < 1) then error("TextSize " .. v .. " is outside 1-100 (the engine rejects this)", 2) end
			rawset(t, k, v)
		end
	end
	G = function(cls, name)
		return setmetatable({ ClassName = cls, Name = name or cls, _kids = {}, _attrs = {} }, gmt)
	end

	-- client script tree ----------------------------------------------------
	local clientRoot = G("Folder", "Client")
	local folders = { Controllers = G("Folder", "Controllers"), Apps = G("Folder", "Apps"), Modules = G("Folder", "Modules") }
	for _, f in folders do f.Parent = clientRoot end
	local modNodes = {}
	for key in CLIENT_SRC do
		local sub, name = key:match("^(%a+)%.(.+)$")
		local n = G("ModuleScript", name)
		n._client = key
		n.Parent = folders[sub]
		modNodes[key] = n
	end

	-- services --------------------------------------------------------------
	local playerGui = G("PlayerGui")
	P.PlayerGui = playerGui
	P.WaitForChild = function(_, n) return playerGui end
	P.LocalPlayerMarker = true
	local actions = {}
	local warns = {}
	local clientServices = {
		ReplicatedStorage = RS,
		Players = { LocalPlayer = P, GetPlayers = function() return players end },
		RunService = { IsServer = function() return false end, IsClient = function() return true end, IsStudio = function() return true end, Heartbeat = sig(), RenderStepped = sig() },
		ContextActionService = { BindAction = function(_, name, fn) actions[name] = fn end, UnbindAction = function() end },
	}
	local clientGame = { GetService = function(_, n) return clientServices[n] or U() end }

	-- client Remotes: the same instances the server uses
	local RealRemotes = require(nodes["Shared.Modules.Remotes"])
	local ClientRemotes = {
		event = function(name)
			local e = RealRemotes.event(name)
			if not rawget(e, "_hooked") then
				e._hooked = true
				e.OnClientEvent = sig()
				local orig = e.FireClient
				e.FireClient = function(self, p, ...)
					orig(self, p, ...)
					if p == P then e.OnClientEvent:_fire(...) end
				end
			end
			return e
		end,
		func = function(name)
			local f = RealRemotes.func(name)
			return { InvokeServer = function(_, ...)
				local h = f.OnServerInvoke
				if not h then error("client calls remote function " .. name .. " but the server has no handler") end
				return h(P, ...)
			end }
		end,
	}

	local cache = {}
	local env
	local function clientRequire(n)
		if n._key == "Shared.Modules.Remotes" then return ClientRemotes end
		if n._key then return require(n) end
		local key = n._client
		if not key then error("client require of non-module " .. tostring(n.Name)) end
		if cache[key] == nil then
			local f, err = loadstring(CLIENT_SRC[key], "@" .. key)
			if not f then error("syntax error in " .. key .. ": " .. tostring(err)) end
			local menv = setmetatable({ script = modNodes[key] }, { __index = env })
			setfenv(f, menv)
			cache[key] = f()
		end
		return cache[key]
	end
	env = setmetatable({
		game = clientGame, workspace = G("Workspace"), Instance = { new = G }, require = clientRequire,
		warn = function(...) table.insert(warns, table.concat({ ... }, " ")) end,
	}, { __index = baseEnv })

	-- start the controllers the way ClientBootstrap does
	local ctrls = {}
	for _, m in folders.Controllers:GetChildren() do
		local ok, c = pcall(clientRequire, m)
		expect(ok, "client controller loads: " .. m.Name .. (if ok then "" else " (" .. tostring(c) .. ")"))
		table.insert(ctrls, c)
	end
	for _, c in ctrls do if c.Init then c:Init() end end
	daemonMode = true
	for _, c in ctrls do if c.Start then task.spawn(function() c:Start() end) end end
	daemonMode = false
	settle()
	expect(#ctrls == 8, "client starts 8 controllers")
	expect(#warns == 0, "client printed no warnings: " .. table.concat(warns, " | "))

	-- helpers
	local function find(root, pred)
		for _, o in descendants(root, {}) do if pred(o) then return o end end
		return nil
	end
	local function textOf(o) local t = rawget(o, "Text") return if type(t) == "string" then t else nil end
	local function findText(root, s) return find(root, function(o) local t = textOf(o) return t ~= nil and t:find(s, 1, true) ~= nil end) end
	local function click(o)
		for _, ev in { "Activated", "MouseButton1Click" } do
			local s = rawget(o, ev)
			if s then s:_fire() end
		end
		settle()
	end
	local function guiNamed(n) for _, g in playerGui._kids do if g.Name == n then return g end end return nil end

	-- 1. HUD
	local hud = guiNamed("HUD")
	expect(hud ~= nil, "HUD gui exists")
	expect(hud.Enabled == false, "the HUD stays hidden behind the title screen")
	local UIBusMod = clientRequire(modNodes["Controllers.UIBus"])
	expect(UIBusMod.introActive == true, "the intro is marked active while the title is up")
	UIBusMod.introActive = false -- the next checks exercise the phone as if the title were closed
	expect(findText(hud, "$") ~= nil, "HUD shows cash")
	local phoneBtn, gearBtn, bakeBtn = findText(hud, "📱 Phone"), findText(hud, "🔧 Gear"), findText(hud, "🍪 Bake")
	expect(phoneBtn and gearBtn and bakeBtn, "HUD has Phone, Gear and Bake buttons")

	-- 2. Gear works from the first minute
	click(gearBtn)
	local phoneGui = guiNamed("Phone")
	expect(phoneGui ~= nil and phoneGui.Enabled == true, "Gear button opens the phone")
	expect(findText(phoneGui, "GearUp") ~= nil, "Gear button shows GearUp")
	expect(findText(phoneGui, "Deliver your first order") == nil, "GearUp is not locked behind an order")

	-- 3. Phone toggles and lists apps
	phoneGui.Enabled = false
	click(phoneBtn)
	expect(phoneGui.Enabled == true, "Phone button opens the phone")
	click(findText(phoneGui, "<")) -- back to the home screen
	expect(findText(phoneGui, "PantryDash") ~= nil and findText(phoneGui, "CrumbChat") ~= nil, "phone home lists apps")
	click(phoneBtn)
	expect(phoneGui.Enabled == false, "Phone button closes the phone again")
	actions.TogglePhone(nil, "Begin")
	expect(phoneGui.Enabled == true, "P key opens the phone")
	actions.TogglePhone(nil, "Begin")
	UIBusMod.introActive = true
	actions.TogglePhone(nil, "Begin")
	expect(phoneGui.Enabled == false, "P does nothing while the title screen is up")
	actions.TogglePhone(nil, "Begin")

	-- 4. Real InteractionService: prompt + Bake shortcut
	local station = Instance.new("Part")
	station.Name = "Counter"
	station.Position = Vector3.new(-39, 2.5, -83)
	station.Size = Vector3.new(14, 4, 4)
	station.CFrame = CFrame.new(station.Position)
	station.Parent = workspace
	config.tagged.BakeStation = { station }
	local real = REAL_INTERACTION(G("ModuleScript", "InteractionService"))
	real:Init()
	real:Start()
	local prompt = station:FindFirstChild("StationPrompt")
	expect(prompt ~= nil, "server puts a ProximityPrompt on the BakeStation")
	expect(prompt.ActionText == "Bake", "prompt reads Bake")

	local root = { Position = Vector3.new(-30, 3, -57), FindFirstChild = function() return nil end, IsA = function() return true end }
	P.Character = { FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return root end end }
	-- far away: pressing E does nothing
	prompt.Triggered:_fire(P) settle()
	expect(not guiNamed("Baking") or guiNamed("Baking").Enabled ~= true, "prompt does nothing when you are far away")
	-- Bake shortcut walks you over and opens the kitchen
	click(bakeBtn)
	expect(root.CFrame ~= nil and root.CFrame.Position.Z < -70, "Bake shortcut moves you to the kitchen")
	local bakeGui = guiNamed("Baking") or guiNamed("Bake") or guiNamed("BakeStation")
	expect(bakeGui ~= nil and bakeGui.Enabled == true, "Bake shortcut opens the kitchen")
	expect(findText(bakeGui, "Start baking") ~= nil, "kitchen shows a Start baking button")
	click(findText(bakeGui, "Close"))
	expect(bakeGui.Enabled == false, "kitchen closes")
	-- the kitchen can be left from any screen with the X in the corner
	clock += 2
	click(bakeBtn)
	expect(bakeGui.Enabled == true, "kitchen reopens")
	click(find(bakeGui, function(o) return rawget(o, "Name") == "Exit" end))
	expect(bakeGui.Enabled == false, "the X in the corner closes the kitchen")
	-- standing at the counter, pressing E opens the kitchen too
	root.Position = Vector3.new(-39, 3, -77)
	clock += 1
	prompt.Triggered:_fire(P) settle()
	expect(bakeGui.Enabled == true, "pressing E at the counter opens the kitchen")

	-- 5. start a bake from the real UI
	click(findText(bakeGui, "Start baking"))
	expect(call(P, "BakeStatus") ~= nil, "Start baking starts a server bake")
	expect(findText(bakeGui, "Mix") ~= nil, "mix stage is shown")
	-- play the whole bake through the real buttons
	local reached = false
	for _ = 1, 60 do
		local buttons = {}
		for _, o in descendants(bakeGui, {}) do
			local t = textOf(o)
			if t and rawget(o, "Activated") and #rawget(o, "Activated")._hs > 0 then table.insert(buttons, o) end
		end
		local labels = {}
		for _, b in buttons do table.insert(labels, b.Text) end
		if findText(bakeGui, "Bake another batch") then reached = true break end
		local pick = nil
		for _, b in buttons do if b.Text:find("Standard") then pick = b end end
		for _, b in buttons do if not pick and b.Text ~= "Close" and b.Text ~= "X" then pick = b break end end
		if not pick then break end
		clock += 3.2
		click(pick)
		settle()
	end
	expect(reached, "a full bake can be finished with the on-screen buttons")

	-- 6. the client asks for its state before the save has loaded (this left the HUD stuck on "Loading...")
	local late = newPlayer(9200, "Early")
	local got = "pending"
	table.insert(players, late) -- present in the server, profile not loaded yet
	task.spawn(function() got = call(late, "GetState") end)
	expect(got == "pending", "GetState waits while the save is still loading")
	table.remove(players)
	join(late)
	settle()
	expect(type(got) == "table" and got.cash ~= nil, "GetState answers once the save has loaded")

	-- 7. unpublished place / Studio without API access: no 30 second wait, the player gets temporary data at once
	store.fail, store.msg = 100, "You must publish this place to the web to access DataStore."
	local offline = newPlayer(9300, "Offline")
	local before = store.calls
	join(offline)
	store.fail, store.msg = 0, nil
	expect(store.calls - before == 1, "an unpublished place is detected on the first attempt")
	expect(T.state(offline) ~= nil, "the player still gets a playable (unsaved) profile")

	-- 8. every remote a client script names is created by the server up front
	local RemotesMod = require(nodes["Shared.Modules.Remotes"])
	local declared = {}
	for _, n in RemotesMod.CLIENT_EVENTS do declared[n] = "event" end
	for _, n in RemotesMod.CLIENT_FUNCS do declared[n] = "func" end
	local missing = {}
	for key, src in CLIENT_SRC do
		for kind, name in src:gmatch('Remotes%.(%a+)%("(%a+)"%)') do
			if declared[name] ~= kind then table.insert(missing, key .. ":" .. name) end
		end
	end
	expect(#missing == 0, "client remotes are all pre-declared: " .. table.concat(missing, ", "))
	RemotesMod.declareAll()
	expect(R.GetState ~= nil and R.Notify ~= nil and R.BakeStatus ~= nil, "declareAll creates the remotes")

	-- 9. title screen and first-join cutscene
	local intro = guiNamed("Intro")
	expect(intro ~= nil, "title screen is shown on load")
	expect(findText(intro, "Cookie Empire") ~= nil, "title screen shows the game name")
	click(findText(intro, "Play"))
	expect(findText(intro, "Madame Vex") ~= nil, "first join: the cutscene starts after Play")
	expect(findText(intro, "Skip intro") ~= nil, "the cutscene has a Skip intro button")
	local seen = 0
	for _ = 1, 30 do
		if findText(intro, "Take the punishment") then break end
		local nxt = findText(intro, "Next") or findText(intro, "Skip typing")
		if not nxt then break end
		clock += 1
		click(nxt)
		seen += 1
	end
	expect(findText(intro, "Take the punishment") ~= nil and findText(intro, "Bake cookies for her") ~= nil, "the cutscene ends with two choices")
	local firstOrder = T.ordersOf(P)[1]
	click(findText(intro, "Bake cookies for her"))
	expect(T.state(P).milestones.introDone == true and T.state(P).milestones.introBake == true, "the bake choice is saved")
	local accepted = false
	for _, o in T.ordersOf(P) do if o.state == "Accepted" then accepted = true end end
	expect(accepted, "choosing to bake accepts the first order")
	click(findText(intro, "Start baking!"))
	expect(guiNamed("Intro") == nil, "Start baking closes the cutscene")
	expect(hud.Enabled == true and UIBusMod.introActive == false, "the HUD appears once the intro is finished")
	expect(select(1, call(P, "IntroChoice", "bake")) == false, "the choice cannot be made twice")

	-- punishment path on a fresh save, and no cutscene on later joins
	local Q = newPlayer(9400, "Punished")
	join(Q)
	local cashBefore = T.state(Q).cash
	local ok2 = call(Q, "IntroChoice", "punish")
	expect(ok2 == true and T.state(Q).cash == cashBefore - 50, "the punishment costs $50")
	local stillAvailable = false
	for _, o in T.ordersOf(Q) do if o.state == "Available" then stillAvailable = true end end
	expect(stillAvailable, "after the punishment the first order is still waiting")
	expect(select(1, call(Q, "IntroChoice", "nonsense")) == false, "an invalid choice is refused")

	-- 10. in Studio an unreachable DataStore costs one attempt, not half a minute
	store.fail = 100
	local studioDown = newPlayer(9500, "StudioDown")
	local callsBefore = store.calls
	join(studioDown)
	store.fail = 0
	expect(store.calls - callsBefore == 1 and T.state(studioDown) ~= nil, "Studio with a failing DataStore: one attempt, then temporary data")
end
