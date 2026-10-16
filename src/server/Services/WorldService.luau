--!strict
-- Sets up lighting and puts floating name labels on tagged parts in the map.
-- Tags (set in tools/map_gen.py): BakeStation, MeetupSpot, PropertyPlot, Landmark.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local STYLES: { [string]: { color: Color3, offset: number, size: number } } = {
	BakeStation = { color = Color3.fromRGB(255, 200, 90), offset = 5, size = 15 },
	MeetupSpot = { color = Color3.fromRGB(120, 220, 255), offset = 6, size = 16 },
	PropertyPlot = { color = Color3.fromRGB(130, 235, 150), offset = 6, size = 16 },
	ReceivingArea = { color = Color3.fromRGB(255, 200, 90), offset = 5, size = 14 },
	Landmark = { color = Color3.fromRGB(255, 236, 200), offset = 8, size = 18 },
}

local WorldService = {}

local function addLabel(part: BasePart, tag: string)
	if part:FindFirstChild("NameTag") then
		return
	end
	local style = STYLES[tag]
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Adornee = part
	gui.AlwaysOnTop = true
	gui.MaxDistance = if tag == "Landmark" then 260 else 130
	gui.Size = UDim2.fromOffset(240, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, style.offset, 0)

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = style.size
	text.TextColor3 = style.color
	text.TextStrokeTransparency = 0.3
	text.Text = part.Name
	text.Parent = gui
	gui.Parent = part
end

local DAY_SECONDS = 14 * 60 -- one full in-game day
local START_CLOCK = 16.5 -- golden hour on arrival

local function isNight(clock: number): boolean
	return clock < 6 or clock > 18.5
end

local function setupLighting()
	Lighting.ClockTime = START_CLOCK
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(110, 105, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 150)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 226, 170)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25

	local sky = Instance.new("Sky")
	sky.StarCount = 3000
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.25
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(199, 215, 235)
	atmosphere.Decay = Color3.fromRGB(240, 220, 190)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.22
	color.Contrast = 0.08
	color.TintColor = Color3.fromRGB(255, 244, 232)
	color.Parent = Lighting

	local depth = Instance.new("DepthOfFieldEffect")
	depth.FarIntensity = 0.12
	depth.FocusDistance = 80
	depth.InFocusRadius = 120
	depth.NearIntensity = 0
	depth.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.3
	bloom.Size = 24
	bloom.Threshold = 1.5
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Parent = Lighting
end

local lampLights: { PointLight } = {}

-- Warm point lights on every street lamp; they switch on at dusk so the city glows at night.
local function lightLamp(part: BasePart)
	if part:FindFirstChild("LampLight") then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "LampLight"
	light.Color = Color3.fromRGB(255, 214, 140)
	light.Range = 26
	light.Brightness = 1.6
	light.Shadows = false
	light.Enabled = isNight(Lighting.ClockTime)
	light.Parent = part
	table.insert(lampLights, light)
end

-- Sparkles on the cookie monument and a mist over the fountain: cheap, built-in textures only.
local function addSparkles(part: BasePart, color: Color3, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.Rate = rate
	e.Lifetime = NumberRange.new(1.5, 3)
	e.Speed = NumberRange.new(1, 4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.LightEmission = 0.6
	e.Parent = part
end

-- A glowing welcome arch just in front of the spawn so the first view has a landmark.
local function buildArch()
	local model = Instance.new("Model")
	model.Name = "Welcome Arch"
	local function block(name: string, pos: Vector3, size: Vector3, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.Position = pos
		p.Color = color
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local center = Vector3.new(-30, 0, -40)
	for _, dx in { -13, 13 } do
		block("Pillar", center + Vector3.new(dx, 9, 0), Vector3.new(3, 18, 3), Color3.fromRGB(120, 78, 60), Enum.Material.Brick)
		block("PillarCap", center + Vector3.new(dx, 18.4, 0), Vector3.new(4.4, 1, 4.4), Color3.fromRGB(240, 200, 120), Enum.Material.SmoothPlastic)
	end
	local beam = block("Sign", center + Vector3.new(0, 16, 0), Vector3.new(30, 5, 1.6), Color3.fromRGB(46, 29, 24), Enum.Material.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = beam
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 214, 120)
		label.Text = "🍪 COOKIE EMPIRE 🍪"
		label.Parent = gui
	end
	local glowLight = Instance.new("PointLight")
	glowLight.Color = Color3.fromRGB(255, 200, 120)
	glowLight.Range = 40
	glowLight.Brightness = 1.5
	glowLight.Parent = beam
	model.Parent = workspace
end

function WorldService:Init()
	setupLighting()
	buildArch()
end

function WorldService:Start()
	for _, inst in workspace:GetDescendants() do
		if inst:IsA("BasePart") then
			if inst.Name == "Lamp" then
				lightLamp(inst)
			elseif inst.Name == "Cookie Monument" then
				addSparkles(inst, Color3.fromRGB(255, 220, 140), 12)
			elseif inst.Name == "FountainColumn" then
				addSparkles(inst, Color3.fromRGB(190, 230, 255), 20)
			end
		end
	end
	-- slow day/night cycle; lamps follow it
	task.spawn(function()
		local wasNight = isNight(Lighting.ClockTime)
		while true do
			task.wait(1)
			Lighting.ClockTime = (Lighting.ClockTime + 24 / DAY_SECONDS) % 24
			local night = isNight(Lighting.ClockTime)
			if night ~= wasNight then
				wasNight = night
				for _, l in lampLights do
					l.Enabled = night
				end
			end
		end
	end)
	for tag in STYLES do
		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsA("BasePart") then
				addLabel(inst, tag)
			end
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
			if inst:IsA("BasePart") then
				addLabel(inst, tag)
			end
		end)
	end
end

return WorldService
