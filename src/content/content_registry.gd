extends RefCounted
## World-scoped, immutable and version-pinned content. No generated code execution.
const Data = preload("res://src/data/json_data.gd")
const SUPPORTED_CAPABILITIES := ["definition.item", "definition.resource", "definition.chest", "definition.creature", "definition.item_use", "definition.loot_extension"]
var _db: RefCounted
var last_error: String:
	get:
		return _db.last_error

func _init(database: RefCounted) -> void:
	_db = database

func register_definition(world_id: String, definition: Dictionary) -> Dictionary:
	if not _db.execute("BEGIN IMMEDIATE"):
		return {}
	var result := _register(world_id, definition)
	if result.is_empty():
		_db.rollback(_db.last_error)
		return {}
	if not _db.execute("COMMIT"):
		_db.rollback(_db.last_error)
		return {}
	return result

func _register(world_id: String, source: Dictionary) -> Dictionary:
	if not Data.valid(source):
		return _error("Content must contain only finite JSON data")
	var definition := source.duplicate(true)
	for field in ["content_id", "version", "kind", "name", "schema_version"]:
		if not definition.has(field):
			return _error("Missing content field: " + field)
	if definition.schema_version != 1 or not Data.integer(definition.schema_version):
		return _error("Unsupported content schema version")
	if not Data.identifier(definition.content_id) or not Data.integer(definition.version) or definition.version < 1:
		return _error("Invalid content ID or version")
	if not definition.kind is String or definition.kind.is_empty() or not definition.name is String or definition.name.is_empty():
		return _error("Content kind and name must be non-empty strings")
	for field in ["metadata", "payload", "provenance"]:
		if not definition.get(field, {}) is Dictionary:
			return _error(field + " must be an object")
		definition[field] = definition.get(field, {})
	for field in ["dependencies", "required_capabilities"]:
		if not definition.get(field, []) is Array:
			return _error(field + " must be an array")
		definition[field] = definition.get(field, [])
	if not definition.get("description", "") is String:
		return _error("Content description must be a string")
	definition.description = definition.get("description", "")
	var requested: Variant = definition.get("status", "active")
	if requested not in ["active", "hidden", "draft", "pending_capability", "invalid_conflicted"]:
		return _error("Invalid content status")
	if _db.rows("SELECT world_id FROM worlds WHERE world_id=?", [world_id]).is_empty():
		return _error("Unknown world")
	var prior: Array = _db.rows("SELECT MAX(version) AS latest FROM content_definitions WHERE world_id=? AND content_id=?", [world_id, definition.content_id])
	var latest: int = 0 if prior[0].latest == null else int(prior[0].latest)
	if int(definition.version) != latest + 1:
		return _error("Content versions are append-only and must increment by one")
	var missing: Array = []
	if "definition." + definition.kind not in SUPPORTED_CAPABILITIES:
		missing.append("definition." + definition.kind)
	for capability in definition.required_capabilities:
		if not capability is String or capability.is_empty():
			return _error("Invalid capability name")
		if capability not in SUPPORTED_CAPABILITIES and capability not in missing:
			missing.append(capability)
	var dependencies_seen: Array = []
	for dependency in definition.dependencies:
		if not dependency is Dictionary or not Data.identifier(dependency.get("content_id")) or not Data.integer(dependency.get("version")) or dependency.version < 1:
			return _error("Invalid dependency: expected content_id and positive version")
		if dependency.content_id == definition.content_id:
			return _error("Self-dependency is not allowed")
		var key := "%s@%d" % [dependency.content_id, dependency.version]
		if key in dependencies_seen:
			return _error("Duplicate dependency: " + key)
		dependencies_seen.append(key)
		var existing := load_definition(world_id, dependency.content_id, int(dependency.version))
		if existing.is_empty():
			return _error("Missing dependency: " + key)
		if existing.status != "active":
			missing.append("dependency:" + key)
	definition.missing_capabilities = missing
	definition.status = "pending_capability" if not missing.is_empty() and requested in ["active", "hidden", "pending_capability"] else requested
	if not _db.execute("INSERT INTO content_definitions(world_id,content_id,version,kind,status,definition_json) VALUES(?,?,?,?,?,?)", [world_id, definition.content_id, int(definition.version), definition.kind, definition.status, JSON.stringify(definition)]):
		return {}
	for dependency in definition.dependencies:
		if not _db.execute("INSERT INTO content_dependencies VALUES(?,?,?,?,?)", [world_id, definition.content_id, int(definition.version), dependency.content_id, int(dependency.version)]):
			return {}
	return definition

