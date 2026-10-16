--!strict
-- Phone (Messages): shows every order with its current state and the one action that moves it forward.
-- Open with P or the Phone button. All state changes are requested from the server; this only draws them.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local HUD = require(script.Parent.HUDController)
local UIBus = require(script.Parent.UIBus)

local PhoneController = {}

local STATES = { "Available", "Accepted", "In Production", "Ready", "Delivered", "Paid" }

function PhoneController:Init() end

function PhoneController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Phone"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local toastGui = Instance.new("ScreenGui")
	toastGui.Name = "PhoneToasts"
	toastGui.ResetOnSpawn = false
	toastGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.fromOffset(340, 56)
	toast.Position = UDim2.new(1, -352, 0, 12)
	toast.BackgroundColor3 = Theme.Buttercream
	toast.TextColor3 = Theme.Cocoa
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 15
	toast.TextWrapped = true
	toast.Visible = false
	toast.Parent = toastGui
	Instance.new("UICorner").Parent = toast
	local toastStroke = Instance.new("UIStroke")
	toastStroke.Color = Theme.Cocoa
	toastStroke.Thickness = 2
	toastStroke.Parent = toast
	local toastId = 0
	local function say(text: string)
		toastId += 1
		local mine = toastId
		toast.Text = text
		toast.Visible = true
		task.delay(5, function()
			if toastId == mine then
				toast.Visible = false
			end
		end)
	end

	local frame = Instance.new("ScrollingFrame")
	frame.Size = UDim2.fromOffset(400, 480)
	frame.Position = UDim2.new(0.5, -200, 0.5, -240)
	frame.BackgroundColor3 = Theme.Buttercream
	frame.BorderSizePixel = 0
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.CanvasSize = UDim2.new()
	frame.ScrollBarThickness = 6
	frame.Parent = gui
	Instance.new("UICorner").Parent = frame
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Theme.Cocoa
	frameStroke.Thickness = 2
	frameStroke.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local receipt: any = nil -- result of the last delivery

	local function text(t: string, h: number, bold: boolean?): TextLabel
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 0, h)
		l.BackgroundTransparency = 1
		l.TextColor3 = Theme.Cocoa
		l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
		l.TextSize = 15
		l.TextWrapped = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextYAlignment = Enum.TextYAlignment.Top
		l.Text = t
		l.Parent = frame
		return l
	end

	local function btn(t: string, color: Color3): TextButton
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, 0, 0, 40)
		b.BackgroundColor3 = color
		b.TextColor3 = Theme.Cocoa
		b.Font = Enum.Font.GothamBold
		b.TextSize = 16
		b.Text = t
		b.Parent = frame
		Instance.new("UICorner").Parent = b
		return b
	end

	local function stateLine(current: string): string
		local parts = {}
		for _, s in STATES do
			table.insert(parts, if s == current then `[{s}]` else s)
		end
		return table.concat(parts, " > ")
	end

	local render

	local function act(action: string, orderId: number, extra: any?)
		local ok, msg = Remotes.func("OrderAction"):InvokeServer(action, orderId, extra)
		if ok then
			if action == "deliver" and type(msg) == "table" then
				receipt = msg
				say(`{msg.customerName}: "{msg.reaction}"  +${msg.pay + msg.tip}`)
			else
				say(tostring(msg))
			end
		else
			say(tostring(msg))
		end
		render()
	end

	-- Stock boxes that could fill this order right now.
	local function matchingBoxes(order: any): { any }
		local found = {}
		local state = HUD.state
		for _, b in (state and state.batches) or {} do
			if b.recipeId == order.recipeId and not b.reservedFor and b.count >= order.count then
				table.insert(found, b)
			end
		end
		return found
	end

	function render()
		for _, c in frame:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		text("Messages", 26, true).TextSize = 20

		if receipt then
			text(`Receipt: {receipt.customerName}`, 22, true)
			local tipText = if receipt.tip > 0 then " (+$" .. receipt.tip .. " tip)" else ""
			text("Delivered and paid  +$" .. receipt.pay .. tipText, 22)
			text(`Batch grade: {receipt.grade or "n/a"}`, 22)
			text(tostring(receipt.feedback or ""), 44)
			text(`"{receipt.reaction}"  ({receipt.relationship})`, 44)
			text(table.concat(receipt.states, " > "), 44)
			if receipt.wasFirst then
				text("First order complete! New customers will text you soon.", 44, true)
			end
			btn("Close receipt", Theme.Butter).Activated:Once(function()
				receipt = nil
				render()
			end)
		end

		local shown = 0
		for _, o in HUD.orders do
			shown += 1
			text(`{o.customerName}: "{o.text}"`, 52, true)
			text(`{o.count}x {o.recipeName}  |  Pays about ${o.offer}  |  Deliver to: {o.destination}`, 36)
			if o.deadline then
				local left = math.max(0, o.deadline - os.time())
				text(`Time left: {math.floor(left / 60)} min`, 18)
			else
				text("No deadline. Take your time.", 18)
			end
			text(stateLine(o.state), 36)

			if o.state == "Available" then
				btn("Accept", Theme.Mint).Activated:Once(function()
					act("accept", o.id)
				end)
				btn("Decline", Theme.Coral).Activated:Once(function()
					act("cancel", o.id)
				end)
			elseif o.state == "Accepted" then
				text("Next: bake it at your kitchen counter (press E).", 36)
				for _, b in matchingBoxes(o) do
					btn(`Use stock box ({b.grade or "Good"}, {b.count} cookies)`, Theme.Butter).Activated:Once(function()
						act("assign", o.id, b.id)
					end)
				end
				btn("Cancel order", Theme.Coral).Activated:Once(function()
					act("cancel", o.id)
				end)
			elseif o.state == "In Production" then
				text("Baking in progress. Finish at the kitchen station.", 36)
				btn("Cancel order", Theme.Coral).Activated:Once(function()
					act("cancel", o.id)
				end)
			elseif o.state == "Ready" then
				btn("Deliver", Theme.Mint).Activated:Once(function()
					act("deliver", o.id)
				end)
			end
		end
		if shown == 0 and not receipt then
			text("No messages yet. Customers will text you soon.", 40)
		end
	end

	Remotes.event("Notify").OnClientEvent:Connect(function(msg)
		say(tostring(msg))
	end)

	HUD:OnOrders(function()
		if gui.Enabled then
			render()
		end
	end)
	HUD:OnState(function()
		if gui.Enabled then
			render()
		end
	end)

	local function toggle()
		gui.Enabled = not gui.Enabled
		if gui.Enabled then
			render()
		end
	end

	UIBus.Toggle.Event:Connect(function(name)
		if name == "Phone" then
			toggle()
		end
	end)

	ContextActionService:BindAction("TogglePhone", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.P)

	render()
end

return PhoneController
