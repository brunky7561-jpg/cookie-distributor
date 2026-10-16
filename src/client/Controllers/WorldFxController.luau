--!strict
-- Client-side visuals that follow your save: the buildings you own appear on their plots (only you see yours), shop signs
-- show your bakery name, and a short welcome card explains where the new features are.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Properties = require(ReplicatedStorage.Shared.Config.Properties)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local UI = require(script.Parent.Parent.Modules.UI)
local HUD = require(script.Parent.HUDController)
local UIBus = require(script.Parent.UIBus)

local WorldFxController = {}

local folder: Folder? = nil
local built: { [string]: Model } = {}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function part(model: Model, name: string, base: CFrame, offset: Vector3, size: Vector3, color: Color3, material: Enum.Material, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = base * CFrame.new(offset)
	p.Color = color
	p.Material = material
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function signFace(parent: Part, face: Enum.NormalId, text: string, textColor: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Name = "SignText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = gui
end

local function glow(p: Part, color: Color3)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 20
	l.Brightness = 1.4
	l.Parent = p
end

local BUILDERS: { [string]: (model: Model, base: CFrame, name: string) -> () } = {
	food_truck = function(m, base, name)
		part(m, "Body", base, Vector3.new(0, 5.2, 0), Vector3.new(14, 7, 7), c(255, 196, 60), Enum.Material.SmoothPlastic)
		part(m, "Cab", base, Vector3.new(8.6, 4, 0), Vector3.new(4, 5, 6.6), c(240, 150, 40), Enum.Material.SmoothPlastic)
		part(m, "Window", base, Vector3.new(0, 5.6, 3.55), Vector3.new(7, 3, 0.2), c(40, 60, 80), Enum.Material.Glass, 0.2)
		part(m, "Awning", base, Vector3.new(0, 7.6, 4.8), Vector3.new(8.5, 0.3, 3.2), c(230, 70, 80), Enum.Material.Fabric)
		for _, x in { -4.5, 4.5, 8.6 } do
			for _, z in { -3.4, 3.4 } do
				local w = part(m, "Wheel", base, Vector3.new(x, 1.3, z), Vector3.new(1.1, 2.6, 2.6), c(30, 30, 34), Enum.Material.SmoothPlastic)
				w.Shape = Enum.PartType.Cylinder
				w.CFrame = base * CFrame.new(x, 1.3, z) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
		local sign = part(m, "Sign", base, Vector3.new(0, 9.6, 0), Vector3.new(10, 2.2, 0.5), c(40, 28, 24), Enum.Material.SmoothPlastic)
		signFace(sign, Enum.NormalId.Front, name, c(255, 230, 150))
		glow(sign, c(255, 210, 140))
	end,
	garage = function(m, base, name)
		part(m, "Walls", base, Vector3.new(0, 6, 0), Vector3.new(22, 12, 14), c(170, 176, 190), Enum.Material.Concrete)
		part(m, "Roof", base, Vector3.new(0, 12.4, 0), Vector3.new(23.5, 1, 15.5), c(90, 94, 110), Enum.Material.Metal)
		part(m, "RollDoor", base, Vector3.new(-3, 4.5, 7.1), Vector3.new(10, 8.6, 0.3), c(230, 232, 240), Enum.Material.Metal)
		part(m, "Window", base, Vector3.new(7, 6.5, 7.1), Vector3.new(5, 3.5, 0.3), c(110, 160, 200), Enum.Material.Glass, 0.25)
		local sign = part(m, "Sign", base, Vector3.new(0, 10.3, 7.3), Vector3.new(16, 2.2, 0.4), c(60, 62, 80), Enum.Material.SmoothPlastic)
		signFace(sign, Enum.NormalId.Front, name, c(255, 220, 130))
		glow(sign, c(255, 220, 160))
	end,
	corner_shop = function(m, base, name)
		part(m, "Walls", base, Vector3.new(0, 8, 0), Vector3.new(24, 16, 16), c(255, 214, 224), Enum.Material.SmoothPlastic)
		part(m, "Roof", base, Vector3.new(0, 16.6, 0), Vector3.new(26, 1.4, 18), c(176, 96, 84), Enum.Material.Slate)
		part(m, "Awning", base, Vector3.new(0, 11.5, 9.4), Vector3.new(22, 0.5, 4.4), c(230, 70, 90), Enum.Material.Fabric)
		part(m, "WindowL", base, Vector3.new(-7, 6, 8.1), Vector3.new(7, 7, 0.3), c(255, 244, 214), Enum.Material.Glass, 0.3)
		part(m, "Door", base, Vector3.new(6, 4.5, 8.1), Vector3.new(5, 9, 0.3), c(120, 80, 56), Enum.Material.Wood)
		local cookie = part(m, "RoofCookie", base, Vector3.new(0, 20.5, 0), Vector3.new(6, 6, 1.2), c(214, 160, 90), Enum.Material.SmoothPlastic)
		cookie.Shape = Enum.PartType.Cylinder
		cookie.CFrame = base * CFrame.new(0, 20.5, 0) * CFrame.Angles(0, math.rad(90), 0)
		local sign = part(m, "Sign", base, Vector3.new(0, 13.4, 8.2), Vector3.new(18, 2.6, 0.4), c(60, 36, 32), Enum.Material.SmoothPlastic)
		signFace(sign, Enum.NormalId.Front, name, c(255, 226, 150))
		glow(sign, c(255, 200, 150))
	end,
}

local function signText(id: string): string
	local s = HUD.state
	local brand = if s and s.settings and s.settings.brandName ~= "" then s.settings.brandName else nil
	return brand or Properties[id].name
end

local function refresh()
	local state = HUD.state
	if not state or not folder then
		return
	end
	for id, def in Properties do
		local owned = state.properties[id] == true and def.plotName ~= nil
		local existing = built[id]
		if owned and not existing and BUILDERS[id] then
			for _, inst in CollectionService:GetTagged("PropertyPlot") do
				if inst:IsA("BasePart") and inst.Name == def.plotName then
					local model = Instance.new("Model")
					model.Name = def.name .. " (yours)"
					-- sit on top of the flat plot marker, facing the same way as the marker
					local base = CFrame.new(inst.Position.X, inst.Position.Y + inst.Size.Y / 2, inst.Position.Z)
					BUILDERS[id](model, base, signText(id))
					model.Parent = folder
					built[id] = model
					break
				end
			end
		elseif existing then
			for _, d in existing:GetDescendants() do
				if d:IsA("TextLabel") and d.Name == "SignText" then
					d.Text = signText(id)
				end
			end
		end
	end
end

local function welcome()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Welcome"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(420, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Theme.Buttercream
	frame.Parent = gui
	UI.corner(frame, 22)
	UI.stroke(frame, 4)
	UI.gradient(frame, Theme.Cream, Theme.Peach)
	UI.padding(frame, 16)
	UI.list(frame, 8)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, 9999)
	limit.Parent = frame

	local x = UI.button(frame, "X  Close", Theme.Coral, function()
		gui:Destroy()
	end)
	x.LayoutOrder = -1
	UI.label(frame, "🍪 Cookie Empire", { bold = true, size = 28, align = Enum.TextXAlignment.Center })
	UI.label(frame, "Bake, deliver, grow.", { size = 16, align = Enum.TextXAlignment.Center })
	UI.label(frame, "📱 Your phone (P) holds everything: orders, ingredients, recipes and more apps that unlock as you grow.", { size = 15 })
	UI.label(frame, "🏠 Buy a Food Truck, Garage or Shop and it appears on its lot with your bakery name on the sign.", { size = 15 })
	UI.label(frame, "🚗 Cars, 🧑‍🍳 bakers, 📈 market events and contracts unlock at higher levels.", { size = 15 })
	UI.button(frame, "Let's bake!", Theme.Butter, function()
		gui:Destroy()
	end)
end

function WorldFxController:Init() end

function WorldFxController:Start()
	local f = Instance.new("Folder")
	f.Name = "MyBuildings" -- client-only: other players never see your buildings
	f.Parent = workspace
	folder = f
	HUD:OnState(refresh)
	refresh()
	-- the welcome card waits for the title screen / cutscene to finish
	if UIBus.introActive then
		UIBus.IntroDone.Event:Connect(function()
			task.delay(0.5, welcome)
		end)
	else
		task.delay(1.5, welcome)
	end
end

return WorldFxController
