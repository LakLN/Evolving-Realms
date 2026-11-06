extends "res://src/world/terrain_v1.gd"
## Atlas terrain v1 (Milestone 04; land plans pin terrain_version 1). A pure function of the
## World seed and the stored land plans: every land owns one SLOT x SLOT square, its
## coast/ridge rim, region cells, roads and gate corridors come from its own record, and
## unclaimed slots are the Veil (uncharted mist, impassable). Adding a land only turns
## Veil into land; established tiles never change. Same interface as terrain_v1.gd.
## Low-frequency fields (coast, warp, pools, patches, ridges) are sampled every GRID tiles
## of the chunk and bilinearly interpolated: part of the v1 algorithm, not a cache.
## Extends terrain v1 only for its typed interface and integer noise/hash helpers; the
## frozen v1 generator itself (ground_at/tile_at of the parent) is never used here.
## Milestone 05: plans with terrain_version 2 (authored layouts such as Snow Mountain)
## are materialized by terrain_layout.gd; every terrain_version 1 plan keeps this file's
## v1 algorithm unchanged, so both versions coexist in one World.
const TerrainV1 = preload("res://src/world/terrain_v1.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const Layout = preload("res://src/world/terrain_layout.gd")
const Spatial = preload("res://src/world/spatial_layout.gd")
const TERRAIN_VERSION := 1
const LAYOUT_TERRAIN_VERSION := 2
const TERRAIN_VERSIONS := [TERRAIN_VERSION, LAYOUT_TERRAIN_VERSION, 3]
const SLOT := 512 # Multiple of CHUNK_SIZE: a chunk always belongs to exactly one slot.
const CACHE_LIMIT := 128
const WARP := 28.0
const GRID := 4
const SAMPLES := CHUNK_SIZE / GRID + 1
const RIM := 255 # Zone of tiles outside the land mass.
var _lands: Dictionary = {} # Vector2i slot -> compiled land
var _plans: Dictionary = {} # land_id -> stored plan
var _sites: Dictionary = {} # Vector2i chunk -> [site instances]
var _spatial_cells: Dictionary = {} # Derived once from the immutable authored patch.
var _spatial_seams: Dictionary = {} # Patch border ring (presentation feathering only).
var _patch_of: Dictionary = {} # tile -> the composed area (spatial plan) containing it.
const SEAM := 3
var _creature_homes: Dictionary = {} # Authored plan-v2 layer; v1 homes stay separate.
var _bytes: Dictionary = {} # chunk -> tiles
var _zones: Dictionary = {} # chunk -> region index per tile (RIM outside the mass)
var _order: Array = []
var _zone_chunk := Vector2i(2147483647, 0) # Layout ecology: zones of the last chunk asked.
var _zone_bytes := PackedByteArray()

func configure_atlas(seed_value: int, plans: Array) -> bool:
	if seed_value < -2147483648 or seed_value > 2147483647:
		last_error = "Unsupported world seed"
		return false
	world_seed = seed_value
	_lands.clear()
	_plans.clear()
	_sites.clear()
	_creature_homes.clear()
	_spatial_cells.clear()
	_spatial_seams.clear()
	_patch_of.clear()
	_bytes.clear()
	_zones.clear()
	_order.clear()
	for plan in plans:
		for patch in patches(plan):
			if not Spatial.validate(patch).is_empty():
				last_error = Spatial.validate(patch)
				return false
		if not int(plan.get("terrain_version", 0)) in TERRAIN_VERSIONS or (int(plan.terrain_version) >= LAYOUT_TERRAIN_VERSION) != plan.has("geography") or (int(plan.terrain_version) == 3 and (not plan.has("spatial") or int(plan.spatial.get("version", 0)) != 1)):
			last_error = "Unsupported atlas terrain version in %s; World was not changed" % str(plan.get("land_id", "?"))
			return false
		var slot := Vector2i(int(plan.slot.x), int(plan.slot.y))
		if _lands.has(slot):
			last_error = "Two lands claim slot %s" % str(slot)
			return false
		_lands[slot] = Layout.compile(plan, compile_kind) if int(plan.terrain_version) >= LAYOUT_TERRAIN_VERSION else _compile(plan)
		_plans[plan.land_id] = plan
		for patch in patches(plan):
			var so := Vector2i(int(patch.origin.x), int(patch.origin.y))
			for sy in int(patch.size.y):
				for sx in int(patch.size.x):
					var tile := so + Vector2i(sx, sy)
					if _spatial_cells.has(tile):
						last_error = "Composed areas overlap at %s" % str(tile)
						return false
					_spatial_cells[tile] = Spatial.cell(patch, tile)
					_patch_of[tile] = patch
					if mini(mini(sx, sy), mini(int(patch.size.x) - 1 - sx, int(patch.size.y) - 1 - sy)) < SEAM:
						_spatial_seams[tile] = true
		for site in plan.get("sites", []):
			var chunk := TerrainV1.chunk_of(Vector2i(int(site.position.x), int(site.position.y)))
			if not _sites.has(chunk): _sites[chunk] = []
			_sites[chunk].append(site)
		for home in plan.get("creature_homes", []):
			var chunk := TerrainV1.chunk_of(Vector2i(int(home.position.x), int(home.position.y)))
			if not _creature_homes.has(chunk): _creature_homes[chunk] = []
			_creature_homes[chunk].append(home)
	last_error = ""
	return true

static func patches(plan: Dictionary) -> Array:
	## Composed areas of a plan: the reference patch, then any further composed areas.
	return ([plan.spatial] if plan.has("spatial") else []) + plan.get("spatial_areas", [])

func creature_homes(chunk: Vector2i) -> Array:
	return _creature_homes.get(chunk, []).duplicate(true)

func spatial_cell(tile: Vector2i) -> Dictionary:
	return _spatial_cells.get(tile, {})

func elevation(tile: Vector2i) -> int:
	return int(spatial_cell(tile).get("height", 0))

func procedural_allowed(tile: Vector2i) -> bool:
	return spatial_cell(tile).is_empty()

func spatial_seam_kind(tile: Vector2i) -> String:
	## Presentation: the outer ring of a composed patch is underpainted with the
	## region's own ground so the composed art can feather into the land around it.
	if not _spatial_seams.has(tile): return ""
	var surface := int(spatial_cell(tile).surface)
	return Surfaces.ART_KIND.get(surface if surface in [Surfaces.TRAIL, Surfaces.CLIFF] else _ground(tile), "")

func can_step(from: Vector2i, to: Vector2i) -> bool:
	if not walkable(from) or not walkable(to): return false
	var delta := to - from
	if absi(delta.x) > 1 or absi(delta.y) > 1:
		if delta.x != 0 and delta.y != 0: return false
		var step := Vector2i(signi(delta.x), signi(delta.y))
		var at := from
		while at != to:
			if not can_step(at, at + step): return false
			at += step
		return true
	if delta.x != 0 and delta.y != 0:
		var x := from + Vector2i(delta.x, 0)
		var y := from + Vector2i(0, delta.y)
		return can_step(from, x) and can_step(x, to) and can_step(from, y) and can_step(y, to)
	if elevation(from) == elevation(to): return true
	return _patch_of.has(from) and Spatial.connector(_patch_of[from], from, to)

func can_reach(from: Vector2i, to: Vector2i) -> bool:
	if elevation(from) == elevation(to): return true
	if absi(from.x-to.x) + absi(from.y-to.y) != 1: return false
	return _patch_of.has(from) and Spatial.connector(_patch_of[from], from, to, false)

func configure(_seed_value: int, _generation_version: int) -> bool:
	last_error = "Atlas terrain needs its land plans (configure_atlas)"
	return false

static func slot_of(tile: Vector2i) -> Vector2i:
	return Vector2i(floori(float(tile.x) / SLOT), floori(float(tile.y) / SLOT))

static func slot_origin(slot: Vector2i) -> Vector2i:
	return slot * SLOT

func plans() -> Array:
	return _plans.values()

func land_at(tile: Vector2i) -> Dictionary:
	var land: Variant = _lands.get(slot_of(tile))
	return land.plan if land != null else {}

func region_at(tile: Vector2i) -> Dictionary:
	## The region a tile belongs to; rim tiles (sea/ridge) count to the nearest region.
	var land: Variant = _lands.get(slot_of(tile))
	if land == null:
		return {}
	var zone := _zone(tile)
	if zone == RIM:
		zone = _nearest(land, Vector2(tile), range(land.seeds.size()))
	return land.plan.regions[zone]

func chunk_danger(chunk: Vector2i) -> int:
	var region := region_at(chunk * CHUNK_SIZE + Vector2i(16, 16))
	return int(region.get("danger", 0))

func ecology_hosts(value: int, point: Vector2i, content_id: String) -> bool:
	var land: Variant = _lands.get(slot_of(point))
	if land == null:
		return false
	var habitat: String = Surfaces.HABITAT_OF.get(value, "")
	if not land.ecology.get(habitat, {}).has(content_id):
		return false
	if land.has("version"): # Layout lands: each area lists its own adapted ecology.
		var chunk := TerrainV1.chunk_of(point)
		if chunk != _zone_chunk or not _zones.has(chunk):
			_chunk_bytes(chunk)
			_zone_chunk = chunk
			_zone_bytes = _zones[chunk]
		var local := TerrainV1.local_of(point)
		var zone: int = _zone_bytes[local.y * CHUNK_SIZE + local.x]
		return zone != RIM and land.kinds[zone].ecology.get(habitat, {}).has(content_id)
	return true

func strict_ecology(point: Vector2i) -> bool:
	## N4 authored areas whitelist their procedural identities. This prevents generic
	## beach/meadow shells, chests and creatures leaking into the lower-mountain basin.
	var land: Variant = _lands.get(slot_of(point))
	return land != null and land.has("plan") and land.plan.get("layout", {}).get("id", "") == "landpkg:snow_mountain/long_thaw_n3" and int(land.plan.get("layout", {}).get("version", 0)) >= 2

func placements(chunk: Vector2i) -> Array:
	## Atlas sites (waystones, landmarks) pinned by land plans, as location instances.
	var result: Array = []
	for site in _sites.get(chunk, []):
		result.append(site.duplicate(true))
	return result

func tile_at(tile: Vector2i) -> int:
	var local := TerrainV1.local_of(tile)
	return _chunk_bytes(TerrainV1.chunk_of(tile))[local.y * CHUNK_SIZE + local.x]

func ground_at(tile: Vector2i) -> int:
	return _ground(tile)

func walkable(tile: Vector2i) -> bool:
	return Surfaces.walkable(tile_at(tile))

func opaque(tile: Vector2i) -> bool:
	return Surfaces.opaque(tile_at(tile))

func biome_at(tile: Vector2i) -> String:
	var value := tile_at(tile)
	if Surfaces.opaque(value) and not value in Surfaces.WALLS:
		return Surfaces.NAME_OF[_ground(tile)]
	return Surfaces.NAME_OF.get(value, "veil")

func art_kind_at(tile: Vector2i) -> String:
	## Presentation: blockers draw on the ground of their region.
	var value := tile_at(tile)
	return Surfaces.ART_KIND[_ground(tile)] if Surfaces.opaque(value) and not value in Surfaces.WALLS else Surfaces.ART_KIND.get(value, "veil")

func warm(chunk: Vector2i) -> bool:
	## Presentation idle work: build a chunk into the cache; false if it already was.
	if _bytes.has(chunk): return false
	_chunk_bytes(chunk)
	return true

func generate_chunk(chunk: Vector2i) -> PackedByteArray:
	return _chunk_bytes(chunk).duplicate()

func chunk_zones(chunk: Vector2i) -> PackedByteArray:
	## Region index per tile of a chunk (RIM outside the land mass); surveys and tests.
	_chunk_bytes(chunk)
	return _zones[chunk].duplicate()

func _zone(tile: Vector2i) -> int:
	var chunk := TerrainV1.chunk_of(tile)
	_chunk_bytes(chunk)
	var local := TerrainV1.local_of(tile)
	return _zones[chunk][local.y * CHUNK_SIZE + local.x]

func _ground(tile: Vector2i) -> int:
	## Ground under a blocker (or the rim) for presentation and biome names.
	var land: Variant = _lands.get(slot_of(tile))
	if land == null:
		return Surfaces.VEIL
	var zone := _zone(tile)
	return land.rim_ground if zone == RIM else land.kinds[zone].ground

func _chunk_bytes(chunk: Vector2i) -> PackedByteArray:
	if _bytes.has(chunk):
		return _bytes[chunk]
	var tiles := PackedByteArray()
	tiles.resize(CHUNK_SIZE * CHUNK_SIZE)
	var zones := PackedByteArray()
	zones.resize(CHUNK_SIZE * CHUNK_SIZE)
	zones.fill(RIM)
	var origin := chunk * CHUNK_SIZE
	var land: Variant = _lands.get(slot_of(origin))
	if land == null or not TerrainV1.in_bounds(origin):
		tiles.fill(Surfaces.VEIL)
	elif land.has("version"):
		Layout.build(self, land, origin, tiles, zones)
		if not patches(land.plan).is_empty():
			for i in tiles.size():
				var c: Dictionary = spatial_cell(origin + Vector2i(i % CHUNK_SIZE, i / CHUNK_SIZE))
				if not c.is_empty(): tiles[i] = int(c.surface)
	else:
		_build(land, origin, tiles, zones)
	_bytes[chunk] = tiles
	_zones[chunk] = zones
	_order.append(chunk)
	if _order.size() > CACHE_LIMIT:
		var old: Vector2i = _order.pop_front()
		_bytes.erase(old)
		_zones.erase(old)
	return tiles

func _build(land: Dictionary, origin: Vector2i, tiles: PackedByteArray, zones: PackedByteArray) -> void:
	var roads: Array = []
	var low := Vector2(origin) - Vector2.ONE * 3
	var high := Vector2(origin) + Vector2.ONE * (CHUNK_SIZE + 3)
	for segment in land.roads:
		if segment.b_max.x >= low.x and segment.b_min.x <= high.x and segment.b_max.y >= low.y and segment.b_min.y <= high.y:
			roads.append(segment)
	var center: Vector2 = land.center
	var box := Rect2(Vector2(origin), Vector2.ONE * (CHUNK_SIZE - 1))
	var nearest_point := Vector2(clampf(center.x, box.position.x, box.end.x), clampf(center.y, box.position.y, box.end.y))
	if nearest_point.distance_to(center) > land.radius * 1.23:
		# Wholly beyond the coast: rim, crossed only by gate corridors.
		for index in tiles.size():
			var point := Vector2(origin.x + index % CHUNK_SIZE, origin.y + index / CHUNK_SIZE)
			tiles[index] = Surfaces.ROAD if _on_road(point, roads) else land.rim
		return
	# Field samples on a GRID lattice covering the chunk (inclusive far edge).
	var coast := PackedFloat32Array()
	var warp_x := PackedFloat32Array()
	var warp_y := PackedFloat32Array()
	var fields: Array = []
	for field in land.fields: fields.append(PackedFloat32Array())
	var candidates := {}
	for j in SAMPLES:
		for i in SAMPLES:
			var sample := origin + Vector2i(i * GRID, j * GRID)
			coast.append(780.0 + float(3 * _noise(sample, 44, land.stream + 1) + _noise(sample, 12, land.stream + 2)) / 4.0 * 440.0 / 1023.0)
			var wx := float(_noise(sample, 40, land.stream + 21) - 512) * WARP / 512.0
			var wy := float(_noise(sample, 40, land.stream + 22) - 512) * WARP / 512.0
			warp_x.append(wx)
			warp_y.append(wy)
			candidates[_nearest(land, Vector2(sample) + Vector2(wx, wy), range(land.seeds.size()))] = true
			for f in land.fields.size():
				fields[f].append(float(_noise(sample, land.fields[f].x, land.stream + land.fields[f].y)))
	var nearby: Array = candidates.keys()
	# Fast paths (same result): one region over the whole chunk, or wholly inland.
	var single: bool = nearby.size() == 1
	var far_corner := 0.0
	for corner in [box.position, box.end, Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y)]:
		far_corner = maxf(far_corner, corner.distance_to(center))
	var inland: bool = far_corner < land.radius * 0.78 - 6.0
	var any_road := not roads.is_empty()
	for y in CHUNK_SIZE:
		for x in CHUNK_SIZE:
			var index := y * CHUNK_SIZE + x
			var tile := origin + Vector2i(x, y)
			var point := Vector2(tile)
			var zone: int = nearby[0] if single else _nearest(land, point + Vector2(_bl(warp_x, x, y), _bl(warp_y, x, y)), nearby)
			if any_road and _on_road(point, roads):
				tiles[index] = Surfaces.ROAD
				zones[index] = zone
				continue
			if not inland:
				var radius: float = land.radius * _bl(coast, x, y) / 1000.0
				var distance := point.distance_to(center)
				if distance > radius:
					tiles[index] = land.rim
					continue
				if distance > radius - 5.0 and land.shore >= 0:
					zones[index] = zone
					tiles[index] = land.shore
					continue
			zones[index] = zone
			tiles[index] = _surface(land.kinds[zone], tile, fields, x, y)

