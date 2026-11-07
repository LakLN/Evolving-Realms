# Evolving Realms — replace Broken Relay v11 building art (bounded change)

Source: `art_sources/EvolvingRealms_BrokenRelay_V11_ArtComponents_V4.zip`.

Goal: Put the **paired facade and roof** into the already-working Broken Relay v11, not start another generic artbase experiment. Source files:

- `01_architecture_pair/outpost_facade_480x240.png`
- `01_architecture_pair/outpost_roof_only_480x240.png`

They are separate 480×240 RGBA images with **identical local positioning** relative to v11's shelter area: grid origin `[18,11]` (pixel origin `[720,440]`), with common foot/pivot `[240,240]`. Existing fade **only** affects the roof. The facade and roof must not both draw opaque roof/wall silhouettes from the old renderer.

Tasks:
1. Read README and COMPONENT_MANIFEST, then inspect current `reference_view.gd` and v11 roof/facade layers. Integrate the two PNGs in the existing layer model in a **bounded opt-in art mode**; keep v11 default and previous saves intact. Do not add new collision or alter gameplay.
2. Make sure the old roof and old facade are **not drawn under the new pair** in this mode, preventing double walls and repeated rooftops. Keep the established walkable floor and actual gameplay objects/content IDs.
3. Fade only `outpost_roof_only_480x240.png`; the door, windows and facade must remain at alpha 1.0. Preserve actor sorting and the roof fade behavior.
4. Use 40px logical grid and Godot 4.7.2. One short scene capture with roof fully visible and one with fade at the entrance is sufficient; **no full suite, no long playthrough, no auto-generated art**.
5. Report if facade/door positions don't align with actual v11 shelter geometry. Do **not** force collision to match art if they differ.

**Do not import** 14 material tiles as a complete terrain atlas, and don't scatter the 16 cliff modules automatically. Those are still visual-review candidates and must not silently become game-ready environment.

Deliver: exact toggle command, files modified, two screenshots or a concrete failure/blocker. Preserve the personal Run 01, v10, Windcut and current opt-in Artbase.
