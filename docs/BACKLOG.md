# Deferred observations — not approved tasks

Record only observations found during approved work. An item here is **not** permission to implement or add to the current objective.

| Date | Observation | Context |
| --- | --- | --- |
| 2026-11-17 | Asset overrides have not been verified against an exported Windows/Linux build, because no export was approved. | Prototype 001; `assets/README.md` requires that check when an export is requested |
| 2026-11-17 | The resolver handles graphics only (`get_texture`). `get_audio` and OGG overrides still need adding when the first sound is introduced. | Prototype 001 has no audio |
| 2026-11-17 | Rendering was checked only with Mesa llvmpipe (software OpenGL) under Xvfb, not on a real GPU, Windows or a high-DPI display. | Prototype 001 screenshots |
| 2026-11-17 | Location banners and the route-time label are world-space text, so they become small at the minimum zoom (about 0.52). | Prototype 001 visual check |
| 2026-11-17 | Companions follow the trail but don't avoid each other. When the party turns sharply, Ember (flying) can briefly overlap Moss. | Prototype 001 companion following |
| 2026-11-17 | The template-art generator (`tools/art/`) needs node, Playwright and Chromium in addition to Python with numpy and Pillow. | Reproducing `template_` art |
| 2026-11-17 | ~~There is no save/load. A session always restarts at Day 1, 08:00 at the camp.~~ Resolved by Prototype 002 (manual save/load). | Prototype 001 |
| 2026-11-17 | The nest sprite still shows three eggs after one has been taken. Only the encounter text changes. | Prototype 002 egg discovery |
| 2026-11-17 | There is no autosave: quitting without saving (F5) loses progress. There is a single save slot, and the save format only checks its version number, with no migration between versions. | Prototype 002 save/load |
| 2026-11-17 | Saves are JSON, so numbers inside the reserved `DragonRecord.genome` load back as floats. Future genetics data should not rely on integer types. | Prototype 002 dragon records |
| 2026-11-17 | Juvenile Cinderwings reuse the adult (Ember) template at 80% size; there is no dedicated juvenile art. The Fernback species data has no egg source or egg art yet. | Prototype 002 growth stages |
| 2026-11-17 | The hover route-time label is drawn under trees and landmarks, so it can be partly hidden in forests. | Seen during Prototype 002 screenshots; behaviour from Prototype 001 |
| 2026-11-17 | GUT 9.7.1 skips a test script that fails to parse: it logs `SCRIPT ERROR` but the summary still says "All tests passed". Always compare the "Scripts" count with the number of test files. | Prototype 003 testing |
| 2026-11-17 | A bloodline bred mostly from one ancestor (e.g. Ember) looks uniform. The only wild source of new colours is the single nest egg, so colour variety relies on the 5% colour shifts. | Prototype 003 playthrough |
| 2026-11-17 | Dragons resting at camp crowd around the tent and can cover the camp label; adults show spread wings because there is no resting-pose art. Only the first 8 resting dragons are drawn. | Prototype 003 camp residents |
| 2026-11-17 | Moss is the only Fernback, so Fernbacks cannot breed. There is no way to release dragons, and no inbreeding effect. | Prototype 003 breeding |
| 2026-11-17 | Breeding seeds include the clock time, so two playthroughs with different travel produce different offspring. Results are deterministic for a given game state, not across playthroughs. | Prototype 003 genetics |
| 2026-11-17 | Only Keen Sight and Short Sight affect play. The other five traits are inherited and shown but marked "future". | Prototype 003 traits |