func _surface(kind: Dictionary, tile: Vector2i, fields: Array, x: int, y: int) -> int:
	var ground: int = kind.ground
	if kind.has("ridges"):
		var value := _bl(fields[kind.ridges.field], x, y)
		if value >= kind.ridges.low and value <= kind.ridges.high:
			return kind.ridges.tile
	if kind.has("pools"):
		var value := _bl(fields[kind.pools.field], x, y)
		if value < kind.pools.below:
			return kind.pools.surface
		if kind.pools.edge >= 0 and value < kind.pools.below + kind.pools.edge_width:
			ground = kind.pools.edge
	if kind.has("patch") and ground == kind.ground and _bl(fields[kind.patch.field], x, y) > kind.patch.above:
		ground = kind.patch.surface
	var feature := coordinate_hash(tile.x, tile.y, 31) % 100
	if kind.has("blocker") and ground in kind.blocker.on and feature < kind.blocker.percent:
		return kind.blocker.tile
	if kind.has("rocks") and feature >= 100 - kind.rocks.percent and Surfaces.HABITAT_OF.has(ground):
		return kind.rocks.tile
	return ground

static func _bl(values: PackedFloat32Array, x: int, y: int) -> float:
	var k := (y / GRID) * SAMPLES + x / GRID
	var fx := float(x % GRID) / GRID
	var fy := float(y % GRID) / GRID
	return lerpf(lerpf(values[k], values[k + 1], fx), lerpf(values[k + SAMPLES], values[k + SAMPLES + 1], fx), fy)