func load_definition(world_id: String, content_id: String, version: int) -> Dictionary:
	var rows: Array = _db.rows("SELECT definition_json FROM content_definitions WHERE world_id=? AND content_id=? AND version=?", [world_id, content_id, version])
	if rows.is_empty():
		if not _db.last_error.is_empty():
			return {}
		return _error("Content definition not found")
	var definition: Variant = JSON.parse_string(rows[0].definition_json)
	if not definition is Dictionary or definition.get("schema_version") != 1 or definition.get("content_id") != content_id or definition.get("version") != version or not definition.get("name") is String or not definition.get("kind") is String or definition.get("status") not in ["active", "pending_capability", "hidden", "draft", "invalid_conflicted"]:
		return _error("Corrupt or unsupported content definition")
	return definition

func list_definitions(world_id: String) -> Array:
	return _db.rows("SELECT content_id,version,kind,status FROM content_definitions WHERE world_id=? ORDER BY content_id,version", [world_id])

func create_instance(world_id: String, instance: Dictionary) -> Dictionary:
	if instance.get("schema_version", 1) != 1:
		return _error("Unsupported instance schema version")
	if not Data.valid(instance) or not Data.identifier(instance.get("instance_id")) or not Data.identifier(instance.get("content_id")) or not Data.integer(instance.get("version")) or not Data.position(instance.get("position")):
		return _error("Invalid instance ID, definition reference, position or JSON data")
	if instance.get("origin") not in ["authored", "procedural", "ai"] or not instance.get("metadata", {}) is Dictionary:
		return _error("Instance needs authored/procedural/ai origin and object metadata")
	var definition := load_definition(world_id, instance.content_id, int(instance.version))
	if definition.is_empty():
		return {}
	if definition.status != "active":
		return _error("Only active content may be instantiated")
	if not _db.execute("INSERT INTO content_instances(world_id,instance_id,content_id,version,instance_json) VALUES(?,?,?,?,?)", [world_id, instance.instance_id, instance.content_id, int(instance.version), JSON.stringify(instance)]):
		return {}
	return instance.duplicate(true)

func load_instance(world_id: String, instance_id: String) -> Dictionary:
	var rows: Array = _db.rows("SELECT instance_json FROM content_instances WHERE world_id=? AND instance_id=?", [world_id, instance_id])
	if rows.is_empty():
		if not _db.last_error.is_empty():
			return {}
		return _error("Content instance not found")
	var instance: Variant = JSON.parse_string(rows[0].instance_json)
	if not instance is Dictionary or instance.get("instance_id") != instance_id or not Data.position(instance.get("position")):
		return _error("Corrupt content instance")
	return instance

func list_instances(world_id: String) -> Array:
	var result: Array = []
	for row in _db.rows("SELECT instance_json FROM content_instances WHERE world_id=? ORDER BY instance_id", [world_id]):
		result.append(JSON.parse_string(row.instance_json))
	return result

func list_instances_in_bounds(world_id: String, min_x: int, min_y: int, max_x: int, max_y: int) -> Array:
	# Inclusive integer bounds. Keep gameplay SQL behind the existing registry API.
	var result: Array = []
	for row in _db.rows("SELECT instance_json FROM content_instances WHERE world_id=? AND json_extract(instance_json,'$.position.x') BETWEEN ? AND ? AND json_extract(instance_json,'$.position.y') BETWEEN ? AND ? ORDER BY instance_id", [world_id, min_x, max_x, min_y, max_y]):
		var instance: Variant = JSON.parse_string(row.instance_json)
		if not instance is Dictionary:
			_db.fail("Corrupt content instance")
			return []
		result.append(instance)
	return result

func _error(message: String) -> Dictionary:
	_db.fail(message)
	return {}
