# Cookie Empire: release readiness

**Status: not released, and not Studio-tested.** Every milestone (0-10) was verified only by a Luau simulation of the server logic plus compile/type checks. No UI, physics, audio or performance has been seen running. Treat the first Studio session as the real QA.

## Launch checklist
- [ ] Open `CookieDistributor.rbxlx` in Studio; Output shows no red errors.
- [ ] `[Server] started 17 services` and `[Client] started 6 controllers`.
- [ ] Studio Settings > Security: enable **Studio Access to API Services** (DataStores).
- [ ] Walk the QA checklist below on a phone-sized emulator and a desktop.
- [ ] Publish to a **private test place** first; test with 2 accounts for 30 minutes (join, leave, rejoin).
- [ ] Check the `[Metrics]` log lines: saveErr and loadErr stay 0.
- [ ] Set DEV_USER_IDS in PlayerDataService to your own id only (the reset button is Studio/dev only).
- [ ] Decide the DataStore name (STORE_NAME). Changing it later orphans every save.

## QA checklist (roadmap section 15, condensed)
1. New player: first order completes in about 5 minutes without outside help.
2. Bake: every stage works; skipping or spamming steps does nothing bad.
3. PantryDash: order, wait, collect; leave mid-delivery and rejoin: the crate is still owed.
4. Orders: accept, bake, deliver, get paid exactly once; cancel and expiry release the cookies.
5. Equipment, recipes, experiments: purchases take the right money; practice raises correctness.
6. Properties: buy the Food Truck; display a batch; walk-in sales and rent behave; a broke player is never punished beyond a closed shop.
7. Staff: hire, assign, read the status reason in each blocked case.
8. Vehicles: perks apply; the car drives (the least certain piece).
9. Market Pulse: event shown; contract delivered; expired contract costs nothing.
10. Settings/Brand: text size, volume, name filtering.
11. Rejoin and server-shutdown saves; two servers at once (session lock).
12. Phone/touch: every button reachable, nothing clipped at 150% text.

## Migration plan
- Schema version is 2. `DataSchema.sanitize` fills every missing field with defaults, so adding a field needs no version bump. A change in the *meaning* of a field needs a bump and a step in `DataSchema.migrate`.
- Never rename `STORE_NAME` or remove fields without a migration step; keep the old field readable for one release.
- A save that cannot be read is never overwritten: the player plays on temporary data (flagged and reported) and the original stays in the DataStore.

## Rollback plan
- Studio keeps published versions: Home > Creations > the place > Versions > Revert. Reverting code is safe because older code ignores newer fields (they are preserved by the session-locked write only if the old code reads them: **fields added after the rollback target are dropped on the player's next save**). To avoid that, roll back *before* many players have saved on the new version, or publish a hotfix forward instead.
- If a bad build is live: set a ServerScript kill switch or shut servers down from the Creator Dashboard, then revert.

## Known risks (honest)
- Stacked, untested layers compound: a UI bug in an early milestone may break later screens. Test in order.
- Vehicle driving is a simple direct-velocity model; it may feel wrong. Perks still work if driving does not.
- The Sugarblock art pass, custom audio, and performance profiling are not done.
- Anti-exploit covers data sanity and remote validation. There is no speed/teleport detection (it risks false positives with vehicles).
- Properties are shared world locations with per-player ownership, not instanced plots.
- OrderedDataStore leaderboard needs live API access to populate.
