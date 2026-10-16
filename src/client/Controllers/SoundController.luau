--!strict
-- Sound effects. Uses Roblox's built-in sounds so nothing needs uploading; if a sound cannot load it is skipped, and
-- the volume comes from the player's saved setting (0 = silent).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local HUD = require(script.Parent.HUDController)

local SOUNDS = {
	notify = "rbxasset://sounds/electronicpingshort.wav",
	cash = "rbxasset://sounds/switch.wav",
}

local SoundController = {}

local function volume(): number
	local s = HUD.state
	return if s and s.settings and type(s.settings.sfx) == "number" then s.settings.sfx else 0.6
end

local function play(name: string)
	local v = volume()
	if v <= 0 or not SOUNDS[name] then
		return
	end
	pcall(function()
		local snd = Instance.new("Sound")
		snd.SoundId = SOUNDS[name]
		snd.Volume = v
		snd.Parent = SoundService
		snd.Ended:Once(function()
			snd:Destroy()
		end)
		snd:Play()
		task.delay(5, function()
			snd:Destroy()
		end)
	end)
end

function SoundController:Init() end

function SoundController:Start()
	Remotes.event("Notify").OnClientEvent:Connect(function()
		play("notify")
	end)
	local lastCash: number? = nil
	HUD:OnState(function()
		local s = HUD.state
		if s then
			if lastCash and s.cash > lastCash then
				play("cash")
			end
			lastCash = s.cash
		end
	end)
end

return SoundController
