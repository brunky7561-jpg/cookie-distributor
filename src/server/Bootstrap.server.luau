--!strict
-- Loads every ModuleScript in Services and calls :Init() then :Start() on each.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
Remotes.declareAll()

local services = script.Parent:WaitForChild("Services")

local loaded = {}
for _, module in services:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, svc = pcall(require, module)
		if ok then
			table.insert(loaded, { name = module.Name, svc = svc })
		else
			warn(`[Server] failed to load {module.Name}: {svc}`)
		end
	end
end

for _, entry in loaded do
	if type(entry.svc) == "table" and entry.svc.Init then
		local ok, err = pcall(entry.svc.Init, entry.svc)
		if not ok then
			warn(`[Server] {entry.name}:Init failed: {err}`) -- one broken service must not stop the others
		end
	end
end
for _, entry in loaded do
	if type(entry.svc) == "table" and entry.svc.Start then
		task.spawn(function()
			local ok, err = pcall(entry.svc.Start, entry.svc)
			if not ok then
				warn(`[Server] {entry.name}:Start failed: {err}`)
			end
		end)
	end
end

print(`[Server] started {#loaded} services`)
