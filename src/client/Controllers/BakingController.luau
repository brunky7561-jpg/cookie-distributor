--!strict
-- Baking station UI: pick a recipe (and which order it is for), then Mix, Portion, Bake, Cool and Package.
-- Opens when the server accepts an interaction with a BakeStation (see InteractionService). The server owns
-- every timer and score; this file only draws the screens and sends the player's button presses.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Baking = require(ReplicatedStorage.Shared.Config.Baking)
local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local HUD = require(script.Parent.HUDController)
local UIBus = require(script.Parent.UIBus)

local BakingController = {}

local RECIPE_ID = "classic_chip"
local STIR_TAPS = 8

function BakingController:Init() end

function BakingController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Bake"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(400, 480)
	frame.Position = UDim2.new(0.5, -200, 0.5, -240)
	frame.BackgroundColor3 = Theme.Buttercream
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Instance.new("UICorner").Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Cocoa
	stroke.Thickness = 2
	stroke.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local bakeStatus = Remotes.func("BakeStatus")
	local bakeStart = Remotes.func("BakeStart")
	local bakeStep = Remotes.func("BakeStep")

	local generation = 0 -- bumped on every screen change so stale timers stop themselves
	local selectedOrder: number? = nil
	local showStage: (info: any) -> ()
	local showRecipe: (message: string?) -> ()

	local function clear()
		generation += 1
		for _, c in frame:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
	end

	local function label(text: string, height: number, bold: boolean?, color: Color3?): TextLabel
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 0, height)
		l.BackgroundTransparency = 1
		l.TextColor3 = color or Theme.Cocoa
		l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
		l.TextSize = 15
		l.TextWrapped = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextYAlignment = Enum.TextYAlignment.Top
		l.Text = text
		l.Parent = frame
		return l
	end

	local function button(text: string, color: Color3?): TextButton
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, 0, 0, 42)
		b.BackgroundColor3 = color or Theme.Coral
		b.TextColor3 = Theme.Cocoa
		b.Font = Enum.Font.GothamBold
		b.TextSize = 17
		b.Text = text
		b.Parent = frame
		Instance.new("UICorner").Parent = b
		return b
	end

	local function title(text: string)
		label(text, 28, true).TextSize = 20
	end

	local function step(action: string, arg: any?): (boolean, any)
		local ok, res = bakeStep:InvokeServer(action, arg)
		return ok, res
	end

	-- A bar that fills over IDEAL * BAR_FACTOR seconds with a green zone around the ideal moment.
	local function timingBar(ideal: number, startedAgo: number, buttonText: string, onStop: () -> ())
		local mine = generation
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, 0, 0, 30)
		bar.BackgroundColor3 = Color3.fromRGB(230, 214, 184)
		bar.BorderSizePixel = 0
		bar.Parent = frame
		Instance.new("UICorner").Parent = bar
		local width = 2 * Baking.ZONE_HALF / Baking.BAR_FACTOR
		local zone = Instance.new("Frame")
		zone.Size = UDim2.fromScale(width, 1)
		zone.Position = UDim2.fromScale(0.5 - width / 2, 0)
		zone.BackgroundColor3 = Theme.Mint
		zone.BorderSizePixel = 0
		zone.Parent = bar
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Theme.Butter
		fill.BackgroundTransparency = 0.35
		fill.BorderSizePixel = 0
		fill.Parent = bar

		local t0 = os.clock() - startedAgo
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			if generation ~= mine then
				conn:Disconnect()
				return
			end
			fill.Size = UDim2.fromScale(math.clamp((os.clock() - t0) / (ideal * Baking.BAR_FACTOR), 0, 1), 1)
		end)
		local stop = button(buttonText, Theme.Coral)
		stop.Activated:Once(function()
			if generation == mine then
				conn:Disconnect()
				onStop()
			end
		end)
	end

	local function showResult(res: any)
		clear()
		local batch = res.batch
		title(`{batch.grade}! ({batch.score}/100)`)
		label(batch.name, 22, true)
		label(tostring(batch.feedback), 48)
		label(`Appeal {batch.appeal}   |   {batch.count} cookies boxed`, 22)
		if res.orderId then
			if res.linkedOrder then
				label("Order status: Ready. Open your phone (P) to deliver it.", 44, true, Theme.Cocoa)
			else
				label("The order is gone, so these cookies went to your stock.", 44)
			end
		else
			label("Boxed into your stock. Assign it to an order from your phone.", 44)
		end
		local again = button("Bake another batch", Theme.Butter)
		again.Activated:Once(function()
			selectedOrder = nil
			showRecipe()
		end)
		local done = button("Close", Theme.Coral)
		done.Activated:Once(function()
			gui.Enabled = false
		end)
	end

	function showStage(info: any)
		clear()
		local stage = info.stage
		local forOrder = if info.orderId then "  (for an order)" else ""

		if stage == "mix" then
			title(`Step 1 of 5: Mix{forOrder}`)
			label("Tap Stir to mix the dough until the bar is full.", 40)
			local bar = Instance.new("Frame")
			bar.Size = UDim2.new(1, 0, 0, 24)
			bar.BackgroundColor3 = Color3.fromRGB(230, 214, 184)
			bar.BorderSizePixel = 0
			bar.Parent = frame
			Instance.new("UICorner").Parent = bar
			local fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(0, 1)
			fill.BackgroundColor3 = Theme.Mint
			fill.BorderSizePixel = 0
			fill.Parent = bar
			local message = label("", 40)
			local stir = button("Stir!", Theme.Coral)
			local taps = 0
			local mine = generation
			stir.Activated:Connect(function()
				if generation ~= mine or taps >= STIR_TAPS then
					return
				end
				taps += 1
				fill.Size = UDim2.fromScale(taps / STIR_TAPS, 1)
				if taps < STIR_TAPS then
					return
				end
				message.Text = "Almost there..."
				task.spawn(function()
					for _ = 1, 20 do
						local ok, res = step("mixDone")
						if generation ~= mine then
							return
						end
						if ok then
							showStage(res)
							return
						end
						if res ~= "keep stirring a little longer" then
							message.Text = tostring(res)
							return
						end
						task.wait(0.5)
					end
				end)
			end)
		elseif stage == "portion" then
			title(`Step 2 of 5: Portion{forOrder}`)
			label("Scoop the dough. Stop the bar in the green zone for even cookies.", 40)
			if info.running then
				timingBar(Baking.PORTION_IDEAL, info.elapsed or 0, "Scoop!", function()
					local ok, res = step("portionStop")
					if ok then
						showStage(res)
					else
						label(tostring(res), 30)
					end
				end)
			else
				button("Start portioning", Theme.Coral).Activated:Once(function()
					local ok, res = step("portionStart")
					if ok then
						showStage(res)
					end
				end)
			end
		elseif stage == "bake" then
			title(`Step 3 of 5: Bake{forOrder}`)
			label("Pull the tray when the bar reaches the green zone. Too early is doughy, too late is dark.", 52)
			if info.running then
				timingBar(Baking.BAKE_IDEAL, info.elapsed or 0, "Pull the tray!", function()
					local ok, res = step("ovenPull")
					if ok then
						showStage(res)
					else
						label(tostring(res), 30)
					end
				end)
			else
				button("Load tray into the oven", Theme.Coral).Activated:Once(function()
					local ok, res = step("ovenStart")
					if ok then
						showStage(res)
					end
				end)
			end
		elseif stage == "cool" then
			title(`Step 4 of 5: Cool{forOrder}`)
			label("Let the tray rest on the rack so the cookies set.", 40)
			local countdown = label("", 28, true)
			local mine = generation
			local remaining = info.coolRemaining or 0
			local endsAt = os.clock() + remaining
			task.spawn(function()
				while generation == mine and os.clock() < endsAt do
					countdown.Text = `Cooling... {math.ceil(endsAt - os.clock())}s`
					task.wait(0.2)
				end
				if generation ~= mine then
					return
				end
				-- allow a little network slack before the server agrees the tray has cooled
				for _ = 1, 10 do
					local ok, res = step("coolDone")
					if generation ~= mine then
						return
					end
					if ok then
						showStage(res)
						return
					end
					task.wait(0.3)
				end
				countdown.Text = "The tray is still cooling. Close and reopen the station."
			end)
		elseif stage == "package" then
			title(`Step 5 of 5: Package{forOrder}`)
			local recipe = Recipes.catalog[info.recipeId]
			label(`This tray has {recipe.yield} cookies. Pick the box that fits.`, 40)
			local message = label("", 40, false, Theme.Coral)
			local mine = generation
			for _, box in Recipes.boxes do
				local b = button(`{box.name} ({box.size} cookies)`, Theme.Butter)
				b.Activated:Connect(function()
					if generation ~= mine then
						return
					end
					local ok, res = step("pack", box.id)
					if ok then
						showResult(res)
					else
						message.Text = tostring(res)
					end
				end)
			end
		end
	end

	function showRecipe(message: string?)
		clear()
		title("Kitchen")
		if message then
			label(message, 44, true, Theme.Coral)
		end
		local recipe = Recipes.catalog[RECIPE_ID]
		label(`{recipe.name}  (makes {recipe.yield} cookies)`, 22, true)

		local state = HUD.state
		local cost = 0
		local missingAny = false
		local order = {}
		for id in recipe.requires do
			table.insert(order, id)
		end
		table.sort(order)
		for _, id in order do
			local need = recipe.requires[id]
			local have = if state then state.ingredients[id] or 0 else 0
			local ing = Ingredients[id]
			cost += ing.cost * need
			local ok = have >= need
			if not ok then
				missingAny = true
			end
			label(`{ing.name}: need {need}, have {have}`, 20, false, if ok then Theme.Cocoa else Theme.Coral)
		end
		label(`Ingredient cost: about ${cost}`, 22)

		local accepted = {}
		for _, o in HUD.orders do
			if o.state == "Accepted" and o.recipeId == RECIPE_ID then
				table.insert(accepted, o)
			end
		end
		if selectedOrder then
			local still = false
			for _, o in accepted do
				if o.id == selectedOrder then
					still = true
				end
			end
			if not still then
				selectedOrder = nil
			end
		end
		if selectedOrder == nil and #accepted > 0 then
			selectedOrder = accepted[1].id
		end

		if #accepted > 0 then
			label("Bake for which order?", 20, true)
			for _, o in accepted do
				local chosen = selectedOrder == o.id
				local b = button(`{if chosen then "> " else ""}{o.customerName}: {o.count} cookies`, if chosen then Theme.Mint else Theme.Butter)
				b.Activated:Once(function()
					selectedOrder = o.id
					showRecipe()
				end)
			end
		else
			label("No accepted orders. Accept one on your phone (P), or bake for stock.", 40)
		end

		if missingAny then
			label("You are short on ingredients. Open the Shop (B) to buy more.", 40, true, Theme.Coral)
		end
		local go = button("Start baking", Theme.Coral)
		go.Activated:Once(function()
			local ok, res = bakeStart:InvokeServer(RECIPE_ID, selectedOrder)
			if ok then
				showStage(res)
			else
				showRecipe(tostring(res))
			end
		end)
		button("Close", Theme.Butter).Activated:Once(function()
			gui.Enabled = false
		end)
	end

	UIBus.Open.Event:Connect(function(panel)
		if panel ~= "Bake" then
			return
		end
		gui.Enabled = true
		local info = bakeStatus:InvokeServer()
		if info then
			showStage(info) -- resume a bake that was left half-finished
		else
			showRecipe()
		end
	end)
end

return BakingController
