# Milestone 4: Recipe depth, experiments and equipment

## What is new
- **Recipe Book** (phone app): known recipes, practice counts, best grade, and saved experiments.
- **Experiments**: pick a flavor, mix-in and finish in the kitchen. A combination that matches a catalog recipe is that recipe (and is discovered). Anything else is a custom cookie that starts at 85% recipe correctness, 92% on the second bake and 100% on the third. A good experiment (score 50+) is saved, up to 8.
- **Gear Up** (phone app, also **B**): Convection Oven (forgiving bake timing), Stand Mixer (faster mixing, double batches), Fan Cooling Rack (shorter cooling).
- **Double batch**: with a Stand Mixer you can bake 12 cookies; ingredients double and you need the 12-box.
- **Result screen** explains each quality factor (recipe, bake, freshness, portion) and what to improve.
- Named-recipe orders accept only that recipe; "any new recipe" orders accept an experiment.
- The old shop controller was removed; the client now starts 5 controllers (HUD, Interaction, UIBus, Baking, Phone).

## Test plan (Studio)
1. Output shows `[Server] started 10 services` and `[Client] started 5 controllers`.
2. Open the Recipe Book (phone, P): known recipes listed with practice counts.
3. At the kitchen counter choose Experiment, set slots, check the summary lists ingredients and cost.
4. Bake the same experiment 3 times; correctness should rise (watch the result breakdown).
5. Buy the Stand Mixer in Gear Up; a double batch should appear and require the 12-box.
6. Accept a named order, try an experiment for it: it must be refused.
7. Rejoin: recipes, recipe book and equipment persist.

## Verified vs not
Server logic: 154 Luau-sim checks pass. The UI (kitchen, result, Recipe Book, Gear Up) compiles and type-checks but has **not been run in Studio**.
