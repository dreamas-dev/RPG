# Endless Road – Roblox version: notes for Claude

These rules override the root CLAUDE.md for any work on the Roblox version:

- Talk to the user in Lithuanian; game text stays in English.
- Work only inside `roblox/` on branch `roblox` (`git push -u origin roblox`).
- Never push to `main` (it deploys the live web game) and never touch the web game files
  (`index.html`, `sw.js`, `build.js`, `supabase/`, `wrangler.jsonc`, ...). Use them only as the source of data and rules.
- Rojo project: `default.project.json`, `src/server`, `src/client`, `src/shared`. Test in Roblox Studio via `rojo serve`.
  Studio place: `rojo build -o EndlessRoad.rbxl` (gitignored), open it, `rojo serve --port 34880` (34872 belongs to
  Dive & Dine's Studio), set that port in the Rojo panel and Connect. Bump `BUILD er-N` in both Main scripts.
- Never ask for passwords, tokens or API keys in chat.
- LICENSE: all rights reserved.
- Restarted 2026-11-02 as an OSRS-style game (original names and art). Done: Millbrook town, melee on 0.6 s ticks,
  rats; saves (DataStore, session lock), 28-slot bag, ground loot, Prayer by burying bones, Woodcutting (trees, oaks).
  Next ideas: Firemaking and Cooking (food to heal), Fishing in the river, a general store and bank in Millbrook.
- Studio tests: `ServerStorage.Test` (BindableFunction: give, chop, take, drop, action, xp) and `ServerStorage.TestAttack`.
  The local place can't reach DataStores, so Studio plays unsaved (message on screen).
- Test with the Roblox Studio MCP (start_stop_play, execute_luau, get_console_output). Use emoji up to Unicode 12 only.
