extends RefCounted
## Explicit opt-in World creation. Existing Worlds never gain this flag on resume.
const PACK := "res://content/structured_world_pack.json"
const LAYERS := ["locations-v1", "structured-world-v1"]

static func enabled(world: Dictionary) -> bool:
	return world.get("blueprint", {}).get("metadata", {}).get("structured_world_version", 0) == 1

static func create(store: RefCounted, name: String, seed_value: int) -> Dictionary:
	return store.create_world(name, seed_value, 1, {"fixed_locations": [], "metadata": {"structured_world_version": 1}})

static func layers(world: Dictionary) -> Array:
	return LAYERS.duplicate() if enabled(world) else ["locations-v1"]

static func clue(instance: Dictionary, destinations: Array) -> String:
	var parts: Array[String] = []
	for point in destinations:
		if point.instance_id == instance.instance_id: continue
		parts.append("%s at (%d,%d)" % [point.metadata.title, int(point.position.x), int(point.position.y)])
	return "Inscriptions point to " + "; ".join(parts) + "." if not parts.is_empty() else ""
