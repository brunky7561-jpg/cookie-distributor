# Milestone 0: Project skeleton and graybox

Source of truth: *Cookie Empire AI-Ready Game Design Roadmap* (v1.0, October 2026), sections 12 to 16.

## 1. Milestone scope and acceptance

Build the starter house, one small street, player spawn, a basic HUD, and interaction prompts, using placeholder parts.
Accept when: the game starts without errors; the player can move, interact with a test station, and return to a stable idle state.

## 2. Files created or changed

| Path in Studio | Type | Change |
| --- | --- | --- |
| ServerScriptService/Server/Bootstrap | Script | Renamed from init.server; loads every service in `Services` |
| ServerScriptService/Server/Services/InteractionService | ModuleScript | New. Gives every station the attributes StationType, OwnerUserId, Capacity, BusyState and a server-side ProximityPrompt; validates station, distance, owner, state, cooldown |
| ServerScriptService/Server/Services/PlayerDataService | ModuleScript | Renamed from DataService |
| ServerScriptService/Server/Services/BakingService | ModuleScript | Baking now requires the player to be near a BakeStation |
| ServerScriptService/Server/Services/CustomerService | ModuleScript | Removed Hooked/Burnout/ghosting; Craving renamed Appeal |
| StarterPlayerScripts/Client/ClientBootstrap | LocalScript | Renamed from init.client |
| StarterPlayerScripts/Client/Controllers/HUDController | ModuleScript | Rebuilt: cash and level, objective text, on-screen Phone and Shop buttons, Sugarblock palette |
| StarterPlayerScripts/Client/Controllers/InteractionController | ModuleScript | New. Opens a panel only when the server accepted an interaction |
| StarterPlayerScripts/Client/Controllers/UIBus | ModuleScript | New. Lets controllers open panels without requiring each other |
| StarterPlayerScripts/Client/Controllers/BakingController | ModuleScript | Renamed from BakeController; no longer opens from a hotkey or client-made prompt |
| ReplicatedStorage/Shared/Config/Theme | ModuleScript | New. Cocoa, Buttercream, Butter, Coral, Mint, Blueberry tokens |
| ReplicatedStorage/Shared/Modules/AppealCalc | ModuleScript | Renamed from CravingCalc |
| Workspace | map | Spawn moved to the starter house door; supply kiosk and path added; districts and plots renamed to the roadmap's names |

## 3. Studio setup

Open `build/CookieDistributor.rbxlx`. No manual setup. For saving, publish the place and turn on Game Settings > Security > Enable Studio Access to API Services.

## 4. Test plan

1. Press Play. Output shows `[Server] started 6 services` and `[Client] started 6 controllers`, with no red errors. Expect: you spawn in front of a small cream house with a path to the square.
2. The HUD shows `$ 50  Lv 1`, the objective "Make your first batch...", and Phone and Shop buttons bottom right.
3. Walk into the house. A prompt "Bake / Kitchen" appears near the counter and the oven. Press E (touch: tap the prompt). The baking panel opens.
4. Walk about 30 studs away and press Start baking from an already open panel. Expect "walk up to your kitchen counter or oven first".
5. Tap Shop, buy flour, and check cash drops and the ingredient count rises. Tap Phone and check the panel opens and closes.
6. Press Stop in Studio, play again, and check cash and ingredients saved (needs API access on).

Edge cases to try: spam E on the prompt (a 0.4 second cooldown applies), open Shop and Phone together, reset your character while the baking panel is open.

## 5. Security notes

Server-owned: cash, inventory, quality, appeal, order state, payouts, station attributes. The client only sends a request; `InteractionService` checks the station still exists and is tagged, the player is within 14 studs of its nearest edge, the owner matches, the station is not busy, and a cooldown. `BakingService.BakeStart` re-checks proximity itself, so the panel cannot be opened from a distance by firing the remote. Remaining rate limits are listed under limitations.

## 6. Known limitations (honest list)

- Nothing here has been run in Studio. I have no way to run Roblox or Luau in this environment.
- Rate limiting exists only on interactions. Shop, bake and order remotes still need per-player limits (Milestone 1 and 2 work).
- BusyState and OwnerUserId are set but not yet used by baking (all starter stations are public).
- The map is a large graybox with many districts; the roadmap suggests a smaller first district. Everything beyond Starter Row and Market Square is optional scenery until later milestones.
- The older phone, shop and baking panels use the previous dark theme; they get the Sugarblock palette in the milestones that rebuild them.

Stop here until these tests pass.
