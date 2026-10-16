--!strict
-- Opening cutscene choice. Plays once per save: the choice is stored in milestones so it never repeats.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Intro = require(ReplicatedStorage.Shared.Config.Intro)
local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local OrderService = require(script.Parent.OrderService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local IntroService = {}

local function choiceFor(id: any): any
	for _, c in Intro.choices do
		if c.id == id then
			return c
		end
	end
	return nil
end

-- Returns ok, message. A second call (or a save that already finished the intro) is refused.
function IntroService:Choose(player: Player, id: any): (boolean, string)
	local data = PlayerDataService:Get(player)
	local choice = choiceFor(id)
	if not data or not choice then
		return false, "pick one of the two options"
	end
	if data.milestones.introDone then
		return false, "you already met her"
	end
	data.milestones.introDone = true
	if choice.id == "bake" then
		data.milestones.introBake = true
		OrderService:AcceptFirstAvailable(player)
	else
		local fine = math.min(Intro.punishmentFee, math.max(0, math.floor(data.cash)))
		data.cash -= fine
		data.milestones.introPunished = true
	end
	PlayerDataService:Replicate(player)
	return true, choice.closing
end

function IntroService:Init()
	Remotes.func("IntroChoice").OnServerInvoke = function(player: Player, id: any)
		if not RateLimit.check(player, "IntroChoice", 0.5) then
			return false, "slow down a little"
		end
		return IntroService:Choose(player, id)
	end
end

function IntroService:Start() end

return IntroService
