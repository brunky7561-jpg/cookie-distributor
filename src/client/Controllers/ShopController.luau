--!strict
-- Gear panel: buy equipment upgrades. Press B or tap Gear. The server validates every purchase.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
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
	frame.Size = UDim2.fromOffset(380, 460)
	frame.Position = UDim2.new(0.5, -190, 0.5, -230)
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
	title.Text = "Gear"
	title.LayoutOrder = -1
	title.Parent = frame

	-- Equipment section: one button per purchasable item
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 36)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextSize = 20
	header.TextColor3 = Color3.fromRGB(255, 232, 190)
	header.Text = "Equipment"
	header.LayoutOrder = 100
	header.Parent = frame

	local gear: { [string]: TextButton } = {}
	local gearIds = {}
	for id, def in Equipment.catalog do
		if def.price > 0 then
			table.insert(gearIds, id)
		end
	end
	table.sort(gearIds)
	local message = Instance.new("TextLabel")
	message.Size = UDim2.new(1, -12, 0, 24)
	message.BackgroundTransparency = 1
	message.Font = Enum.Font.GothamBold
	message.TextSize = 14
	message.TextColor3 = Color3.fromRGB(255, 190, 110)
	message.Text = ""
	message.LayoutOrder = 200
	message.Parent = frame
	for i, id in gearIds do
		local def = Equipment.catalog[id]
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -12, 0, 64)
		btn.LayoutOrder = 100 + i
		btn.BackgroundColor3 = Color3.fromRGB(94, 64, 40)
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 14
		btn.TextWrapped = true
		btn.Text = `{def.name}  ${def.price}\n{def.description}`
		btn.Parent = frame
		gear[id] = btn
		btn.Activated:Connect(function()
			local _, res = Remotes.func("BuyEquipment"):InvokeServer(id)
			message.Text = tostring(res)
		end)
	end

	HUD:OnState(function(state)
		for id, btn in gear do
			local def = Equipment.catalog[id]
			if state.equipment and state.equipment[id] then
				btn.Text = `{def.name}  (owned)`
				btn.BackgroundColor3 = Color3.fromRGB(70, 110, 70)
			elseif def.requiresMilestone and not state.milestones[def.requiresMilestone] then
				btn.Text = `{def.name}  ${def.price}\nLocked: deliver your first order`
			else
				btn.Text = `{def.name}  ${def.price}\n{def.description}`
			end
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
