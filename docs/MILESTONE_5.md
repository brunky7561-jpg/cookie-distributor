# Milestone 5: Properties and storefront

## What is new
- **Property Desk** (phone app, unlocks at level 3): preview a property, see cash after, then confirm. Food Truck ($1500, lvl 3), Garage Kitchen ($4000, lvl 5), Corner Cookie Shop ($9000, lvl 7).
- Each property adds storage, a **delivery mat** (PantryDash can deliver there) and, from the truck up, a **display case**.
- **Display case**: put a finished batch on display; walk-in customers buy cookies every 20 seconds, a few per round. Pay is modest by design (about 60% of a typical order), so orders stay the better deal. A displayed batch cannot be promised to an order until you take it off display.
- **Rent** is charged every 10 minutes. If you cannot pay, the storefront closes until you can. Nothing is ever repossessed.
- Properties are *locations in the shared world*: each player's ownership, storage and display case are their own, but the building markers are shared. Instanced per-player plots are deferred (see roadmap risks).

## Test plan (Studio)
1. Output: `[Server] started 11 services`, `[Client] started 5 controllers`.
2. Reach level 3 (or edit cash/level with the dev reset); Property Desk appears on the phone.
3. Preview the Food Truck: confirm shows cash after. Buy it; storage in PantryDash grows.
4. Order ingredients to "Food Truck" in PantryDash; a crate appears at its mat (-14,-96).
5. Bake a batch, put it on display, wait about 20 s: a "Walk-in customers bought..." toast and cash rise.
6. Spend cash below rent and wait 10 min (or edit DAY): storefront closes with a toast.

## Verified vs not
Server logic: 180 sim checks pass (purchase gates, display limits, sales, rent, closing, persistence). Property Desk UI and the new mat markers are untested in Studio.
