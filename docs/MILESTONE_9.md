# Milestone 9: Polish, accessibility, audio, brand

## What is new
- **Settings** app (always available): text size 100/125/150% (applies to every phone screen), sound volume, goal hints on/off. All saved on the server.
- **Brand Studio** (level 3): name your bakery (3-20 letters/numbers/spaces, run through Roblox text filtering, refused if the filter is unavailable) and pick a color. The name shows as the phone title.
- **Sound**: a new SoundController plays Roblox's built-in ping on notifications and a click when cash rises. Volume follows the setting; a sound that cannot load is skipped silently. Client now starts **6 controllers**.
- The phone UI kit scales text and touch targets together, and every button is at least 44 px tall.

## Not done (honest list)
- A full art pass (decor, lighting, skybox, signage) and custom sound/music assets: these need iteration in Studio that I cannot do from here.
- Performance profiling: no measurements exist. The UI rebuilds a screen on each state change, which is fine at this size but unmeasured.
- Colorblind palettes and a reduce-motion option (the saved `effects` flag exists but nothing animated reads it yet).

## Test plan (Studio)
1. `[Client] started 6 controllers`, no red errors.
2. Settings: pick 150% text; every phone screen grows and nothing is clipped on a phone-sized emulator.
3. Volume Off: no ping on a notification. 60%: ping returns.
4. Brand Studio at level 3: save "Sweet Dreams"; the phone title changes; rejoin keeps it. Try a symbol-filled name: refused with a reason.
5. Turn Goal hints off: the Next Goal panel hides.

## Verified vs not
Server logic: 254 sim checks pass (setting validation, NaN/out-of-range, brand rules, filter outage, schema repair, persistence). Layout at larger text sizes and all audio are untested in Studio.
