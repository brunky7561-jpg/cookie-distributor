--!strict
-- Title screen on every load, and the opening cutscene the first time a save joins. Text comes from Config/Intro.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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

	-- a slowly orbiting camera over the plaza, softened with a blur, behind the menus
	local center = Vector3.new(0, 14, 0)
	local angle = 0
	local blur = Instance.new("BlurEffect")
	blur.Size = 0
	blur.Parent = Lighting
	TweenService:Create(blur, TweenInfo.new(1.2), { Size = 18 }):Play()
	local orbit = RunService.RenderStepped:Connect(function(dt: number)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		angle += dt * 0.1
		local radius = 95 + math.sin(angle * 0.7) * 10
		local height = 48 + math.sin(angle * 1.3) * 8
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius), center)
	end)

	local generation = 0
	local function close()
		generation += 1
		orbit:Disconnect()
		local cam = workspace.CurrentCamera
		if cam then
			cam.CameraType = Enum.CameraType.Custom -- hand the camera back to the player's character
		end
		blur:Destroy()
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
		stage.BackgroundTransparency = 0.35 -- the blurred plaza keeps turning behind the dialogue

		for _, top in { true, false } do
			local bar = Instance.new("Frame")
			bar.Size = UDim2.new(1, 0, 0.1, 0)
			bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
			bar.Position = UDim2.fromScale(0, if top then 0 else 1)
			bar.BackgroundColor3 = Color3.new(0, 0, 0)
			bar.BorderSizePixel = 0
			bar.Parent = stage
		end

		local portrait = UI.badge(stage, Intro.antagonist.portrait, 150, Theme.Coral)
		portrait.AnchorPoint = Vector2.new(0.5, 0.5)
		portrait.Position = UDim2.fromScale(0.5, 0.3)

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
	local screen = fullFrame(gui, Theme.Night)
	screen.BackgroundTransparency = 0.45 -- the blurred, orbiting plaza shows through
	local col = column(screen, 460)
	local logo = UI.badge(col, "🍪", 120, Theme.Butter)
	logo.LayoutOrder = 1
	logo.Rotation = -8
	-- a gentle bob so the title feels alive
	TweenService:Create(logo, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 8 }):Play()
	local title = UI.label(col, Intro.title.name, { size = 64, align = Enum.TextXAlignment.Center, color = Theme.Cream, font = Enum.Font.FredokaOne, shadow = true })
	title.LayoutOrder = 2
	local tagline = UI.label(col, Intro.title.tagline, { size = 22, align = Enum.TextXAlignment.Center, color = Theme.Butter, font = Enum.Font.GothamBold, shadow = true })
	tagline.LayoutOrder = 3
	local play: TextButton
	local starting = false
	play = UI.button(col, Intro.title.playText, Theme.Butter, function()
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
			local ok, err = (pcall :: any)(cutscene)
			if not ok then
				warn(`[Intro] the cutscene failed: {err}`)
				close() -- never leave the player stuck on the title screen
			end
		else
			close()
		end
	end)
	play.LayoutOrder = 4
	local hint = UI.label(col, Intro.title.hint, { size = 14, align = Enum.TextXAlignment.Center, color = Theme.Cream, font = Enum.Font.GothamBold, shadow = true })
	hint.LayoutOrder = 5
end

return IntroController
