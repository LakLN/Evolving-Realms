extends RefCounted
## Shared, bounded data vocabulary. No callbacks or executable code in definitions.
const Data = preload("res://src/data/json_data.gd")
const PATH := "res://content/effect_rules.json"

static func rules() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PATH))

static func integer(value: Variant, low: int, high: int) -> bool:
	return Data.integer(value) and value >= low and value <= high

static func check_modifier(value: Variant) -> String:
	if not value is Dictionary: return "Effect modifier must be an object"
	if value.get("type") not in ["damage", "healing", "resistance", "status_duration", "status_stacks"]:
		return "Unknown effect modifier"
	if value.has("status") and not Data.identifier(value.status): return "Modifier status must be an ID"
	if value.type == "resistance" and value.get("add", 0) != 0: return "Resistance uses percent"
	if value.type in ["status_duration", "status_stacks"] and value.get("percent", 0) != 0: return "Status duration/stacks use add"
	if value.has("element") and not rules().elements.has(value.element):
		return "Unknown modifier element"
	if not integer(value.get("percent", 0), -100, 500) or not integer(value.get("add", 0), -20, 20):
		return "Effect modifier outside bounds"
	if not value.get("conditions", []) is Array or value.get("conditions", []).size() > 8:
		return "Effect modifier needs at most 8 conditions"
	for condition in value.get("conditions", []):
		if not condition is Dictionary: return "Effect condition must be an object"
		if condition.get("type") not in ["target_status", "source_status", "hp_below_percent", "hp_at_least_percent"]:
			return "Unknown effect modifier condition"
		if condition.type.ends_with("status"):
			if not Data.identifier(condition.get("status")):
				return "Condition needs status ID"
		elif not integer(condition.get("value"), 1, 100):
			return "Condition needs HP percent 1..100"
	return ""

static func classify(definition: Dictionary) -> Dictionary:
	var missing: Array = []
	var problem := ""
	var p: Dictionary = definition.get("payload", {})
	if definition.get("status", "active") != "active": missing.append("effect.status." + str(definition.get("status")))
	if not p.get("modifiers", []) is Array: return {"missing": missing, "problem": "Status modifiers must be an array"}
	if not rules().elements.has(p.get("element", "neutral")):
		missing.append("effect.element." + str(p.get("element")))
	if not integer(p.get("duration"), 1, 100) or not integer(p.get("max_stacks", 1), 1, 20) or p.get("refresh", "refresh") not in ["keep", "refresh", "extend"] or not p.get("harmful", true) is bool:
		problem = "Status needs bounded duration, stacks, refresh and harmful flag"
	if not integer(p.get("skip_every", 0), 0, 10):
		problem = "Status skip_every must be 0..10"
	if p.has("tick"):
		if not p.tick is Dictionary or not p.tick.get("type") is String:
			problem = "Invalid status tick"
		elif p.tick.type not in ["damage", "heal"]:
			missing.append("effect.tick." + p.tick.type)
		elif not integer(p.tick.get("amount"), 1, 1000):
			problem = "Status tick amount must be 1..1000"
	for modifier in p.get("modifiers", []):
		if not modifier is Dictionary or modifier.get("stat") not in ["attack", "defense", "max_hp"] or not integer(modifier.get("add", 0), -1000, 1000) or not integer(modifier.get("percent", 0), -90, 500):
			problem = "Invalid status stat modifier"
	for key in p:
		if key not in ["element", "duration", "max_stacks", "refresh", "harmful", "tick", "skip_every", "modifiers"]: missing.append("effect.status_field." + str(key))
	for capability in definition.get("required_capabilities", []):
		missing.append(capability)
	return {"missing": missing, "problem": problem}

static func check_application(effect: Dictionary, definition: Dictionary, registry: RefCounted, world_id: String, missing: Array) -> String:
	if not Data.identifier(effect.get("content_id")) or not integer(effect.get("version"), 1, 1000000): return "Status needs pinned content_id/version"
	var pinned: bool = definition.get("dependencies", []).any(func(d: Dictionary) -> bool: return d.content_id == effect.content_id and int(d.version) == int(effect.version))
	if not pinned: return "Status must be a pinned dependency"
	if registry != null:
		var status: Dictionary = registry.load_definition(world_id, effect.content_id, int(effect.version))
		if status.get("kind") != "status": return "Missing pinned status definition"
		var verdict := classify(status)
		missing.append_array(verdict.missing)
		return verdict.problem
	return ""

static func valid_record(record: Dictionary) -> bool:
	return Data.identifier(record.get("id")) and integer(record.get("version"), 1, 1000000) and record.get("source") is Dictionary and Data.identifier(record.source.get("content_id")) and integer(record.source.get("version"), 1, 1000000) and record.source.get("actor") is String and record.get("target") is String and integer(record.get("remaining"), 1, 100) and integer(record.get("stacks"), 1, 20) and integer(record.get("last_tick"), 0, 1000000000) and integer(record.get("last_aged", 0), 0, 1000000000) and record.get("inputs") is Dictionary and integer(record.inputs.get("power"), 0, 1000) and integer(record.inputs.get("max_stacks"), 1, 20) and record.stacks <= record.inputs.max_stacks

static func has_status(statuses: Array, id: String) -> bool:
	return statuses.any(func(s: Dictionary) -> bool: return s.id == id)

static func matches(modifier: Dictionary, source: Dictionary, target: Dictionary, elements: Array, status: String = "") -> bool:
	if modifier.has("element") and modifier.element not in elements:
		return false
	if modifier.has("status") and modifier.status != status:
		return false
	for c in modifier.get("conditions", []):
		match c.type:
			"target_status":
				if not has_status(target.get("statuses", []), c.status): return false
			"source_status":
				if not has_status(source.get("statuses", []), c.status): return false
			"hp_below_percent":
				if int(source.hp) * 100 >= int(source.max_hp) * int(c.value): return false
			"hp_at_least_percent":
				if int(source.hp) * 100 < int(source.max_hp) * int(c.value): return false
	return true

static func damage(amount: int, elements: Array, source: Dictionary, target: Dictionary) -> int:
	# Flat additions -> additive outgoing % -> average per-element resistance -> clamp.
	var flat := 0
	var percent := 0
	for m in source.get("modifiers", []):
		if m.type == "damage" and matches(m, source, target, elements):
			flat += int(m.get("add", 0))
			percent += int(m.get("percent", 0))
	var resistance := 0
	for element in elements:
		var subtotal := 0
		for m in target.get("modifiers", []):
			if m.type == "resistance" and matches(m, target, source, [element]): subtotal += int(m.get("percent", 0))
		resistance += clampi(subtotal, -100, 100)
	resistance = resistance / maxi(1, elements.size())
	return maxi(0, (amount + flat) * maxi(0, 100 + percent) / 100 * (100 - resistance) / 100)
