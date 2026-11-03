extends RefCounted
## Versioned World Core layout over frozen terrain v1. No Run state or I/O.
const Terrain = preload("res://src/world/terrain_v1.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
const SIZE := 128
const CACHE_LIMIT := 16
const SITE_NAMES := {"forest_supply": "Healing grove", "meadow_supply": "Pilgrim spring", "beach_supply": "Sheltered tidepool", "forest_relic": "Hunter watchtower", "meadow_relic": "Standing-stone vault", "beach_relic": "Wreck shrine"}
var terrain: RefCounted
var _plans := {}
var _profiles := {}

func _init(generator: RefCounted) -> void:
	terrain = generator

static func cell_of(tile: Vector2i) -> Vector2i:
	return Vector2i(floori(float(tile.x) / SIZE), floori(float(tile.y) / SIZE))

func describe(cell: Vector2i) -> Dictionary:
	if _profiles.has(cell): return _profiles[cell].duplicate(true)
	var shares := {"forest": 0, "beach": 0, "meadow": 0, "ocean": 0}
	for y in 4:
		for x in 4:
			shares[terrain.biome_at(cell * SIZE + Vector2i(16 + x * 32, 16 + y * 32))] += 1
	var biome := "forest"
	for key in ["beach", "meadow"]:
		if shares[key] > shares[biome]: biome = key
	if shares[biome] == 0: biome = "ocean"
	var roll: int = terrain.coordinate_hash(cell.x, cell.y, Loot.number("region-v1/danger")) % 100
	var danger := 0 if roll < 35 else (1 if roll < 70 else (2 if roll < 90 else 3))
	var themes := {"forest": ["Herbal woodland", "Hunting wood"], "beach": ["Tidal coast", "Wreck coast"], "meadow": ["Spring pasture", "Standing-stone moor"], "ocean": ["Open sea", "Open sea"]}
	var variant := 1 if danger >= 2 else 0
	var prefixes := ["Silver", "Ashen", "Amber", "Mist", "Elder", "Moon", "Thorn", "Dawn"]
	var name: String = prefixes[terrain.coordinate_hash(cell.x, cell.y, 811) % prefixes.size()] + " " + themes[biome][variant]
	var profile := {"structured_world_version": 1, "region_id": "realm:sw1/%d/%d" % [cell.x, cell.y], "cell": {"x": cell.x, "y": cell.y}, "bounds": {"x": cell.x * SIZE, "y": cell.y * SIZE, "size": SIZE},
		"name": name, "biome": biome, "theme": themes[biome][variant], "danger": danger, "surface_samples": shares,
		"resource_percent": 200 if variant == 0 else 60, "opportunity": "supplies and recovery" if variant == 0 else "relics and dangerous wildlife"}
	if _profiles.size() >= CACHE_LIMIT: _profiles.erase(_profiles.keys()[0])
	_profiles[cell] = profile
	return profile.duplicate(true)

func plan(cell: Vector2i) -> Dictionary:
	if _plans.has(cell): return _plans[cell].duplicate(true)
	var profile := describe(cell)
	var points: Array = []
	# Inset anchors keep the whole connected cluster in its owning region.
	for attempt in 24:
		var anchor := cell * SIZE + Vector2i(32 + terrain.coordinate_hash(cell.x, cell.y, 820 + attempt * 2) % 64, 32 + terrain.coordinate_hash(cell.x, cell.y, 821 + attempt * 2) % 64)
		if attempt < 16 and terrain.biome_at(anchor) != profile.biome: continue
		if not Spawn.accessible(terrain, anchor): continue
		var paths := _paths(anchor)
		if paths.size() < 256: continue
		var far := anchor
		var far_order := 2147483647
		for tile in paths:
			var distance: int = maxi(absi(tile.x - anchor.x), absi(tile.y - anchor.y))
			if distance < 24: continue
			var order: int = terrain.coordinate_hash(tile.x, tile.y, 864)
			if order < far_order:
				far = tile
				far_order = order
		if far == anchor: continue
		var side := anchor
		var side_order := 2147483647
		for tile in paths:
			var separation: int = mini(absi(tile.x - far.x) + absi(tile.y - far.y), absi(tile.x - anchor.x) + absi(tile.y - anchor.y))
			if separation < 18: continue
			var order: int = terrain.coordinate_hash(tile.x, tile.y, 865)
			if order < side_order:
				side = tile
				side_order = order
		if side == anchor: continue
		for role in ["waystone", "supply", "relic"]:
			var tile: Vector2i = anchor if role == "waystone" else (side if role == "supply" else far)
			var definition_biome: String = terrain.biome_at(tile)
			var content: String = "m03:place/waystone" if role == "waystone" else "m03:place/%s_%s" % [definition_biome, role]
			points.append({"instance_id": "loc:sw1/%d/%d/%s" % [cell.x, cell.y, role], "content_id": content, "version": 1, "position": {"x": tile.x, "y": tile.y}, "origin": "procedural",
				"metadata": {"structured_world_version": 1, "region_id": profile.region_id, "region_name": profile.name, "role": role, "path_from_waystone": paths[tile], "title": "%s - %s" % [profile.name, SITE_NAMES.get("%s_%s" % [definition_biome, role], "Waystone")], "reason": "read bearings" if role == "waystone" else ("supplies for the journey" if role == "supply" else "coins and lore; collapsed ruins cost 3 HP")}})
		break
	for point in points:
		var leads: Array = []
		for other in points:
			if other.instance_id != point.instance_id: leads.append({"instance_id": other.instance_id, "position": other.position.duplicate(), "metadata": {"title": other.metadata.title}, "region_id": profile.region_id, "role": other.metadata.role, "reason": other.metadata.reason})
		point.metadata["leads"] = leads
	if not points.is_empty(): points[2].metadata["frontiers"] = frontiers(cell)
	profile["destinations"] = points
	if _plans.size() >= CACHE_LIMIT: _plans.erase(_plans.keys()[0])
	_plans[cell] = profile
	return profile.duplicate(true)

func _paths(start: Vector2i) -> Dictionary:
	var cell := cell_of(start)
	var radius: int = 24 + terrain.coordinate_hash(cell.x, cell.y, 862) % 9
	var seen := {start: true}
	var paths := {start: 0}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		for direction in Spawn.DIRECTIONS:
			var next: Vector2i = tile + direction
			if seen.has(next) or maxi(absi(next.x - start.x), absi(next.y - start.y)) > radius: continue
			seen[next] = true
			if not terrain.walkable(next): continue
			paths[next] = int(paths[tile]) + 1
			queue.append(next)
	return paths

func placements(chunk: Vector2i) -> Array:
	var result: Array = []
	for point in plan(cell_of(chunk * 32)).destinations:
		if Terrain.chunk_of(Vector2i(int(point.position.x), int(point.position.y))) == chunk: result.append(point)
	return result

func spawn(run_seed: int, requested: String) -> Dictionary:
	var selected := Spawn.select(terrain, run_seed, requested, Spawn.RUN_SELECTION_VERSION)
	if selected.is_empty(): return {}
	var start := cell_of(Vector2i(int(selected.position.x), int(selected.position.y)))
	for attempt in 64:
		var cell := start if attempt == 0 else Vector2i(terrain.coordinate_hash(run_seed, attempt, 840) % 32 - 16, terrain.coordinate_hash(run_seed, attempt, 841) % 32 - 16)
		var points: Array = plan(cell).destinations
		if points.is_empty(): continue
		var tile := Vector2i(int(points[0].position.x), int(points[0].position.y))
		if terrain.biome_at(tile) != selected.biome: continue
		return {"position": points[0].position.duplicate(), "biome": selected.biome, "selection_version": 3, "structured_world_version": 1}
	return {}

func frontiers(cell: Vector2i) -> Array:
	var result: Array = []
	var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var names := ["north", "east", "south", "west"]
	var first: int = terrain.coordinate_hash(cell.x, cell.y, 851) % 4
	for offset in 2:
		var side: int = (first + offset) % 4
		var neighbor: Vector2i = cell + directions[side]
		if not Terrain.in_bounds(neighbor * SIZE + Vector2i(64, 64)): continue
		var region := describe(neighbor)
		result.append({"region_id": region.region_id, "name": region.name, "direction": names[side], "bounds": region.bounds,
			"danger": region.danger, "opportunity": region.opportunity, "knowledge": "unsurveyed_region", "path_confirmed": false})
	return result
