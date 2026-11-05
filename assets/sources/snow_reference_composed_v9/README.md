# Broken Relay composed ground (reference layout v9)

Code-authored candidate art. `assets/game/snow/reference/reference_v9_ground.png` is
painted by `tools/art/compose_snow_area.py` from the same spatial plan used for
collision and navigation (`content/land_layouts/snow_mountain_reference.json`, whose
geometry is authored in `tools/relay_layout_v9.py`). Inputs: the Snow terrain T1
tiles (`tools/art/build_snow_terrain.py`), the candidate material atlas
(`snow_reference_materials_v1`) and the accepted S1 pine/rock props.

Presentation only: the image is keyed by layout id and version, so v8 Worlds keep the
older cell renderer and no geometry is inferred from pixels. Rebuild after any change
to the layout or the T1 tiles:

    .venv/Scripts/python.exe tools/art/build_snow_terrain.py
    .venv/Scripts/python.exe tools/art/compose_snow_area.py

Not final artistic acceptance.
