# Milestone 8: Rivals, contracts, market events, leaderboard

## What is new
- **Market Pulse** (phone app, level 2 + first order): shows today's event, your contract and the top earners.
- **Market events** rotate every 15 minutes (Chocolate Craze, Salty-Sweet Week, Sugar Festival, Quiet Day). Orders whose cookies carry the matching tag pay 20-25% more. The event is a pure function of the clock, so everyone sees the same one.
- **Contracts**: one big order at a time (12 cookies of one recipe, score 65+, about 1.5x normal pay, 20 min). Cookies on display or promised to an order do not count. Delivery is all-or-nothing. Winning gives cash, XP and 5 reputation.
- **Rivals** (Sugar Rush Bakery, The Golden Whisk, Crumb & Co.) compete for each contract. If it expires a rival wins it; the only cost is the missed opportunity, and your win/loss record is shown.
- **Leaderboard**: lifetime gross in an OrderedDataStore, refreshed every minute. If the store is unavailable the board is just empty.

## Test plan (Studio)
1. `[Server] started 14 services` (adds Property, Staff, Vehicle, Market on top of the earlier 10: 14 total), `[Client] started 5 controllers`.
2. Reach level 2 and finish an order: Market Pulse unlocks. A contract appears within a minute.
3. Bake 12 cookies of the contract recipe at 65+ (a double batch works), tap Deliver.
4. Wait for the event to change (15 min) or compare two servers: same event.
5. Enable Studio API access to DataStores to see the leaderboard populate.

## Verified vs not
Server logic: 237 sim checks pass. Leaderboard (OrderedDataStore) is only checked for graceful failure. Market Pulse UI untested in Studio.
