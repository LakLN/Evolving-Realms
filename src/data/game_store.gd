extends RefCounted
## Public data facade for gameplay. Empty results/false mean failure; read last_error.
const Database = preload("res://src/data/database.gd")
const Data = preload("res://src/data/json_data.gd")
const Registry = preload("res://src/content/content_registry.gd")
const FogMask = preload("res://src/run/fog_mask.gd")
var _db := Database.new()
var content := Registry.new(_db)
var last_error: String:
	get:
		return _db.last_error
var last_backup_path: String:
	get:
		return _db.last_backup_path

func open(path: String = "user://realms.sqlite") -> bool:
	return _db.open(path)

func close() -> void:
	_db.close()

func create_world(name: String, seed_value: int, generation_version: int = 1, blueprint: Dictionary = {"fixed_locations": [], "metadata": {}}) -> Dictionary:
	if name.strip_edges().is_empty() or not Data.seed_value(seed_value) or generation_version != 1:
		return _error("World needs a name, signed 32-bit seed and supported generation version 1")
	if not Data.valid(blueprint) or not blueprint.get("fixed_locations") is Array or not blueprint.get("metadata") is Dictionary:
		return _error("Blueprint needs finite JSON, fixed_locations array and metadata object")
	if not _supported_atlas(blueprint):
		return _error("Unsupported world atlas version or atlas blueprint with fixed locations")
	if blueprint.metadata.has("structured_world_version") and (not Data.integer(blueprint.metadata.structured_world_version) or blueprint.metadata.structured_world_version != 1):
		return _error("Unsupported structured World Core version; existing save was not changed")
	var world_id := Data.uuid()
	if not _db.execute("INSERT INTO worlds VALUES(?,?,?,?,?,?,?)", [world_id, name, seed_value, generation_version, 1, JSON.stringify(blueprint), _timestamp()]):
		return {}
	return load_world(world_id)

func load_world(world_id: String) -> Dictionary:
	var rows := _db.rows("SELECT * FROM worlds WHERE world_id=?", [world_id])
	if rows.is_empty():
		if not last_error.is_empty():
			return {}
		return _error("World not found")
	var world: Dictionary = rows[0]
	if world.schema_version != 1 or world.generation_version != 1:
		return _error("Unsupported world schema or generator version")
	var blueprint: Variant = JSON.parse_string(world.blueprint_json)
	if not blueprint is Dictionary or not blueprint.get("fixed_locations") is Array or not blueprint.get("metadata") is Dictionary:
		return _error("Corrupt world blueprint")
	if not _supported_atlas(blueprint):
		return _error("Unsupported world atlas version; existing save was not changed")
	if blueprint.metadata.has("structured_world_version") and (not Data.integer(blueprint.metadata.structured_world_version) or blueprint.metadata.structured_world_version != 1):
		return _error("Unsupported structured World Core version; existing save was not changed")
	world.erase("blueprint_json")
	world.blueprint = blueprint
	return world

func list_worlds() -> Array:
	return _db.rows("SELECT world_id,name,seed,generation_version,schema_version,created_at FROM worlds ORDER BY created_at,world_id")

func create_run(world_id: String, seed_value: int, spawn: Dictionary, mode: String = "normal", stats: Dictionary = {}) -> Dictionary:
	if not Data.seed_value(seed_value) or mode not in ["normal", "permadeath"] or not Data.valid(stats):
		return _error("Invalid run seed, mode or stats")
	if not Data.valid(spawn) or not Data.position(spawn.get("position")) or not spawn.get("biome") is String or spawn.biome.is_empty():
		return _error("Spawn needs integer position and a non-empty biome")
	if load_world(world_id).is_empty():
		return {}
	var state := {
		"status": "alive", "turn": 0,
		"character": {"position": spawn.position.duplicate(true), "stats": stats.duplicate(true)},
		"inventory": {}, "explored": [], "entity_mutations": {}, "map_waypoint": {},
	}
	var run_id := Data.uuid()
	if not _db.execute("INSERT INTO runs(run_id,world_id,seed,schema_version,mode,spawn_json,state_json,created_at) VALUES(?,?,?,?,?,?,?,?)", [run_id, world_id, seed_value, 1, mode, JSON.stringify(spawn), JSON.stringify(state), _timestamp()]):
		return {}
	return load_run(run_id)

func load_run(run_id: String) -> Dictionary:
	# One SELECT gives a consistent snapshot of state, revision and mutations,
	# even if another connection commits a save while this run is being loaded.
	var rows := _db.rows("SELECT runs.*, (SELECT json_group_object(instance_id,json(state_json)) FROM run_entity_states WHERE run_entity_states.run_id=runs.run_id) AS mutations_json FROM runs WHERE run_id=?", [run_id])
	if rows.is_empty():
		if not last_error.is_empty():
			return {}
		return _error("Run not found")
	var run: Dictionary = rows[0]
	if run.schema_version != 1:
		return _error("Unsupported run schema version")
	if load_world(run.world_id).is_empty():
		return {}
	var state: Variant = JSON.parse_string(run.state_json)
	var spawn: Variant = JSON.parse_string(run.spawn_json)
	var mutations: Variant = JSON.parse_string(run.mutations_json)
	if not state is Dictionary or not spawn is Dictionary or not mutations is Dictionary or not Data.position(spawn.get("position")) or not spawn.get("biome") is String:
		return _error("Corrupt run data")
	run.erase("state_json")
	run.erase("spawn_json")
	run.erase("mutations_json")
	run.spawn = spawn
	run.state = state
	run.state["entity_mutations"] = mutations
	run.state["map_waypoint"] = run.state.get("map_waypoint", {})
	if not _validate_state(run.world_id, run.state):
		return {}
	return run

