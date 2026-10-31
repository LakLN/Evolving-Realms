# Evolving Realms — Original Art Batch 01

Five original AI-generated fantasy pixel-art source sheets for the first forest vertical slice.

## Contents

- `environment/forest_grass_beach_water_tilesheet.png`: grass, forest floor, paths, beach, water, rocks, bushes and trees.
- `characters/player_adventurer_spritesheet.png`: adventurer poses in four directions.
- `creatures/gray_wolf_spritesheet.png`: gray wolf poses and attacks.
- `props/chests_resources_items_sheet.png`: chests, gathering resources, spring and loot props.
- `landmarks/discoveries_ruins_shrines_sheet.png`: ruins, shrines, leyline, poison vent and monolith.

## Integration notes for Claude/Godot

These are **source art sheets**, not verified production-ready tilesets/spritesheets. The AI-generated frames are not guaranteed to have identical dimensions or precise grid alignment, and ground tiles are **not verified seamlessly tileable**. Inspect and crop individual sprites, normalize scale, feet/pivot anchors and transparency, and confirm animation consistency rather than treating the sheets as uniform frame grids. Do not change existing 32x32 world coordinate logic, collision or saves to fit artwork. Keep fallback where needed and preserve originals.

Art direction: colorful mystical fantasy pixel art, top-down / three-quarter top-down, warm greens and earth tones, turquoise water and blue magical glow.

Generated for the user's Evolving Realms project.
