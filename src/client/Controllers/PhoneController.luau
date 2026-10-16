--!strict
-- Phone shell: one persistent button (or P) opens it; the home screen lists apps from Config/Apps and each app
-- draws itself into the content area. Apps live in the Apps folder and return { id, render(ctx) }.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AppsConfig = require(ReplicatedStorage.Shared.Config.Apps)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local UI = require(script.Parent.Parent.Modules.UI)
local HUD = require(script.Parent.HUDController)
local UIBus = require(script.Parent.UIBus)

local PhoneController = {}

type App = { id: string, render: (ctx: any) -> () }

function PhoneController:Init() end

function PhoneController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- load app modules
	local apps: { [string]: App } = {}
	local appsFolder = script.Parent.Parent:WaitForChild("Apps")
	for _, m in appsFolder:GetChildren() do
		if m:IsA("ModuleScript") then
			local ok, app = pcall(require, m)
			if ok and type(app) == "table" and AppsConfig.byId[app.id] then
				apps[app.id] = app
			else
				warn(`[Phone] could not load app {m.Name}: {app}`)
			end
		end
	end

	-- toasts live in their own always-on gui so they show while the phone is closed
	local toastGui = Instance.new("ScreenGui")
	toastGui.Name = "PhoneToasts"
	toastGui.ResetOnSpawn = false
	toastGui.Parent = playerGui
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.fromOffset(340, 0)
	toast.AutomaticSize = Enum.AutomaticSize.Y
	toast.Position = UDim2.new(1, -352, 0, 12)
	toast.BackgroundColor3 = Theme.Buttercream
	toast.TextColor3 = Theme.Cocoa
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 15
	toast.TextWrapped = true
	toast.Visible = false
	toast.Parent = toastGui
	UI.corner(toast)
	UI.stroke(toast)
	UI.padding(toast, 8)
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

	-- phone frame
	local gui = Instance.new("ScreenGui")
	gui.Name = "Phone"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.92, 0.88)
	frame.BackgroundColor3 = Theme.Buttercream
	frame.BorderSizePixel = 0
	frame.Parent = gui
	UI.corner(frame, 24)
	UI.stroke(frame, 5)
	UI.gradient(frame, Theme.Cream, Theme.Peach)
	local frameStroke = frame:FindFirstChildOfClass("UIStroke")
	if frameStroke then
		frameStroke.Color = Theme.Night
	end
	local limits = Instance.new("UISizeConstraint")
	limits.MinSize = Vector2.new(300, 360)
	limits.MaxSize = Vector2.new(430, 640)
	limits.Parent = frame

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 52)
	header.BackgroundColor3 = Theme.Night
	header.BorderSizePixel = 0
	header.Parent = frame
	UI.corner(header, 20)
	UI.gradient(header, Theme.Cocoa, Theme.Night)

	local backBtn = Instance.new("TextButton")
	backBtn.Size = UDim2.fromOffset(44, 44)
	backBtn.Position = UDim2.fromOffset(4, 4)
	backBtn.BackgroundColor3 = Theme.Butter
	backBtn.TextColor3 = Theme.Cocoa
	backBtn.Font = Enum.Font.GothamBold
	backBtn.TextSize = 22
	backBtn.Text = "<"
	backBtn.Parent = header
	UI.corner(backBtn)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -150, 1, 0)
	titleLabel.Position = UDim2.fromOffset(52, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Theme.Buttercream
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 20
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "Phone"
	titleLabel.Parent = header

	local cashLabel = Instance.new("TextLabel")
	cashLabel.Size = UDim2.fromOffset(60, 44)
	cashLabel.Position = UDim2.new(1, -108, 0, 4)
	cashLabel.BackgroundTransparency = 1
	cashLabel.TextColor3 = Theme.Butter
	cashLabel.Font = Enum.Font.GothamBold
	cashLabel.TextSize = 16
	cashLabel.TextXAlignment = Enum.TextXAlignment.Right
	cashLabel.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(44, 44)
	closeBtn.Position = UDim2.new(1, -48, 0, 4)
	closeBtn.BackgroundColor3 = Theme.Coral
	closeBtn.TextColor3 = Theme.Cocoa
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 20
	closeBtn.Text = "X"
	closeBtn.Parent = header
	UI.corner(closeBtn)

	local content = Instance.new("ScrollingFrame")
	content.Position = UDim2.fromOffset(0, 56)
	content.Size = UDim2.new(1, 0, 1, -56)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.ScrollBarThickness = 6
	content.Parent = frame
	UI.padding(content, 8)
	UI.list(content, 6)

	local current: string? = nil -- open app id, nil = home screen
	local announced: { [string]: boolean } = {}

	local function unlocked(appId: string): boolean
		local state = HUD.state
		return state ~= nil and AppsConfig.byId[appId].unlock(state)
	end

	local function seen(appId: string): boolean
		local state = HUD.state
		return state ~= nil and state.settings ~= nil and state.settings.seenApps ~= nil and state.settings.seenApps[appId] == true
	end

	local render

	local function openApp(appId: string?)
		current = appId
		if appId and not seen(appId) then
			task.spawn(function()
				Remotes.func("SeenApp"):InvokeServer(appId)
			end)
		end
		render()
	end

	function render()
		UI.clear(content)
		local state = HUD.state
		UI.textScale = if state and state.settings and state.settings.textScale then state.settings.textScale else 1
		backBtn.Visible = current ~= nil
		cashLabel.Text = if state then UI.money(state.cash) else ""
		if not state then
			titleLabel.Text = "Phone"
			UI.label(content, "Loading...")
			return
		end
		if current and apps[current] and unlocked(current) then
			titleLabel.Text = AppsConfig.byId[current].title
			apps[current].render({
				content = content,
				state = state,
				orders = HUD.orders,
				say = say,
				back = function()
					openApp(nil)
				end,
				rerender = render,
			})
			return
		end
		current = nil
		backBtn.Visible = false
		local brand = if state.settings.brandName ~= "" then state.settings.brandName else "Phone"
		titleLabel.Text = brand
		local grid = Instance.new("Frame")
		grid.Size = UDim2.new(1, 0, 0, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.BackgroundTransparency = 1
		grid.Parent = content
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(0.5, -6, 0, 104)
		layout.CellPadding = UDim2.fromOffset(8, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for i, def in AppsConfig.list do
			local on = unlocked(def.id) and apps[def.id] ~= nil
			local b = Instance.new("TextButton")
			b.LayoutOrder = i
			b.BackgroundColor3 = if on then Theme[def.color] else Color3.fromRGB(205, 198, 184)
			b.Text = ""
			b.AutoButtonColor = on
			b.Parent = grid
			UI.corner(b, 18)
			UI.stroke(b, 2)
			UI.gradient(b)
			local icon = Instance.new("TextLabel")
			icon.BackgroundTransparency = 1
			icon.Size = UDim2.new(1, 0, 0, 46)
			icon.Position = UDim2.fromOffset(0, 8)
			icon.Font = Enum.Font.GothamBold
			icon.TextSize = 36
			icon.Text = if on then def.icon else "🔒"
			icon.TextTransparency = if on then 0 else 0.35
			icon.Parent = b
			local name = Instance.new("TextLabel")
			name.BackgroundTransparency = 1
			name.Size = UDim2.new(1, -8, 0, 30)
			name.Position = UDim2.new(0, 4, 1, -34)
			name.Font = Enum.Font.GothamBold
			name.TextSize = 14
			name.TextColor3 = Theme.Cocoa
			name.TextWrapped = true
			name.Text = def.title
			name.Parent = b
			if on and not seen(def.id) then
				local badge = UI.pill(b, "NEW")
				badge.Position = UDim2.new(1, -8, 0, 6)
				badge.AnchorPoint = Vector2.new(1, 0)
			end
			b.Activated:Connect(function()
				if on then
					openApp(def.id)
				else
					say(def.unlockHint)
				end
			end)
		end
		UI.label(content, "Tap an app to open it. New apps appear as your business grows.", { size = 13 })
	end

	backBtn.Activated:Connect(function()
		openApp(nil)
	end)
	closeBtn.Activated:Connect(function()
		gui.Enabled = false
	end)

	Remotes.event("Notify").OnClientEvent:Connect(function(msg)
		say(tostring(msg))
	end)

	local function onChange()
		-- announce newly unlocked apps once
		local state = HUD.state
		if state then
			local fresh = {}
			for _, def in AppsConfig.list do
				if def.unlock(state) and not seen(def.id) and not announced[def.id] and def.id ~= "crumbchat" and def.id ~= "pantrydash" and def.id ~= "settings" then
					announced[def.id] = true
					table.insert(fresh, def)
				end
			end
			if #fresh == 1 then
				say(`New app: {fresh[1].title}. {fresh[1].blurb}`)
			elseif #fresh > 1 then
				local names = {}
				for _, def in fresh do
					table.insert(names, def.title)
				end
				say(`New apps: {table.concat(names, ", ")}. Open your phone to explore.`)
			end
		end
		if gui.Enabled then
			render()
		end
	end
	HUD:OnOrders(onChange)
	HUD:OnState(onChange)

	-- keep delivery countdowns fresh while PantryDash is open
	task.spawn(function()
		while true do
			task.wait(1)
			if gui.Enabled and current == "pantrydash" and HUD.state and #HUD.state.deliveries > 0 then
				render()
			end
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
	UIBus.Open.Event:Connect(function(panel)
		if panel == "PhonePantry" then
			gui.Enabled = true
			openApp("pantrydash")
		elseif panel == "PhoneGear" then
			gui.Enabled = true
			if unlocked("gearup") then
				openApp("gearup")
			else
				openApp(nil)
				say(AppsConfig.byId.gearup.unlockHint)
			end
		end
	end)

	ContextActionService:BindAction("OpenGear", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			UIBus.Open:Fire("PhoneGear")
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.B)

	ContextActionService:BindAction("TogglePhone", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.P)
end

return PhoneController
