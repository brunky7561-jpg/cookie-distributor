--!strict
-- Operational counters, printed as one log line every five minutes so a live server's health can be read from the
-- developer console. Nothing leaves the server: there is no external analytics.
local Players = game:GetService("Players")

local RateLimit = require(game:GetService("ReplicatedStorage").Shared.Modules.RateLimit)
local PlayerDataService = require(script.Parent.PlayerDataService)
local IntegrityService = require(script.Parent.IntegrityService)

local MetricsService = {}

function MetricsService:Snapshot(): { [string]: any }
	local rejected = 0
	local worst, worstKey = 0, ""
	for key, n in RateLimit.rejected do
		rejected += n
		if n > worst then
			worst, worstKey = n, key
		end
	end
	local unsaved = 0
	for _, p in Players:GetPlayers() do
		if PlayerDataService:Get(p) and not PlayerDataService:IsPersistent(p) then
			unsaved += 1
		end
	end
	return {
		players = #Players:GetPlayers(),
		unsavedPlayers = unsaved,
		loadErrors = PlayerDataService.errors.load,
		saveErrors = PlayerDataService.errors.save,
		malformedSaves = PlayerDataService.errors.malformed,
		integrityRepairs = IntegrityService.repairs,
		rateLimited = rejected,
		noisiestRemote = worstKey,
	}
end

function MetricsService:Init() end

function MetricsService:Start()
	task.spawn(function()
		while true do
			task.wait(300)
			local s = MetricsService:Snapshot()
			print(`[Metrics] players={s.players} unsaved={s.unsavedPlayers} loadErr={s.loadErrors} saveErr={s.saveErrors} malformed={s.malformedSaves} repairs={s.integrityRepairs} rateLimited={s.rateLimited} noisiest={s.noisiestRemote}`)
		end
	end)
end

return MetricsService
