extends RefCounted
## Location layer v1 (Milestone 02 I): special places distributed per established
## region. Placements are a pure function of World seed, terrain v1, the chunk, its
## object placements and the revision/layers it was established with (RegionLedger).
## They are World facts; discovery and resolution are per-Run entity mutations.
const Structured = preload("res://src/world/structured_world.gd")
const Regions = preload("res://src/world/structured_regions.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const Data = preload("res://src/data/json_data.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Encounters = preload("res://src/world/world_encounters.gd")
const Region = preload("res://src/world/region_context.gd")
const Events = preload("res://src/core/world_events.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
const WorldRules = preload("res://src/core/world_rules.gd")
const LAYER := "locations-v1"
const GENERATION_VERSION := 1
const BUDGET := 1 # At most one special place per chunk, whatever is activated.
const FIELDS := ["category", "visual", "spawn", "discovery", "interactions", "world_properties"]
const DISCOVERY := ["visible", "proximity", "hidden", "search"]
const TRIGGERS := ["discover", "enter", "interact"]
var regions: RefCounted
## Atlas Worlds (M04): the terrain pins land sites (waystones, landmarks) like M03 regions.
var atlas_sites: RefCounted
var world: Dictionary
var terrain: RefCounted
var registry: RefCounted
var ledger: RefCounted
var objects: RefCounted
var rules: Array = []
## "id@version" -> active, validated location and world_event definitions.
var definitions: Dictionary = {}
var chunks: Dictionary = {}
var center := Vector2i(2147483647, 2147483647)
var last_error := ""

static func classify(definition: Dictionary, registry: RefCounted, world_id: String, context: Dictionary, skills: RefCounted) -> Dictionary:
	var missing: Array = []
	var p: Variant = definition.get("payload")
	if not p is Dictionary: return {"problem": "Location payload must be an object", "missing": missing}
	for field in p:
		if field not in FIELDS: missing.append("payload.location." + str(field))
	if not p.get("category") is String or p.category.is_empty() or p.category.length() > 32: return {"problem": "Location needs a category (1..32 characters)", "missing": missing}
	if not p.get("visual", "location") is String: return {"problem": "Location visual must be a string", "missing": missing}
	var spawn: Variant = p.get("spawn")
	if not spawn is Dictionary or not spawn.get("biomes") is Array or spawn.biomes.is_empty() or spawn.biomes.size() > 3 or not spawn.biomes.all(func(b: Variant) -> bool: return b in Surfaces.HABITATS):
		return {"problem": "Location spawn needs 1..3 of forest/beach/meadow", "missing": missing}
	if not Events._between(spawn.get("per_10000"), 1, 50) or not Events._between(spawn.get("priority", 50), 0, 100): return {"problem": "Location spawn needs per_10000 1..50 and priority 0..100", "missing": missing}
	for key in spawn:
		if key not in ["biomes", "per_10000", "priority", "conditions"]: missing.append("parameter.location_spawn." + str(key))
	var problem := Encounters.check_spawn_conditions(spawn.get("conditions", []), missing, "location")
	if not problem.is_empty(): return {"problem": problem, "missing": missing}
	if p.has("world_properties"):
		problem = WorldRules.validate(p.world_properties, missing)
		if not problem.is_empty(): return {"problem": problem, "missing": missing}
		for item in p.world_properties.thaw_fuel:
			if not Events._pinned(definition, item) or registry.load_definition(world_id, item.content_id, int(item.version)).get("kind") != "item": return {"problem": "Thaw fuel must pin an item dependency", "missing": missing}
	var discovery: Variant = p.get("discovery", {"mode": "visible"})
	if not discovery is Dictionary or not discovery.get("mode") is String: return {"problem": "Discovery needs a mode", "missing": missing}
	if discovery.mode not in DISCOVERY: missing.append("location.discovery." + discovery.mode)
	if not Events._between(discovery.get("radius", 1), 0, 7): return {"problem": "Discovery radius must be 0..7", "missing": missing}
	problem = Events.check_conditions(discovery.get("conditions", []), context, skills, missing)
	if not problem.is_empty(): return {"problem": "Discovery: " + problem, "missing": missing}
	var interactions: Variant = p.get("interactions")
	if not interactions is Array or interactions.is_empty() or interactions.size() > 8: return {"problem": "Location needs 1..8 interactions", "missing": missing}
	var ids: Array = []
	for interaction in interactions:
		if not interaction is Dictionary or not interaction.get("id") is String or not RegEx.create_from_string("^[a-z][a-z0-9_]{0,31}$").search(interaction.id) or interaction.id in ids:
			return {"problem": "Interaction needs a unique lower-case id", "missing": missing}
		for key in interaction:
			if key not in ["id", "verb", "trigger", "event", "after", "exclusive", "world_method", "reveal_conditions", "repeat"]: missing.append("parameter.location_interaction." + str(key))
		if interaction.has("repeat"):
			# event.repeat: recurs `every` turns after its last use, at most `times` uses.
			var repeat: Variant = interaction.repeat
			if not repeat is Dictionary or not Events._between(repeat.get("every"), 10, 5000) or (repeat.has("times") and not Events._between(repeat.times, 2, 50)):
				return {"problem": "Interaction repeat needs every 10..5000 and optional times 2..50", "missing": missing}
			for key in repeat:
				if key not in ["every", "times"]: missing.append("parameter.location_repeat." + str(key))
			if interaction.get("exclusive", false) or interaction.has("world_method") or interaction.get("trigger", "interact") == "discover":
				return {"problem": "Recurring interactions cannot be exclusive, world methods or discover triggers", "missing": missing}
		if interaction.has("world_method"):
			if not p.has("world_properties"): return {"problem": "World method needs object properties", "missing": missing}
			if interaction.world_method not in ["heat", "force"]: missing.append("world_rule.method." + str(interaction.world_method))
			if not interaction.get("exclusive", false) or interaction.get("trigger", "interact") != "interact": return {"problem": "World methods require exclusive player interactions", "missing": missing}
		problem = Events.check_conditions(interaction.get("reveal_conditions", []), context, skills, missing)
		if not problem.is_empty(): return {"problem": problem, "missing": missing}
		if not interaction.get("verb", "Explore") is String or interaction.get("verb", "").length() > 40: return {"problem": "Interaction verb must be short text", "missing": missing}
		if interaction.get("trigger", "interact") not in TRIGGERS: missing.append("location.trigger." + str(interaction.get("trigger")))
		if interaction.has("after") and interaction.after not in ids: return {"problem": "Interaction 'after' must name an earlier interaction", "missing": missing}
		if not interaction.get("exclusive", false) is bool: return {"problem": "Interaction exclusive must be a bool", "missing": missing}
		var ref: Variant = interaction.get("event")
		if not ref is Dictionary or not Data.identifier(ref.get("content_id")) or not Data.integer(ref.get("version")) or not Events._pinned(definition, ref):
			return {"problem": "Interaction event must be a pinned dependency", "missing": missing}
		if registry.load_definition(world_id, ref.content_id, int(ref.version)).get("kind") != "world_event": return {"problem": "Interaction event must be a world_event: " + str(ref.content_id), "missing": missing}
		if interaction.has("world_method"):
			var response: Dictionary = registry.load_definition(world_id, ref.content_id, int(ref.version)).payload
			if response.has("cost") or not response.get("outcomes", []).all(func(o: Dictionary) -> bool: return o.type == "grant_items"): return {"problem": "Ice supply events describe intact item contents only; rules own costs and damage", "missing": missing}
		ids.append(interaction.id)
	return {"problem": "", "missing": missing}

static func revision_of(definition: Dictionary) -> int:
	## Activation revision; authored (pack) locations belong to the layer itself (0).
	var value: Variant = definition.get("provenance", {}).get("encounter_revision", 0)
	return int(value) if Data.integer(value) else 0

func configure(blueprint: Dictionary, generator: RefCounted, content: RefCounted, region_ledger: RefCounted, object_layer: RefCounted, context: Dictionary, skills: RefCounted) -> bool:
	regions = object_layer.regions
	atlas_sites = generator if generator.has_method("placements") else null
	world = blueprint
	terrain = generator
	registry = content
	ledger = region_ledger
	objects = object_layer
	rules.clear()
	definitions.clear()
	chunks.clear()
	center = Vector2i(2147483647, 2147483647)
	for header in registry.list_definitions(world.world_id):
		if header.kind != "location" or header.status != "active":
			continue # Pending locations (or pending events) never appear.
		var definition: Dictionary = registry.load_definition(world.world_id, header.content_id, int(header.version))
		var verdict := classify(definition, registry, world.world_id, context, skills) if not definition.is_empty() else {"problem": registry.last_error, "missing": []}
		if not verdict.problem.is_empty() or not verdict.missing.is_empty():
			return _fail("Invalid location %s: %s %s" % [header.content_id, verdict.problem, str(verdict.missing)])
		for interaction in definition.payload.interactions:
			var event: Dictionary = registry.load_definition(world.world_id, interaction.event.content_id, int(interaction.event.version))
			var checked := Events.classify(event, registry, world.world_id, context, skills)
			if event.get("status") != "active" or not checked.problem.is_empty() or not checked.missing.is_empty():
				return _fail("Location %s uses an unsupported event %s: %s %s" % [header.content_id, interaction.event.content_id, checked.problem, str(checked.missing)])
			definitions[_key(event.content_id, int(event.version))] = event
		definitions[_key(definition.content_id, int(definition.version))] = definition
		if (regions != null or atlas_sites != null) and definition.content_id.begins_with("m03:place/"): continue
		# Land-package places (M05) exist only where a land plan pins them as sites.
		if definition.get("metadata", {}).get("site_only", false) == true: continue
		rules.append({"definition": definition, "revision": revision_of(definition), "stream": Loot.number("locations-v1/" + definition.content_id)})
	last_error = ""
	return true

func rules_at(at_revision: int) -> Array:
	var latest := {}
	for rule in rules:
		var id: String = rule.definition.content_id
		if rule.revision <= at_revision and (not latest.has(id) or int(rule.definition.version) > int(latest[id].definition.version)):
			latest[id] = rule
	var result: Array = latest.values()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(a.definition.payload.spawn.get("priority", 50))
		var pb := int(b.definition.payload.spawn.get("priority", 50))
		return pa < pb or (pa == pb and a.definition.content_id < b.definition.content_id))
	return result

func preview_chunk(chunk: Vector2i, at_revision: int, layers: Array, bytes: PackedByteArray = PackedByteArray()) -> Array:
	## Pure: special places of a chunk established with these layers at this revision.
	if LAYER not in layers:
		return []
	var destinations: Array = regions.placements(chunk) if regions != null and "structured-world-v1" in layers and at_revision >= 1 else []
	if atlas_sites != null and "atlas-world-v1" in layers:
		destinations = atlas_sites.placements(chunk)
	var active := rules_at(at_revision)
	if active.is_empty():
		return destinations
	if bytes.is_empty():
		bytes = terrain.generate_chunk(chunk)
	var occupied := {}
	var placed: Array = objects.chunks[chunk] if objects.chunks.has(chunk) else objects.generate_chunk(chunk)
	for instance in placed: # Never cover or replace an object (landmarks included).
		occupied[Vector2i(int(instance.position.x), int(instance.position.y))] = true
	for instance in destinations: occupied[Vector2i(int(instance.position.x), int(instance.position.y))] = true
	var shares := Region.biome_shares(bytes)
	var danger := Region.danger(terrain, chunk)
	var eligible := active.filter(func(rule: Dictionary) -> bool: return Encounters._chunk_allows(rule.definition.payload.spawn, shares, danger))
	var origin := chunk * Terrain.CHUNK_SIZE
	var order_stream := Loot.number("locations-v1/order")
	var adaptive: bool = terrain.has_method("ecology_hosts") # Atlas lands: adapted ecology.
	var best := {}
	var seeds := PackedInt64Array()
	var chances := PackedInt32Array()
	for rule in eligible:
		seeds.append(terrain.stream_seed(rule.stream))
		chances.append(int(rule.definition.payload.spawn.per_10000))
	for y in Terrain.CHUNK_SIZE:
		for x in Terrain.CHUNK_SIZE:
			var ground: int = bytes[y * Terrain.CHUNK_SIZE + x]
			var point := origin + Vector2i(x, y)
			if not terrain.procedural_allowed(point): continue
			var habitat: String = Surfaces.HABITAT_OF.get(ground, "")
			if habitat.is_empty() or occupied.has(point):
				continue
			for i in Terrain.roll_rules(seeds, chances, point.x, point.y):
				var rule: Dictionary = eligible[i]
				var spawn: Dictionary = rule.definition.payload.spawn
				var strict: bool = adaptive and terrain.has_method("strict_ecology") and terrain.strict_ecology(point)
				if not ((not strict and habitat in spawn.biomes) or (adaptive and terrain.ecology_hosts(ground, point, rule.definition.content_id))) or not Encounters._tile_allows(terrain, chunk, bytes, point, spawn):
					continue
				# Four neighbour probes recompute terrain instead of reading chunk bytes.
				# Test it only for spawn candidates; all rules share this predicate.
				# Coordinate hashes are stateless: no random stream/order is consumed.
				if not _open(point):
					break
				var order: int = terrain.coordinate_hash(point.x, point.y, order_stream)
				if best.is_empty() or order < best.order or (order == best.order and (point.y < best.point.y or (point.y == best.point.y and point.x < best.point.x))):
					best = {"point": point, "local": Vector2i(x, y), "rule": rule, "order": order}
				break
	if best.is_empty() or BUDGET < 1:
		return destinations
	var definition: Dictionary = best.rule.definition
	return destinations + [{"instance_id": "loc:v%d/%d/%d/%d_%d" % [GENERATION_VERSION, chunk.x, chunk.y, best.local.x, best.local.y],
		"content_id": definition.content_id, "version": int(definition.version), "position": {"x": best.point.x, "y": best.point.y}, "origin": "procedural",
		"metadata": {"location_generation_version": GENERATION_VERSION, "location_revision": best.rule.revision, "established_revision": at_revision}}]

func _open(point: Vector2i) -> bool:
	## Never on a dead end: a place must not become the only way through.
	var exits := 0
	for direction in Spawn.DIRECTIONS:
		if terrain.walkable(point + direction): exits += 1
	return exits >= 2

func chunk_locations(chunk: Vector2i, bytes: PackedByteArray = PackedByteArray()) -> Array:
	## Establishes the chunk on first load (shared with creature encounters).
	last_error = ""
	var revision: int = ledger.establish(chunk, ledger.revision)
	if revision < 0:
		_fail(ledger.last_error)
		return []
	return preview_chunk(chunk, revision, ledger.layers(chunk), bytes)

func follow(tile: Vector2i, terrain_chunks: Dictionary) -> bool:
	var next := Terrain.chunk_of(tile)
	if next == center:
		return true
	var loaded := {}
	for y in range(next.y - 1, next.y + 2):
		for x in range(next.x - 1, next.x + 2):
			var chunk := Vector2i(x, y)
			if chunks.has(chunk):
				loaded[chunk] = chunks[chunk]
				continue
			loaded[chunk] = chunk_locations(chunk, terrain_chunks.get(chunk, PackedByteArray()))
			if not last_error.is_empty():
				return false
	chunks = loaded
	center = next
	return true

func loaded() -> Array:
	var result: Array = []
	for list in chunks.values():
		result.append_array(list)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.instance_id < b.instance_id)
	return result

