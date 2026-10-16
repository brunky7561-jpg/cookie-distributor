--!strict
-- Loads every ModuleScript in Controllers and calls :Init() then :Start() on each.
local controllers = script.Parent:WaitForChild("Controllers")

local loaded = {}
for _, module in controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, c = pcall(require, module)
		if ok then
			table.insert(loaded, { name = module.Name, c = c })
		else
			warn(`[Client] failed to load {module.Name}: {c}`)
		end
	end
end

for _, entry in loaded do
	if type(entry.c) == "table" and entry.c.Init then
		entry.c:Init()
	end
end
for _, entry in loaded do
	if type(entry.c) == "table" and entry.c.Start then
		task.spawn(entry.c.Start, entry.c)
	end
end

print(`[Client] started {#loaded} controllers`)
