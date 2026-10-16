# Milestone 1: One complete cookie order

Source of truth: *Cookie Empire AI-Ready Game Design Roadmap* (v1.0, October 2026), Milestone 1 and sections 4 and 5.
Stacked on Milestone 0 (PR #7). Milestone 0 has not been tested in Studio yet, so test it first.

## 1. Scope and acceptance

Seeded customer request, choose the Classic Chip recipe, check inventory, bake a batch, package it, deliver, get paid.
Accept when: a new player can finish the first order without admin commands; ingredients are consumed once; the payout is granted once; each state is visible.

## 2. What changed

| Path in Studio | Type | Change |
| --- | --- | --- |
| Server/Services/InventoryService | ModuleScript | New. Only place that adds or removes ingredients and packaged boxes. `Consume` is all-or-nothing; boxes can be reserved for one order |
| Server/Services/OrderService | ModuleScript | Replaces CustomerService. Order state machine Available > Accepted > In Production > Ready > Delivered > Paid, a seeded free first order (no deadline), cancel/decline, expiry for later random orders |
| Server/Services/BakingService | ModuleScript | Rewritten: Mix, Portion, Bake, Cool, Package, all timed by the server |
| Server/Services/EconomyService | ModuleScript | Shop purchases go through InventoryService; rate limited |
| Server/Services/PlayerDataService | ModuleScript | Starter pantry now includes 2 chocolate chips (enough for the first batch); new `milestones` table |
| Client/Controllers/BakingController | ModuleScript | Recipe screen (needs/have, cost, which order to bake for) and the five station steps; a half-finished bake resumes when you reopen the station |
| Client/Controllers/PhoneController | ModuleScript | Messages: every order with its state line, the next action, a delivery receipt |
| Client/Controllers/HUDController | ModuleScript | Objective text follows the order state, so the first loop is spelled out |
| Shared/Config/Recipes, Baking | ModuleScript | Classic Chip recipe, box sizes, station timings |
| Shared/Modules/Quality, RateLimit | ModuleScript | Quality model 40/30/15/15 with grades and feedback; per-player remote cooldowns |

Server now prints `[Server] started 7 services`. Client still prints `[Client] started 6 controllers`.

## 3. Test plan (new player, no admin commands)

1. Press Play. Output shows the two "started" lines above and no red errors. The HUD says to open your phone and accept Mrs. Park's order. A toast says a new order arrived.
2. Press **P**. Mrs. Park asks for 6 Classic Chip cookies, pays about $30, no deadline. The state line reads `[Available] > Accepted > ...`. Tap **Accept**. State becomes Accepted and the HUD says to walk to your kitchen counter.
3. Walk to the counter or oven in your kitchen and press **E**. The Kitchen screen lists Flour 2, Butter 1, White Sugar 1, Chocolate Chips 1 with your amounts, and "Bake for" is Mrs. Park. Tap **Start baking**.
4. Mix: tap **Stir!** 8 times. Portion: tap **Start portioning**, then **Scoop!** when the bar is in the green zone. Bake: **Load tray**, then **Pull the tray!** in the green zone. Cool: wait about 4 seconds. Package: tap **Small box** first (it should refuse), then **Standard box**.
5. Result shows a grade (Needs Work / Good / Great / Perfect Batch), a score out of 100 and one sentence of feedback. Check your inventory: the ingredients were taken once, and a second Start baking while one is running is refused. Press **P**: state is Ready.
6. Tap **Deliver**. A receipt shows Delivered and Paid, the grade and feedback, the customer reaction and your payout. Cash goes up once. Tap Deliver again (or spam it): nothing more is paid.
7. Edge checks: bake badly on purpose (stop the bars far from green) and read the feedback; close the Kitchen screen mid-bake and press E again, it should resume; decline the first order and a new one appears; with no ingredients, Start baking says what is missing and points to the Shop (B).
8. Wait about 30 seconds after step 6: new random customer orders start arriving, each with a deadline.

## 4. Security notes

- Server-owned: ingredient counts, bake timing and scores, quality grade, order state, box reservation, payout. The client sends only a recipe id, an order id, a button name and a box id; all are type-checked and validated.
- Ingredients are consumed in one all-or-nothing step after every check passes. The order leaves the table before the payout, so one order can only pay once. A cancelled or expired order releases its reserved box.
- Rate limits: BakeStart 0.5 s, BakeStep 0.15 s, OrderAction 0.2 s, BuyIngredient 0.1 s per player.
- Bake steps must come in order; the mix step needs at least 3 s and the tray needs 4 s of cooling on the server clock.

## 5. Known limitations

- Not run in Studio. The server logic was run against a fake Roblox environment with the real Luau interpreter (`python3 tools/sim/build_sim.py out.luau && luau out.luau`, 39 checks pass), and every file passes the Luau syntax check. The UI code has not been run.
- Recipe correctness and ingredient freshness are always full marks for now: there is one guided recipe and ingredients do not spoil. They start to matter with free-form recipes (Milestone 4) and freshness (later).
- Delivery is a phone hand-over to a text destination. Walking to a destination and the CrumbChat/PantryDash apps are Milestone 3.
- Orders and the first-order flag: the flag (`milestones.firstOrderDone`) saves with the player, but open orders and unboxed batches in progress are not saved until Milestone 2 hardens persistence.
- Starting cash is still $50 (the roadmap's $250 arrives in Milestone 2). The other ingredients in the Shop are not used by Classic Chip yet.
- Old UI panels (Shop) are not on the Sugarblock theme yet; Milestone 9 covers art.

Stop here until these tests pass.