func find(instance_id: String) -> Dictionary:
	for list in chunks.values():
		for instance in list:
			if instance.instance_id == instance_id:
				return instance
	return {}

func definition_for(instance: Dictionary) -> Dictionary:
	return definitions.get(_key(instance.content_id, int(instance.version)), {})

func event(ref: Dictionary) -> Dictionary:
	return definitions.get(_key(ref.content_id, int(ref.version)), {})

func materialize(instance: Dictionary) -> bool:
	var existing: Dictionary = registry.load_instance(world.world_id, instance.instance_id)
	if not existing.is_empty():
		if existing.content_id != instance.content_id or int(existing.version) != int(instance.version) or int(existing.position.x) != int(instance.position.x) or int(existing.position.y) != int(instance.position.y):
			return _fail("Established location conflicts with generated placement")
		return true
	if registry.last_error != "Content instance not found":
		return _fail(registry.last_error)
	if registry.create_instance(world.world_id, instance).is_empty():
		return _fail(registry.last_error)
	return true

func _sited(instance_id: String) -> bool:
	## Pinned destinations with leads: M03 structured regions or M04 atlas land sites.
	return (regions != null and instance_id.begins_with("loc:sw1/")) or (atlas_sites != null and instance_id.begins_with("loc:atlas/"))

