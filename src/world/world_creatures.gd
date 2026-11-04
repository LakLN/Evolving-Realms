extends RefCounted
## Creature layer v1: data-driven species and deterministic home placements.
## Placements depend only on World seed, terrain v1 and species data, never on
## Run, visit order or time. Per-run hp/position/death live in entity mutations.
const Effects = preload("res://src/core/effects.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const Data = preload("res://src/data/json_data.gd")
const Pack = preload("res://src/content/starter_pack.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Combat = preload("res://src/core/combat.gd")
const Encounters = preload("res://src/world/world_encounters.gd")
const DISPOSITIONS := ["hostile", "neutral", "passive"]
const MAX_PER_CHUNK := 6
var world: Dictionary
var terrain: RefCounted
var registry: RefCounted
var definitions: Dictionary = {}
var rules: Array = []
## Milestone 02 H: encounter layer over v1 and the World's established-region ledger.
## Without a ledger (pure tools/tests) only v1 homes exist.
var encounters := Encounters.new()
var ledger: RefCounted = null
var last_error := ""

func configure(blueprint: Dictionary, generator: RefCounted, content: RefCounted, region_ledger: RefCounted = null) -> bool:
	world = blueprint
	ledger = region_ledger
	terrain = generator
	registry = content
	var pack := Pack.new()
	if not pack.install(registry, world.world_id, Pack.CREATURES_PATH):
		return _fail(pack.last_error)
	definitions.clear()
	rules.clear()
	var headers: Array = registry.list_definitions(world.world_id)
	if not registry.last_error.is_empty():
		return _fail(registry.last_error)
	for header in headers:
		# Like objects: v1 distributions pin the first immutable definition.
		if int(header.version) != 1 or header.status != "active" or header.kind != "creature":
			continue
		var definition: Dictionary = registry.load_definition(world.world_id, header.content_id, 1)
		if definition.is_empty():
			return _fail(registry.last_error)
		if not validate(definition):
			return false
		definitions[_key(definition.content_id, 1)] = definition
		# The frozen v1 layer never admits AI species; they spawn through encounters.
		if definition.payload.has("spawn") and definition.get("provenance", {}).get("origin") != "ai":
			# ecology_only (M05 land packages): only where a land's ecology adapts it, never natively.
			rules.append({"definition": definition, "stream": Loot.number("creatures-v1/" + definition.content_id), "priority": int(definition.payload.spawn.get("priority", 20)), "ecology_only": definition.payload.spawn.get("ecology_only", false) == true})
	rules.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.priority < b.priority or (a.priority == b.priority and a.definition.content_id < b.definition.content_id))
	if not encounters.configure(registry, world.world_id, self):
		return _fail(encounters.last_error)
	last_error = ""
	return true

func validate(definition: Dictionary) -> bool:
	var id := str(definition.get("content_id"))
	var payload: Variant = definition.get("payload")
	if not payload is Dictionary or payload.has("interaction"):
		return _fail("Creature payload must be an object without object interactions: " + id)
	if not payload.get("visual", "creature") is String or payload.get("disposition") not in DISPOSITIONS:
		return _fail("Creature needs hostile/neutral/passive disposition and string visual: " + id)
	if not Combat.valid_stats(payload.get("stats")):
		return _fail("Creature stats need integer max_hp >= 1, attack and defense: " + id)
	if not payload.get("elements", ["neutral"]) is Array or payload.get("elements", []).any(func(e: Variant) -> bool: return not Effects.rules().elements.has(e)):
		return _fail("Creature has unsupported elements: " + id)
	if not payload.get("effect_modifiers", []) is Array or not payload.get("on_hit_effects", []) is Array or payload.get("on_hit_effects", []).size() > 8:
		return _fail("Creature effects must be bounded arrays: " + id)
	for modifier in payload.get("effect_modifiers", []):
		var problem := Effects.check_modifier(modifier)
		if not problem.is_empty(): return _fail(id + ": " + problem)
	for effect in payload.get("on_hit_effects", []):
		if not effect is Dictionary or effect.get("type") != "apply_status": return _fail("Unsupported creature hit effect: " + id)
		var missing: Array = []
		var problem := Effects.check_application(effect, definition, registry, world.world_id, missing)
		if not problem.is_empty() or not missing.is_empty(): return _fail(id + ": " + problem + " missing " + str(missing))
	var movement: Variant = payload.get("movement")
	if not movement is Dictionary or not movement.get("biomes") is Array or movement.biomes.is_empty() or not Data.integer(movement.get("leash")) or movement.leash < 1 or movement.leash > 12:
		return _fail("Creature movement needs biomes and leash 1..12: " + id)
	if not Data.integer(movement.get("move_per_10000", 10000)) or movement.get("move_per_10000", 10000) < 1 or movement.get("move_per_10000", 10000) > 10000:
		return _fail("Creature move_per_10000 must be 1..10000: " + id)
	for biome in movement.biomes:
		if biome not in Surfaces.HABITATS:
			return _fail("Unsupported creature movement biome: " + id)
	var ai: Variant = payload.get("ai")
	if not ai is Dictionary:
		return _fail("Creature AI settings must be an object: " + id)
	for field in [["detect_radius", 0, 10], ["wander_per_10000", 0, 10000], ["flee_radius", 0, 10], ["flee_below_percent", 0, 100]]:
		var value: Variant = ai.get(field[0], 0)
		if not Data.integer(value) or value < field[1] or value > field[2]:
			return _fail("Creature AI %s must be %d..%d: %s" % [field[0], field[1], field[2], id])
	if not Data.integer(ai.get("detect_radius")):
		return _fail("Creature AI needs detect_radius: " + id)
	var loot := Loot.new()
	if not loot.validate(payload.get("loot"), registry, world.world_id):
		return _fail(id + ": " + loot.last_error)
	for drop in payload.loot.get("guaranteed", []) + payload.loot.get("entries", []):
		var declared := false
		for dependency in definition.get("dependencies", []):
			declared = declared or (dependency.content_id == drop.content_id and dependency.version == drop.version)
		if not declared:
			return _fail("Creature loot is not pinned in definition dependencies: " + str(drop.content_id))
	if payload.has("spawn"):
		var spawn: Variant = payload.spawn
		if not spawn is Dictionary or not spawn.get("biomes") is Array or spawn.biomes.is_empty() or not Data.integer(spawn.get("per_10000")) or spawn.per_10000 < 0 or spawn.per_10000 > 500 or not Data.integer(spawn.get("priority", 20)):
			return _fail("Invalid creature distribution (per_10000 0..500): " + id)
		for biome in spawn.biomes:
			if biome not in movement.biomes:
				return _fail("Creature spawn biome must also be a movement biome: " + id)
	return true

func generate_chunk(chunk: Vector2i, bytes: PackedByteArray = PackedByteArray()) -> Array:
	## Home placements on walkable tiles of the species' spawn biomes, one per tile,
	## at most MAX_PER_CHUNK per chunk (lowest IDs kept), sorted by ID.
	if bytes.is_empty():
		bytes = terrain.generate_chunk(chunk)
	var origin := chunk * Terrain.CHUNK_SIZE
	var result: Array = []
	var adaptive: bool = terrain.has_method("ecology_hosts") # Atlas lands: adapted ecology.
	for y in Terrain.CHUNK_SIZE:
		for x in Terrain.CHUNK_SIZE:
			var ground: int = bytes[y * Terrain.CHUNK_SIZE + x]
			var habitat: String = Surfaces.HABITAT_OF.get(ground, "")
			if habitat.is_empty():
				continue
			var point := origin + Vector2i(x, y)
			for rule in rules:
				var spawn: Dictionary = rule.definition.payload.spawn
				if terrain.coordinate_hash(point.x, point.y, rule.stream) % 10000 >= int(spawn.per_10000) or not ((habitat in spawn.biomes and not rule.ecology_only) or (adaptive and terrain.ecology_hosts(ground, point, rule.definition.content_id))):
					continue
				result.append({"instance_id": "crt:v1/%d/%d/%d_%d" % [chunk.x, chunk.y, x, y], "content_id": rule.definition.content_id, "version": 1, "position": {"x": point.x, "y": point.y}, "origin": "procedural", "metadata": {"creature_generation_version": 1}})
				break
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.instance_id < b.instance_id)
	return result.slice(0, MAX_PER_CHUNK)

