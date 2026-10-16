--!strict
-- Settings: text size, sound volume and effects. Changes are saved on the server and apply right away.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Config.Brand)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local UI = require(script.Parent.Parent.Modules.UI)

local Theme = UI.Theme

local Settings = {}
Settings.id = "settings"

local function set(ctx: any, key: string, value: any)
	local ok, msg = Remotes.func("SettingSet"):InvokeServer(key, value)
	if not ok then
		ctx.say(tostring(msg))
	end
end

function Settings.render(ctx: any)
	local s = ctx.state.settings
	UI.label(ctx.content, "Text size", { bold = true, size = 18 })
	local row = UI.row(ctx.content)
	for _, scale in Brand.TEXT_SCALES do
		local b = UI.button(row, `{scale * 100}%`, if s.textScale == scale then Theme.Butter else Theme.Buttercream, function()
			set(ctx, "textScale", scale)
		end)
		b.Size = UDim2.new(1 / #Brand.TEXT_SCALES, -4, 0, UI.MIN_TOUCH)
		b.AutomaticSize = Enum.AutomaticSize.None
	end

	UI.label(ctx.content, "Sound volume", { bold = true, size = 18 })
	local vrow = UI.row(ctx.content)
	for _, level in { 0, 0.3, 0.6, 1 } do
		local b = UI.button(vrow, if level == 0 then "Off" else `{level * 100}%`, if math.abs(s.sfx - level) < 0.05 then Theme.Butter else Theme.Buttercream, function()
			set(ctx, "sfx", level)
		end)
		b.Size = UDim2.new(0.25, -4, 0, UI.MIN_TOUCH)
		b.AutomaticSize = Enum.AutomaticSize.None
	end

	UI.label(ctx.content, "Guidance", { bold = true, size = 18 })
	UI.button(ctx.content, if s.guidance then "Goal hints: ON" else "Goal hints: OFF", if s.guidance then Theme.Mint else Theme.Buttercream, function()
		set(ctx, "guidance", not s.guidance)
	end)
	UI.label(ctx.content, "Everything in the game works with touch, mouse or keyboard. Nothing is timed against you while menus are open.", { size = 13 })
end

return Settings
