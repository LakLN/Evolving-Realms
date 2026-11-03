extends RefCounted
## Atlas terrain v2 (Milestone 05): materializes authored-layout land plans (Snow
## Mountain). Used by terrain_atlas.gd only for plans with terrain_version 2; atlas
## terrain v1 lands never reach this code. Pure function of the World seed and the
## stored plan; low-frequency fields use the same 4-tile lattice + bilinear scheme as v1,
## aligned to chunk origins, so output never depends on visit order. Precedence per tile:
## coast rim (cliff) < trails/pass corridor < shelters < escarpment < barriers < lakes
## (ice + clear shore) < windbreaks < clearings < area ground, patches, pines and rocks.
const Surfaces = preload("res://src/world/surfaces.gd")
const CHUNK := 32
const GRID := 4
const SAMPLES := CHUNK / GRID + 1
const RIM := 255
const RAG_MIN := 0.6
const RAG_MAX := 1.35

static func compile(plan: Dictionary, compile_kind: Callable) -> Dictionary:
	var geo: Dictionary = plan.geography
	var kinds: Array = []
	var seeds: Array = []
	var fields: Array = []
	for region in plan.regions:
		seeds.append(Vector2(int(region.seed.x), int(region.seed.y)))
		var rules: Dictionary = plan.kinds[region.kind]
		var kind: Dictionary = compile_kind.call(rules)
		if kind.has("patch"):
			var field := Vector2i(kind.patch.scale, 13)
			if not field in fields: fields.append(field)
			kind.patch.field = fields.find(field)
		kind.ecology = {}
		for habitat in rules.get("ecology", {}):
			kind.ecology[habitat] = {}
			for content_id in rules.ecology[habitat]: kind.ecology[habitat][content_id] = true
		kinds.append(kind)
	var roads: Array = []
	for road in plan.roads:
		roads.append(_capsule(road.a, road.b, float(road.width) / 10.0))
	var barriers: Array = []
	for barrier in geo.barriers:
		barriers.append(_capsule(barrier.a, barrier.b, float(barrier.width) / 10.0, RAG_MAX))
	var windbreaks: Array = []
	for line in geo.windbreaks:
		var capsule := _capsule(line.a, line.b, float(line.width) / 10.0)
		capsule.tile = Surfaces.BY_NAME[line.tile]
		windbreaks.append(capsule)
	var clearings: Array = []
	for clearing in geo.clearings:
		var c := Vector2(int(clearing.x), int(clearing.y))
		var radius := float(clearing.r)
		clearings.append({"c": c, "r2": radius * radius, "b_min": c - Vector2.ONE * radius, "b_max": c + Vector2.ONE * radius})
	var shelters: Array = []
	for shelter in geo.shelters:
		var doors := {}
		for door in shelter.doors: doors[Vector2i(int(door.x), int(door.y))] = true
		shelters.append({"rect": Rect2i(int(shelter.rect.x), int(shelter.rect.y), int(shelter.rect.w), int(shelter.rect.h)), "doors": doors})
	var escarpment := _ellipse(geo.escarpment, 31)
	escarpment.surface = Surfaces.CLIFF
	var ellipses: Array = [escarpment]
	var union := {} # habitat -> {content_id: true}: every area's adapted ecology.
	for kind in kinds:
		for habitat in kind.ecology:
			if not union.has(habitat): union[habitat] = {}
			union[habitat].merge(kind.ecology[habitat])
	for index in geo.lakes.size():
		var lake := _ellipse(geo.lakes[index], 41 + index)
		lake.shore = float(geo.lakes[index].shore)
		lake.surface = Surfaces.ICE
		ellipses.append(lake)
	return {"version": 2, "plan": plan, "center": Vector2(int(plan.center.x), int(plan.center.y)), "radius": float(plan.radius), "stream": int(plan.stream),
		"rim": Surfaces.CLIFF, "rim_ground": Surfaces.SNOW, "shore": -1, "kinds": kinds, "seeds": seeds, "roads": roads, "fields": fields,
		"coast": {"min": float(geo.coast.min) / 1000.0, "max": float(geo.coast.max) / 1000.0, "scale": int(geo.coast.scale)}, "warp": float(geo.warp),
		"barriers": barriers, "windbreaks": windbreaks, "clearings": clearings, "shelters": shelters, "ellipses": ellipses, "ecology": union}

static func _capsule(a_value: Dictionary, b_value: Dictionary, width: float, reach: float = 1.0) -> Dictionary:
	var a := Vector2(int(a_value.x), int(a_value.y))
	var b := Vector2(int(b_value.x), int(b_value.y))
	var margin := width * reach + 1.0
	return {"a": a, "b": b, "width": width, "width_squared": width * width, "b_min": Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * margin, "b_max": Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * margin}

