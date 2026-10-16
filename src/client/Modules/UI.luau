--!strict
-- Small UI kit shared by the phone and the panels. Everything auto-sizes to its text so nothing gets clipped,
-- every button is at least 44 px tall for touch, and colors come only from Theme.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local UI = {}

UI.Theme = Theme
UI.MIN_TOUCH = 44

function UI.corner(inst: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = inst
end

function UI.stroke(inst: Instance, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = Theme.Cocoa
	s.Thickness = thickness or 2
	s.Parent = inst
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
	l.TextSize = o.size or 15
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
	b.Size = UDim2.new(1, 0, 0, UI.MIN_TOUCH)
	b.AutomaticSize = Enum.AutomaticSize.Y
	b.BackgroundColor3 = color or Theme.Coral
	b.TextColor3 = Theme.Cocoa
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextWrapped = true
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	UI.corner(b)
	UI.stroke(b, 1.5)
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
	UI.corner(f)
	UI.stroke(f, 1.5)
	UI.padding(f, 8)
	UI.list(f, 4)
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
