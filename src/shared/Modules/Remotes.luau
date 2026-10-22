--!strict
-- Server creates remotes on first request; client waits for them. Same call on both sides.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local function folder(): Folder
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	if f then
		return f :: Folder
	end
	if RunService:IsServer() then
		local new = Instance.new("Folder")
		new.Name = "Remotes"
		new.Parent = ReplicatedStorage
		return new
	end
	return ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local function get(name: string, className: string): Instance
	local f = folder()
	local existing = f:FindFirstChild(name)
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local r = Instance.new(className)
		r.Name = name
		r.Parent = f
		return r
	end
	local found = f:WaitForChild(name, 10)
	if found then
		return found
	end
	warn(`[Remotes] the server never created "{name}"; things that need it will not work`)
	return f:WaitForChild(name)
end

-- Every remote the client uses. The server creates them all up front, so a client script can never end up
-- waiting forever for one that no service happened to create yet.
Remotes.CLIENT_EVENTS = { "InteractionAccepted", "Notify", "OrdersUpdated", "StateUpdated" }
Remotes.CLIENT_FUNCS = {
	"BakeStart", "BakeStatus", "BakeStep", "BrandSet", "BuyEquipment", "ContractDeliver", "DevBoost", "DevReset", "DisplaySet",
	"GetOrders", "GetState", "GoToKitchen", "IntroChoice", "MarketStatus", "OrderAction", "PantryOrder", "PropertyBuy", "SeenApp", "SettingSet",
	"StaffAssign", "StaffFire", "StaffHire", "VehicleBuy", "VehicleRemove", "VehicleSpawn",
}

function Remotes.declareAll()
	for _, name in Remotes.CLIENT_EVENTS do
		get(name, "RemoteEvent")
	end
	for _, name in Remotes.CLIENT_FUNCS do
		get(name, "RemoteFunction")
	end
end

function Remotes.event(name: string): RemoteEvent
	return get(name, "RemoteEvent") :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return get(name, "RemoteFunction") :: RemoteFunction
end

return Remotes
