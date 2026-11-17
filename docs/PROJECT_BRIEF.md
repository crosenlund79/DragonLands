# Project Brief — Single design and task handoff record

This file **records** decisions and approvals; it never grants them. Only the user can approve scope, in their message in the current conversation. **Undecided = ask, don't choose.**

## Game decisions (user-confirmed only)

- **Game title:** DragonLands
- **Godot version (pin minor, e.g. 4.x):** 4.7 (verified with 4.7.2 stable; GL Compatibility renderer). Confirmed by the user on 2026-11-17.
- **Premise / core player loop:** An original dragon game about collecting dragons; future breeding, genetics, encounters and exploration systems are intended (user, Prototype 001 and 002 requests). The first collecting loop is: discover an egg, carry it home, incubate it, hatch a new dragon (Prototype 002). The full core loop is still undecided. Background research: `docs/dragon_adventures_research_godot.md` (reference only).
- **Perspective / art direction:** 2D fantasy overworld whose exploration feel is inspired by Heroes of Might and Magic III and Age of Wonders, with original assets and mechanics and visually coherent `template_` artwork (user). The specific template style is a Claude proposal (see Proposals below).
- **Confirmed mechanics and constraints (Prototype 001):** One handcrafted forest region with roads, mountains, rivers and landmarks. Mouse click-to-move with path preview, obstacle-aware pathfinding, camera pan and zoom. Two visually distinct companion dragons that follow the adventurer. Fog of war revealed by exploration. A few discoverable locations, including a dragon nest that opens a simple encounter panel. Continuous in-game time that advances with travel, with no turns, daily movement points or End Turn button. Minimal HUD showing time, location and travelling dragons. Do not copy copyrighted game assets.
- **Confirmed mechanics and constraints (Prototype 002):** The Emberfall Nest encounter lets the player acquire a Cinderwing egg; the same egg cannot be collected repeatedly from the same encounter. Eggs are persistent objects shown in a simple UI and develop with the in-game world clock. A ready egg hatches by returning to Wayfarer's Camp. The player names the hatchling, and its species and basic characteristics are displayed, in a small hatching moment using replaceable `template_` art. A modular, persistent dragon data model holds unique identity, species, name, age/growth state and room for future genetic information, structured for later inheritance, mutations and breeding. Ember and Moss keep working. Minimal save/load covers the world clock, explored map and discoveries, collected eggs and incubation progress, and owned dragons and their identities, without duplicating eggs or dragons on load.
- **Explicitly out of scope:** Breeding mechanics, genetic inheritance calculations, mutations, combat (including dragon combat), inventories beyond the egg list, complex NPCs, multiple new species, multiple or additional regions, base construction, elaborate progression. No EXE or installer unless explicitly requested.
- **Existing modules / boundaries:** `src/world`, `src/navigation`, `src/travel`, `src/companions`, `src/dragons`, `src/eggs`, `src/exploration`, `src/time`, `src/encounters`, `src/save`, `src/overworld` (session rules + entry scene), `src/camera`, `src/ui`, `src/assets`. See `README.md`. No Autoloads.
- **Testing framework (GUT or GdUnit4) and commands:** GUT 9.7.1, vendored in `addons/gut` (confirmed by the user on 2026-11-17). Run `godot --headless --path . --import`, then `godot --headless --path . -s res://addons/gut/gut_cmdln.gd`.
- **Target platforms:** Undecided (runtime asset overrides currently cover Windows/Linux only; other platforms need an explicit decision)
- **Asset override notes:** The graphics resolver is implemented (`src/assets/asset_resolver.gd`, PNG overrides in `custom/graphics/<logical path>.png`, effective after a restart). Audio overrides are not implemented yet because the game has no audio. Verification against an exported build is pending, since no export has been approved.

## Current approved objective

**Status: Prototype 002 implemented on `claude/sharp-fermi-ag525t`, awaiting user review. Not merged to `main`.** Prototype 001 is on the same branch and also unmerged.

- **User approval (reference / summary):** User message of 2026-11-17, "DragonLands — Prototype 002: The First Dragon Egg": the first dragon-collecting experience (egg discovery, incubation and hatching, dragon records, minimal save/load, tests), continuing from Prototype 001 with Godot 4.7.2 and GUT. No installer/EXE; no merge to `main` without approval.
- **Objective (one by default):** Prototype 002 — The First Dragon Egg.
- **In scope:** The Prototype 002 mechanics listed above, using the existing visual style and asset override conventions, with all Prototype 001 exploration, movement, companions, visuals and controls preserved.
- **Out of scope:** As listed above.
- **Acceptance criteria / done when:** An egg can be acquired at the nest only once (also after loading). Eggs appear in the HUD and develop with the world clock. A ready egg hatches at camp into a named dragon whose species and characteristics are shown. Dragon records persist and support growth stages and reserved genetics fields. Save/load round-trips the clock, map, discoveries, eggs and dragons without duplicates. Unit, integration and Prototype 001 regression tests pass. The egg-to-hatch sequence works in a visual run.
- **Relevant module tests:** `tests/unit/test_dragon_records.gd`, `tests/unit/test_eggs_and_hatching.gd`, plus every Prototype 001 unit test.
- **Relevant integration/manual checks:** `tests/integration/test_egg_flow.gd`, `test_save_load.gd`, `test_egg_to_hatch_scene.gd`, plus the Prototype 001 integration tests. Manual: a rendered playthrough of nest → carry → camp → hatch → name → follow → save → load → growth.

## Proposals awaiting user approval

These are Claude's choices made while implementing. They work in the prototypes but are not confirmed design decisions.

- **Time model (P001):** The clock moves only while the party travels or makes an encounter choice. The world waits while idle.
- **Exploration rule (P001):** Routes only go through explored land. Clicking into fog walks to the visible edge in that direction and keeps extending as the fog clears.
- **Numbers (P001):** Sight radius 5.5 cells; climbing the watchtower reveals 11 cells, which shows the nest. Travel time per cell: road 10 min, meadow 15, rocky hills 22, woodland 24.
- **Template art style (P001):** Storybook vector look with a warm dark outline, light from the upper left and painted terrain blending.
- **Getting the egg (P002):** A new nest choice, "Ask, through Ember, for an egg" (45 min). The wild Cinderwing gives one egg; the nest is then marked as emptied for good.
- **Incubation (P002):** 12 in-game hours. The egg develops while carried, not only at camp. At camp, "Keep the egg warm until it hatches" waits out the remaining time; a ready egg offers "Hatch the Cinderwing egg".
- **Hatchling (P002):** It joins the travelling party. Temperament and markings are picked from the egg's stored seed, so reloading cannot re-roll them. Growth stages: hatchling under 1 day old, juvenile under 4 days, adult after that. Hatchlings walk. Juveniles use the adult art at 80% size and fly.
- **Save/load (P002):** One manual save slot (F5/F9 or the HUD buttons), no autosave. The adventurer's position is also saved. Loading restarts the scene from the save.
- **Next-iteration candidates:** See the Prototype 002 report in the conversation. None of them is approved.
