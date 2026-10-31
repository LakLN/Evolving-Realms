extends SceneTree
## Compare the optimized location filter against the exact pre-optimization loop.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Packs = preload("res://src/content/starter_pack.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Locations = preload("res://src/world/world_locations.gd")
const Encounters = preload("res://src/world/world_encounters.gd")
const Region = preload("res://src/world/region_context.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Data = preload("res://src/data/json_data.gd")

class Probe extends Locations:
	var open_calls := 0
	func _open(point: Vector2i) -> bool:
		open_calls += 1
		return super._open(point)

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	Session.auto_awaken = false
	var old_calls := 0
	var new_calls := 0
	var places := 0
	var old_us := 0
	var new_us := 0
	for seed_value in [1847, -99, 2147483647]:
		var store := Store.new()
		store.open(ProjectSettings.globalize_path("user://chunk-filter-" + Data.uuid() + ".sqlite"))
		var world: Dictionary = store.create_world("Filter equivalence", seed_value, 1, Packs.blueprint(seed_value))
		var session := Session.new(store)
		if not session.start_new(world.world_id, 7301):
			check(false, session.last_error)
			quit(1)
			return
		var layer := Probe.new()
		layer.terrain = session.terrain
		layer.objects = session.objects
		layer.rules = session.locations.rules
		var centers: Array = []
		for y in range(-2, 2):
			for x in range(-3, 3): centers.append(Vector2i(x, y))
		centers.append(Terrain.chunk_of(session.position))
		centers.append(Vector2i(31250, 31250)) # World edge and outside-bounds neighbours.
		var equal := true
		var reference := {}
		for chunk in centers:
			var bytes: PackedByteArray = session.terrain.generate_chunk(chunk)
			layer.open_calls = 0
			var start := Time.get_ticks_usec()
			var expected := legacy_preview(layer, chunk, 100, [Locations.LAYER], bytes)
			old_us += Time.get_ticks_usec() - start
			old_calls += layer.open_calls
			layer.open_calls = 0
			start = Time.get_ticks_usec()
			var actual := layer.preview_chunk(chunk, 100, [Locations.LAYER], bytes)
			new_us += Time.get_ticks_usec() - start
			new_calls += layer.open_calls
			equal = equal and expected == actual
			places += actual.size()
			reference[chunk] = actual
		check(equal, "Exact old/new placement ID, position, definition and revision for seed %d" % seed_value)
		centers.reverse()
		for chunk in centers:
			equal = equal and reference[chunk] == layer.preview_chunk(chunk, 100, [Locations.LAYER], session.terrain.generate_chunk(chunk))
		check(equal, "Visit order does not change placements for seed %d" % seed_value)
		check(layer.preview_chunk(Vector2i.ZERO, 0, [], session.terrain.generate_chunk(Vector2i.ZERO)).is_empty(), "Legacy regions without location layer stay empty")
		store.close()
	check(places > 0, "Equivalence includes real locations, not only empty chunks (%d)" % places)
	check(new_calls * 20 < old_calls, "Expensive neighbour checks reduced: %d -> %d" % [old_calls, new_calls])
	print("Paired location loop total: before %.3f ms, after %.3f ms" % [old_us / 1000.0, new_us / 1000.0])
	print("CHUNK PERFORMANCE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func legacy_preview(layer: RefCounted, chunk: Vector2i, revision: int, layers: Array, bytes: PackedByteArray) -> Array:
	## Frozen reference of ad0b72f preview_chunk; validation/definitions remain shared.
	if Locations.LAYER not in layers: return []
	var active: Array = layer.rules_at(revision)
	if active.is_empty(): return []
	var occupied := {}
	var placed: Array = layer.objects.chunks[chunk] if layer.objects.chunks.has(chunk) else layer.objects.generate_chunk(chunk)
	for instance in placed: occupied[Vector2i(int(instance.position.x), int(instance.position.y))] = true
	var shares := Region.biome_shares(bytes)
	var danger := Region.danger(layer.terrain, chunk)
	var eligible: Array = active.filter(func(rule: Dictionary) -> bool: return Encounters._chunk_allows(rule.definition.payload.spawn, shares, danger))
	var origin := chunk * Terrain.CHUNK_SIZE
	var order_stream := Loot.number("locations-v1/order")
	var best := {}
	for y in Terrain.CHUNK_SIZE:
		for x in Terrain.CHUNK_SIZE:
			var ground: int = bytes[y * Terrain.CHUNK_SIZE + x]
			var point := origin + Vector2i(x, y)
			if ground not in [Terrain.FOREST, Terrain.BEACH, Terrain.MEADOW] or occupied.has(point) or not layer._open(point): continue
			for rule in eligible:
				var spawn: Dictionary = rule.definition.payload.spawn
				if Terrain.BIOMES[ground] not in spawn.biomes or layer.terrain.coordinate_hash(point.x, point.y, rule.stream) % 10000 >= int(spawn.per_10000) or not Encounters._tile_allows(layer.terrain, chunk, bytes, point, spawn): continue
				var order: int = layer.terrain.coordinate_hash(point.x, point.y, order_stream)
				if best.is_empty() or order < best.order or (order == best.order and (point.y < best.point.y or (point.y == best.point.y and point.x < best.point.x))): best = {"point": point, "local": Vector2i(x, y), "rule": rule, "order": order}
				break
	if best.is_empty() or Locations.BUDGET < 1: return []
	var definition: Dictionary = best.rule.definition
	return [{"instance_id": "loc:v%d/%d/%d/%d_%d" % [Locations.GENERATION_VERSION, chunk.x, chunk.y, best.local.x, best.local.y], "content_id": definition.content_id, "version": int(definition.version), "position": {"x": best.point.x, "y": best.point.y}, "origin": "procedural", "metadata": {"location_generation_version": Locations.GENERATION_VERSION, "location_revision": best.rule.revision, "established_revision": revision}}]
