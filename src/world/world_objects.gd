extends RefCounted
## Object layer v1. Definitions are data; placements are non-blocking.
const Structured = preload("res://src/world/structured_world.gd")
const Regions = preload("res://src/world/structured_regions.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const Data = preload("res://src/data/json_data.gd")
const Pack = preload("res://src/content/starter_pack.gd")
const Loot = preload("res://src/core/loot_table.gd")
var regions: RefCounted
var world: Dictionary
var terrain: RefCounted
var terrain_cache: RefCounted
var registry: RefCounted
var definitions: Dictionary = {}
var rules: Array = []
var chunks: Dictionary = {}
var center := Vector2i(2147483647, 2147483647)
var last_error := ""

func configure(blueprint: Dictionary, generator: RefCounted, content: RefCounted, cache: RefCounted) -> bool:
	regions = Regions.new(generator) if Structured.enabled(blueprint) else null
	world = blueprint
	terrain = generator
	registry = content
	terrain_cache = cache
	var pack := Pack.new()
	if not pack.install(registry, world.world_id):
		return _fail(pack.last_error)
	definitions.clear()
	rules.clear()
	var headers: Array = registry.list_definitions(world.world_id)
	if not registry.last_error.is_empty():
		return _fail(registry.last_error)
	for header in headers:
		# v1 distributions pin the first immutable definition; no automatic upgrades.
		if int(header.version) != 1 or header.status != "active" or header.kind not in ["resource", "chest"]:
			continue
		var definition: Dictionary = registry.load_definition(world.world_id, header.content_id, 1)
		if definition.is_empty():
			return _fail(registry.last_error)
		if not definition.payload.has("interaction"):
			continue # Legacy descriptive content without a gameplay handler.
		if not _valid_definition(definition):
			return false
		definitions[_key(definition.content_id, 1)] = definition
		if definition.payload.has("spawn"):
			rules.append({"definition": definition, "stream": Loot.number("objects-v1/" + definition.content_id), "priority": int(definition.payload.spawn.get("priority", 20))})
	rules.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.priority < b.priority or (a.priority == b.priority and a.definition.content_id < b.definition.content_id))
	for location in world.blueprint.fixed_locations:
		if not location is Dictionary or not location.has("content_id"):
			continue # Geography-only landmarks are not interactable objects.
		if not Data.identifier(location.get("id")) or not Data.position(location.get("position")) or not Data.integer(location.get("version")):
			return _fail("Invalid interactable World Blueprint location")
		var instance := {"instance_id": location.id, "content_id": location.content_id, "version": int(location.version), "position": location.position.duplicate(true), "origin": "authored", "metadata": {"blueprint": true}}
		if not _valid_instance(instance) or not materialize(instance):
			return false
	last_error = ""
	return true

func _valid_definition(definition: Dictionary) -> bool:
	var payload: Dictionary = definition.payload
	if not payload.get("visual", "resource") is String:
		return _fail("Object visual must be a string: " + str(definition.content_id))
	if payload.interaction not in ["gather", "open", "pickup"] or (definition.kind == "chest" and payload.interaction != "open") or (definition.kind == "resource" and payload.interaction == "open"):
		return _fail("Unsupported object interaction: " + str(definition.content_id))
	var loot := Loot.new()
	if not loot.validate(payload.get("loot"), registry, world.world_id):
		return _fail(str(definition.content_id) + ": " + loot.last_error)
	for drop in payload.loot.get("guaranteed", []) + payload.loot.get("entries", []):
		var declared := false
		for dependency in definition.dependencies:
			declared = declared or (dependency.content_id == drop.content_id and dependency.version == drop.version)
		if not declared:
			return _fail("Loot reference is not pinned in definition dependencies: " + str(drop.content_id))
	if payload.has("spawn"):
		var spawn: Variant = payload.spawn
		if not spawn is Dictionary or not spawn.get("biomes") is Array or spawn.biomes.is_empty() or not Data.integer(spawn.get("per_10000")) or spawn.per_10000 < 0 or spawn.per_10000 > 10000 or not Data.integer(spawn.get("priority", 20)):
			return _fail("Invalid object distribution: " + str(definition.content_id))
		for biome in spawn.biomes:
			if biome not in Surfaces.HABITATS:
				return _fail("Unsupported object spawn biome")
	return true

func _valid_instance(instance: Dictionary) -> bool:
	if not Data.identifier(instance.get("instance_id")) or not Data.identifier(instance.get("content_id")) or not Data.integer(instance.get("version")) or instance.version < 1:
		return _fail("Invalid object instance identity or definition reference")
	var point: Variant = instance.get("position")
	if not Data.position(point) or point.x < -Terrain.LIMIT or point.x > Terrain.LIMIT or point.y < -Terrain.LIMIT or point.y > Terrain.LIMIT:
		return _fail("Object position is outside terrain bounds")
	if not terrain.walkable(Vector2i(int(point.x), int(point.y))):
		return _fail("Object cannot be placed on blocked terrain")
	var key := _key(instance.content_id, int(instance.version))
	if not definitions.has(key):
		var definition: Dictionary = registry.load_definition(world.world_id, instance.content_id, int(instance.version))
		if definition.is_empty() or definition.get("kind") not in ["resource", "chest"] or not definition.payload.has("interaction") or definition.status != "active":
			return _fail("Object needs an active gameplay definition")
		if not _valid_definition(definition):
			return false
		definitions[key] = definition
	return true