func _key(content_id: String, version: int) -> String:
	return "%s@%d" % [content_id, version]

func _fail(message: String) -> bool:
	last_error = message
	return false

func clue(instance: Dictionary, include_frontiers: bool = false) -> String:
	if not _sited(str(instance.instance_id)): return ""
	var text := Structured.clue(instance, instance.get("metadata", {}).get("leads", []))
	if include_frontiers:
		for frontier in instance.get("metadata", {}).get("frontiers", []):
			text += " Beyond here: %s to the %s (%s). Route unsurveyed; water may require a detour." % [frontier.name, frontier.direction, frontier.opportunity]
	return text

func known_leads(mutations: Dictionary, from: Vector2i) -> Array:
	last_error = ""
	var found := {}
	for id in mutations:
		if not _sited(str(id)): continue
		if not mutations[id].get("location", false) or not mutations[id].get("discovered", false): continue
		var instance: Dictionary = registry.load_instance(world.world_id, id)
		if instance.is_empty():
			_fail(registry.last_error)
			return []
		for lead in instance.get("metadata", {}).get("leads", []):
			var result: Dictionary = lead.duplicate(true)
			result["knowledge"] = "discovered" if mutations.get(lead.instance_id, {}).get("discovered", false) else "lead"
			result["resolved"] = not mutations.get(lead.instance_id, {}).get("resolved", {}).is_empty()
			result["manhattan_distance"] = absi(int(lead.position.x) - from.x) + absi(int(lead.position.y) - from.y)
			found[lead.instance_id] = result
	var ids: Array = found.keys()
	ids.sort()
	var result: Array = []
	for id in ids: result.append(found[id])
	return result

func known_frontiers(mutations: Dictionary) -> Array:
	last_error = ""
	var found := {}
	for id in mutations:
		if not _sited(str(id)) or mutations[id].get("resolved", {}).is_empty(): continue
		var instance: Dictionary = registry.load_instance(world.world_id, id)
		if instance.is_empty():
			_fail(registry.last_error)
			return []
		for frontier in instance.get("metadata", {}).get("frontiers", []): found[frontier.region_id] = frontier.duplicate(true)
	var ids: Array = found.keys()
	ids.sort()
	var result: Array = []
	for id in ids: result.append(found[id])
	return result