func list_runs(world_id: String) -> Array:
	return _db.rows("SELECT run_id,world_id,seed,schema_version,mode,revision,created_at,json_extract(state_json,'$.status') AS status FROM runs WHERE world_id=? ORDER BY created_at,run_id", [world_id])

func save_run(run_id: String, expected_revision: int, state: Dictionary) -> bool:
	if not _db.execute("BEGIN IMMEDIATE"):
		return false
	# Only the header is needed here; re-reading and re-validating the whole old state
	# made every save cost twice its size (matters for per-action permadeath commits).
	var rows := _db.rows("SELECT world_id,mode,revision,schema_version,json_extract(state_json,'$.status') AS status FROM runs WHERE run_id=?", [run_id])
	if rows.is_empty():
		return _db.rollback(last_error if not last_error.is_empty() else "Run not found")
	var run: Dictionary = rows[0]
	if run.schema_version != 1:
		return _db.rollback("Unsupported run schema version")
	if run.revision != expected_revision:
		return _db.rollback("Stale run revision; reload before saving")
	if run.mode == "permadeath" and run.status == "dead":
		return _db.rollback("A dead permadeath run is read-only")
	if run.mode == "normal" and state.get("status") == "dead":
		return _db.rollback("Normal-mode death is never saved; the last living save stays authoritative")
	if not _validate_state(run.world_id, state):
		return _db.rollback(last_error)
	var body := state.duplicate() # Shallow: only the mutation map is dropped from the body.
	body.erase("entity_mutations")
	if not _db.execute("UPDATE runs SET state_json=?,revision=revision+1 WHERE run_id=? AND revision=?", [JSON.stringify(body), run_id, expected_revision]):
		return _db.rollback(last_error)
	if not _db.execute("DELETE FROM run_entity_states WHERE run_id=?", [run_id]):
		return _db.rollback(last_error)
	for instance_id in state.entity_mutations:
		if not _db.execute("INSERT INTO run_entity_states VALUES(?,?,?,?)", [run_id, run.world_id, instance_id, JSON.stringify(state.entity_mutations[instance_id])]):
			return _db.rollback(last_error)
	if not _db.execute("COMMIT"):
		return _db.rollback(last_error)
	return true

func _validate_state(world_id: String, state: Dictionary) -> bool:
	if not Data.valid(state) or state.size() != 7:
		return _db.fail("Run state must have exactly seven supported fields and finite JSON data")
	for key in ["status", "turn", "character", "inventory", "explored", "entity_mutations", "map_waypoint"]:
		if not state.has(key):
			return _db.fail("Missing run state field: " + key)
	if state.status not in ["alive", "dead"] or not Data.integer(state.turn) or state.turn < 0:
		return _db.fail("Invalid run status or turn")
	if not state.character is Dictionary or not Data.position(state.character.get("position")) or not state.character.get("stats") is Dictionary:
		return _db.fail("Character needs integer position and object stats")
	if not state.inventory is Dictionary or not state.explored is Array or not state.entity_mutations is Dictionary:
		return _db.fail("Invalid inventory, explored or entity_mutations container")
	if not state.map_waypoint is Dictionary or (not state.map_waypoint.is_empty() and not Data.position(state.map_waypoint)):
		return _db.fail("Map waypoint must be empty or an integer tile position")
	if not FogMask.valid_all(state.explored):
		return _db.fail("Explored entries must be integer tiles or 32x32 chunk masks")
	for content_id in state.inventory:
		var stack: Variant = state.inventory[content_id]
		if not Data.identifier(content_id) or not stack is Dictionary or not Data.integer(stack.get("version")) or not Data.integer(stack.get("quantity")) or stack.version < 1 or stack.quantity < 1:
			return _db.fail("Inventory requires content ID -> {version, positive quantity}")
		var definition := content.load_definition(world_id, content_id, int(stack.version))
		if definition.is_empty():
			return false
		if definition.status != "active":
			return _db.fail("Inventory cannot use inactive content")
	for instance_id in state.entity_mutations:
		if not state.entity_mutations[instance_id] is Dictionary:
			return _db.fail("Entity mutation must be an object")
	if not state.entity_mutations.is_empty():
		# One query for all referenced instances (was one SELECT + parse per mutation).
		var ids: Array = state.entity_mutations.keys()
		var found: Array = _db.rows("SELECT COUNT(*) AS known FROM content_instances WHERE world_id=? AND instance_id IN (SELECT value FROM json_each(?))", [world_id, JSON.stringify(ids)])
		if found.is_empty():
			return false
		if int(found[0].known) != ids.size():
			return _db.fail("Content instance not found")
	return true

static func _supported_atlas(blueprint: Dictionary) -> bool:
	## Milestone 04 atlas Worlds: the row keeps generation_version 1 (schema CHECK); the
	## blueprint declares world_atlas_version 1 and each land plan pins its terrain version.
	## Unknown atlas versions are refused; atlas blueprints carry no fixed landmarks.
	if not blueprint.metadata.has("world_atlas_version"):
		return true
	var atlas: Variant = blueprint.metadata.world_atlas_version
	return Data.integer(atlas) and int(atlas) == 1 and blueprint.fixed_locations.is_empty() and not blueprint.metadata.has("structured_world_version")

func _error(message: String) -> Dictionary:
	_db.fail(message)
	return {}

func _timestamp() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"
