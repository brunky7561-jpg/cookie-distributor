--!strict
-- Receives server-accepted station interactions and opens the matching panel.
-- The ProximityPrompt itself lives on the station and is handled by the server (InteractionService),
-- so the client can never open a station UI the server did not approve.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local UIBus = require(script.Parent.UIBus)

local InteractionController = {}

function InteractionController:Init() end

function InteractionController:Start()
	Remotes.event("InteractionAccepted").OnClientEvent:Connect(function(panel: any)
		if type(panel) == "string" then
			UIBus.Open:Fire(panel)
		end
	end)
end

return InteractionController
