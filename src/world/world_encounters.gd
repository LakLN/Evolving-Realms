extends RefCounted
## Encounter layer v1 (Milestone 02 H): data-driven distribution of activated creature
## definitions on top of the frozen creature-generation v1 homes. A chunk's encounters
## are a pure function of World seed, terrain v1, the chunk and the encounter revision
## the chunk was established at (RegionLedger) — never Run, visit order or time.
const Terrain = preload("res://src/world/terrain_v1.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const Data = preload("res://src/data/json_data.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Region = preload("res://src/world/region_context.gd")
const Ledger = preload("res://src/world/region_ledger.gd")
const GENERATION_VERSION := 1
const BUDGET := 3 # Encounter homes per chunk, whatever the number of activated rules.
const MAX_TOTAL := 6 # Never more creature homes per chunk than v1 already allows.
const FIELDS := ["creature", "biomes", "per_10000", "max_per_chunk", "priority", "conditions"]
const CONDITIONS := {"danger": ["min", "max"], "biome_share": ["biome", "min_percent"], "near_terrain": ["terrain", "radius"]}
const NEAR := {"water": Terrain.WATER, "tree": Terrain.TREE, "rock": Terrain.ROCK}
var rules: Array = []
## Highest activation revision among active encounter definitions (0 = v1 only).
var revision := 0
var last_error := ""

func condition_names() -> Array:
	return CONDITIONS.keys()

static func classify(definition: Dictionary, registry: RefCounted, world_id: String) -> Dictionary:
	## Engine rules for an encounter definition: {problem, missing}. Unknown condition
	## types and fields are named capabilities, never guessed.
	var missing: Array = []
	var p: Variant = definition.get("payload")
	if not p is Dictionary:
		return {"problem": "Encounter payload must be an object", "missing": missing}
	for field in p:
		if field not in FIELDS: missing.append("payload.encounter." + str(field))
	var ref: Variant = p.get("creature")
	if not ref is Dictionary or not Data.identifier(ref.get("content_id")) or not Data.integer(ref.get("version")) or ref.version < 1:
		return {"problem": "Encounter needs creature content_id/version", "missing": missing}
	if not definition.get("dependencies", []).any(func(d: Variant) -> bool: return d is Dictionary and d.get("content_id") == ref.content_id and int(d.get("version", 0)) == int(ref.version)):
		return {"problem": "Encounter creature must be a pinned dependency", "missing": missing}
	var creature: Dictionary = registry.load_definition(world_id, ref.content_id, int(ref.version)) if registry != null else {}
	if registry != null and creature.get("kind") != "creature":
		return {"problem": "Encounter creature must be a creature definition", "missing": missing}
	var habitat: Array = creature.get("payload", {}).get("movement", {}).get("biomes", Terrain.BIOMES) if creature.get("payload", {}).get("movement") is Dictionary else Terrain.BIOMES
	if not p.get("biomes") is Array or p.biomes.is_empty() or p.biomes.size() > 3:
		return {"problem": "Encounter needs 1..3 biomes", "missing": missing}
	for biome in p.biomes:
		if biome not in Surfaces.HABITATS: return {"problem": "Unknown encounter biome: " + str(biome), "missing": missing}
		if biome not in habitat: return {"problem": "Encounter biome is outside the creature's movement biomes: " + str(biome), "missing": missing}
	if not _between(p.get("per_10000"), 1, 200): return {"problem": "Encounter per_10000 must be 1..200", "missing": missing}
	if not _between(p.get("max_per_chunk", 1), 1, BUDGET): return {"problem": "Encounter max_per_chunk must be 1..%d" % BUDGET, "missing": missing}
	if not _between(p.get("priority", 50), 0, 100): return {"problem": "Encounter priority must be 0..100", "missing": missing}
	var problem := check_spawn_conditions(p.get("conditions", []), missing, "encounter")
	if not problem.is_empty(): return {"problem": problem, "missing": missing}
	return {"problem": "", "missing": missing}

static func check_spawn_conditions(conditions: Variant, missing: Array, label: String) -> String:
	## Region/tile conditions shared by encounters and locations (danger, biome share,
	## nearby terrain). Unknown types are named `<label>.condition.<type>`.
	if not conditions is Array or conditions.size() > 4: return "Spawn conditions must be an array of at most 4"
	for condition in conditions:
		if not condition is Dictionary or not condition.get("type") is String: return "Spawn condition needs a type"
		if not CONDITIONS.has(condition.type):
			missing.append("%s.condition.%s" % [label, condition.type])
			continue
		for key in condition:
			if key != "type" and key not in CONDITIONS[condition.type]: missing.append("parameter.%s_condition.%s.%s" % [label, condition.type, key])
		match condition.type:
			"danger":
				if not _between(condition.get("min", 0), 0, 3) or not _between(condition.get("max", 3), 0, 3) or condition.get("min", 0) > condition.get("max", 3): return "Danger condition needs 0 <= min <= max <= 3"
			"biome_share":
				if condition.get("biome") not in Region.SURFACES or not _between(condition.get("min_percent"), 1, 100): return "Biome share needs a surface and min_percent 1..100"
			"near_terrain":
				if not NEAR.has(condition.get("terrain")) or not _between(condition.get("radius", 1), 1, 3): return "Near terrain needs water/tree/rock and radius 1..3"
	return ""

static func current_revision(registry: RefCounted, world_id: String) -> int:
	return Ledger.current_revision(registry, world_id) # Shared with locations (Checkpoint I).

static func _between(value: Variant, low: int, high: int) -> bool:
	return Data.integer(value) and value >= low and value <= high

func configure(registry: RefCounted, world_id: String, creatures: RefCounted) -> bool:
	rules.clear()
	revision = 0
	var headers: Array = registry.list_definitions(world_id)
	if not registry.last_error.is_empty():
		return _fail(registry.last_error)
	for header in headers:
		if header.kind != "encounter" or header.status != "active":
			continue # Pending/draft encounters (e.g. a pending creature) never spawn.
		var definition: Dictionary = registry.load_definition(world_id, header.content_id, int(header.version))
		if definition.is_empty():
			return _fail(registry.last_error)
		var verdict := classify(definition, registry, world_id)
		if not verdict.problem.is_empty() or not verdict.missing.is_empty():
			return _fail("Invalid encounter %s: %s %s" % [definition.content_id, verdict.problem, str(verdict.missing)])
		var stamp: Variant = definition.get("provenance", {}).get("encounter_revision")
		if not Data.integer(stamp) or stamp < 1:
			return _fail("Encounter has no activation revision: " + definition.content_id)
		var ref: Dictionary = definition.payload.creature
		var creature: Dictionary = creatures.definition_for({"content_id": ref.content_id, "version": int(ref.version)})
		if creature.is_empty():
			return _fail("Encounter creature is not an active, valid creature: %s %s" % [ref.content_id, creatures.last_error])
		rules.append({"definition": definition, "creature": creature, "revision": int(stamp), "stream": Loot.number("encounters-v1/" + definition.content_id)})
		revision = maxi(revision, int(stamp))
	last_error = ""
	return true

func rules_at(at_revision: int) -> Array:
	## Per encounter ID, the latest version activated at or before the revision.
	var latest := {}
	for rule in rules:
		var id: String = rule.definition.content_id
		if rule.revision <= at_revision and (not latest.has(id) or int(rule.definition.version) > int(latest[id].definition.version)):
			latest[id] = rule
	var result: Array = latest.values()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.definition.payload.get("priority", 50)) < int(b.definition.payload.get("priority", 50)) or (int(a.definition.payload.get("priority", 50)) == int(b.definition.payload.get("priority", 50)) and a.definition.content_id < b.definition.content_id))
	return result

