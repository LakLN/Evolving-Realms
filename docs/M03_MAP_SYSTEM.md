# World Map, Minimap and Waypoints

The map UI is a read-only view over the active Run's explored fog masks, plus one
Run-local waypoint. It does not change terrain, movement, encounters, discoveries,
or region records.

## Controls

- **M** opens or closes the world map. **Esc** also closes it.
- Drag on the map to pan; use the mouse wheel to zoom (3–24 screen pixels per tile).
- Left-click to place or move the waypoint; right-click to remove it.
- **N** hides or shows the HUD minimap. It does not spend a turn.
- The minimap sits below the top HUD at the upper-right, follows the player, marks
  the player and nearby discovered landmarks, and indicates a distant waypoint at
  the edge in its direction.

Map coordinates are integer world-tile coordinates; the 40-pixel gameplay tile
rendering scale is not used for map calculations. The player marker stays visible
when panning away from the player, and the waypoint has an edge direction indicator
when it is outside the current view.

## Fog and landmark rules

Only tiles set in the active Run's saved/existing explored masks are painted.
Unexplored terrain remains transparent over the dark map background. Terrain is
sampled for those explored tile coordinates from the configured deterministic terrain
generator; drawing never follows or fills the chunk cache, asks the Region Ledger to
establish a region, or reveals new map state.

Landmarks are sourced only from discovered location mutations in that Run. The map
loads their already-persisted instance positions and uses their definition names;
it does not enumerate undiscovered generated locations.

## Performance and persistence

The map keeps one 32×32 pixel texture per explored chunk and draws all chunks through
one `Control`; it does not create a UI node per tile. A texture is rebuilt only when
that chunk's fog mask changes. Existing discovered landmarks are loaded once when a
Run is attached; new markers are handled only from discovery events. The minimap
draws the few chunk textures intersecting its local viewport.

`map_waypoint` is saved in the active Run state as either `{}` or
`{"x": integer, "y": integer}`. Editing it marks the Run unsaved and follows the
existing save/autosave/exit policy. Older six-field Run states load with an empty
waypoint; no SQLite migration is needed.

The generic marker interface is `set_markers(Array)`, with each record shaped as
`{"id": String, "position": {"x": integer, "y": integer}, "label": String,
"kind": String}`. The current gameplay source supplies discovered landmarks only.
Future systems can supply other already-known marker types without map code knowing
their content IDs.

## Limits

Waypoints are visual markers only: there is no automatic pathfinding, fast travel,
hidden-location reveal, region-name generation, or destination discovery. A player
may place a waypoint on the dark map, but doing so does not reveal the terrain there.
