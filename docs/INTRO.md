# Title screen and opening cutscene

- Title screen shows on every load; press Play.
- First time a save joins, Play starts a short cutscene with the antagonist (default: Madame Vex, Head of the Cookie Council).
  She offers a choice: **take the punishment** ($50 fine) or **bake cookies for her** (the first order is accepted for you).
  The choice is stored in `milestones.introDone`, so it never plays twice for the same save.
- Everything (name, portrait, lines, choices, fine) lives in `src/shared/Config/Intro.luau`.
- Roblox moderation can reject real people's names or likenesses, so the default antagonist is fictional.
