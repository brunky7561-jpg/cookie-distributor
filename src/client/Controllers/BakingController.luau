--!strict
-- Baking UI: pick ingredients, then stop the mixer and pull the tray at the right moment.
-- Opens when the server accepts an interaction with a station tagged "BakeStation" (see InteractionService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)
local AppealCalc = require(ReplicatedStorage.Shared.Modules.AppealCalc)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local HUD = require(script.Parent.HUDController)
local UIBus = require(script.Parent.UIBus)

local BakingController = {}

local BROWN = Color3.fromRGB(94, 64, 40)
local CREAM = Color3.fromRGB(255, 232, 190)
local MAX_INGREDIENTS = 8

local function label(parent: Instance, text: string, height: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -12, 0, height)
	l.BackgroundTransparency = 1
	l.TextColor3 = CREAM
	l.Font = Enum.Font.GothamBold
	l.TextSize = 16
	l.TextWrapped = true
	l.Text = text
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -12, 0, 36)
	b.BackgroundColor3 = BROWN
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.Gotham
	b.TextSize = 16
	b.Text = text
	b.Parent = parent
	return b
end

function BakingController:Init() end

function BakingController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Bake"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(380, 460)
	frame.Position = UDim2.new(0.5, -190, 0.5, -230)
	frame.BackgroundColor3 = Color3.fromRGB(40, 28, 20)
	frame.Parent = gui
	Instance.new("UICorner").Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local bake = {
		start = Remotes.func("BakeStart"),
		mixStop = Remotes.func("MixStop"),
		ovenStart = Remotes.func("OvenStart"),
		ovenPull = Remotes.func("OvenPull"),
	}

	local busy = false

	local function clear()
		for _, c in frame:GetChildren() do
			if not c:IsA("UIListLayout") and not c:IsA("UICorner") then
				c:Destroy()
			end
		end
	end

	-- A bar that fills over 2 * ideal seconds with a green zone at the halfway mark.
	local function timingBar(ideal: number, text: string, onStop: () -> ())
		clear()
		label(frame, text, 40)
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, -12, 0, 28)
		bar.BackgroundColor3 = Color3.fromRGB(70, 50, 36)
		bar.Parent = frame
		local zone = Instance.new("Frame")
		zone.Size = UDim2.fromScale(0.24, 1)
		zone.Position = UDim2.fromScale(0.38, 0)
		zone.BackgroundColor3 = Color3.fromRGB(90, 190, 90)
		zone.BorderSizePixel = 0
		zone.Parent = bar
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Color3.fromRGB(255, 190, 60)
		fill.BackgroundTransparency = 0.4
		fill.BorderSizePixel = 0
		fill.Parent = bar

		local stop = button(frame, "Stop!")
		local t0 = os.clock()
		local conn = RunService.RenderStepped:Connect(function()
			fill.Size = UDim2.fromScale(math.clamp((os.clock() - t0) / (ideal * 2), 0, 1), 1)
		end)
		stop.Activated:Once(function()
			conn:Disconnect()
			onStop()
		end)
	end

	local showPicker

	local function showResult(batch: any)
		clear()
		label(frame, `{batch.name}`, 30)
		label(frame, `Quality {math.floor(batch.quality * 100)}%   Appeal {batch.appeal}`, 24)
		label(frame, `Effects: {if #batch.effects > 0 then table.concat(batch.effects, ", ") else "none"}`, 24)
		label(frame, `{batch.count} cookies added to your inventory`, 24)
		local again = button(frame, "Bake again")
		again.Activated:Once(function()
			busy = false
			showPicker()
		end)
	end

	local function runBake(picked: { string })
		busy = true
		local ok, info = bake.start:InvokeServer(picked)
		if not ok then
			busy = false
			showPicker(tostring(info))
			return
		end
		timingBar(info.mixIdeal, "Mix! Stop in the green zone.", function()
			bake.mixStop:InvokeServer()
			clear()
			label(frame, "Dough is ready.", 30)
			local go = button(frame, "Put in oven")
			go.Activated:Once(function()
				bake.ovenStart:InvokeServer()
				timingBar(info.ovenIdeal, "Baking... pull the tray in the green zone.", function()
					local pulled, batch = bake.ovenPull:InvokeServer()
					if pulled then
						showResult(batch)
					else
						busy = false
						showPicker("something went wrong with that batch")
					end
				end)
			end)
		end)
	end

	function showPicker(message: string?)
		clear()
		label(frame, message or "Pick ingredients (tap to add, up to 8)", 36)
		local counts: { [string]: number } = {}
		local picked: { string } = {}
		local preview = label(frame, "", 40)
		preview.LayoutOrder = 1000

		local function refresh()
			if #picked == 0 then
				preview.Text = "Nothing selected"
				return
			end
			local r = AppealCalc.compute(picked, 0.85)
			preview.Text = `{#picked}/{MAX_INGREDIENTS} picked   Appeal ~{r.score}`
		end

		local state = HUD.state
		local ids = {}
		for id in Ingredients do
			table.insert(ids, id)
		end
		table.sort(ids)
		for _, id in ids do
			local have = if state then state.ingredients[id] or 0 else 0
			if have > 0 then
				local b = button(frame, "")
				local function text()
					b.Text = `{Ingredients[id].name}   picked {counts[id] or 0} / have {have}`
				end
				text()
				b.Activated:Connect(function()
					if (counts[id] or 0) >= have or #picked >= MAX_INGREDIENTS then
						-- tap past the limit to remove one instead
						if (counts[id] or 0) > 0 then
							counts[id] -= 1
							table.remove(picked, table.find(picked, id) :: number)
						end
					else
						counts[id] = (counts[id] or 0) + 1
						table.insert(picked, id)
					end
					text()
					refresh()
				end)
			end
		end
		refresh()
		local close = button(frame, "Close")
		close.LayoutOrder = 1002
		close.Activated:Once(function()
			gui.Enabled = false
		end)
		local go = button(frame, "Start baking")
		go.LayoutOrder = 1001
		go.Activated:Once(function()
			if #picked > 0 and not busy then
				runBake(picked)
			else
				showPicker("pick at least one ingredient")
			end
		end)
	end

	UIBus.Open.Event:Connect(function(panel)
		if panel == "Bake" then
			gui.Enabled = true
			if not busy then
				showPicker()
			end
		end
	end)
end

return BakingController
