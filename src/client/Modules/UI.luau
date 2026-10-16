--!strict
-- Small UI kit shared by the phone and the panels. Everything auto-sizes to its text so nothing gets clipped,
-- every button is at least 44 px tall for touch, and colors come only from Theme.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local UI = {}

UI.Theme = Theme
UI.MIN_TOUCH = 44
UI.textScale = 1 -- accessibility: set from the player's saved settings before each render

function UI.corner(inst: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = inst
end

function UI.stroke(inst: Instance, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = Theme.Cocoa
	s.Thickness = thickness or 2
	s.Transparency = 0.15
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
end

-- A soft vertical gradient from `top` to `bottom` (defaults to a lighter and a slightly deeper shade of the fill).
function UI.gradient(inst: GuiObject, top: Color3?, bottom: Color3?)
	local base = inst.BackgroundColor3
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top or base:Lerp(Color3.new(1, 1, 1), 0.35), bottom or base:Lerp(Color3.new(0, 0, 0), 0.08))
	g.Parent = inst
end

-- Small rounded badge, e.g. "NEW".
function UI.pill(parent: Instance, text: string, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.BackgroundColor3 = color or Theme.Cherry
	l.TextColor3 = Theme.Cream
	l.Font = Enum.Font.GothamBlack
	l.TextSize = 11
	l.Text = " " .. text .. " "
	l.Parent = parent
	UI.corner(l, 8)
	return l
end

function UI.padding(inst: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = inst
end

function UI.list(inst: Instance, gap: number?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = inst
	return l
end

-- Destroys everything a screen added (keeps layouts, padding and decoration).
function UI.clear(inst: Instance)
	for _, c in inst:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

export type LabelOpts = { size: number?, bold: boolean?, color: Color3?, align: Enum.TextXAlignment?, order: number? }

function UI.label(parent: Instance, text: string, opts: LabelOpts?): TextLabel
	local o: LabelOpts = opts or {}
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.TextColor3 = o.color or Theme.Cocoa
	l.Font = if o.bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextSize = math.floor((o.size or 15) * UI.textScale + 0.5)
	l.TextWrapped = true
	l.TextXAlignment = o.align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Text = text
	if o.order then
		l.LayoutOrder = o.order
	end
	l.Parent = parent
	return l
end

function UI.button(parent: Instance, text: string, color: Color3?, onClick: (() -> ())?): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, math.floor(UI.MIN_TOUCH * UI.textScale))
	b.AutomaticSize = Enum.AutomaticSize.Y
	b.BackgroundColor3 = color or Theme.Coral
	b.TextColor3 = Theme.Cocoa
	b.Font = Enum.Font.GothamBold
	b.TextSize = math.floor(16 * UI.textScale + 0.5)
	b.TextWrapped = true
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	UI.corner(b, 12)
	UI.stroke(b, 1.5)
	UI.gradient(b)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- A rounded, outlined box that stacks its children vertically and grows with them.
function UI.card(parent: Instance, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundColor3 = color or Theme.Buttercream
	f.BorderSizePixel = 0
	f.Parent = parent
	UI.corner(f, 14)
	UI.stroke(f, 1.5)
	UI.gradient(f, (color or Theme.Buttercream):Lerp(Theme.Cream, 0.6), color or Theme.Buttercream)
	UI.padding(f, 10)
	UI.list(f, 5)
	return f
end

-- A horizontal row (for -/+ steppers and similar).
function UI.row(parent: Instance, height: number?): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, height or UI.MIN_TOUCH)
	f.BackgroundTransparency = 1
	f.Parent = parent
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 6)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = f
	return f
end

function UI.money(n: number): string
	return "$" .. tostring(math.floor(n))
end

return UI
