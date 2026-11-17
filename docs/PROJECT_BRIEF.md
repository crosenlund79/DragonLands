# Project Brief — Single design and task handoff record

This file **records** decisions and approvals; it never grants them. Only the user can approve scope, in their message in the current conversation. **Undecided = ask, don't choose.**

## Game decisions (user-confirmed only)

- **Game title:** DragonLands
- **Godot version (pin minor, e.g. 4.x):** 4.7 (verified with 4.7.2 stable; GL Compatibility renderer). Confirmed by the user on 2026-11-17.
- **Premise / core player loop:** An original dragon game; future breeding, genetics, encounters and exploration systems are intended (user, Prototype 001 request). The full core loop is still undecided. Background research: `docs/dragon_adventures_research_godot.md` (reference only).
- **Perspective / art direction:** 2D fantasy overworld whose exploration feel is inspired by Heroes of Might and Magic III and Age of Wonders, with original assets and mechanics and visually coherent `template_` artwork (user). The specific template style is a Claude proposal (see Proposals below).
- **Confirmed mechanics and constraints (Prototype 001):** One handcrafted forest region with roads, mountains, rivers and landmarks. Mouse click-to-move with path preview, obstacle-aware pathfinding, camera pan and zoom. Two visually distinct companion dragons that follow the adventurer. Fog of war revealed by exploration. A few discoverable locations, including a dragon nest that opens a simple encounter panel. Continuous in-game time that advances with travel, with no turns, daily movement points or End Turn button. Minimal HUD showing time, location and travelling dragons. Do not copy copyrighted game assets.
- **Explicitly out of scope:** Breeding mechanics, combat, inventories, complex NPCs, multiple regions, base construction, elaborate progression. No EXE or installer unless explicitly requested.
- **Existing modules / boundaries:** `src/world`, `src/navigation`, `src/travel`, `src/companions`, `src/exploration`, `src/time`, `src/encounters`, `src/overworld` (session rules + entry scene), `src/camera`, `src/ui`, `src/assets`. See `README.md`. No Autoloads.
- **Testing framework (GUT or GdUnit4) and commands:** GUT 9.7.1, vendored in `addons/gut` (confirmed by the user on 2026-11-17). Run `godot --headless --path . --import`, then `godot --headless --path . -s res://addons/gut/gut_cmdln.gd`.
- **Target platforms:** Undecided (runtime asset overrides currently cover Windows/Linux only; other platforms need an explicit decision)
- **Asset override notes:** The graphics resolver is implemented (`src/assets/asset_resolver.gd`, PNG overrides in `custom/graphics/<logical path>.png`, effective after a restart). Audio overrides are not implemented yet because the game has no audio. Verification against an exported build is pending, since no export has been approved.

## Current approved objective

**Status: Implemented on `claude/sharp-fermi-ag525t`, awaiting user review. Not merged to `main`.**

- **User approval (reference / summary):** User message of 2026-11-17, "DragonLands — Prototype 001: The Living Overworld": build, test and report on a small playable 2D overworld prototype, with changes kept isolated from `main` until approved.
- **Objective (one by default):** Prototype 001 — The Living Overworld.
- **In scope:** All items listed under the confirmed mechanics above, plus original `template_` art following the replaceable-art convention.
- **Out of scope:** As listed above.
- **Acceptance criteria / done when:** The region is playable. Click-to-move shows a path preview and avoids obstacles. The camera pans and zooms. Both dragons follow naturally. Fog lifts with exploration. Locations are discoverable, and the nest opens an encounter panel. The clock advances with travel only. The HUD shows time, location and dragons. Module and integration tests pass.
- **Relevant module tests:** `tests/unit/*` (asset resolver, region map, pathfinder, path follower, follow trail, fog, clock, locations/encounters, party, view helpers).
- **Relevant integration/manual checks:** `tests/integration/*` (region data, session contracts, headless scene smoke test). Manual: movement and companion feel, visual readability at several zoom levels and times of day.

## Proposals awaiting user approval

These are Claude's choices made while implementing Prototype 001. They work in the prototype but are not confirmed design decisions.

- **Time model:** The clock moves only while the party travels or makes an encounter choice. The world waits while idle.
- **Exploration rule:** Routes only go through explored land. Clicking into fog walks to the visible edge in that direction and keeps extending as the fog clears.
- **Numbers:** Sight radius 5.5 cells; climbing the watchtower reveals 11 cells, which shows the nest. Travel time per cell: road 10 min, meadow 15, rocky hills 22, woodland 24.
- **Template art style:** Storybook vector look with a warm dark outline, light from the upper left and painted terrain blending.
- **Next-iteration candidates:** See the Prototype 001 report in the conversation. None of them is approved.
