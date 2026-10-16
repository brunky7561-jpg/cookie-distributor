--!strict
-- Server-owned interaction contract. Every station in Workspace carries a tag (e.g. BakeStation) and this
-- service gives it the attributes StationType, OwnerUserId, Capacity and BusyState plus a ProximityPrompt.
-- A trigger is only forwarded to the client after the server checks the station, distance, owner and state.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local MAX_DISTANCE = 14 -- studs from the nearest edge of the station
local COOLDOWN = 0.4 -- seconds between interactions per player

type StationDef = { action: string, object: string, panel: string, capacity: number }

local STATION_TYPES: { [string]: StationDef } = {
	BakeStation = { action = "Bake", object = "Kitchen", panel = "Bake", capacity = 1 },
}

local lastUse: { [Player]: number } = {}
local accepted = Remotes.event("InteractionAccepted")

local InteractionService = {}

local function distanceToPart(player: Player, part: BasePart): number?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	-- distance to the closest point of the part, so long counters count from their edge
	local localPos = part.CFrame:PointToObjectSpace(root.Position)
	local half = part.Size / 2
	local clamped =
		Vector3.new(math.clamp(localPos.X, -half.X, half.X), math.clamp(localPos.Y, -half.Y, half.Y), math.clamp(localPos.Z, -half.Z, half.Z))
	return (localPos - clamped).Magnitude
end

-- Public: studs from the player's character to the nearest edge of a part (nil if the player has no character).
function InteractionService:DistanceToPart(player: Player, part: BasePart): number?
	return distanceToPart(player, part)
end

-- True if the player is close enough to any station with this tag. Other services use this to guard actions.
function InteractionService:IsNearStation(player: Player, tag: string): boolean
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
			local d = distanceToPart(player, inst)
			if d and d <= MAX_DISTANCE + 4 then
				return true
			end
		end
	end
	return false
end

local function onTriggered(part: BasePart, tag: string, def: StationDef, player: Player)
	local now = os.clock()
	if now - (lastUse[player] or 0) < COOLDOWN then
		return
	end
	lastUse[player] = now

	if not part:IsDescendantOf(workspace) or not CollectionService:HasTag(part, tag) then
		return
	end
	local d = distanceToPart(player, part)
	if not d or d > MAX_DISTANCE then
		return
	end
	local owner = part:GetAttribute("OwnerUserId")
	if owner ~= 0 and owner ~= player.UserId then
		return -- someone else's station
	end
	if part:GetAttribute("BusyState") == "Busy" then
		return
	end
	accepted:FireClient(player, def.panel)
end

local function setup(part: Instance, tag: string)
	local def = STATION_TYPES[tag]
	if not part:IsA("BasePart") or not def or part:FindFirstChild("StationPrompt") then
		return
	end
	part:SetAttribute("StationType", tag)
	part:SetAttribute("OwnerUserId", 0) -- 0 = public starter station; property ownership arrives in a later milestone
	part:SetAttribute("Capacity", def.capacity)
	part:SetAttribute("BusyState", "Idle")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StationPrompt"
	prompt.ActionText = def.action
	prompt.ObjectText = def.object
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		onTriggered(part, tag, def, player)
	end)
end

function InteractionService:Init() end

function InteractionService:Start()
	for tag in STATION_TYPES do
		for _, inst in CollectionService:GetTagged(tag) do
			setup(inst, tag)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
			setup(inst, tag)
		end)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastUse[p] = nil
	end)
end

return InteractionService
