--!strict
-- Vehicles: buying is validated here; spawning builds a simple driveable car on the server. The car is a body with a
-- VehicleSeat; while someone sits in it the server steers it from the seat's throttle and steer values, and
-- AlignOrientation keeps it upright so it cannot tip over. One vehicle per player; it is removed when they leave.
-- This is the least-tested piece of the game: if driving misbehaves, the delivery perks from owning a vehicle still work.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local RateLimit = require(ReplicatedStorage.Shared.Modules.RateLimit)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)

type Car = { model: Model, body: BasePart, seat: VehicleSeat, speed: number, owner: Player }

local cars: { [Player]: Car } = {}
local folder: Folder? = nil

local VehicleService = {}

local function buildCar(player: Player, def: any, at: CFrame): Car
	local model = Instance.new("Model")
	model.Name = `{def.name} ({player.Name})`
	local c = Color3.fromRGB(def.color[1], def.color[2], def.color[3])

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(6, 2, 10)
	body.Color = c
	body.Material = Enum.Material.SmoothPlastic
	body.CustomPhysicalProperties = PhysicalProperties.new(2, 0, 0, 1, 1) -- low friction: we drive it directly
	body.CFrame = at
	body.Parent = model

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.CFrame = at * CFrame.new(0, 1.5, -1)
	seat.MaxSpeed = 0 -- we move the body ourselves
	seat.Torque = 0
	seat.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = seat
	weld.Parent = body

	for _, off in { Vector3.new(-3.2, -1, -3.5), Vector3.new(3.2, -1, -3.5), Vector3.new(-3.2, -1, 3.5), Vector3.new(3.2, -1, 3.5) } do
		local wheel = Instance.new("Part")
		wheel.Name = "Wheel"
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(0.8, 2.4, 2.4)
		wheel.Color = Color3.fromRGB(40, 40, 40)
		wheel.CanCollide = false
		wheel.CFrame = at * CFrame.new(off) * CFrame.Angles(0, 0, math.rad(90))
		wheel.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = wheel
		w.Parent = body
	end

	-- keep the car upright (yaw is free, tilt is not)
	local att = Instance.new("Attachment")
	att.Parent = body
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.AlignType = Enum.AlignType.PrimaryAxisParallel
	align.PrimaryAxis = Vector3.new(0, 1, 0)
	align.Attachment0 = att
	align.MaxTorque = 1e7
	align.Responsiveness = 40
	align.Parent = body

	model.PrimaryPart = body
	model.Parent = folder
	return { model = model, body = body, seat = seat, speed = def.speed, owner = player }
end

local function remove(player: Player)
	local car = cars[player]
	if car then
		cars[player] = nil
		car.model:Destroy()
	end
end

function VehicleService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Vehicles"
	folder.Parent = workspace

	Remotes.func("VehicleBuy").OnServerInvoke = function(player: Player, id: any): (boolean, string)
		if not RateLimit.check(player, "VehicleBuy", 0.5) then
			return false, "slow down a little"
		end
		local data = PlayerDataService:Get(player)
		local def = if type(id) == "string" then Vehicles.catalog[id] else nil
		if not data or not def then
			return false, "unknown vehicle"
		end
		if data.vehicles[def.id] then
			return false, "you already own that"
		end
		if data.level < def.unlockLevel then
			return false, `Reach level {def.unlockLevel} to buy the {def.name}.`
		end
		if not EconomyService:TrySpend(player, def.price) then
			return false, `You need ${def.price} for the {def.name}.`
		end
		data.vehicles[def.id] = true
		EconomyService:Record(player, "other", def.price)
		PlayerDataService:Replicate(player)
		return true, `You bought the {def.name}! Spawn it from the Wheelhouse.`
	end

	Remotes.func("VehicleSpawn").OnServerInvoke = function(player: Player, id: any): (boolean, string)
		if not RateLimit.check(player, "VehicleSpawn", 3) then
			return false, "give it a few seconds"
		end
		local data = PlayerDataService:Get(player)
		local def = if type(id) == "string" then Vehicles.catalog[id] else nil
		if not data or not def or not data.vehicles[def.id] then
			return false, "you do not own that vehicle"
		end
		local char = player.Character
		local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
		if not root or not root:IsA("BasePart") then
			return false, "your character is not ready"
		end
		remove(player)
		local ok, car = pcall(buildCar, player, def, root.CFrame * CFrame.new(0, 3, -12))
		if not ok then
			warn(`[Vehicle] could not build {def.id}: {car}`)
			return false, "the vehicle could not be built; delivery perks still apply"
		end
		cars[player] = car :: Car
		return true, `Your {def.name} is ready. Hop in the driver seat.`
	end

	Remotes.func("VehicleRemove").OnServerInvoke = function(player: Player): boolean
		remove(player)
		return true
	end

	Players.PlayerRemoving:Connect(remove)
end

function VehicleService:Start()
	RunService.Heartbeat:Connect(function()
		for player, car in cars do
			local seat = car.seat
			if not seat.Parent then
				cars[player] = nil
			elseif seat.Occupant then
				local throttle = math.clamp(seat.ThrottleFloat, -1, 1)
				local steer = math.clamp(seat.SteerFloat, -1, 1)
				local look = car.body.CFrame.LookVector
				local vel = car.body.AssemblyLinearVelocity
				local target = look * throttle * car.speed
				car.body.AssemblyLinearVelocity = Vector3.new(target.X, vel.Y, target.Z)
				car.body.AssemblyAngularVelocity = Vector3.new(0, -steer * 1.8 * (if throttle < 0 then -1 else 1), 0)
			end
		end
	end)
end

return VehicleService