func chunk_creatures(chunk: Vector2i, bytes: PackedByteArray = PackedByteArray()) -> Array:
	## Homes a Run sees in this chunk: v1 plus encounters of the revision the chunk was
	## established at. The first load establishes it (World-scoped, immutable).
	last_error = ""
	if bytes.is_empty():
		bytes = terrain.generate_chunk(chunk)
	if ledger == null:
		return native_chunk(chunk, bytes)
	var revision: int = ledger.establish(chunk, ledger.revision)
	if revision < 0:
		_fail(ledger.last_error)
		return []
	return preview_chunk(chunk, revision, bytes)

func native_chunk(chunk: Vector2i, bytes: PackedByteArray = PackedByteArray()) -> Array:
	## Pure native homes for certifiers/tools; never establishes a region.
	return _with_authored(chunk, generate_chunk(chunk, bytes))

func preview_chunk(chunk: Vector2i, revision: int, bytes: PackedByteArray = PackedByteArray()) -> Array:
	## Pure: the chunk's homes at an encounter revision. Never writes.
	if bytes.is_empty():
		bytes = terrain.generate_chunk(chunk)
	var homes := generate_chunk(chunk, bytes)
	var result: Array = homes + encounters.generate(terrain, chunk, bytes, revision, homes)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.instance_id < b.instance_id)
	return _with_authored(chunk, result)

