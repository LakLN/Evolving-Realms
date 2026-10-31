extends RefCounted
const Terrain = preload("res://src/world/terrain_v1.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
const PATH := "res://content/starter_pack.json"
const CREATURES_PATH := "res://content/creatures_pack.json"
const SURVIVAL_PATH := "res://content/survival_pack.json"
const EQUIPMENT_PATH := "res://content/equipment_pack.json"
const TALENT_PATH := "res://content/talent_pack.json"
const SKILL_PATH := "res://content/skill_pack.json"
const EFFECT_PATH := "res://content/effect_pack.json"
const WORLD_PATH := "res://content/world_pack.json"
const LOCATION_PATH := "res://content/location_pack.json"
const ALL_PATHS := [PATH, CREATURES_PATH, SURVIVAL_PATH, EQUIPMENT_PATH, TALENT_PATH, SKILL_PATH, EFFECT_PATH, WORLD_PATH, LOCATION_PATH] # Install order: dependencies first.
var last_error := ""

func install(registry: RefCounted, world_id: String, path: String = PATH) -> bool:
	# Packs are append-only data; each version-1 definition is registered once per world.
	var pack: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not pack is Dictionary or pack.get("pack_version") != 1 or not pack.get("definitions") is Array:
		last_error = "Starter content pack is missing or unsupported"
		return false
	for definition in pack.definitions:
		var existing: Dictionary = registry.load_definition(world_id, definition.content_id, int(definition.version))
		if existing.is_empty():
			if registry.last_error != "Content definition not found":
				last_error = registry.last_error
				return false
			if registry.register_definition(world_id, definition).is_empty():
				last_error = registry.last_error
				return false
		else:
			# Reserved pack IDs are immutable; never overwrite existing user content.
			for key in definition:
				if existing.get(key) != definition[key]:
					last_error = "Starter content conflicts with established definition " + str(definition.content_id)
					return false
	last_error = ""
	return true

static func blueprint(seed_value: int) -> Dictionary:
	var terrain := Terrain.new()
	if not terrain.configure(seed_value, 1):
		return {}
	var landmark := Spawn.select(terrain, 7301)
	if landmark.is_empty():
		return {}
	return {"fixed_locations": [{"id": "landmark:wayfarer_cache", "content_id": "core:wayfarer_cache", "version": 1, "position": landmark.position}], "metadata": {"starter_pack": 1}}