func follow(tile: Vector2i) -> bool:
	var next_center := Terrain.chunk_of(tile)
	if center == next_center:
		return true
	var next := {}
	for y in range(next_center.y - 1, next_center.y + 2):
		for x in range(next_center.x - 1, next_center.x + 2):
			var chunk := Vector2i(x, y)
			if chunks.has(chunk):
				next[chunk] = chunks[chunk]
			else:
				var objects := generate_chunk(chunk)
				if not last_error.is_empty():
					return false
				next[chunk] = objects
	chunks = next
	center = next_center
	return true

func generate_chunk(chunk: Vector2i) -> Array:
	last_error = ""
	var origin := chunk * Terrain.CHUNK_SIZE
	var persisted: Array = registry.list_instances_in_bounds(world.world_id, origin.x, origin.y, origin.x + 31, origin.y + 31)
	if not registry.last_error.is_empty():
		_fail(registry.last_error)
		return []
	var result: Array = []
	var reserved := {}
	var regional_percent := 100
	if regions != null:
		regional_percent = int(regions.describe(Regions.cell_of(origin)).resource_percent)
		for destination in regions.placements(chunk): reserved[Vector2i(int(destination.position.x), int(destination.position.y))] = true
	elif terrain.has_method("placements"): # Atlas land sites keep their tiles free too.
		for destination in terrain.placements(chunk): reserved[Vector2i(int(destination.position.x), int(destination.position.y))] = true
	var occupied := {}
	for instance in persisted:
		var key := _key(instance.content_id, int(instance.version))
		if not definitions.has(key):
			var definition: Dictionary = registry.load_definition(world.world_id, instance.content_id, int(instance.version))
			if definition.is_empty():
				_fail(registry.last_error)
				return []
			if not definition.payload.has("interaction"):
				continue
		if not _valid_instance(instance):
			return []
		var point := Vector2i(int(instance.position.x), int(instance.position.y))
		if reserved.has(point):
			_fail("Authored object overlaps a structured destination; placement refused")
			return []
		if occupied.has(point):
			_fail("Conflicting established objects share a tile")
			return []
		occupied[point] = true
		result.append(instance)
	var bytes: PackedByteArray = terrain_cache.chunks.get(chunk, PackedByteArray())
	if bytes.is_empty():
		bytes = terrain.generate_chunk(chunk)
	var adaptive: bool = terrain.has_method("ecology_hosts") # Atlas lands: adapted ecology.
	for y in Terrain.CHUNK_SIZE:
		for x in Terrain.CHUNK_SIZE:
			var point := origin + Vector2i(x, y)
			var ground: int = bytes[y * 32 + x]
			var habitat: String = Surfaces.HABITAT_OF.get(ground, "")
			if habitat.is_empty() or occupied.has(point) or reserved.has(point):
				continue
			for rule in rules:
				var spawn: Dictionary = rule.definition.payload.spawn
				var chance := int(spawn.per_10000)
				if regions != null and rule.definition.content_id.begins_with("m03:resource/"): chance = chance * regional_percent / 100
				if not (habitat in spawn.biomes or (adaptive and terrain.ecology_hosts(ground, point, rule.definition.content_id))) or terrain.coordinate_hash(point.x, point.y, rule.stream) % 10000 >= chance:
					continue
				result.append({"instance_id": "proc:v1/%d/%d/%d_%d" % [chunk.x, chunk.y, x, y], "content_id": rule.definition.content_id, "version": 1, "position": {"x": point.x, "y": point.y}, "origin": "procedural", "metadata": {"object_generation_version": 1}})
				break
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.instance_id < b.instance_id)
	return result

func definition_for(instance: Dictionary) -> Dictionary:
	return definitions.get(_key(instance.content_id, int(instance.version)), {})

func find(instance_id: String) -> Dictionary:
	for objects in chunks.values():
		for instance in objects:
			if instance.instance_id == instance_id:
				return instance
	return {}

func materialize(instance: Dictionary) -> bool:
	if not _valid_instance(instance):
		return false
	var existing: Dictionary = registry.load_instance(world.world_id, instance.instance_id)
	if not existing.is_empty():
		# Compare numerically: stored JSON yields floats, freshly generated placements ints.
		if existing.content_id != instance.content_id or int(existing.version) != int(instance.version) or int(existing.position.x) != int(instance.position.x) or int(existing.position.y) != int(instance.position.y):
			return _fail("Established object conflicts with generated placement")
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
