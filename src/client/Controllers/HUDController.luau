--!strict
-- Always-visible HUD: cash and level, the current objective, and on-screen Phone / Gear buttons (touch friendly).
-- Also keeps the latest server state for other controllers (HUD:OnState).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Milestones = require(ReplicatedStorage.Shared.Config.Milestones)
local RunService = game:GetService("RunService")
local UIBus = require(script.Parent.UIBus)

local HUD = {}
HUD.state = nil :: any
HUD.orders = {} :: { any }
local listeners: { (any) -> () } = {}
local orderListeners: { (any) -> () } = {}

-- Called whenever the server sends the full order list (and once right away if we already have it).
function HUD:OnOrders(fn: (any) -> ())
	table.insert(orderListeners, fn)
	fn(HUD.orders)
end

function HUD:OnState(fn: (any) -> ())
	table.insert(listeners, fn)
	if HUD.state then
		fn(HUD.state)
	end
end

-- The objective follows the most advanced active order, so the first loop is always spelled out.
local function objectiveFor(state: any, orders: { any }): string
	local best: any = nil
	local rank = { Available = 1, Accepted = 2, ["In Production"] = 3, Ready = 4 }
	for _, o in orders do
		if not best or (rank[o.state] or 0) > (rank[best.state] or 0) then
			best = o
		end
	end
	if best then
		if best.state == "Available" then
			return `Open your phone (P or the Phone button) and accept {best.customerName}'s order.`
		elseif best.state == "Accepted" then
			return `Tap the 🍪 Bake button (bottom right) to bake {best.recipeName}. Or walk to the kitchen counter and press E.`
		elseif best.state == "In Production" then
			return "Finish your bake: tap the 🍪 Bake button (or press E at the counter) to continue."
		elseif best.state == "Ready" then
			return `Open your phone and deliver the cookies to {best.customerName}.`
		end
	end
	if state.milestones and state.milestones.firstOrderDone then
		return "Nice work! Wait for new orders, or order ingredients in PantryDash on your phone."
	end
	return "Waiting for your first customer to text you..."
end

local function card(parent: Instance, size: UDim2, position: UDim2): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = Theme.Buttercream
	f.BorderSizePixel = 0
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Cocoa
	stroke.Thickness = 2
	stroke.Transparency = 0.1
	stroke.Parent = f
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Theme.Cream, Theme.Peach)
	grad.Parent = f
	return f
end

local function label(parent: Instance, text: string, size: number, pos: UDim2, dim: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = dim
	l.Position = pos
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = Theme.Cocoa
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Parent = parent
	return l
end

local function actionButton(parent: Instance, text: string, color: Color3, pos: UDim2, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(120, 56) -- large enough for touch
	b.Position = pos
	b.AnchorPoint = Vector2.new(1, 1)
	b.BackgroundColor3 = color
	b.TextColor3 = Theme.Cocoa
	b.Font = Enum.Font.GothamBold
	b.TextSize = 20
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Cocoa
	stroke.Thickness = 2.5
	stroke.Parent = b
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4), color)
	grad.Parent = b
	b.Activated:Connect(onClick)
	return b
end

function HUD:Init() end

