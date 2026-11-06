# Evolving Realms — Snow Mountain Environment Rebuild V1

**Decision locked (2026-11-06):** Rebuild all seven Snow Mountain areas as authored 2D three-quarter-view RPG environments using approved **sample #3 — Modern Stylized Pixel Fantasy**. Old flat art/geometry is reference/prototype, **not** the final map. This is not a switch to 3D or a new isometric coordinate system.

## Immediately actionable

1. Save this package under `docs/design/snow_rebuild/` in the **current local Git project**. Existing Art Pass V3 stays opt-in as an archival visual comparison; it is **not** the base layer of the new production map.
2. Give your coding agent `04_AGENT_PROMPT_BROKEN_RELAY_REBUILD.md` **together with the rest of this package**, plus access to the project. One coherent mission: build the **new Broken Relay v11 spatial layout and correctly layered view**, without changing existing v10 saves or FE/gameplay systems.
3. The agent implements authored map composition and integration using only **verified game-ready** art available in the project. If some art is not ready, leave its item explicit in the `ASSET_GAPS` report rather than treating noisy concept-sheet cutouts as finished assets. **Do not call the rebuild visually complete until replacement art is actually complete.**
4. When agent delivers the new v11 map package and a native 1100×720 capture, return the diff/capture here. We continue production of missing modular art against **the new map specification**, not the old screenshot.

**No further screenshot of old map is necessary. No more V3-overlay patching. No full regression suite. No human playtest until the Snow Mountain region is complete.**

Read in order: `01_MASTER_REBUILD_PLAN.md` → `02_BROKEN_RELAY_SCENE_BRIEF.md` → `03_GAME_ART_AND_ACCEPTANCE.md` → `04_AGENT_PROMPT_BROKEN_RELAY_REBUILD.md`.
