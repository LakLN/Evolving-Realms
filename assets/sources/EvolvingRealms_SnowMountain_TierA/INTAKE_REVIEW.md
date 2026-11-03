# Tier A reference intake (spoilers)

Received 2026-11-03 from the user-selected D:/Game/RPG/assets/sources directory.
README.md, manifest.json, original_generated_sheet.png and all seven reference crops
are preserved byte-for-byte; intake_provenance.json records SHA-256 checksums.
The supplied README/manifest remain unchanged. No runtime assets or mappings changed.

Visual inspection confirms these are a labeled presentation board and reference
crops, rather than native production sheets. No readiness blocker is closed.

- Bell/cairn/pine: useful silhouettes, but crops include backgrounds/scenery and
  require isolated production treatment. Actual canvases 390x350, 400x347, 715x350;
  intended runtime outputs remain 96x112, 80x80, 96x96.
- Hare: actual 1142x252, intended 672x304, 32 frames. Only partial side-view poses;
  the required down/left/right/up idle, walk, hit and death sequences are absent.
- Sentinel: actual 1141x324, intended 924x304, 44 frames. Concept silhouette needs
  comparison with the approved winter ram-beast; the image reads as an armored,
  elongated beast carrying bells. Four complete directions/states are absent.
- Items: actual 368x268, intended 96x64. The board depicts a fragment, metal lump,
  rune stone, crystal, berries and fur; this does not provide the six specified
  resin/ration/scrap/clasp/shard/mantle identities.
- Scree: actual 371x238, intended 120x40. Perspective-like raised snow/stone blocks
  and scenic detail are not evidence of flat, seamless 40px walkable ground.
- RGBA alone does not establish transparency: minimum alpha in bell/cairn/scree/
  sentinel/hare/items is respectively 19/15/20/11/42/118, with maximum 252.
  These crops have no fully transparent background pixels. Pine has alpha zero
  somewhere, but still includes visible presentation scenery and backing.

Full source remains 1536x1024. Labels stating target dimensions are not actual
sprite dimensions. No frames, directions or item semantics will be invented by
renaming/resizing these images. No image generation or background editing performed.

Next: obtain the remainder of the user's integration/playtest instructions (their
request stopped at "They may"), then choose allowed preparation work against the
existing Tier A handoff. Production art, director style/silhouette acceptance,
animation QA and a human playtest remain outstanding.
