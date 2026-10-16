--!strict
-- Shows cash and level, and keeps the latest server state for other controllers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local HUD = {}
HUD.state = nil :: any
local listeners: { (any) -> () } = {}

function HUD:OnState(fn: (any) -> ())
	table.insert(listeners, fn)
	if HUD.state then
		fn(HUD.state)
	end
end

function HUD:Init() end

function HUD:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(220, 56)
	label.Position = UDim2.new(0, 12, 0, 12)
	label.BackgroundColor3 = Color3.fromRGB(40, 28, 20)
	label.BackgroundTransparency = 0.2
	label.TextColor3 = Color3.fromRGB(255, 232, 190)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = "Loading..."
	label.Parent = gui
	Instance.new("UICorner").Parent = label

	local function apply(state: any)
		HUD.state = state
		label.Text = `$ {math.floor(state.cash)}   Lv {state.level}\n[B] Shop  [K] Bake`
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
