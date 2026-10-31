extends RefCounted
## World events (Milestone 02 I): data-only consequences of discovering, entering or
## interacting with a location. Each outcome type has exactly one trusted handler in
## LocationRuntime; unknown outcome/condition types are named pending capabilities and
## never run. Conditions reuse the skill learn/use vocabulary plus three local types.
const Data = preload("res://src/data/json_data.gd")
const Effects = preload("res://src/core/effects.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Skills = preload("res://src/core/skills.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const FIELDS := ["conditions", "cost", "outcomes", "message", "tone"]
const TONES := ["boon", "bane", "neutral"]
const OUTCOMES := {"grant_items": ["items"], "loot": ["table"], "apply_status": ["content_id", "version"],
	"cleanse": ["harmful"], "heal": ["amount"], "damage": ["amount"], "sate": ["amount"], "quench": ["amount"],
	"xp": ["amount"], "restore": ["resource", "amount"]}
## Location-only conditions; every other known type is a skill condition.
const LOCAL_CONDITIONS := {"perception": [], "status": ["status"], "biome": ["values"], "any_of": ["conditions"]}

static func check_conditions(conditions: Variant, context: Dictionary, skills: RefCounted, missing: Array) -> String:
	if not conditions is Array or conditions.size() > 8:
		return "Conditions must be an array of at most 8"
	for condition in conditions:
		if not condition is Dictionary or not condition.get("type") is String:
			return "Condition needs a type"
		if LOCAL_CONDITIONS.has(condition.type):
			for key in condition:
				if key != "type" and key not in LOCAL_CONDITIONS[condition.type]: missing.append("parameter.location_condition.%s.%s" % [condition.type, key])
			match condition.type:
				"status":
					if not Data.identifier(condition.get("status")): return "Status condition needs a status ID"
				"biome":
					if not condition.get("values") is Array or condition.values.is_empty() or not condition.values.all(func(b: Variant) -> bool: return b in Terrain.BIOMES): return "Biome condition needs forest/beach/meadow values"
				"any_of":
					if not condition.get("conditions") is Array or condition.conditions.is_empty(): return "any_of needs conditions"
					var nested := check_conditions(condition.conditions, context, skills, missing)
					if not nested.is_empty(): return nested
		elif condition.type in Skills.CONDITIONS:
			var problem: String = skills.check_conditions([condition], context, missing)
			if not problem.is_empty(): return problem
		else:
			missing.append("location.condition." + condition.type) # Never treated as met.
	return ""

static func classify(definition: Dictionary, registry: RefCounted, world_id: String, context: Dictionary, skills: RefCounted) -> Dictionary:
	var missing: Array = []
	var p: Variant = definition.get("payload")
	if not p is Dictionary: return {"problem": "World event payload must be an object", "missing": missing}
	for field in p:
		if field not in FIELDS: missing.append("payload.world_event." + str(field))
	var problem := check_conditions(p.get("conditions", []), context, skills, missing)
	if not problem.is_empty(): return {"problem": problem, "missing": missing}
	if not p.get("message", "") is String or p.get("message", "").length() > 500: return {"problem": "Event message must be text up to 500 characters", "missing": missing}
	if p.get("tone", "neutral") not in TONES: return {"problem": "Event tone must be boon/bane/neutral", "missing": missing}
	var cost: Variant = p.get("cost", {})
	if not cost is Dictionary or not cost.get("items", []) is Array or cost.get("items", []).size() > 4: return {"problem": "Event cost must be {items: [...]} with at most 4 items", "missing": missing}
	for item in cost.get("items", []):
		problem = _item_ref(item, definition, registry, world_id)
		if not problem.is_empty(): return {"problem": "Cost: " + problem, "missing": missing}
	var outcomes: Variant = p.get("outcomes")
	if not outcomes is Array or outcomes.is_empty() or outcomes.size() > 8: return {"problem": "World event needs 1..8 outcomes", "missing": missing}
	for outcome in outcomes:
		if not outcome is Dictionary or not outcome.get("type") is String: return {"problem": "Outcome needs a type", "missing": missing}
		if not OUTCOMES.has(outcome.type):
			missing.append("event.outcome." + outcome.type)
			continue
		for key in outcome:
			if key != "type" and key not in OUTCOMES[outcome.type]: missing.append("parameter.event_outcome.%s.%s" % [outcome.type, key])
		match outcome.type:
			"grant_items":
				if not outcome.get("items") is Array or outcome.items.is_empty() or outcome.items.size() > 8: problem = "grant_items needs 1..8 items"
				else:
					for item in outcome.items:
						problem = _item_ref(item, definition, registry, world_id)
						if not problem.is_empty(): break
			"loot":
				var table := Loot.new()
				if not table.validate(outcome.get("table"), registry, world_id): problem = table.last_error
				else:
					for entry in outcome.table.get("entries", []) + outcome.table.get("guaranteed", []):
						if not _pinned(definition, entry): problem = "Loot must pin each item"
			"apply_status":
				problem = Effects.check_application(outcome, definition, registry, world_id, missing)
			"cleanse":
				if not outcome.get("harmful", true) is bool: problem = "cleanse needs harmful bool"
			"heal", "damage", "sate", "quench":
				if not _between(outcome.get("amount"), 1, 1000): problem = outcome.type + " needs amount 1..1000"
			"xp":
				if not _between(outcome.get("amount"), 1, 10000): problem = "xp needs amount 1..10000"
			"restore":
				if not skills.rules.get("resources", {}).has(outcome.get("resource")): missing.append("skill.resource." + str(outcome.get("resource")))
				elif not _between(outcome.get("amount"), 1, 1000): problem = "restore needs amount 1..1000"
		if not problem.is_empty(): return {"problem": problem, "missing": missing}
	return {"problem": "", "missing": missing}

static func _item_ref(item: Variant, definition: Dictionary, registry: RefCounted, world_id: String) -> String:
	if not item is Dictionary or not Data.identifier(item.get("content_id")) or not Data.integer(item.get("version")) or not _between(item.get("quantity", 1), 1, 100):
		return "Item needs content_id, version and quantity 1..100"
	if not _pinned(definition, item): return "Item must be a pinned dependency: " + str(item.content_id)
	if registry.load_definition(world_id, item.content_id, int(item.version)).get("kind") != "item": return "Not an item definition: " + str(item.content_id)
	return ""

static func _pinned(definition: Dictionary, ref: Dictionary) -> bool:
	return definition.get("dependencies", []).any(func(d: Variant) -> bool: return d is Dictionary and d.get("content_id") == ref.get("content_id") and int(d.get("version", 0)) == int(ref.get("version", -1)))

static func _between(value: Variant, low: int, high: int) -> bool:
	return Data.integer(value) and value >= low and value <= high

static func describe_condition(condition: Dictionary) -> String:
	match condition.get("type"):
		"perception": return "spiritual perception"
		"status": return "under " + str(condition.status).get_slice("/", 1).capitalize()
		"biome": return "in " + "/".join(condition.values)
		"any_of": return "one of (" + " or ".join(condition.conditions.map(func(c: Dictionary) -> String: return describe_condition(c))) + ")"
	return Skills.describe(condition)
