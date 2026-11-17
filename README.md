# DragonLands

An original 2D fantasy dragon game built with **Godot 4.7** (GL Compatibility renderer).
Current state: **Prototype 003 — Bloodlines**, built on Prototype 002 — The First Dragon Egg and
Prototype 001 — The Living Overworld.

Lead your adventurer through the handcrafted *Elderwood Vale* with two companion dragons, Ember (a flying
Cinderwing drake) and Moss (a ground-walking Fernback wyrm). Roads, a river and lake, deep forests and a
mountain range shape the routes; fog lifts as you explore, and a wild dragon nests somewhere in the peaks.
Time flows continuously while you travel: no turns, movement points or End Turn button.

At the Emberfall Nest you can ask, through Ember, for one Cinderwing egg. The egg develops with the world clock while
you carry it (shown under the clock). At Wayfarer's Camp you can keep it warm by the fire until it hatches. Then you name
the hatchling, see its characteristics, and it walks with your party, growing into a flying juvenile after a day.

**Bloodlines:**
- **Genes:** every dragon carries three colour channels, a markings pattern and gameplay traits with tiers I–X.
  Offspring visibly blend their parents' colours and inherit markings.
- **Scouting:** Keen Sight in a travelling dragon widens how far your party scouts.
- **Breeding:** at Wayfarer's Camp, choose "Tend your dragons" to pair two grown dragons of the same species. The
  breeding screen shows the exact odds. The egg's genes are fixed when it is laid.
- **Generations:** rest at camp while hatchlings grow, keep the offspring that improved, and breed on. Every rule and
  probability is in [`docs/GENETICS.md`](docs/GENETICS.md).
- **Party:** the collection screen lists every dragon with its genes, comparison and ancestry. Up to three dragons
  travel with you; the others rest around the camp.

## Run

Open the folder in Godot 4.7.x and press **F5**, or:

```bash
godot --path .
```

No executable or installer is produced. Exports need explicit approval (see `docs/GODOT_CLAUDE_GUIDELINES.md`).

## Controls

| Input | Action |
| --- | --- |
| Left-click | Travel there. A dotted route and an estimated travel time are previewed on hover. Clicking into fog walks toward that spot as far as explored land allows, and extends the route as the fog clears. |
| Right- or middle-drag, WASD / arrow keys | Pan the camera |
| Mouse wheel | Zoom toward the cursor |
| Space / C | Camera follows the adventurer again |
| Tab, or the Dragons button | Open the dragon collection (party changes and breeding only at camp); Esc closes it |
| F5 / F9, or the Save / Load buttons | Save, or load the single save slot |

The save is a JSON file in Godot's user data folder (`user://savegame.json`). On Linux that is
`~/.local/share/godot/app_userdata/DragonLands/`; on Windows, `%APPDATA%\Godot\app_userdata\DragonLands\`.

## Tests (GUT 9.7.1, headless)

```bash
godot --headless --path . --import
```

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```

The second command runs every test in `tests/unit/` and `tests/integration/` (config: `.gutconfig.json`).
GUT is vendored unchanged in `addons/gut` (MIT licence, `addons/gut/LICENSE.md`).

## Code layout

| Module | Responsibility |
| --- | --- |
| `src/world/` | Terrain types, region grid (`RegionMap`), handcrafted region data (`regions/elderwood_vale.gd`), terrain/decor rendering |
| `src/navigation/` | Terrain-weighted A* that only routes through explored land; route preview drawing |
| `src/travel/` | Moving along a route (`PathFollower`) and the adventurer actor |
| `src/genetics/` | `Genome` (colours, markings, traits), `TraitCatalog`, `GeneticsEngine` (seeded inheritance, wild genomes, exact odds, inheritance notes), colour names |
| `src/dragons/` | Species (`SpeciesCatalog`), individual dragons (`DragonRecord`), the roster, the permanent `LineageBook`, `BreedingRules`, recolouring (`DragonLook` + shader) |
| `src/eggs/` | Collected eggs and incubation (`EggRecord`, `EggCollection`), hatching (`Hatching`) |
| `src/save/` | `SaveGame`: JSON save/load of a session (validated, replaces state, never duplicates) |
| `src/companions/` | Breadcrumb following (`FollowTrail`), companion actors that grow with their dragon, dragons resting at camp |
| `src/exploration/` | Fog of war, locations and their discovery, fog and landmark rendering |
| `src/time/` | Continuous world clock and daylight tint |
| `src/encounters/` | Encounter content (text, choices, time costs) |
| `src/overworld/` | `OverworldSession` (rules and state, no Nodes) and the entry scene that wires the views |
| `src/camera/`, `src/ui/` | Map camera; HUD, encounter panel, hatching panel, collection & breeding screen |
| `src/assets/` | `AssetResolver`, the single entry point for replaceable graphics |

## Replacing the art

Every graphic is loaded by logical name through `AssetResolver` (contract: `assets/README.md`). To override one,
put a PNG with the same logical path in `custom/graphics/` and restart the game. For example,
`custom/graphics/dragons/ember.png` replaces `assets/graphics/dragons/template_ember.png`. Missing or broken
overrides fall back to the template art with a warning. Keep each override's proportions close to the template's so it
stands on the same ground point (see `src/world/sprite_anchor.gd`).

Logical names: `terrain/{grass, forest_floor, road, water, rock}` (seamless 256 px tiles), `fog/clouds`,
`decor/{tree_oak, tree_pine, bush, rocks, mountain_a, mountain_b, bridge}`,
`landmarks/{camp, watchtower, lodge, standing_stones, dragon_nest}`, `actors/adventurer`,
`dragons/{ember, moss, cinderwing_hatchling}`, `eggs/{cinderwing, cinderwing_cracked}`.

Each dragon image has a recolour mask, `dragons/<name>_mask`, that marks body (red), belly (green) and wings/crest
(blue); black areas keep their original colours. If you replace a dragon image, replace its mask too, or the inherited
colours land in the wrong places.

All `template_` art is original and generated by `tools/art/generate_template_art.py` (numpy/Pillow textures
and hand-written SVG shapes rendered with headless Chromium through Playwright).

## Project rules

`CLAUDE.md` → `docs/GODOT_CLAUDE_GUIDELINES.md` (the authoritative rules), `docs/DESIGN_WORKFLOW.md`,
`docs/PROJECT_BRIEF.md` (decisions and the current objective), `docs/GENETICS.md` (breeding rules and odds),
`docs/BACKLOG.md` (deferred observations).
