extends RefCounted
## Whole-land survey on the actual materialized terrain (Milestone 05): 4-connected
## flood fill from a start tile over one land's slot. Reports reachable tiles per region,
## whether gates, starts and shelter doors are reachable, and walkable pockets nobody can
## reach. Development/validation tool; reads terrain only, never writes anything.
const TerrainV1 = preload("res://src/world/terrain_v1.gd")
const TerrainAtlas = preload("res://src/world/terrain_atlas.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const SIDE := TerrainAtlas.SLOT / TerrainV1.CHUNK_SIZE

static func slot_chunks(terrain: RefCounted, slot: Vector2i) -> Dictionary:
	## Every chunk of the slot, generated once (order-independent by construction).
	var result := {}
	var first := slot * SIDE
	for cy in SIDE:
		for cx in SIDE:
			var chunk := first + Vector2i(cx, cy)
			result[chunk] = terrain.generate_chunk(chunk)
	return result

static func value_at(chunks: Dictionary, tile: Vector2i) -> int:
	var bytes: Variant = chunks.get(TerrainV1.chunk_of(tile))
	if bytes == null:
		return Surfaces.VEIL
	var local := TerrainV1.local_of(tile)
	return bytes[local.y * TerrainV1.CHUNK_SIZE + local.x]

static func survey(terrain: RefCounted, plan: Dictionary, from: Vector2i, chunks: Dictionary = {}) -> Dictionary:
	var slot := Vector2i(int(plan.slot.x), int(plan.slot.y))
	if chunks.is_empty():
		chunks = slot_chunks(terrain, slot)
	var origin := TerrainAtlas.slot_origin(slot)
	var size := TerrainAtlas.SLOT
	var seen := PackedByteArray()
	seen.resize(size * size)
	var queue: Array[Vector2i] = []
	if Surfaces.walkable(value_at(chunks, from)):
		queue.append(from)
		seen[(from.y - origin.y) * size + from.x - origin.x] = 1
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			var local: Vector2i = next - origin
			if local.x < 0 or local.y < 0 or local.x >= size or local.y >= size or seen[local.y * size + local.x] != 0:
				continue
			if Surfaces.walkable(value_at(chunks, next)) and not terrain.can_step(current, next): continue
			seen[local.y * size + local.x] = 1
			if Surfaces.walkable(value_at(chunks, next)) and terrain.can_step(current, next):
				queue.append(next)
			else:
				seen[local.y * size + local.x] = 2
	var reached := {}
	for tile in queue: reached[tile] = true
	var by_region := {}
	var by_value := {}
	var walkable_total := 0
	for chunk in chunks:
		var bytes: PackedByteArray = chunks[chunk]
		for i in bytes.size():
			var value: int = bytes[i]
			by_value[value] = int(by_value.get(value, 0)) + 1
			if Surfaces.walkable(value): walkable_total += 1
	var zones := {}
	for chunk in chunks: zones[chunk] = terrain.chunk_zones(chunk)
	for tile in queue:
		var local := TerrainV1.local_of(tile)
		var region: int = zones[TerrainV1.chunk_of(tile)][local.y * TerrainV1.CHUNK_SIZE + local.x]
		by_region[region] = int(by_region.get(region, 0)) + 1
	var gates := {}
	for gate in plan.gates:
		gates[gate.gate_id] = reached.has(Vector2i(int(gate.position.x), int(gate.position.y)))
	var starts := {}
	for start in plan.get("starts", []):
		starts[start.start_id] = reached.has(Vector2i(int(start.position.x), int(start.position.y)))
	var shelters := {}
	for shelter in plan.get("geography", {}).get("shelters", []):
		shelters[shelter.shelter_id] = shelter.doors.all(func(d: Dictionary) -> bool: return reached.has(Vector2i(int(d.x), int(d.y))))
	return {"reached": queue.size(), "walkable": walkable_total, "unreached": walkable_total - queue.size(), "by_region": by_region,
		"by_value": by_value, "gates": gates, "starts": starts, "shelters": shelters, "reached_set": reached, "chunks": chunks}

static func steps(terrain: RefCounted, from: Vector2i, limit: int, goal: Callable) -> int:
	## Walking steps (4-connected, real terrain) to the nearest tile where goal(tile) is
	## true, or -1 beyond `limit`. Used for food/water access on final terrain.
	if goal.call(from):
		return 0
	var seen := {from: 0}
	var queue: Array[Vector2i] = [from]
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		var depth: int = seen[current]
		if depth >= limit:
			continue
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if seen.has(next) or not terrain.can_step(current, next):
				continue
			seen[next] = depth + 1
			if goal.call(next):
				return depth + 1
			queue.append(next)
	return -1

static func overview(chunks: Dictionary, plan: Dictionary, colors: Dictionary, scale: int = 1) -> Image:
	## One pixel (or scale x scale) per tile of the slot: a developer's terrain map.
	var slot := Vector2i(int(plan.slot.x), int(plan.slot.y))
	var origin := TerrainAtlas.slot_origin(slot)
	var image := Image.create(TerrainAtlas.SLOT * scale, TerrainAtlas.SLOT * scale, false, Image.FORMAT_RGBA8)
	for chunk in chunks:
		var bytes: PackedByteArray = chunks[chunk]
		var base: Vector2i = chunk * TerrainV1.CHUNK_SIZE - origin
		for i in bytes.size():
			var color: Color = colors.get(int(bytes[i]), Color.MAGENTA)
			var at := (base + Vector2i(i % TerrainV1.CHUNK_SIZE, i / TerrainV1.CHUNK_SIZE)) * scale
			if scale == 1:
				image.set_pixelv(at, color)
			else:
				image.fill_rect(Rect2i(at, Vector2i(scale, scale)), color)
	return image
