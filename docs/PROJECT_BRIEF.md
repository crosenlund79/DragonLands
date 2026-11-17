# Project Brief — Single design and task handoff record

This file **records** decisions and approvals; it never grants them. Only the user can approve scope, in their message in the current conversation. **Undecided = ask, don't choose.**

## Game decisions (user-confirmed only)

- **Game title:** DragonLands
- **Godot version (pin minor, e.g. 4.x):** 4.7 (verified with 4.7.2 stable; GL Compatibility renderer). Confirmed by the user on 2026-11-17.
- **Premise / core player loop:** An original dragon game about collecting and selectively breeding dragons (user, Prototype 001–003 requests). The loop so far: explore, discover an egg, carry it home, incubate and hatch it (Prototype 002), then breed adults at camp and improve a bloodline over generations (Prototype 003). Exploration is not to be replaced by a management simulator. The full core loop is still undecided. Background research: `docs/dragon_adventures_research_godot.md` (reference only).
- **Perspective / art direction:** 2D fantasy overworld whose exploration feel is inspired by Heroes of Might and Magic III and Age of Wonders, with original assets and mechanics and visually coherent `template_` artwork (user). The specific template style is a Claude proposal (see Proposals below).
- **Confirmed mechanics and constraints (Prototype 001):** One handcrafted forest region with roads, mountains, rivers and landmarks. Mouse click-to-move with path preview, obstacle-aware pathfinding, camera pan and zoom. Two visually distinct companion dragons that follow the adventurer. Fog of war revealed by exploration. A few discoverable locations, including a dragon nest that opens a simple encounter panel. Continuous in-game time that advances with travel, with no turns, daily movement points or End Turn button. Minimal HUD showing time, location and travelling dragons. Do not copy copyrighted game assets.
- **Confirmed mechanics and constraints (Prototype 002):** The Emberfall Nest encounter lets the player acquire a Cinderwing egg; the same egg cannot be collected repeatedly from the same encounter. Eggs are persistent objects shown in a simple UI and develop with the in-game world clock. A ready egg hatches by returning to Wayfarer's Camp. The player names the hatchling, and its species and basic characteristics are displayed, in a small hatching moment using replaceable `template_` art. A modular, persistent dragon data model holds unique identity, species, name, age/growth state and room for future genetic information, structured for later inheritance, mutations and breeding. Ember and Moss keep working. Minimal save/load covers the world clock, explored map and discoveries, collected eggs and incubation progress, and owned dragons and their identities, without duplicating eggs or dragons on load.
- **Confirmed mechanics and constraints (Prototype 003):**
  - **Genetics:** a deterministic, seedable engine:
    - three independently inherited colour channels and inheritable markings, kept separate from gameplay traits;
    - several positive and negative traits with tiers 1–10, allowing gradual improvement through selective breeding;
    - a small, documented chance of variation;
    - parent ids, generation numbers and permanent ancestry.
  - **Probabilities:** original and transparent, never presented as Dragon Adventures odds.
  - **When genes are set:** when the egg is created, so reloading cannot re-roll them.
  - **Appearance:** offspring visibly show inherited colours and markings, through replaceable template art with recolouring (masks / layers / procedural), keeping species silhouettes and the storybook style.
  - **Breeding at Wayfarer's Camp:**
    - select two compatible adults and compare them before pairing;
    - the egg goes through the existing incubation and hatching pipeline;
    - modest in-game breeding time and cooldowns, no real-time waiting;
    - inheritance and ancestry are shown after hatching;
    - same-species only, no hybrids;
    - a fresh game must reach its first breeding through Ember and the original Cinderwing egg, with no compatibility dead ends.
  - **Collection screen:** every owned dragon (including those not travelling), with:
    - names, species, age, growth and origin;
    - colours, markings, traits and tiers;
    - parents and generation;
    - a comparison of two dragons and a simple ancestry view.
  - **Party:** owned dragons are separate from the travelling party; at most three travel, chosen at camp.
  - **Genetics in play:** at least one inherited trait gives a modest, testable exploration benefit, without changing the movement feel.
  - **Resting:** a simple camp action advances in-game time.
  - **Saves:** save/load extended while still loading Prototype 002 saves, never duplicating dragons, eggs or lineage.
