--!strict
-- Title screen on every load, and the opening cutscene the first time a save joins. Text comes from Config/Intro.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Intro = require(ReplicatedStorage.Shared.Config.Intro)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local UI = require(script.Parent.Parent.Modules.UI)
local HUD = require(script.Parent.HUDController)

local IntroController = {}

function IntroController:Init() end

local function fullFrame(parent: Instance, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Active = true -- swallow clicks so nothing underneath is pressed by accident
	f.Parent = parent
	return f
end

local function column(parent: Instance, width: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(width, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundTransparency = 1
	f.Parent = parent
	UI.list(f, 10)
	return f
end

function IntroController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "Intro"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local generation = 0
	local function close()
		generation += 1
		gui:Destroy()
	end

	-- cutscene ----------------------------------------------------------------
	local function cutscene()
		generation += 1
		local mine = generation
		for _, child in gui:GetChildren() do
			child:Destroy()
		end
		local stage = fullFrame(gui, Theme.Night)
		UI.gradient(stage, Theme.Cocoa, Theme.Night)

		for _, top in { true, false } do
			local bar = Instance.new("Frame")
			bar.Size = UDim2.new(1, 0, 0.1, 0)
			bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
			bar.Position = UDim2.fromScale(0, if top then 0 else 1)
			bar.BackgroundColor3 = Color3.new(0, 0, 0)
			bar.BorderSizePixel = 0
			bar.Parent = stage
		end

		local portrait = Instance.new("TextLabel")
		portrait.AnchorPoint = Vector2.new(0.5, 0.5)
		portrait.Position = UDim2.fromScale(0.5, 0.3)
		portrait.Size = UDim2.fromOffset(160, 160)
		portrait.BackgroundTransparency = 1
		portrait.Text = Intro.antagonist.portrait
		portrait.TextSize = 110
		portrait.Parent = stage

		local box = Instance.new("Frame")
		box.AnchorPoint = Vector2.new(0.5, 1)
		box.Position = UDim2.new(0.5, 0, 0.88, 0)
		box.Size = UDim2.new(0.9, 0, 0, 0)
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.BackgroundColor3 = Theme.Buttercream
		box.Parent = stage
		UI.corner(box, 18)
		UI.stroke(box, 3)
		UI.gradient(box, Theme.Cream, Theme.Peach)
		UI.padding(box, 14)
		UI.list(box, 8)
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(620, 9999)
		limit.Parent = box

		local function clearBox()
			for _, child in box:GetChildren() do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
		end

		local function showChoices()
			clearBox()
			UI.label(box, `{Intro.antagonist.name} waits for your answer...`, { bold = true, size = 17 })
			for _, choice in Intro.choices do
				UI.button(box, choice.label, Theme.Butter, function()
					if generation ~= mine then
						return
					end
					local ok, success = pcall(function()
						return Remotes.func("IntroChoice"):InvokeServer(choice.id)
					end)
					if generation ~= mine then
						return
					end
					clearBox()
					UI.label(box, Intro.antagonist.name, { bold = true, size = 18, color = Theme.Cherry })
					UI.label(box, choice.reply, { size = 17 })
					UI.label(box, if ok and success then choice.closing else "Let's get started.", { size = 14 })
					UI.button(box, Intro.startButton, Theme.Coral, close)
				end)
			end
		end

		local function showLine(index: number)
			if generation ~= mine then
				return
			end
			local line = Intro.lines[index]
			if not line then
				showChoices()
				return
			end
			clearBox()
			local isYou = line.speaker == "You"
			UI.label(box, if isYou then "You" else `{line.speaker}, {Intro.antagonist.role}`, { bold = true, size = 15, color = if isYou then Theme.Blueberry else Theme.Cherry })
			local text = UI.label(box, line.text, { size = 18 })
			local full = line.text
			local typing = true
			text.Text = ""
			local nextBtn: TextButton
			nextBtn = UI.button(box, "Next", Theme.Butter, function()
				if typing then
					typing = false -- first press finishes the sentence
					text.Text = full
					nextBtn.Text = "Next"
				else
					showLine(index + 1)
				end
			end)
			UI.button(box, "Skip", Theme.Cream, function()
				showChoices()
			end)
			nextBtn.Text = "Skip typing"
			task.spawn(function()
				for i = 1, #full do
					if not typing or generation ~= mine then
						break
					end
					text.Text = string.sub(full, 1, i)
					task.wait(Intro.typeSpeed)
				end
				if typing and generation == mine then
					typing = false
					text.Text = full
					nextBtn.Text = "Next"
				end
			end)
		end

		showLine(1)
	end

	-- title screen ---------------------------------------------------------------
	local screen = fullFrame(gui, Theme.Peach)
	UI.gradient(screen, Theme.Butter, Theme.Coral)
	local col = column(screen, 440)
	local logo = UI.label(col, "🍪", { size = 90, align = Enum.TextXAlignment.Center })
	logo.TextSize = 90
	UI.label(col, Intro.title.name, { bold = true, size = 46, align = Enum.TextXAlignment.Center, color = Theme.Cocoa })
	UI.label(col, Intro.title.tagline, { size = 20, align = Enum.TextXAlignment.Center, color = Theme.Cocoa })
	local play: TextButton
	local starting = false
	play = UI.button(col, Intro.title.playText, Theme.Cream, function()
		if starting then
			return
		end
		starting = true
		play.Text = "Loading..."
		-- the save may still be loading; the HUD keeps retrying, so wait for it
		local waited = 0
		while not HUD.state and waited < 30 do
			task.wait(0.25)
			waited += 0.25
		end
		local state: any = HUD.state
		if state and not (state.milestones and state.milestones.introDone) then
			cutscene()
		else
			close()
		end
	end)
	UI.label(col, Intro.title.hint, { size = 14, align = Enum.TextXAlignment.Center, color = Theme.Cocoa })
end

return IntroController