static func _nearest(land: Dictionary, point: Vector2, indices: Array) -> int:
	var best: int = indices[0]
	var best_distance := INF
	for index in indices:
		var distance: float = point.distance_squared_to(land.seeds[index])
		if distance < best_distance or (distance == best_distance and index < best):
			best = index
			best_distance = distance
	return best

static func _on_road(point: Vector2, roads: Array) -> bool:
	for segment in roads:
		var ab: Vector2 = segment.b - segment.a
		var length := ab.length_squared()
		var t := 0.0 if length == 0.0 else clampf((point - segment.a).dot(ab) / length, 0.0, 1.0)
		if point.distance_squared_to(segment.a + ab * t) <= segment.width_squared:
			return true
	return false

func _compile(plan: Dictionary) -> Dictionary:
	var kinds: Array = []
	var seeds: Array = []
	var fields: Array = []
	for region in plan.regions:
		seeds.append(Vector2(int(region.seed.x), int(region.seed.y)))
		var kind := compile_kind(plan.kinds[region.kind])
		for key in [["ridges", 11], ["pools", 12], ["patch", 13]]:
			if kind.has(key[0]):
				var field := Vector2i(kind[key[0]].scale, key[1])
				if not field in fields: fields.append(field)
				kind[key[0]].field = fields.find(field)
		kinds.append(kind)
	var roads: Array = []
	for road in plan.roads:
		var a := Vector2(int(road.a.x), int(road.a.y))
		var b := Vector2(int(road.b.x), int(road.b.y))
		var width := float(road.width) / 10.0
		roads.append({"a": a, "b": b, "width_squared": width * width, "b_min": Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * width, "b_max": Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * width})
	var ecology := {}
	for habitat in plan.get("ecology", {}):
		ecology[habitat] = {}
		for content_id in plan.ecology[habitat]: ecology[habitat][content_id] = true
	return {"plan": plan, "center": Vector2(int(plan.center.x), int(plan.center.y)), "radius": float(plan.radius), "stream": int(plan.stream),
		"rim": Surfaces.ROCK if plan.rim == "ridge" else Surfaces.WATER, "rim_ground": Surfaces.SNOW if plan.rim == "ridge" else Surfaces.WATER,
		"shore": Surfaces.BY_NAME.get(plan.get("shore", ""), -1), "kinds": kinds, "seeds": seeds, "roads": roads, "fields": fields, "ecology": ecology}

