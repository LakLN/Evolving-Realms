extends RefCounted
## Composable creature traits: each trait is a bounded data part read by one generic
## handler (fear of elements in creature_ai.gd, resistances in the shared effect
## engine, charge and ally calls in creature_roster.gd). A creature's traits are its
## payload.traits plus the `assign` overlay for established v1 definitions.
const Effects = preload("res://src/core/effects.gd")
const PATH := "res://content/creature_traits.json"
const FIELDS := ["name", "description", "fears_elements", "effect_modifiers", "call_allies", "charge", "ranged"]
static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_rules = parsed if parsed is Dictionary and parsed.get("version") == 1 and validate(parsed).is_empty() else {"version": 1, "traits": {}, "assign": {}}
		if not (parsed is Dictionary and validate(parsed).is_empty()):
			push_error("Creature traits rejected: " + (validate(parsed) if parsed is Dictionary else "not an object"))
	return _rules

static func validate(data: Dictionary) -> String:
	if not data.get("traits") is Dictionary or not data.get("assign", {}) is Dictionary:
		return "traits and assign must be objects"
	for id in data.traits:
		var part: Variant = data.traits[id]
		if not part is Dictionary or not part.get("name") is String:
			return "Trait %s needs a name" % id
		for key in part:
			if key not in FIELDS: return "Trait %s: unknown field %s" % [id, key]
		for element in part.get("fears_elements", []):
			if not Effects.rules().elements.has(element): return "Trait %s: unknown element %s" % [id, element]
		for modifier in part.get("effect_modifiers", []):
			var problem := Effects.check_modifier(modifier)
			if not problem.is_empty(): return "Trait %s: %s" % [id, problem]
		var charge: Dictionary = part.get("charge", {})
		if not charge.is_empty() and (int(charge.get("min", 0)) < 2 or int(charge.get("max", 0)) < int(charge.min) or int(charge.max) > 5 or int(charge.get("attack_percent", 0)) < 100 or int(charge.attack_percent) > 400 or int(charge.get("cooldown_turns", 0)) < 1):
			return "Trait %s: charge needs min 2..max<=5, attack_percent 100..400, cooldown >= 1" % id
		var call: Dictionary = part.get("call_allies", {})
		var ranged: Dictionary = part.get("ranged", {})
		if not ranged.is_empty() and (not Effects.integer(ranged.get("min"), 2, 8) or not Effects.integer(ranged.get("max"), 2, 8) or not Effects.integer(ranged.get("cooldown_turns"), 1, 20) or int(ranged.min) < 2 or int(ranged.max) < int(ranged.min) or int(ranged.max) > 8 or int(ranged.cooldown_turns) < 1 or int(ranged.cooldown_turns) > 20):
			return "Trait %s: ranged needs integer min 2..max<=8 and cooldown 1..20" % id
		if not call.is_empty() and (int(call.get("radius", 0)) < 1 or int(call.radius) > 16 or int(call.get("alert_turns", 0)) < 1):
			return "Trait %s: call_allies needs radius 1..16 and alert_turns >= 1" % id
	for content_id in data.get("assign", {}):
		for id in data.assign[content_id]:
			if not data.traits.has(id): return "Unknown trait %s assigned to %s" % [id, content_id]
	return ""

static func ids(definition: Dictionary) -> Array:
	var result: Array = rules().assign.get(str(definition.get("content_id", "")), []).duplicate()
	for id in definition.get("payload", {}).get("traits", []):
		if id not in result and rules().traits.has(id):
			result.append(id)
	return result

static func of(definition: Dictionary) -> Dictionary:
	## Merged parts: {names, fears, effect_modifiers, charge, call_allies}.
	var merged := {"names": [], "fears": [], "effect_modifiers": [], "charge": {}, "call_allies": {}, "ranged": {}}
	for id in ids(definition):
		var part: Dictionary = rules().traits[id]
		merged.names.append(part.name)
		for element in part.get("fears_elements", []):
			if element not in merged.fears: merged.fears.append(element)
		merged.effect_modifiers.append_array(part.get("effect_modifiers", []))
		if part.has("charge"): merged.charge = part.charge
		if part.has("call_allies"): merged.call_allies = part.call_allies
		if part.has("ranged"): merged.ranged = part.ranged
	return merged

static func described(definition: Dictionary) -> Array:
	## [{name, description}] for UI.
	return ids(definition).map(func(id: String) -> Dictionary: return {"name": rules().traits[id].name, "description": rules().traits[id].get("description", "")})
