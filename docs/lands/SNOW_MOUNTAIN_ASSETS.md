# Snow Mountain asset inventory — Stage E1

Updated 2026-11-02. S1 source boards **exist** under
`assets/sources/EvolvingRealms_Batch_S1/` and runtime slices are integrated under
`assets/game/snow/`. They remain provisional, not final accepted assets.

The authoritative inventory, all 28 classified readiness blockers and extraction
limitations are in [SNOW_MOUNTAIN_STAGE_E1.md](SNOW_MOUNTAIN_STAGE_E1.md).
Exact next production prompts, file layouts, frame pivots, stable IDs and
acceptance criteria: [SNOW_MOUNTAIN_ASSET_REQUEST.md](SNOW_MOUNTAIN_ASSET_REQUEST.md).
Historical S1 integration: [SNOW_MOUNTAIN_STAGE_D.md](SNOW_MOUNTAIN_STAGE_D.md).

| Batch | Present / usable provisionally | Still needed |
|---|---|---|
| S1 / S2 terrain | snow4, ice3, taiga3, trail2, cliff2, face2, floor2, timber1; E1 fixes exact variant edge joins | frozen scree3; production terrain acceptance; cliff orientations/corners and boundary art |
| S1 / S3 props | pine1, rock1, shrub, stump, supply/barrel/crate | pine+2, rock+2, actual fallen trunk intact/searched |
| S1 / S3 shelter | lean-to, snow hut, floor/wall, fire | entrance/footprint variants and native relay accents |
| S4 wildlife | S1 front wolf idle4/walk4, sample attack3, static side/back | native hare, sentinel, complete directional wolf animations, drawn deaths |
| S5 landmarks | hut/rock/log-stack stand-ins only for bell/cairn/fallen pine | bell/frame, cairn and state variants; cleft optional future |
| S5 icons | generic inventory/slot fallbacks | six native item icons; no native skill definition needs a new icon today |
| S3 weather | code streak/rings | snow/wind textures and exposure/shelter/warning glyphs |

Rebuild only S1 with `.venv/Scripts/python.exe tools/art/build_snow_s1.py`;
verify with `.venv/Scripts/python.exe tools/art/check_snow_s1.py` and the native
snow-gameplay suite. Shared art tools are reused; Batch01/02 are not regenerated.
No package installation into shared environments is needed. Sources remain
immutable. Generated runtime PNGs/index are tracked; diagnostic contact sheets,
logs and screenshots remain under ignored `.tools/`.

Completion requires real identity-correct runtime art, full frame/variant mapping,
rendered review and human asset acceptance. Generic stand-ins, code-painted
textures and passing file-existence checks cannot close dependencies. No E1 entry
is marked complete; all unfinished dependencies remain in the manifest.