static func compile_kind(rules: Dictionary) -> Dictionary:
	var kind := {"ground": Surfaces.BY_NAME[rules.ground]}
	if rules.has("ridges"):
		kind.ridges = {"tile": Surfaces.BY_NAME[rules.ridges.tile], "scale": int(rules.ridges.scale), "low": int(rules.ridges.low), "high": int(rules.ridges.high)}
	if rules.has("pools"):
		kind.pools = {"surface": Surfaces.BY_NAME[rules.pools.surface], "scale": int(rules.pools.scale), "below": int(rules.pools.below), "edge": Surfaces.BY_NAME.get(rules.pools.get("edge", ""), -1), "edge_width": int(rules.pools.get("edge_width", 0))}
	if rules.has("patch"):
		kind.patch = {"surface": Surfaces.BY_NAME[rules.patch.surface], "scale": int(rules.patch.scale), "above": int(rules.patch.above)}
	if rules.has("blocker"):
		kind.blocker = {"tile": Surfaces.BY_NAME[rules.blocker.tile], "percent": int(rules.blocker.percent), "on": rules.blocker.on.map(func(n: String) -> int: return Surfaces.BY_NAME[n])}
	if rules.has("rocks"):
		kind.rocks = {"tile": Surfaces.BY_NAME[rules.rocks.tile], "percent": int(rules.rocks.percent)}
	return kind
