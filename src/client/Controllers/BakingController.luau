--!strict
-- Baking station UI: pick a recipe (or experiment), pick which order it is for, then Mix, Portion, Bake, Cool and Package.
-- Opens when the server accepts an interaction with a BakeStation (see InteractionService). The server owns every
-- timer and score; this file only draws the screens and sends the player's button presses.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Baking = require(ReplicatedStorage.Shared.Config.Baking)
local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local AppealCalc = require(ReplicatedStorage.Shared.Modules.AppealCalc)
local Quality = require(ReplicatedStorage.Shared.Modules.Quality)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local UI = require(script.Parent.Parent.Modules.UI)
local HUD = require(script.Parent.HUDController)
local UIBus = require(script.Parent.UIBus)

local Theme = UI.Theme

local BakingController = {}

function BakingController:Init() end

function BakingController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Bake"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.92, 0.88)
	frame.BackgroundColor3 = Theme.Buttercream
	frame.BorderSizePixel = 0
	frame.Parent = gui
	UI.corner(frame, 18)
	UI.stroke(frame, 3)
	local limits = Instance.new("UISizeConstraint")
	limits.MinSize = Vector2.new(300, 360)
	limits.MaxSize = Vector2.new(430, 640)
	limits.Parent = frame

	-- always-visible exit; a bake in progress is kept by the server and resumes when the kitchen is opened again
	local exit = Instance.new("TextButton")
	exit.Name = "Exit"
	exit.AnchorPoint = Vector2.new(1, 0)
	exit.Position = UDim2.new(1, -8, 0, 8)
	exit.Size = UDim2.fromOffset(40, 40)
	exit.BackgroundColor3 = Theme.Coral
	exit.TextColor3 = Theme.Cream
	exit.Font = Enum.Font.FredokaOne
	exit.TextSize = 22
	exit.Text = "X"
	exit.ZIndex = 20
	exit.Parent = frame
	UI.corner(exit, 20)
	exit.Activated:Connect(function()
		gui.Enabled = false
	end)

	local content = Instance.new("ScrollingFrame")
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.ScrollBarThickness = 6
	content.Parent = frame
	UI.padding(content, 10)
	UI.list(content, 6)

	local bakeStatus = Remotes.func("BakeStatus")
	local bakeStart = Remotes.func("BakeStart")
	local bakeStep = Remotes.func("BakeStep")

	local generation = 0 -- bumped on every screen change so stale timers stop themselves
	local selectedRecipe = "classic_chip" -- catalog id or "experiment"
	local selectedOrder: number? = nil
	local batchMult = 1
	local slots: { [string]: string? } = { flavor = "white_sugar" }
	local showStage: (info: any) -> ()
	local showKitchen: (message: string?) -> ()

	local function clear()
		generation += 1
		UI.clear(content)
	end

	local function title(text: string)
		UI.label(content, text, { bold = true, size = 20 })
	end

	local function step(action: string, arg: any?): (boolean, any)
		local ok, res = bakeStep:InvokeServer(action, arg)
		return ok, res
	end

	-- A bar that fills over IDEAL * BAR_FACTOR seconds with a green zone around the ideal moment.
	local function timingBar(ideal: number, startedAgo: number, buttonText: string, onStop: () -> (), slack: number?)
		local mine = generation
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, 0, 0, 30)
		bar.BackgroundColor3 = Color3.fromRGB(230, 214, 184)
		bar.BorderSizePixel = 0
		bar.Parent = content
		UI.corner(bar)
		local width = 2 * (Baking.ZONE_HALF * ideal + (slack or 0)) / (ideal * Baking.BAR_FACTOR)
		local zone = Instance.new("Frame")
		zone.Size = UDim2.fromScale(width, 1)
		zone.Position = UDim2.fromScale(0.5 - width / 2, 0)
		zone.BackgroundColor3 = Theme.Mint
		zone.BorderSizePixel = 0
		zone.Parent = bar
		for _, edge in { 0, 1 } do -- the two lines the marker must stop between
			local line = Instance.new("Frame")
			line.Size = UDim2.new(0, 3, 1, 8)
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.Position = UDim2.new(edge, 0, 0.5, 0)
			line.BackgroundColor3 = Theme.Cocoa
			line.BorderSizePixel = 0
			line.Parent = zone
		end
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Theme.Butter
		fill.BackgroundTransparency = 0.35
		fill.BorderSizePixel = 0
		fill.Parent = bar

		local marker = Instance.new("Frame") -- the moving line; stop it between the two dark lines
		marker.Size = UDim2.new(0, 6, 1, 14)
		marker.AnchorPoint = Vector2.new(0.5, 0.5)
		marker.Position = UDim2.new(0, 0, 0.5, 0)
		marker.BackgroundColor3 = Theme.Coral
		marker.BorderSizePixel = 0
		marker.ZIndex = 5
		marker.Parent = bar
		UI.corner(marker, 3)

		local t0 = os.clock() - startedAgo
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			if generation ~= mine then
				conn:Disconnect()
				return
			end
			local progress = math.clamp((os.clock() - t0) / (ideal * Baking.BAR_FACTOR), 0, 1)
			fill.Size = UDim2.fromScale(progress, 1)
			marker.Position = UDim2.new(progress, 0, 0.5, 0)
		end)
		UI.button(content, buttonText, Theme.Coral, function()
			if generation == mine then
				conn:Disconnect()
				onStop()
			end
		end)
	end

	local function percent(x: number): string
		return `{math.floor(x * 100 + 0.5)}%`
	end

	local function showResult(res: any)
		clear()
		local batch = res.batch
		title(`{batch.grade}! ({batch.score}/100)`)
		if res.discovered then
			UI.label(content, "Discovery! This recipe is now in your Recipe Book.", { bold = true, color = Theme.Coral })
		end
		UI.label(content, batch.name, { bold = true, size = 17 })
		-- the grade, explained: each factor and how much it counts
		local f = batch.factors
		local w = Quality.WEIGHTS
		local card = UI.card(content)
		UI.label(card, "How your score was made", { bold = true, size = 14 })
		UI.label(card, `Recipe {percent(f.recipe)}  (counts {percent(w.recipe)})`, { size = 13 })
		UI.label(card, `Dough mixing {percent(f.dough or 1)}  (counts {percent(w.dough)})`, { size = 13 })
		UI.label(card, `Bake timing {percent(f.bake)}  (counts {percent(w.bake)})`, { size = 13 })
		UI.label(card, `Ingredient freshness {percent(f.fresh)}  (counts {percent(w.fresh)})`, { size = 13 })
		UI.label(card, `Portion consistency {percent(f.portion)}  (counts {percent(w.portion)})`, { size = 13 })
		UI.label(content, tostring(batch.feedback), { bold = true })
		UI.label(content, `Appeal {batch.appeal}   |   {batch.count} cookies boxed`, { size = 14 })
		if res.orderId then
			if res.linkedOrder then
				UI.label(content, "Order status: Ready. Open your phone (P) to deliver it.", { bold = true })
			else
				UI.label(content, "The order is gone, so these cookies went to your stock.")
			end
		else
			UI.label(content, "Boxed into your stock. Assign it to an order from your phone.", { size = 14 })
		end
		UI.button(content, "Bake another batch", Theme.Butter, function()
			selectedOrder = nil
			showKitchen()
		end)
		UI.button(content, "Close", Theme.Coral, function()
			gui.Enabled = false
		end)
	end

	function showStage(info: any)
		clear()
		local stage = info.stage
		local forOrder = if info.orderId then "  (for an order)" else ""

		if stage == "mix" then
			title(`Step 1 of 5: Mix{forOrder}`)
			-- Dough minigame: a marker sweeps back and forth; press Stir while it is inside the green zone.
			local rounds = math.clamp((info.mixTaps or 8) - 3, 3, 5)
			UI.label(content, `Stir the dough {rounds} times. Press Stir when the marker is in the green zone. A miss only lowers your dough score.`)
			local bar = Instance.new("Frame")
			bar.Size = UDim2.new(1, 0, 0, 36)
			bar.BackgroundColor3 = Color3.fromRGB(230, 214, 184)
			bar.BorderSizePixel = 0
			bar.Parent = content
			UI.corner(bar)
			local ZONE = 0.2
			local zone = Instance.new("Frame")
			zone.Size = UDim2.fromScale(ZONE, 1)
			zone.BackgroundColor3 = Theme.Mint
			zone.BorderSizePixel = 0
			zone.Parent = bar
			local marker = Instance.new("Frame")
			marker.Size = UDim2.new(0, 8, 1, 14)
			marker.AnchorPoint = Vector2.new(0.5, 0.5)
			marker.Position = UDim2.new(0, 0, 0.5, 0)
			marker.BackgroundColor3 = Theme.Coral
			marker.BorderSizePixel = 0
			marker.ZIndex = 5
			marker.Parent = bar
			UI.corner(marker, 4)
			local status = UI.label(content, "", { bold = true, size = 16 })
			local message = UI.label(content, "")
			local mine = generation
			local round = 1
			local points = 0
			local zoneLeft = 0.4
			local started = os.clock()
			local finished = false
			local function newRound()
				zoneLeft = 0.1 + math.random() * (0.8 - ZONE)
				zone.Position = UDim2.fromScale(zoneLeft, 0)
				started = os.clock()
				status.Text = `Round {round} of {rounds}   |   Dough {math.floor(points / math.max(1, round - 1) * 100 + 0.5)}%`
			end
			newRound()
			status.Text = `Round 1 of {rounds}`
			local conn: RBXScriptConnection
			conn = RunService.RenderStepped:Connect(function()
				if generation ~= mine or finished then
					conn:Disconnect()
					return
				end
				-- triangle wave 0..1..0, a little faster every round
				local speed = 0.7 + 0.15 * (round - 1)
				local phase = ((os.clock() - started) * speed) % 2
				marker.Position = UDim2.new(if phase < 1 then phase else 2 - phase, 0, 0.5, 0)
			end)
			UI.button(content, "Stir!", Theme.Coral, function()
				if generation ~= mine or finished then
					return
				end
				local phase = ((os.clock() - started) * (0.7 + 0.15 * (round - 1))) % 2
				local x = if phase < 1 then phase else 2 - phase
				local gap = math.max(zoneLeft - x, x - (zoneLeft + ZONE), 0)
				local hit = if gap == 0 then 1 elseif gap < ZONE * 0.6 then 0.5 else 0
				points += hit
				message.Text = if hit == 1 then "Perfect stir!" elseif hit == 0.5 then "Close!" else "Missed, keep going."
				if round < rounds then
					round += 1
					newRound()
					return
				end
				finished = true
				local score = points / rounds
				status.Text = `Dough {math.floor(score * 100 + 0.5)}%`
				task.spawn(function()
					for _ = 1, 20 do
						local ok, res = step("mixDone", score)
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
			UI.label(content, "Scoop the dough. Stop the bar in the green zone for even cookies.")
			if info.running then
				timingBar(Baking.PORTION_IDEAL, info.elapsed or 0, "Scoop!", function()
					local ok, res = step("portionStop")
					if ok then
						showStage(res)
					else
						UI.label(content, tostring(res))
					end
				end)
			else
				UI.button(content, "Start portioning", Theme.Coral, function()
					local ok, res = step("portionStart")
					if ok then
						showStage(res)
					end
				end)
			end
		elseif stage == "bake" then
			title(`Step 3 of 5: Bake{forOrder}`)
			UI.label(content, "Pull the tray when the bar reaches the green zone. Too early is doughy, too late is dark.")
			if info.running then
				timingBar(Baking.BAKE_IDEAL, info.elapsed or 0, "Pull the tray!", function()
					local ok, res = step("ovenPull")
					if ok then
						showStage(res)
					else
						UI.label(content, tostring(res))
					end
				end, info.bakeSlack)
			else
				UI.button(content, "Load tray into the oven", Theme.Coral, function()
					local ok, res = step("ovenStart")
					if ok then
						showStage(res)
					end
				end)
			end
		elseif stage == "cool" then
			title(`Step 4 of 5: Cool{forOrder}`)
			UI.label(content, "Let the tray rest on the rack so the cookies set.")
			local countdown = UI.label(content, "", { bold = true, size = 18 })
			local mine = generation
			local endsAt = os.clock() + (info.coolRemaining or 0)
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
			UI.label(content, `This tray has {info.yield} cookies. Pick the box that fits.`)
			local message = UI.label(content, "", { color = Theme.Coral, bold = true })
			local mine = generation
			for _, box in Recipes.boxes do
				UI.button(content, `{box.name} ({box.size} cookies)`, Theme.Butter, function()
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

	-- What the currently selected recipe needs, as { recipeName, requires } or nil with a reason.
	local function currentRecipe(state: any): (string?, { [string]: number }?, string?)
		if selectedRecipe == "experiment" then
			local clean, err = Recipes.validateSlots(slots :: any)
			if not clean then
				return nil, nil, err
			end
			local named = Recipes.matchCatalog(clean)
			local name = if named and state.recipes[named.id] then named.name else "Experimental cookies"
			return name, Recipes.requiresFor(clean), nil
		end
		local r = Recipes.catalog[selectedRecipe]
		if r and state.recipes[r.id] then
			return r.name, r.requires, nil
		end
		return nil, nil, "pick a recipe"
	end

	function showKitchen(message: string?)
		clear()
		local state = HUD.state
		if not state then
			UI.label(content, "Loading...")
			return
		end
		local effects = Equipment.effective(state.equipment)
		title("Kitchen")
		if message then
			UI.label(content, message, { bold = true, color = Theme.Coral })
		end

		-- 1. recipe
		UI.label(content, "1. Pick a recipe", { bold = true })
		local ids = {}
		for id in Recipes.catalog do
			if state.recipes[id] then
				table.insert(ids, id)
			end
		end
		table.sort(ids, function(a: string, b: string)
			local ra, rb = Recipes.catalog[a], Recipes.catalog[b]
			local la: number, lb: number = ra.unlockLevel or 1, rb.unlockLevel or 1
			if la ~= lb then
				return la < lb
			end
			return a < b
		end)
		if selectedRecipe ~= "experiment" and not state.recipes[selectedRecipe] then
			selectedRecipe = "classic_chip"
		end
		for _, id in ids do
			local r = Recipes.catalog[id]
			local cost = 0
			for ing, n in r.requires do
				cost += Ingredients[ing].cost * n
			end
			local appeal = AppealCalc.compute(Recipes.expand(r.requires), 0.9).score
			local chosen = selectedRecipe == id
			UI.button(content, `{if chosen then "> " else ""}{r.name}  (batch of 6: ${cost} to make, sells ~${math.floor(Recipes.SELL_PRICE * (r.priceMult or 1) * 6)}, Appeal ~{appeal})`, if chosen then Theme.Mint else Theme.Buttercream, function()
				selectedRecipe = id
				showKitchen()
			end)
		end
		UI.button(content, `{if selectedRecipe == "experiment" then "> " else ""}Experiment: invent a recipe`, if selectedRecipe == "experiment" then Theme.Mint else Theme.Blueberry, function()
			selectedRecipe = "experiment"
			showKitchen()
		end)

		-- experiment slots
		if selectedRecipe == "experiment" then
			UI.label(content, "Dough (flour and butter) is always included. Add a flavor, and optionally a mix-in and a finish.", { size = 13 })
			for _, slot in Recipes.slotOrder do
				local def = Recipes.slots[slot]
				UI.label(content, `{string.upper(string.sub(slot, 1, 1))}{string.sub(slot, 2)}{if def.required then " (required)" else " (optional)"}`, { bold = true, size = 14 })
				if not def.required then
					UI.button(content, `{if slots[slot] == nil then "> " else ""}None`, if slots[slot] == nil then Theme.Mint else Theme.Buttercream, function()
						slots[slot] = nil
						showKitchen()
					end)
				end
				for _, opt in def.options do
					local locked = opt ~= "white_sugar" and (state.ingredients[opt] or 0) == 0
					local label = `{if slots[slot] == opt then "> " else ""}{Ingredients[opt].name} (have {state.ingredients[opt] or 0})`
					UI.button(content, label, if slots[slot] == opt then Theme.Mint else Theme.Buttercream, function()
						slots[slot] = opt
						showKitchen()
					end)
					_ = locked
				end
			end
		end

		-- summary for the current choice
		local name, requires, why = currentRecipe(state)
		local missingAny = false
		if requires and name then
			local summary = UI.card(content)
			UI.label(summary, name, { bold = true })
			local ids2: { string } = {}
			for id in requires do
				table.insert(ids2, id)
			end
			table.sort(ids2)
			local cost = 0
			for _, id in ids2 do
				local need = requires[id] * batchMult
				local have = state.ingredients[id] or 0
				cost += Ingredients[id].cost * need
				if have < need then
					missingAny = true
				end
				UI.label(summary, `{Ingredients[id].name}: need {need}, have {have}`, { size = 13, color = if have >= need then Theme.Cocoa else Theme.Coral })
			end
			local appeal = AppealCalc.compute(Recipes.expand(requires, batchMult), 0.9).score
			local tagSet: { [string]: boolean } = {}
			for id in requires do
				for _, t in Ingredients[id].tags do
					tagSet[t] = true
				end
			end
			local tags = {}
			for t in tagSet do
				table.insert(tags, t)
			end
			table.sort(tags)
			UI.label(summary, `Cost about ${cost}  |  Appeal about {appeal}  |  Tags: {table.concat(tags, ", ")}`, { size = 13 })
			if selectedRecipe == "experiment" then
				UI.label(summary, "New combinations score lower at first. Bake the same experiment again to perfect it.", { size = 13 })
			end
		elseif why then
			UI.label(content, why, { color = Theme.Coral })
		end

		-- 2. order
		local accepted = {}
		for _, o in HUD.orders do
			if o.state == "Accepted" then
				local fits = o.recipeId == "any" or o.recipeId == selectedRecipe
				if fits then
					table.insert(accepted, o)
				end
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
		UI.label(content, "2. Bake for which order?", { bold = true })
		if #accepted > 0 then
			for _, o in accepted do
				local chosen = selectedOrder == o.id
				UI.button(content, `{if chosen then "> " else ""}{o.customerName}: {o.count} cookies`, if chosen then Theme.Mint else Theme.Buttercream, function()
					selectedOrder = if chosen then nil else o.id
					showKitchen()
				end)
			end
			UI.label(content, "Tap an order again to bake for stock instead.", { size = 12 })
		else
			UI.label(content, "No accepted order fits this recipe. You can bake for stock, or accept an order on your phone (P).", { size = 13 })
		end

		-- 3. batch size
		if effects.maxBatchMult >= 2 then
			UI.label(content, "3. Batch size", { bold = true })
			UI.button(content, `{if batchMult == 1 then "> " else ""}Single batch (6 cookies)`, if batchMult == 1 then Theme.Mint else Theme.Buttercream, function()
				batchMult = 1
				showKitchen()
			end)
			UI.button(content, `{if batchMult == 2 then "> " else ""}Double batch (12 cookies, Large box)`, if batchMult == 2 then Theme.Mint else Theme.Buttercream, function()
				batchMult = 2
				showKitchen()
			end)
		else
			batchMult = 1
		end

		if missingAny then
			UI.label(content, "You are short on ingredients. Order more with PantryDash on your phone.", { bold = true, color = Theme.Coral })
			UI.button(content, "Open PantryDash", Theme.Blueberry, function()
				gui.Enabled = false
				UIBus.Open:Fire("PhonePantry")
			end)
		end
		UI.button(content, "Start baking", Theme.Coral, function()
			local options: any = { batchMult = batchMult }
			local recipeId = selectedRecipe
			if selectedRecipe == "experiment" then
				options.slots = slots
			end
			local ok, res = bakeStart:InvokeServer(recipeId, selectedOrder, options)
			if ok then
				showStage(res)
			else
				showKitchen(tostring(res))
			end
		end)
		UI.button(content, "Close", Theme.Butter, function()
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
			showKitchen()
		end
	end)
end

return BakingController
