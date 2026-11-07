extends RefCounted
## Authored resident ecology v1. State filters gate initial arrival only; thereafter
## position/death/loot are normal Run mutations, never a chunk-local re-roll.
const Surfaces = preload("res://src/world/surfaces.gd")
const Data = preload("res://src/data/json_data.gd")

static func validate(home: Dictionary, terrain: RefCounted) -> String:
	var meta: Dictionary = home.get("metadata", {})
	if meta.has("residency_version") and (not Data.integer(meta.residency_version) or int(meta.residency_version) != 1): return "Unsupported resident ecology version"
	if meta.has("residency_version"):
		if terrain.get("variants") == null: return "Resident ecology requires an authored atlas resolver"
		if meta.has("weather") or meta.has("returns"): return "Resident ecology v1 cannot mix with weather/return homes"
		if not meta.get("habitats") is Array or meta.habitats.is_empty() or meta.habitats.any(func(h: Variant) -> bool: return h not in Surfaces.HABITATS): return "Unsupported resident habitat"
		var tile := Vector2i(int(home.position.x), int(home.position.y))
		if Surfaces.HABITAT_OF.get(terrain.tile_at(tile), "") not in meta.habitats or terrain.variants.footprint.has(tile): return "Resident home must be stable dry habitat"
	if not meta.has("world_state"): return ""
	if not meta.has("residency_version"): return "World-state arrivals require persistent residency"
	var rule: Variant = meta.world_state
	if not rule is Dictionary or not Data.identifier(rule.get("id")) or not Data.integer(rule.get("version")) or int(rule.version) != 1 or not rule.get("values") is Array or rule.values.is_empty(): return "Unsupported resident world-state condition"
	if terrain.get("variants") == null: return "Resident condition requires a world-state resolver"
	for d in terrain.variants.definitions:
		if d.id != rule.id or int(d.version) != int(rule.version): continue
		var known: Array = ["baseline"] + d.variants.map(func(v: Dictionary) -> String: return v.id)
		if rule.values.any(func(value: Variant) -> bool: return value not in known): return "Unknown resident world-state value"
		return ""
	return "Unknown resident world-state source"

static func eligible(rule: Dictionary, terrain: RefCounted) -> bool:
	var state: String = str(terrain.variants.active.get(rule.id, {}).get("id", "baseline"))
	return state in rule.values