static func _ridge(point: Vector2, barriers: Array, rag: float) -> bool:
	## Ragged, tapered ridge: the half-width wanders with a fine noise field (rag 0..1)
	## and narrows toward both ends, so barriers read as rock spurs, not ruled bars.
	for segment in barriers:
		var ab: Vector2 = segment.b - segment.a
		var length := ab.length_squared()
		var t := 0.0 if length == 0.0 else clampf((point - segment.a).dot(ab) / length, 0.0, 1.0)
		var ends := absf(t - 0.5) * 2.0
		var width: float = segment.width * (1.0 - 0.45 * ends * ends * ends) * lerpf(RAG_MIN, RAG_MAX, rag)
		if point.distance_squared_to(segment.a + ab * t) <= width * width:
			return true
	return false

static func _ellipse(value: Dictionary, salt: int) -> Dictionary:
	var c := Vector2(int(value.center.x), int(value.center.y))
	var r := Vector2(int(value.radius.x), int(value.radius.y))
	var jitter := float(value.jitter) / 1000.0
	var reach := maxf(r.x, r.y) * (1.0 + jitter) + float(value.get("shore", 0)) + 1.0
	return {"c": c, "r": r, "jitter": jitter, "scale": int(value.scale), "salt": salt, "shore": 0.0, "b_min": c - Vector2.ONE * reach, "b_max": c + Vector2.ONE * reach}

static func _near(items: Array, low: Vector2, high: Vector2) -> Array:
	return items.filter(func(s: Dictionary) -> bool: return s.b_max.x >= low.x and s.b_min.x <= high.x and s.b_max.y >= low.y and s.b_min.y <= high.y)

static func _on(point: Vector2, capsules: Array) -> Dictionary:
	for segment in capsules:
		var ab: Vector2 = segment.b - segment.a
		var length := ab.length_squared()
		var t := 0.0 if length == 0.0 else clampf((point - segment.a).dot(ab) / length, 0.0, 1.0)
		if point.distance_squared_to(segment.a + ab * t) <= segment.width_squared:
			return segment
	return {}

