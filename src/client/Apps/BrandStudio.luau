--!strict
-- Brand Studio: name your bakery and pick its color. The name is filtered by the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Config.Brand)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local UI = require(script.Parent.Parent.Modules.UI)

local Theme = UI.Theme
local draftName = ""
local draftColor: number? = nil

local BrandStudio = {}
BrandStudio.id = "brandstudio"

function BrandStudio.render(ctx: any)
	local s = ctx.state.settings
	if draftName == "" then
		draftName = s.brandName
	end
	local color = draftColor or s.brandColor

	local preview = UI.card(ctx.content, Color3.fromRGB(Brand.COLORS[color].rgb[1], Brand.COLORS[color].rgb[2], Brand.COLORS[color].rgb[3]))
	UI.label(preview, if draftName ~= "" then draftName else "Your Bakery", { bold = true, size = 22, align = Enum.TextXAlignment.Center })

	UI.label(ctx.content, "Bakery name", { bold = true, size = 18 })
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, UI.MIN_TOUCH)
	box.BackgroundColor3 = Theme.Buttercream
	box.TextColor3 = Theme.Cocoa
	box.Font = Enum.Font.Gotham
	box.TextSize = math.floor(16 * UI.textScale + 0.5)
	box.PlaceholderText = `{Brand.NAME_MIN}-{Brand.NAME_MAX} letters, numbers, spaces`
	box.ClearTextOnFocus = false
	box.Text = draftName
	box.Parent = ctx.content
	UI.corner(box)
	UI.stroke(box, 1.5)
	box.FocusLost:Connect(function()
		draftName = box.Text
		ctx.rerender()
	end)

	UI.label(ctx.content, "Color", { bold = true, size = 18 })
	for i, c in Brand.COLORS do
		UI.button(ctx.content, c.name .. (if i == color then "  (selected)" else ""), Color3.fromRGB(c.rgb[1], c.rgb[2], c.rgb[3]), function()
			draftColor = i
			ctx.rerender()
		end)
	end
	UI.button(ctx.content, "Save brand", Theme.Butter, function()
		local ok, msg = Remotes.func("BrandSet"):InvokeServer(draftName, color)
		ctx.say(tostring(msg))
		if ok then
			draftColor = nil
		end
		ctx.rerender()
		return ok
	end)
end

return BrandStudio
