extends RefCounted
## Minimal derived region facts (Milestone 02 H): biome shares and a danger tier per
## chunk. Derived from World seed and terrain v1 with separate hash streams, never
## stored and never changing geography. Future world generation can extend this.
const Structured = preload("res://src/world/structured_world.gd")
const Regions = preload("res://src/world/structured_regions.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const Loot = preload("res://src/core/loot_table.gd")
const DANGER_SCALE := 4 # Chunks per danger region side (128x128 tiles).
const DANGER_BANDS := [35, 70, 90, 100] # Cumulative percent for tiers 0..3.
const SURFACES := ["forest", "beach", "meadow", "water"]

static func danger(terrain: RefCounted, chunk: Vector2i) -> int:
	if terrain.has_method("chunk_danger"): # Atlas lands: the designed region's danger.
		return terrain.chunk_danger(chunk)
	var region := Vector2i(floori(float(chunk.x) / DANGER_SCALE), floori(float(chunk.y) / DANGER_SCALE))
	var roll: int = terrain.coordinate_hash(region.x, region.y, Loot.number("region-v1/danger")) % 100
	for tier in DANGER_BANDS.size():
		if roll < DANGER_BANDS[tier]:
			return tier
	return DANGER_BANDS.size() - 1

static func biome_shares(bytes: PackedByteArray) -> Dictionary:
	## Percent of the chunk per surface; trees count as forest, rocks as their ground.
	var counts := {"forest": 0, "beach": 0, "meadow": 0, "water": 0}
	for value in bytes:
		match value:
			Terrain.FOREST, Terrain.TREE: counts.forest += 1
			Terrain.BEACH: counts.beach += 1
			Terrain.MEADOW: counts.meadow += 1
			Terrain.WATER: counts.water += 1
			_:
				# Atlas surfaces (snowfield, taiga, ashland...) only appear when present.
				var habitat: String = Surfaces.HABITAT_OF.get(value, "") # Rocks, ice, lava: none.
				if value == Surfaces.PINE: habitat = "taiga"
				elif value == Surfaces.BASALT: habitat = "ashland"
				if not habitat.is_empty(): counts[habitat] = int(counts.get(habitat, 0)) + 1
	var shares := {}
	for surface in counts:
		if surface in SURFACES or int(counts[surface]) > 0:
			shares[surface] = int(counts[surface] * 100 / maxi(1, bytes.size()))
	return shares

static func describe(layer: RefCounted, chunk: Vector2i) -> Dictionary:
	## Context for authoring: what this region is and what already lives there. Read
	## only: describing never establishes the chunk.
	var bytes: PackedByteArray = layer.terrain.generate_chunk(chunk)
	var revision: int = layer.ledger.established(chunk) if layer.ledger != null else -1
	var effective: int = revision if revision >= 0 else (layer.ledger.revision if layer.ledger != null else layer.encounters.revision)
	var present := {}
	for placement in layer.preview_chunk(chunk, effective, bytes):
		present["%s@%d" % [placement.content_id, int(placement.version)]] = true
	var shares := biome_shares(bytes)
	var valid: Array = []
	for definition in layer.habitats():
		if definition.payload.movement.biomes.any(func(b: String) -> bool: return shares.get(b, 0) > 0):
			valid.append("%s@%d" % [definition.content_id, int(definition.version)])
	valid.sort()
	var names: Array = present.keys()
	names.sort()
	var description := {"chunk": {"x": chunk.x, "y": chunk.y}, "danger": danger(layer.terrain, chunk), "biome_shares": shares,
		"established": revision >= 0, "encounter_revision": effective, "world_revision": layer.ledger.revision if layer.ledger != null else layer.encounters.revision,
		"present_creatures": names, "valid_creatures": valid,
		"capabilities": ["definition.encounter"] + layer.encounters.condition_names().map(func(c: String) -> String: return "encounter.condition." + c)}
	if Structured.enabled(layer.world): description["structured_region"] = Regions.new(layer.terrain).plan(Regions.cell_of(chunk * 32))
	return description
