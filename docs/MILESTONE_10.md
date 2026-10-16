# Milestone 10: Release readiness

## What is new
- **IntegrityService**: every minute, repairs impossible values (NaN/negative cash, XP, stats, ingredients; empty batches) and counts repairs.
- **MetricsService**: one log line every 5 minutes: players, unsaved players, load/save errors, malformed saves, integrity repairs, rate-limited calls and the noisiest remote.
- **Save-failure message**: if an autosave gives up after retries the player is told once; they were already told if their data failed to load.
- **Rate limiter** now counts rejections per remote.
- `docs/RELEASE.md`: launch checklist, QA checklist (from the roadmap), migration and rollback plan, known risks.

## Verified
269 sim checks pass, including: v1 and v2 saves migrate; hostile save data is repaired; 1564 fuzzed remote calls with junk arguments produce zero errors and never create money; the audit repairs and then finds nothing.

## Test plan (Studio)
1. `[Server] started 17 services`, `[Client] started 6 controllers`.
2. Play 6 minutes; the output shows one `[Metrics]` line with zeros for errors.
3. Full pass of the QA checklist in `docs/RELEASE.md`.
