--!strict
-- PantryDash deliveries: validated purchase, courier drops a crate at the property's receiving mat, player collects it.
-- Paid deliveries are saved, so a crate is never lost by leaving the game: it is simply waiting on the next visit.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Properties = require(ReplicatedStorage.Shared.Config.Properties)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local DeliveryMath = require(ReplicatedStorage.Shared.Modules.DeliveryMath)
local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local InteractionService = require(script.Parent.InteractionService)

local COLLECT_DISTANCE = 16
local TICK = 1

local crates: { [Player]: { [number]: BasePart } } = {}
local folder: Folder? = nil

local DeliveryService = {}

local function cratesFor(player: Player): { [number]: BasePart }
	local t = crates[player]
	if not t then
		t = {}
		crates[player] = t
	end
	return t
end

local function notify(player: Player, text: string)
	Remotes.event("Notify"):FireClient(player, text)
end

local function findMat(def: any): BasePart?
	for _, inst in CollectionService:GetTagged("ReceivingArea") do
		if inst:IsA("BasePart") and inst.Name == def.receivingName and inst:IsDescendantOf(workspace) then
			return inst
		end
	end
	return nil
end

local function itemCount(items: { [string]: number }): number
	local n = 0
	for _, c in items do
		n += c
	end
	return n
end

local function findDelivery(data: any, id: number): (any?, number?)
	for i, d in data.deliveries do
		if d.id == id then
			return d, i
		end
	end
	return nil, nil
end

local function collect(player: Player, crate: BasePart)
	if not RateLimit.check(player, "CollectCrate", 0.5) then
		return
	end
	local data = PlayerDataService:Get(player)
	local id = crate:GetAttribute("DeliveryId")
	if not data or type(id) ~= "number" or crate:GetAttribute("OwnerUserId") ~= player.UserId then
		return -- not your crate
	end
	local d, index = findDelivery(data, id)
	if not d or not index then
		crate:Destroy()
		return
	end
	local distance = InteractionService:DistanceToPart(player, crate)
	if not distance or distance > COLLECT_DISTANCE then
		return
	end
	-- Capacity can only be exceeded here if something else filled the pantry meanwhile; the crate waits for room.
	local onHand = 0
	for _, n in data.ingredients do
		onHand += n
	end
	if onHand + itemCount(d.items) > DeliveryMath.capacity(data) then
		notify(player, "Your storage is full. Use some ingredients, then collect the crate.")
		return
	end

	-- The delivery leaves the list before any item is added, so a crate can only ever be collected once.
	table.remove(data.deliveries, index)
	cratesFor(player)[id] = nil
	crate:Destroy()
	local total = 0
	for ing, n in d.items do
		InventoryService:Add(player, ing, n)
		total += n
	end
	PlayerDataService:Replicate(player)
	notify(player, `Collected {total} items. They are in your pantry.`)
end

local function courier(near: Vector3, parent: Instance)
	local body = Instance.new("Part")
	body.Name = "Courier"
	body.Size = Vector3.new(2, 3, 1.5)
	body.Position = near
	body.Anchored = true
	body.CanCollide = false
	body.Color = Theme.Mint
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = parent
	local head = Instance.new("Part")
	head.Name = "CourierHead"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.Position = near + Vector3.new(0, 2.3, 0)
	head.Anchored = true
	head.CanCollide = false
	head.Color = Theme.Butter
	head.Parent = parent
	task.delay(8, function()
		body:Destroy()
		head:Destroy()
	end)
end

local function spawnCrate(player: Player, d: any)
	local mine = cratesFor(player)
	if mine[d.id] then
		return
	end
	local def = Properties[d.propertyId]
	local mat = if def then findMat(def) else nil
	if not mat or not folder then
		return
	end
	local slot = 0
	for _ in mine do
		slot += 1
	end
	local crate = Instance.new("Part")
	crate.Name = `Supply Crate ({player.Name})`
	crate.Size = Vector3.new(3, 2.4, 3)
	crate.Anchored = true
	crate.Color = Theme.Butter
	crate.Material = Enum.Material.Wood
	crate.Position = mat.Position + Vector3.new(((slot % 3) - 1) * 3.4, mat.Size.Y / 2 + 1.2, math.floor(slot / 3) * 3.4)
	crate:SetAttribute("OwnerUserId", player.UserId)
	crate:SetAttribute("DeliveryId", d.id)
	crate.Parent = folder

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 34)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 60
	gui.Parent = crate
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Theme.Buttercream
	label.TextColor3 = Theme.Cocoa
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.Text = `Supplies for {player.DisplayName}`
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Collect"
	prompt.ObjectText = "Supply crate"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = crate
	prompt.Triggered:Connect(function(who: Player)
		collect(who, crate)
	end)

	mine[d.id] = crate
	courier(crate.Position + Vector3.new(4, 0, 0), folder)
	notify(player, `Your supplies arrived at the {if def then def.name else "property"}. Collect the crate!`)
end

local function dropCrates(player: Player)
	for _, crate in cratesFor(player) do
		crate:Destroy()
	end
	crates[player] = nil
end

function DeliveryService:Init()
	Remotes.func("PantryQuote").OnServerInvoke = function(player: Player, rawItems: any, propertyId: any): (boolean, any)
		if not RateLimit.check(player, "PantryQuote", 0.15) then
			return false, "slow down a little"
		end
		local data = PlayerDataService:Get(player)
		local items, err = DeliveryMath.normalize(rawItems)
		if not data or not items then
			return false, err or "your data is still loading"
		end
		local quote, qerr = DeliveryMath.quote(data, items, propertyId)
		if not quote then
			return false, qerr
		end
		return true, quote
	end

	Remotes.func("PantryOrder").OnServerInvoke = function(player: Player, rawItems: any, propertyId: any): (boolean, any)
		if not RateLimit.check(player, "PantryOrder", 0.5) then
			return false, "slow down a little"
		end
		local data = PlayerDataService:Get(player)
		local items, err = DeliveryMath.normalize(rawItems)
		if not data or not items then
			return false, err or "your data is still loading"
		end
		local quote, qerr = DeliveryMath.quote(data, items, propertyId)
		if not quote then
			return false, qerr
		end
		if not EconomyService:TrySpend(player, quote.total) then
			return false, "not enough cash"
		end
		EconomyService:Record(player, "supplies", quote.subtotal)
		EconomyService:Record(player, "delivery", quote.fee)
		local d = { id = data.nextDeliveryId, items = quote.items, propertyId = quote.propertyId, arriveAt = os.time() + quote.eta }
		data.nextDeliveryId += 1
		table.insert(data.deliveries, d)
		PlayerDataService:Replicate(player)
		return true, { id = d.id, arriveAt = d.arriveAt, total = quote.total }
	end

	PlayerDataService.Reset:Connect(function(player: Player)
		dropCrates(player)
	end)
end

function DeliveryService:Start()
	local f = workspace:FindFirstChild("DeliveryCrates")
	if not f then
		f = Instance.new("Folder")
		f.Name = "DeliveryCrates"
		f.Parent = workspace
	end
	folder = f :: Folder

	Players.PlayerRemoving:Connect(dropCrates)
	while true do
		task.wait(TICK)
		for _, player in Players:GetPlayers() do
			local data = PlayerDataService:Get(player)
			if data then
				for _, d in data.deliveries do
					if os.time() >= d.arriveAt then
						spawnCrate(player, d)
					end
				end
			end
		end
	end
end

return DeliveryService