function HUD:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local top = card(gui, UDim2.fromOffset(300, 96), UDim2.new(0, 12, 0, 12))
	local stats = label(top, "Loading...", 22, UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 28))
	local objective = label(top, "", 15, UDim2.fromOffset(12, 36), UDim2.new(1, -24, 0, 54))
	objective.Font = Enum.Font.Gotham
	objective.TextYAlignment = Enum.TextYAlignment.Top

	-- Next-goal panel: always shows the first unfinished business milestone.
	local goalCard = card(gui, UDim2.fromOffset(300, 78), UDim2.new(0, 12, 0, 116))
	local goalTitle = label(goalCard, "NEXT GOAL", 12, UDim2.fromOffset(12, 4), UDim2.new(1, -24, 0, 16))
	goalTitle.TextColor3 = Theme.Coral
	local goalText = label(goalCard, "", 15, UDim2.fromOffset(12, 20), UDim2.new(1, -24, 0, 22))
	local goalHint = label(goalCard, "", 13, UDim2.fromOffset(12, 42), UDim2.new(1, -24, 0, 34))
	goalHint.Font = Enum.Font.Gotham
	goalHint.TextYAlignment = Enum.TextYAlignment.Top

	-- Compact order tracker: the current order's state stays visible while the phone is closed.
	local trackCard = card(gui, UDim2.fromOffset(300, 48), UDim2.new(0, 12, 0, 202))
	local trackText = label(trackCard, "", 14, UDim2.fromOffset(12, 4), UDim2.new(1, -24, 0, 40))
	trackText.Font = Enum.Font.GothamBold
	trackCard.Visible = false

	-- Dev-only: wipes your save so the first-time flow can be replayed. The server refuses it outside Studio.
	if RunService:IsStudio() then
		local reset = Instance.new("TextButton")
		reset.Size = UDim2.fromOffset(150, 32)
		reset.Position = UDim2.new(0, 12, 1, -12)
		reset.AnchorPoint = Vector2.new(0, 1)
		reset.BackgroundColor3 = Theme.Blueberry
		reset.TextColor3 = Theme.Cocoa
		reset.Font = Enum.Font.GothamBold
		reset.TextSize = 13
		reset.Text = "Dev: reset my save"
		reset.Parent = gui
		Instance.new("UICorner").Parent = reset
		reset.Activated:Connect(function()
			Remotes.func("DevReset"):InvokeServer()
		end)
		local boost = reset:Clone()
		boost.Position = UDim2.new(0, 12, 1, -50)
		boost.Size = UDim2.fromOffset(190, 32)
		boost.BackgroundColor3 = Theme.Mint
		boost.Text = "Dev: unlock everything"
		boost.Parent = gui
		boost.Activated:Connect(function()
			Remotes.func("DevBoost"):InvokeServer()
		end)
	end

	actionButton(gui, "📱 Phone", Theme.Coral, UDim2.new(1, -12, 1, -12), function()
		UIBus.Toggle:Fire("Phone")
	end)
	actionButton(gui, "🔧 Gear", Theme.Butter, UDim2.new(1, -144, 1, -12), function()
		UIBus.Open:Fire("PhoneGear")
	end)
	actionButton(gui, "🍪 Bake", Theme.Mint, UDim2.new(1, -276, 1, -12), function()
		-- the server walks you to the kitchen counter if you are far away, then the kitchen opens
		local ok = Remotes.func("GoToKitchen"):InvokeServer()
		if ok then
			UIBus.Open:Fire("Bake")
		end
	end)

	local function refreshObjective()
		if HUD.state then
			objective.Text = objectiveFor(HUD.state, HUD.orders)
			local top: any = nil
			local rank = { Available = 1, Accepted = 2, ["In Production"] = 3, Ready = 4 }
			for _, o in HUD.orders do
				if not top or (rank[o.state] or 0) > (rank[top.state] or 0) then
					top = o
				end
			end
			trackCard.Visible = top ~= nil
			if top then
				trackText.Text = `ORDER: {top.customerName}, {top.count}x {top.recipeName}\n[{top.state}]`
			end
			goalCard.Visible = HUD.state.settings == nil or HUD.state.settings.guidance ~= false
			local goal = Milestones.next(HUD.state)
			if goal then
				goalText.Text = goal.title
				goalHint.Text = goal.hint
			else
				goalText.Text = "All starter goals complete!"
				goalHint.Text = "New goals unlock as the game grows."
			end
		end
	end

	local function apply(state: any)
		HUD.state = state
		stats.Text = `💰 ${math.floor(state.cash)}     ⭐ Lv {state.level}`
		refreshObjective()
		for _, fn in listeners do
			task.spawn(fn, state)
		end
	end

	local function applyOrders(list: any)
		HUD.orders = list
		refreshObjective()
		for _, fn in orderListeners do
			task.spawn(fn, list)
		end
	end

	Remotes.event("OrdersUpdated").OnClientEvent:Connect(applyOrders)
	Remotes.event("StateUpdated").OnClientEvent:Connect(apply)
	task.spawn(function()
		local okOrders, list = pcall(function()
			return Remotes.func("GetOrders"):InvokeServer()
		end)
		if okOrders and list then
			applyOrders(list)
		end
	end)
	local ok, state = pcall(function()
		return Remotes.func("GetState"):InvokeServer()
	end)
	if ok and state then
		apply(state)
	end
end

return HUD
