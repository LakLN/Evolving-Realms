extends RefCounted
## Small, deterministic rule vocabulary. Data supplies thresholds; character stats
## remain derived by CharacterStats. Rewards/costs commit through LocationRuntime.
const Data = preload("res://src/data/json_data.gd")

static func validate(properties: Variant, missing: Array) -> String:
	if not properties is Dictionary: return "World properties must be an object"
	for key in properties:
		if key not in ["version", "material", "fracture_attack", "thaw_fuel"]: missing.append("world_rule.property." + str(key))
	if properties.get("version") != 1: missing.append("world_rule.version." + str(properties.get("version")))
	if properties.get("material") != "ordinary_ice": missing.append("world_rule.material." + str(properties.get("material")))
	if not Data.integer(properties.get("fracture_attack")) or properties.fracture_attack < 1 or properties.fracture_attack > 1000: return "Ice fracture_attack must be 1..1000"
	if not properties.get("thaw_fuel") is Array or properties.thaw_fuel.is_empty() or properties.thaw_fuel.size() > 4: return "Ice needs 1..4 thaw fuel costs"
	for item in properties.thaw_fuel:
		if not item is Dictionary or not Data.identifier(item.get("content_id")) or not Data.integer(item.get("version")) or item.version < 1 or not Data.integer(item.get("quantity")) or item.quantity < 1 or item.quantity > 100: return "Invalid thaw fuel"
	return ""

static func response(properties: Dictionary, method: String, payload: Dictionary) -> Dictionary:
	## Shared state response, not a separate authored answer for each object. Base
	## events describe intact contents. Force destroys two thirds, and cuts hands;
	## heat uses the object's declared fuel through the ordinary atomic cost path.
	var result := payload.duplicate(true)
	if method == "heat":
		result.cost = {"items": properties.thaw_fuel.duplicate(true)}
	elif method == "force":
		for outcome in result.outcomes:
			if outcome.type == "grant_items":
				for item in outcome.items: item.quantity = maxi(1, int(item.get("quantity", 1)) / 3)
		result.outcomes.append({"type": "damage", "amount": 2})
	return result

static func requirement(session: RefCounted, properties: Dictionary, method: String) -> String:
	if method == "force" and int(session.combat_stats().attack) < int(properties.fracture_attack):
		return "Attack %d+ to fracture this ice (current %d); equipment and talents count" % [int(properties.fracture_attack), int(session.combat_stats().attack)]
	return ""

static func knowledge(method: String) -> Dictionary:
	if method == "heat":
		return {"id": "rules:ice_heat_v1", "category": "Materials", "title": "Thawing ordinary ice", "text": "A controlled resin-and-wood fire thaws ordinary ice around supplies. Each thaw consumes one Pine resin and one Wood. Thawing preserves the full contents; it does not consume HP. This applies to ordinary ice, not every frozen material."}
	return {"id": "rules:ice_force_v1", "category": "Materials", "title": "Fracturing ordinary ice", "text": "Icebound supplies can be freed by force when your current Attack reaches the object's fracture threshold. Equipment, talents and temporary stat effects count. Shattering costs 2 HP and destroys part of these fragile supplies. Inspect a discovered object to read its threshold; Knowledge is never required to try."}
