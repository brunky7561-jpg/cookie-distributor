--!strict
-- Always-visible HUD: cash and level, the current objective, and on-screen Phone / Shop buttons (touch friendly).
-- Also keeps the latest server state for other controllers (HUD:OnState).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local UIBus = require(script.Parent.UIBus)

local HUD = {}
HUD.state = nil :: any
local listeners: { (any) -> () } = {}

function HUD:OnState(fn: (any) -> ())
	table.insert(listeners, fn)
	if HUD.state then
		fn(HUD.state)
	end
end

local function objectiveFor(state: any): string
	if #state.batches == 0 then
		return "Make your first batch: walk to the counter or oven in your kitchen and press E (or tap Bake)."
	end
	return "Nice! Open the phone to see who wants cookies, then deliver an order."
end

local function card(parent: Instance, size: UDim2, position: UDim2): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = Theme.Buttercream
	f.BorderSizePixel = 0
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Cocoa
	stroke.Thickness = 2
	stroke.Parent = f
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
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Cocoa
	stroke.Thickness = 2
	stroke.Parent = b
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

	actionButton(gui, "Phone", Theme.Coral, UDim2.new(1, -12, 1, -12), function()
		UIBus.Toggle:Fire("Phone")
	end)
	actionButton(gui, "Shop", Theme.Butter, UDim2.new(1, -144, 1, -12), function()
		UIBus.Toggle:Fire("Shop")
	end)

	local function apply(state: any)
		HUD.state = state
		stats.Text = `$ {math.floor(state.cash)}    Lv {state.level}`
		objective.Text = objectiveFor(state)
		for _, fn in listeners do
			task.spawn(fn, state)
		end
	end

	Remotes.event("StateUpdated").OnClientEvent:Connect(apply)
	local ok, state = pcall(function()
		return Remotes.func("GetState"):InvokeServer()
	end)
	if ok and state then
		apply(state)
	end
end

return HUD