func _with_authored(chunk: Vector2i, homes: Array) -> Array:
	# Plan-v2 authored encounters are an independent append-only layer. Never replace
	# a v1 home or an encounter if it already occupies the authored tile.
	if not terrain.has_method("creature_homes"): return homes
	var occupied := {}
	for home in homes: occupied[Vector2i(int(home.position.x), int(home.position.y))] = true
	for home in terrain.creature_homes(chunk):
		var tile := Vector2i(int(home.position.x), int(home.position.y))
		if occupied.has(tile): continue
		homes.append(home)
		occupied[tile] = true
	homes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.instance_id < b.instance_id)
	return homes

func habitats() -> Array:
	## Creature definitions that can currently appear (v1 species and encounter species).
	var result := {}
	for rule in rules:
		result[_key(rule.definition.content_id, 1)] = rule.definition
	for rule in encounters.rules:
		result[_key(rule.creature.content_id, int(rule.creature.version))] = rule.creature
	return result.values()

func definition_for(instance: Dictionary) -> Dictionary:
	var key := _key(instance.content_id, int(instance.version))
	if not definitions.has(key):
		var definition: Dictionary = registry.load_definition(world.world_id, instance.content_id, int(instance.version))
		if definition.is_empty() or definition.kind != "creature" or definition.status != "active" or not validate(definition):
			return {}
		definitions[key] = definition
	return definitions[key]

func materialize(instance: Dictionary) -> bool:
	## Persist the immutable home placement once so run mutations can reference it.
	var existing: Dictionary = registry.load_instance(world.world_id, instance.instance_id)
	if not existing.is_empty():
		if existing.content_id != instance.content_id or int(existing.version) != int(instance.version) or int(existing.position.x) != int(instance.position.x) or int(existing.position.y) != int(instance.position.y):
			return _fail("Established creature conflicts with generated placement")
		return true
	if registry.last_error != "Content instance not found":
		return _fail(registry.last_error)
	if registry.create_instance(world.world_id, instance).is_empty():
		return _fail(registry.last_error)
	return true

func _key(content_id: String, version: int) -> String:
	return "%s@%d" % [content_id, version]

func _fail(message: String) -> bool:
	last_error = message
	return false
