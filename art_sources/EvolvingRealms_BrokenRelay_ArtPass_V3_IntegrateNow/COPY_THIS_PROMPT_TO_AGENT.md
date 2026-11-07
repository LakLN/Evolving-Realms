# Evolving Realms — Integrate Broken Relay V3 art pass (one bounded task)

The director has approved sample #3 (Modern Stylized Pixel Fantasy) as the visual target. A preview-safe source kit has been prepared to move this forward in-engine. Locate `project.godot` in the CURRENT repository; do not assume an old machine path. Source package folder: `BrokenRelay_ArtPass_V3_IntegrateNow` (inside the extracted ZIP).

1. Inspect `README_INTEGRATE_NOW.md` and `ARTPASS_MANIFEST.json` first. Import the two exact-size 1920x1600 images into `res://assets/game/snow/reference/` and keep the existing v10 images unchanged.
2. Add a reversible visual preview option to the existing reference composition rendering path, scoped ONLY to `layout_version=10`, `area=default`; use the two art-pass images. Do not overwrite the live manifest in-place, alter v10 layout data, collision, actor/gameplay scripts or save migrations. Preserve normal art mode by default; make preview easy to toggle.
3. Inspect roof sorting/fade and the main bridge alignment in the current renderer. If Godot is installed, produce ONE native 1100x720 image and only a minimal smoke check. If Godot is absent, report accurately and do not fabricate tests/screenshots.
4. Return paths to the preview screenshot (if any) and changed files. Do not run a full test suite, touch FE, generate new artwork, redesign geography, or start adjacent tasks.

Important: V3 is an INTEGRATION PREVIEW, not final art or an assertion of pixel-perfect registration. If preview shows major mismatch, keep normal mode unchanged, report the exact problem and stop instead of rewriting all world logic.
