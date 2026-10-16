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
	return f:WaitForChild(name)
end

function Remotes.event(name: string): RemoteEvent
	return get(name, "RemoteEvent") :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return get(name, "RemoteFunction") :: RemoteFunction
end

return Remotes
