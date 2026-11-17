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
| 2026-11-17 | There is no save/load. A session always restarts at Day 1, 08:00 at the camp. | Prototype 001 |
