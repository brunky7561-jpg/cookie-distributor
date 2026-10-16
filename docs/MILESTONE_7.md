# Milestone 7: Vehicles

## What is new
- **Wheelhouse** (phone app, level 4): buy the Compact Car ($800, lvl 4) or Delivery Van ($2500, lvl 6) and spawn it near you.
- **Real perk, not just decoration**: owning a vehicle shortens PantryDash courier time (15 s -> 10 s car, 6 s van) and the van removes the small-order fee. This is validated on the server in the shared DeliveryMath.
- **Driving**: the car is a server-built body with a VehicleSeat. While seated, W/A/S/D drives it (the server reads throttle/steer and moves the body; AlignOrientation keeps it upright). One vehicle per player; it disappears when you leave.
- Walking always works. Nothing requires a vehicle.

## Not built yet (honest list)
- Route guidance and destination markers on the map.
- Fuel, damage, traffic and multiple seats beyond the driver seat.
- Hinge-based wheel physics. Driving is a simple direct-velocity model on purpose, because it is far less likely to break untested.

## Test plan (Studio)
1. Level 4 (dev reset can help). Wheelhouse appears.
2. Buy the Compact Car; PantryDash now says "Arrives in about 10 seconds".
3. Spawn: a coloured car appears about 12 studs ahead. Sit in the driver seat; W/S moves, A/D turns, it does not tip over.
4. Leave and rejoin: ownership persists; spawn again works.
5. If the car drives badly (this is the risk), report it: perks still work.

## Verified vs not
Server logic: 217 sim checks pass (buy, gates, ETA/fee perks, quotes, persistence). **Driving physics has not been run at all**; the sim cannot model Roblox physics.