func generate(terrain: RefCounted, chunk: Vector2i, bytes: PackedByteArray, at_revision: int, homes: Array) -> Array:
	## Encounter homes for one chunk; `homes` are the chunk's v1 placements (kept).
	var active := rules_at(at_revision)
	var budget := mini(BUDGET, MAX_TOTAL - homes.size())
	if active.is_empty() or budget <= 0:
		return []
	var occupied := {}
	for home in homes:
		occupied[Vector2i(int(home.position.x), int(home.position.y))] = true
	var shares := Region.biome_shares(bytes)
	var danger := Region.danger(terrain, chunk)
	var eligible := active.filter(func(rule: Dictionary) -> bool: return _chunk_allows(rule.definition.payload, shares, danger))
	var origin := chunk * Terrain.CHUNK_SIZE
	var order_stream := Loot.number("encounters-v1/order")
	var adaptive: bool = terrain.has_method("ecology_hosts") # Atlas lands: adapted ecology.
	var candidates: Array = []
	var seeds := PackedInt64Array()
	var chances := PackedInt32Array()
	for rule in eligible:
		seeds.append(terrain.stream_seed(rule.stream))
		chances.append(int(rule.definition.payload.per_10000))
	for y in Terrain.CHUNK_SIZE:
		for x in Terrain.CHUNK_SIZE:
			var ground: int = bytes[y * Terrain.CHUNK_SIZE + x]
			var point := origin + Vector2i(x, y)
			var habitat: String = Surfaces.HABITAT_OF.get(ground, "")
			if habitat.is_empty() or occupied.has(point):
				continue
			# Pure predicates: rolling first (rule order kept) selects the same rule.
			for i in Terrain.roll_rules(seeds, chances, point.x, point.y):
				var rule: Dictionary = eligible[i]
				var p: Dictionary = rule.definition.payload
				var strict: bool = adaptive and terrain.has_method("strict_ecology") and terrain.strict_ecology(point)
				if not ((not strict and habitat in p.biomes) or (adaptive and terrain.ecology_hosts(ground, point, str(p.creature.content_id)))) or not _tile_allows(terrain, chunk, bytes, point, p):
					continue
				candidates.append({"point": point, "local": Vector2i(x, y), "rule": rule, "order": terrain.coordinate_hash(point.x, point.y, order_stream)})
				break
	# Hash order spreads the budget over the chunk instead of favoring low IDs.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.order < b.order or (a.order == b.order and (a.point.y < b.point.y or (a.point.y == b.point.y and a.point.x < b.point.x))))
	var counts := {}
	var result: Array = []
	for candidate in candidates:
		if result.size() >= budget:
			break
		var definition: Dictionary = candidate.rule.definition
		var used: int = counts.get(definition.content_id, 0)
		if used >= int(definition.payload.get("max_per_chunk", 1)):
			continue
		counts[definition.content_id] = used + 1
		var creature: Dictionary = definition.payload.creature
		result.append({"instance_id": "enc:v%d/%d/%d/%d_%d" % [GENERATION_VERSION, chunk.x, chunk.y, candidate.local.x, candidate.local.y],
			"content_id": creature.content_id, "version": int(creature.version), "position": {"x": candidate.point.x, "y": candidate.point.y}, "origin": "procedural",
			"metadata": {"encounter_generation_version": GENERATION_VERSION, "encounter": {"content_id": definition.content_id, "version": int(definition.version)},
				"encounter_revision": candidate.rule.revision, "established_revision": at_revision}})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.instance_id < b.instance_id)
	return result

static func _chunk_allows(payload: Dictionary, shares: Dictionary, danger: int) -> bool:
	for condition in payload.get("conditions", []):
		match condition.type:
			"danger":
				if danger < int(condition.get("min", 0)) or danger > int(condition.get("max", 3)): return false
			"biome_share":
				if int(shares.get(condition.biome, 0)) < int(condition.min_percent): return false
	return true

static func _tile_allows(terrain: RefCounted, chunk: Vector2i, bytes: PackedByteArray, point: Vector2i, payload: Dictionary) -> bool:
	for condition in payload.get("conditions", []):
		if condition.type != "near_terrain":
			continue
		var wanted: int = NEAR[condition.terrain]
		var radius := int(condition.get("radius", 1))
		var found := false
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var tile := point + Vector2i(dx, dy)
				var value: int = bytes[Terrain.local_of(tile).y * Terrain.CHUNK_SIZE + Terrain.local_of(tile).x] if Terrain.chunk_of(tile) == chunk else terrain.tile_at(tile)
				found = found or value == wanted
		if not found: return false
	return true

func _fail(message: String) -> bool:
	last_error = message
	return false
