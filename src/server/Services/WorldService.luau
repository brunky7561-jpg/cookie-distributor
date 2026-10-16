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

local function setupLighting()
	Lighting.ClockTime = 15
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(120, 120, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.4

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.25
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(199, 215, 235)
	atmosphere.Decay = Color3.fromRGB(240, 220, 190)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.15
	color.Contrast = 0.05
	color.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.3
	bloom.Size = 24
	bloom.Threshold = 1.5
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Parent = Lighting
end

function WorldService:Init()
	setupLighting()
end

function WorldService:Start()
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