- **Explicitly out of scope:** Hybrid species, combat (including dragon combat), multiplayer, economy, extensive inventory, complex NPCs, new or additional regions, base construction, large species expansion, elaborate progression, replacing the exploration game with a management simulator. No EXE or installer unless explicitly requested.
- **Existing modules / boundaries:** `src/world`, `src/navigation`, `src/travel`, `src/companions`, `src/dragons`, `src/genetics`, `src/eggs`, `src/exploration`, `src/time`, `src/encounters`, `src/save`, `src/overworld` (session rules + entry scene), `src/camera`, `src/ui`, `src/assets`. See `README.md` and `docs/GENETICS.md`. No Autoloads.
- **Testing framework (GUT or GdUnit4) and commands:** GUT 9.7.1, vendored in `addons/gut` (confirmed by the user on 2026-11-17). Run `godot --headless --path . --import`, then `godot --headless --path . -s res://addons/gut/gut_cmdln.gd`.
- **Target platforms:** Undecided (runtime asset overrides currently cover Windows/Linux only; other platforms need an explicit decision)
- **Asset override notes:** The graphics resolver is implemented (`src/assets/asset_resolver.gd`, PNG overrides in `custom/graphics/<logical path>.png`, effective after a restart). Audio overrides are not implemented yet because the game has no audio. Verification against an exported build is pending, since no export has been approved.

## Current approved objective

**Status: Prototype 003 implemented on `claude/sharp-fermi-ag525t`, awaiting user review. Not merged to `main`.** Prototypes 001 and 002 are on the same branch and also unmerged.

- **User approval (reference / summary):** User message of 2026-11-17, "DragonLands — Prototype 003: Bloodlines": the first complete, meaningful multigenerational breeding system (genetics, visible variation, breeding at camp, collection and bloodlines, a genetic benefit in exploration, persistence and testing), continuing with Godot 4.7.2 and GUT. No installer/EXE; no merge to `main` without approval.
- **Objective (one by default):** Prototype 003 — Bloodlines.
- **In scope:** The Prototype 003 mechanics listed above, keeping all Prototype 001 and 002 gameplay, the modular architecture, the asset override conventions and all previous tests.
- **Out of scope:** As listed above.
- **Acceptance criteria / done when:**
  - Starting from a fresh game, the player can breed, see inherited differences, pick good offspring and improve a bloodline over several generations.
  - Genes are fixed at egg creation and survive save/load.
  - Colours and markings are visible on the dragons.
  - The collection shows all dragons, comparison and ancestry; the party is limited to three and chosen at camp.
  - Keen Sight measurably widens scouting.
  - Prototype 002 saves still load without duplicates.
  - Deterministic, statistical, multi-generation, eligibility, party and scene tests pass, along with all earlier tests.
- **Relevant module tests:** `tests/unit/test_genetics.gd`, `test_lineage_and_rules.gd`, `test_dragon_records.gd`, `test_eggs_and_hatching.gd`, plus all earlier unit tests.
- **Relevant integration/manual checks:** `tests/integration/test_breeding_flow.gd`, `test_multigeneration.gd`, `test_save_compat.gd` (genuine Prototype 002 saves in `tests/fixtures/`), `test_bloodlines_scene.gd`, plus all earlier integration tests. Manual: a rendered five-generation playthrough (collection, comparison, odds, hatching cards, ancestry, party, camp residents, save/load).

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
- **Genetics numbers (P003):** All values in `docs/GENETICS.md`, which are my own choices:
  - tier odds: 35% → 8% chance of +1 for matched tiers; ±10% otherwise;
  - inheritance: 50% from a single carrier; 2% spontaneous;
  - variation: 5% colour shift per channel; 4% pattern change;
  - wild-born ranges as documented there.
- **Traits (P003):** The seven-trait list. Only Keen Sight (+0.15 cells per tier) and Short Sight (−0.10) are active; the party uses its best scout.
- **Breeding rules (P003):** No sexes. No penalty for pairing relatives. Pairing takes 3h, then 24h cooldown for each parent. At most 4 carried eggs.
- **Camp flow (P003):**
  - **Choices:** the camp panel gains "Tend your dragons" (opens the collection), "Rest until <next milestone>" and "Rest for a day".
  - **Panels:** closing the collection or a hatching card at camp returns to the camp panel. Tab or the HUD "Dragons" button opens the collection anywhere; the party and breeding can only be changed at camp.
  - **New hatchlings:** they join the party if a slot is free; otherwise they rest at camp, where resting dragons are drawn around the tent.
- **Appearance (P003):** Recolouring uses a luminance-preserving mask shader with procedural markings. Fernback dapples stay teal as a species feature. Colour names such as "bright gold" are descriptive.
- **Old saves (P003):** Prototype 002 dragons get fixed genomes (Ember, Moss) or wild genomes seeded by their id; old eggs use their own seed.
- **Next-iteration candidates:** See the Prototype 003 report in the conversation. None of them is approved.
