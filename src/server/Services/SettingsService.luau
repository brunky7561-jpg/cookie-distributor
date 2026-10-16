--!strict
-- Player settings (text size, sound volume, effects) and the bakery brand. Everything is validated against Config/Brand.
-- The bakery name is player-written text, so it goes through Roblox text filtering before it is saved or shown.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Brand = require(ReplicatedStorage.Shared.Config.Brand)
local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local SettingsService = {}

local function filtered(player: Player, text: string): string?
	local ok, result = pcall(function()
		local obj = TextService:FilterStringAsync(text, player.UserId)
		return obj:GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(result) == "string" then
		return result
	end
	return nil
end

function SettingsService:Init()
	Remotes.func("SettingSet").OnServerInvoke = function(player: Player, key: any, value: any): (boolean, string)
		if not RateLimit.check(player, "SettingSet", 0.2) then
			return false, "slow down a little"
		end
		local data = PlayerDataService:Get(player)
		if not data then
			return false, "loading"
		end
		local s = data.settings
		if key == "textScale" then
			if not table.find(Brand.TEXT_SCALES, value) then
				return false, "unknown text size"
			end
			s.textScale = value
		elseif key == "sfx" then
			if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then
				return false, "volume must be between 0 and 1"
			end
			s.sfx = math.floor(value * 10 + 0.5) / 10
		elseif key == "effects" or key == "guidance" then
			if type(value) ~= "boolean" then
				return false, "bad value"
			end
			s[key] = value
		else
			return false, "unknown setting"
		end
		PlayerDataService:Replicate(player)
		return true, "Saved."
	end

	Remotes.func("BrandSet").OnServerInvoke = function(player: Player, name: any, colorIndex: any): (boolean, string)
		if not RateLimit.check(player, "BrandSet", 2) then
			return false, "slow down a little"
		end
		local data = PlayerDataService:Get(player)
		if not data then
			return false, "loading"
		end
		if type(colorIndex) ~= "number" or colorIndex % 1 ~= 0 or colorIndex < 1 or colorIndex > #Brand.COLORS then
			return false, "pick one of the colors"
		end
		local clean, reason = Brand.cleanName(name)
		if not clean then
			return false, reason or "bad name"
		end
		local safe = filtered(player, clean)
		if not safe then
			return false, "Could not check that name right now. Try again in a moment."
		end
		if safe ~= clean then
			return false, "That name was not allowed. Try another."
		end
		data.settings.brandName = clean
		data.settings.brandColor = colorIndex
		PlayerDataService:Replicate(player)
		return true, `Welcome, {clean}!`
	end
end

function SettingsService:Start() end

return SettingsService
