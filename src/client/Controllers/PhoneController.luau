--!strict
-- Phone: shows customer orders and lets you hand over a batch. Press P to open.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local HUD = require(script.Parent.HUD)

local PhoneController = {}

local CREAM = Color3.fromRGB(255, 232, 190)
local BROWN = Color3.fromRGB(94, 64, 40)

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
	toast.BackgroundColor3 = Color3.fromRGB(40, 28, 20)
	toast.TextColor3 = CREAM
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 15
	toast.TextWrapped = true
	toast.Visible = false
	toast.Parent = toastGui
	local toastId = 0
	local function say(text: string)
		toastId += 1
		local mine = toastId
		toast.Text = text
		toast.Visible = true
		task.delay(4, function()
			if toastId == mine then
				toast.Visible = false
			end
		end)
	end

	local frame = Instance.new("ScrollingFrame")
	frame.Size = UDim2.fromOffset(380, 460)
	frame.Position = UDim2.new(0.5, -190, 0.5, -230)
	frame.BackgroundColor3 = Color3.fromRGB(40, 28, 20)
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.CanvasSize = UDim2.new()
	frame.Parent = gui
	Instance.new("UICorner").Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local orders: { [number]: any } = {}
	local chooseFor: number? = nil

	local function text(t: string, h: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, -12, 0, h)
		l.BackgroundTransparency = 1
		l.TextColor3 = CREAM
		l.Font = Enum.Font.Gotham
		l.TextSize = 15
		l.TextWrapped = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = t
		l.Parent = frame
		return l
	end

	local function btn(t: string): TextButton
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, -12, 0, 32)
		b.BackgroundColor3 = BROWN
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.Gotham
		b.TextSize = 15
		b.Text = t
		b.Parent = frame
		return b
	end

	local render

	function render()
		for _, c in frame:GetChildren() do
			if not c:IsA("UIListLayout") and not c:IsA("UICorner") then
				c:Destroy()
			end
		end
		text("Phone", 28).Font = Enum.Font.GothamBold

		if chooseFor then
			local order = orders[chooseFor]
			if not order then
				chooseFor = nil
				return render()
			end
			text(`Deliver to {order.customerName} (needs {order.count} cookies)`, 40)
			local state = HUD.state
			local any = false
			for _, b in (state and state.batches) or {} do
				any = true
				local choice = btn(`{b.name}  Q{math.floor(b.quality * 100)}%  Craving {b.craving}  x{b.count}`)
				choice.Activated:Once(function()
					local ok, res = Remotes.func("DeliverOrder"):InvokeServer(order.id, b.id)
					if ok then
						orders[order.id] = nil
						chooseFor = nil
						say(
							`{res.customerName}: "{res.reaction}"  +${res.pay}  ({res.relationship}){if res.ghosted then " They need a break from cookies." else ""}`
						)
					else
						say(tostring(res))
					end
					render()
				end)
			end
			if not any then
				text("You have no cookies. Press K to bake some.", 40)
			end
			btn("Back").Activated:Once(function()
				chooseFor = nil
				render()
			end)
			return
		end

		local shown = 0
		for _, o in orders do
			shown += 1
			text(`{o.customerName} ({o.personality}): "{o.text}"  Offer ${o.offer}`, 64)
			local row = btn("Deliver")
			row.Activated:Once(function()
				chooseFor = o.id
				render()
			end)
			local decline = btn("Decline")
			decline.Activated:Once(function()
				Remotes.func("DeclineOrder"):InvokeServer(o.id)
				orders[o.id] = nil
				render()
			end)
		end
		if shown == 0 then
			text("No messages yet. Customers will text you soon.", 40)
		end
	end

	Remotes.event("OrderReceived").OnClientEvent:Connect(function(order)
		orders[order.id] = order
		say(`New order from {order.customerName}! Press P.`)
		render()
	end)
	Remotes.event("OrderExpired").OnClientEvent:Connect(function(id)
		orders[id] = nil
		if chooseFor == id then
			chooseFor = nil
		end
		render()
	end)

	HUD:OnState(function()
		if gui.Enabled and chooseFor then
			render()
		end
	end)

	ContextActionService:BindAction("TogglePhone", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			gui.Enabled = not gui.Enabled
			if gui.Enabled then
				render()
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.P)

	render()
end

return PhoneController
