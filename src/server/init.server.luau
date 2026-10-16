--!strict
-- Loads every ModuleScript in Services and calls :Init() then :Start() on each.
local services = script:WaitForChild("Services")

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
		entry.svc:Init()
	end
end
for _, entry in loaded do
	if type(entry.svc) == "table" and entry.svc.Start then
		task.spawn(entry.svc.Start, entry.svc)
	end
end

print(`[Server] started {#loaded} services`)
