# Milestone 6: First employee

## What is new
- **Staff Board** (phone app, unlocks once you own a Food Truck or bigger): hire Sam ($30/day, skill 1), Rosa ($70, skill 2) or Ike ($130, skill 3).
- One baker per extra oven (total oven slots minus your own). Pick which known recipe they bake.
- A baker bakes one batch of 6 every 100/80/60 seconds using pantry ingredients. Quality is deterministic: score 60/70/80 by skill (+10 after 10 bakes), never random. Hand baking can still reach 100.
- The board always states **why** a baker is idle: needs a recipe, waiting on ingredients (with the exact shortfall), storage full, or waiting for wages.
- Wages are charged every 10 minutes and recorded in the Ledger as wages. If you cannot pay, the baker waits; nobody is fired and nothing is lost.

## Test plan (Studio)
1. `[Server] started 12 services`, `[Client] started 5 controllers`.
2. With a Food Truck, open Staff Board, hire Sam, choose Classic Chip. Status reads "Baking ... %".
3. After about 100 s a batch of 6 "Baked by Sam." appears in storage.
4. Empty the pantry: the status names the missing ingredient. Restock via PantryDash: it resumes.
5. Drop cash to 0 and wait for pay day: status "Waiting for wages"; add cash and it resumes.
6. Ledger shows wages.

## Verified vs not
Server logic: 204 sim checks pass. Staff Board UI untested in Studio.