static func build(terrain: RefCounted, land: Dictionary, origin: Vector2i, tiles: PackedByteArray, zones: PackedByteArray) -> void:
	var low := Vector2(origin) - Vector2.ONE * 3
	var high := Vector2(origin) + Vector2.ONE * (CHUNK + 3)
	var roads := _near(land.roads, low, high)
	var barriers := _near(land.barriers, low, high)
	var windbreaks := _near(land.windbreaks, low, high)
	var clearings := _near(land.clearings, low, high)
	var ellipses := _near(land.ellipses, low, high)
	var shelters: Array = land.shelters.filter(func(s: Dictionary) -> bool: return s.rect.intersects(Rect2i(origin - Vector2i.ONE, Vector2i.ONE * (CHUNK + 2))))
	var center: Vector2 = land.center
	var stream: int = land.stream
	var box := Rect2(Vector2(origin), Vector2.ONE * (CHUNK - 1))
	var nearest_point := Vector2(clampf(center.x, box.position.x, box.end.x), clampf(center.y, box.position.y, box.end.y))
	if nearest_point.distance_to(center) > land.radius * land.coast.max + 1.0:
		for index in tiles.size():
			var point := Vector2(origin.x + index % CHUNK, origin.y + index / CHUNK)
			tiles[index] = Surfaces.TRAIL if not _on(point, roads).is_empty() else Surfaces.CLIFF
		return
	var coast := PackedFloat32Array()
	var warp_x := PackedFloat32Array()
	var warp_y := PackedFloat32Array()
	var fields: Array = []
	for field in land.fields: fields.append(PackedFloat32Array())
	var jitters: Array = []
	for ellipse in ellipses: jitters.append(PackedFloat32Array())
	var rag := PackedFloat32Array()
	var grove := PackedFloat32Array()
	var warp: float = land.warp
	for j in SAMPLES:
		for i in SAMPLES:
			var sample := origin + Vector2i(i * GRID, j * GRID)
			coast.append(float(3 * terrain._noise(sample, land.coast.scale, stream + 1) + terrain._noise(sample, 12, stream + 2)) / 4.0 / 1023.0)
			warp_x.append(float(terrain._noise(sample, 40, stream + 21) - 512) * warp / 512.0)
			warp_y.append(float(terrain._noise(sample, 40, stream + 22) - 512) * warp / 512.0)
			for f in land.fields.size():
				fields[f].append(float(terrain._noise(sample, land.fields[f].x, stream + land.fields[f].y)))
			rag.append(float(terrain._noise(sample, 9, stream + 61)) / 1023.0)
			grove.append(float(terrain._noise(sample, 18, stream + 62)) / 1023.0)
			for e in ellipses.size():
				jitters[e].append(float(terrain._noise(sample, ellipses[e].scale, stream + ellipses[e].salt)) / 1023.0 * 2.0 - 1.0)
	for y in CHUNK:
		for x in CHUNK:
			var index := y * CHUNK + x
			var tile := origin + Vector2i(x, y)
			var point := Vector2(tile)
			var zone := _nearest(land.seeds, point + Vector2(_bl(warp_x, x, y), _bl(warp_y, x, y)))
			zones[index] = zone
			if not roads.is_empty() and not _on(point, roads).is_empty():
				tiles[index] = Surfaces.TRAIL
				continue
			var coast_radius: float = land.radius * lerpf(land.coast.min, land.coast.max, _bl(coast, x, y))
			if point.distance_to(center) > coast_radius:
				tiles[index] = Surfaces.CLIFF
				zones[index] = RIM
				continue
			var shelter_value := _shelter(shelters, tile)
			if shelter_value >= 0:
				tiles[index] = shelter_value
				continue
			var clear := false
			var value := -1
			for e in ellipses.size():
				var ellipse: Dictionary = ellipses[e]
				var d: Vector2 = (point - ellipse.c) / ellipse.r
				var reach: float = 1.0 + ellipse.jitter * _bl(jitters[e], x, y)
				var distance := d.length()
				if distance < reach:
					value = ellipse.surface
					break
				if ellipse.shore > 0.0 and (distance - reach) * minf(ellipse.r.x, ellipse.r.y) < ellipse.shore:
					clear = true
			if value >= 0:
				tiles[index] = value
				continue
			if not barriers.is_empty() and _ridge(point, barriers, _bl(rag, x, y)):
				tiles[index] = Surfaces.CLIFF
				continue
			if not windbreaks.is_empty():
				var line := _on(point, windbreaks)
				if not line.is_empty():
					tiles[index] = line.tile
					continue
			if not clear:
				for clearing in clearings:
					if point.distance_squared_to(clearing.c) <= clearing.r2:
						clear = true
						break
			tiles[index] = _surface(terrain, land.kinds[zone], tile, fields, x, y, clear, _bl(grove, x, y))

static func _shelter(shelters: Array, tile: Vector2i) -> int:
	for shelter in shelters:
		var rect: Rect2i = shelter.rect
		if not rect.has_point(tile):
			continue
		var edge := tile.x == rect.position.x or tile.y == rect.position.y or tile.x == rect.end.x - 1 or tile.y == rect.end.y - 1
		return Surfaces.TIMBER if edge and not shelter.doors.has(tile) else Surfaces.FLOOR
	return -1

static func _surface(terrain: RefCounted, kind: Dictionary, tile: Vector2i, fields: Array, x: int, y: int, clear: bool, grove: float) -> int:
	## grove (0..1, low frequency) gathers pines into stands with open glades between.
	var ground: int = kind.ground
	if kind.has("patch") and _bl(fields[kind.patch.field], x, y) > kind.patch.above:
		ground = kind.patch.surface
	if clear:
		return ground
	var feature: int = terrain.coordinate_hash(tile.x, tile.y, 31) % 100
	if kind.has("blocker") and ground in kind.blocker.on and feature < roundi(kind.blocker.percent * clampf(grove * 2.4 - 0.5, 0.0, 2.2)):
		return kind.blocker.tile
	if kind.has("rocks") and feature >= 100 - kind.rocks.percent and Surfaces.HABITAT_OF.has(ground):
		return kind.rocks.tile
	return ground

static func _bl(values: PackedFloat32Array, x: int, y: int) -> float:
	var k := (y / GRID) * SAMPLES + x / GRID
	var fx := float(x % GRID) / GRID
	var fy := float(y % GRID) / GRID
	return lerpf(lerpf(values[k], values[k + 1], fx), lerpf(values[k + SAMPLES], values[k + SAMPLES + 1], fx), fy)

static func _nearest(seeds: Array, point: Vector2) -> int:
	var best := 0
	var best_distance := INF
	for index in seeds.size():
		var distance: float = point.distance_squared_to(seeds[index])
		if distance < best_distance:
			best = index
			best_distance = distance
	return best

static func ground_of(land: Dictionary, zone: int) -> int:
	return land.rim_ground if zone == RIM else land.kinds[zone].ground
