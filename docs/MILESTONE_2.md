# Milestone 2: Save/load and basic progression

Source of truth: *Cookie Empire AI-Ready Game Design Roadmap*, Milestone 2 and sections 10 and 13. Stacked on Milestone 1 (PR #8).

## 1. Scope and acceptance

Persist cash, inventory, unlocked recipe, completed milestones and starter equipment. Add one equipment upgrade and a clear next-goal panel.
Accept when: progress survives a leave/rejoin test in a published test place; missing or malformed data gets safe defaults; save errors are logged.

## 2. What changed

| Path | Change |
| --- | --- |
| Shared/Modules/DataSchema | New. Schema version 2, migration from the old unversioned save, and `sanitize` that rebuilds a profile only from known, type-checked fields |
| Shared/Config/Equipment | New. Starter equipment plus the Convection Oven ($150, unlocked by the first order) |
| Shared/Config/Milestones | New. Ordered business goals used by both the server (to award) and the HUD (to display) |
| Server/Services/PlayerDataService | Rewritten around DataSchema: retries with backoff on load and save, error counters and warnings, newer-version saves are never loaded or overwritten, temporary profile when the store is down, dev reset |
| Server/Services/ProgressService | New. Awards milestones once each; gives a small supply kit to a player with no cash, ingredients or cookies (5 minute cooldown) |
| Server/Services/EquipmentService | New. Validated purchase of equipment; effective stats for the baking station |
| Server/Services/BakingService, Shared/Modules/Quality | The oven's forgiveness (`bakeSlack`) widens the timing window |
| Client HUD | Next-goal panel under the status card; Studio-only "Dev: reset my save" button |
| Client Shop | New Equipment section (Convection Oven) |
| Economy | Starting cash $250, roadmap starter pantry, first-order payouts in the $45 to 70 range, ledger stats (gross, supplies, wages, delivery, other, orders) |

Server prints `[Server] started 9 services`. Client still prints `[Client] started 6 controllers`.

## 3. Test plan

1. Fresh start: HUD shows $250 and the goal "Deliver your first order". Complete the first order (see MILESTONE_1.md). Cash goes up by about $45 to 80 and the goal moves to "Save $150 for an oven upgrade" (or straight to "Buy the Convection Oven" if you already have $150).
2. Publish the place and turn on Game Settings > Security > Enable Studio Access to API Services. Play a published test place (or Studio with API access).
3. Leave/rejoin: after delivering an order and buying nothing else, stop the game and start it again. Cash, ingredients, level, and the finished first-order goal are still there. A box you had not delivered is still in stock; open orders are not saved and the first order is offered again only if you never completed one.
4. Shop (B) > Equipment: the Convection Oven shows "Locked" before your first order, then its price. Buying with less than $150 says you need $150 and takes nothing. Buy it: cash drops by $150, the button says owned, the goal advances.
5. Bake again: the green zone on the oven bar is visibly wider than before, and pulling about half a second late still gives a full bake score.
6. Rapid exit: deliver an order and leave within a second. Rejoin: the payout is there (the save runs on leave).
7. Broke recovery: in Studio, spend or lose everything (or use the Dev button to reset, then buy nothing). A player with under $10, no ingredients and no cookies gets a toast about a neighbor's basket and a small supply kit, at most once per 5 minutes.
8. Dev reset (Studio only): click "Dev: reset my save". Cash returns to $250, inventory to the starter pantry, and the first order is offered again. In a published game the button is not shown and the server refuses the request.
9. Failure handling: check Output with a bad connection or with API access off: you should see `[PlayerDataService]` warnings with the failure reason and a toast saying progress will not be saved this session. The game stays playable.

## 4. Security and reliability notes

- Saved data is rebuilt field by field: unknown ingredient or equipment ids, negative or non-numeric values, junk batches, and stale box reservations are all removed or clamped on load.
- A save written by a newer version (a rollback case) is never loaded or overwritten.
- If loading fails, the player plays with a temporary profile that is never written, so a bad load cannot erase a real save.
- Equipment purchases: id allow-list, owned check, unlock check, price check and rate limit, all on the server.
- Server logic checked in the Luau sim: leave/rejoin, v1 migration, malformed data, newer-version save, simulated DataStore failures on load and save, rapid exit, lock handling, recovery kit and its cooldown, dev reset in and out of Studio, equipment rules (74 checks pass in total with Milestone 1).

## 5. Known limitations

- Not run in Studio or against the real DataStore; the failure cases use a fake store. Please run steps 2 to 3 in a published test place.
- Open orders and unfinished bake sessions are not saved. Cookies already boxed are. The ingredient cost of an interrupted bake is lost.
- The Shop panel still carries ingredient buying and equipment. Milestone 3 moves ingredients into PantryDash and Milestone 4 moves equipment into GearUp.
- Reputation and skills exist in the schema but nothing awards them yet.
- The recovery kit gives one batch of Classic Chip ingredients only.

Stop here until these tests pass (or continue with Milestone 3 at your own risk: it builds on this).
