# Title screen and opening cutscene

- Title screen shows on every load; press Play.
- First time a save joins, Play starts a short cutscene with the antagonist (default: Madame Vex, Head of the Cookie Council).
  She offers a choice: **take the punishment** ($50 fine) or **bake cookies for her** (the first order is accepted for you).
  The choice is stored in `milestones.introDone`, so it never plays twice for the same save.
- Everything (name, portrait, lines, choices, fine) lives in `src/shared/Config/Intro.luau`.
- Roblox moderation can reject real people's names or likenesses, so the default antagonist is fictional.

# Baking minigames and starting economy
- **Dough:** press E at the counter, start a bake, then press Stir when the moving marker is inside the green zone (5 rounds). The score (0-100%) is sent with the mix step and counts 10% of batch quality. A miss only lowers it.
- **Oven:** stop the red marker between the two dark lines (same timing rules as before, now drawn as a marker between lines).
- **Economy:** the Classic Chip cookie sells for $15 and costs $10 to make ($60 of ingredients per batch of 6). Ingredient prices, order offers and delivery fees were rescaled to match.
