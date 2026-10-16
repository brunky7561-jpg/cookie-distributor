--!strict
-- Ingredient shop panel. Press B to open. Prices come from the shared config; the server validates every purchase.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local HUD = require(script.Parent.HUDController)
local UIBus = require(script.Parent.UIBus)

local ShopController = {}

function ShopController:Init() end

function ShopController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("ScrollingFrame")
	frame.Size = UDim2.fromOffset(360, 420)
	frame.Position = UDim2.new(0.5, -180, 0.5, -210)
	frame.BackgroundColor3 = Color3.fromRGB(40, 28, 20)
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.Parent = gui
	Instance.new("UICorner").Parent = frame
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(255, 232, 190)
	title.Text = "Ingredient Shop"
	title.LayoutOrder = -1
	title.Parent = frame

	local ids = {}
	for id in Ingredients do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Ingredients[a].cost < Ingredients[b].cost
	end)

	local buy = Remotes.func("BuyIngredient")
	local owned: { [string]: TextButton } = {}
	for i, id in ids do
		local ing = Ingredients[id]
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -12, 0, 36)
		btn.LayoutOrder = i
		btn.BackgroundColor3 = Color3.fromRGB(94, 64, 40)
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 16
		btn.Text = `{ing.name}  ${ing.cost}`
		btn.Parent = frame
		owned[id] = btn
		btn.Activated:Connect(function()
			local ok, reason = buy:InvokeServer(id, 1)
			if not ok then
				btn.Text = `{ing.name}: {reason}`
				task.delay(1.5, function()
					btn.Text = `{ing.name}  ${ing.cost}`
				end)
			end
		end)
	end

	HUD:OnState(function(state)
		for id, btn in owned do
			local n = state.ingredients[id] or 0
			btn.Text = `{Ingredients[id].name}  ${Ingredients[id].cost}   (have {n})`
		end
	end)

	local function toggle()
		gui.Enabled = not gui.Enabled
	end

	UIBus.Toggle.Event:Connect(function(name)
		if name == "Shop" then
			toggle()
		end
	end)

	ContextActionService:BindAction("ToggleShop", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.B)
end

return ShopController
