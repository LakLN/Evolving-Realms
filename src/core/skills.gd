extends RefCounted
## Skill resources (content/skill_rules.json) and validation of `skill` definitions,
## skill books and gear skill modifiers. A skill is data: a type (active / passive /
## triggered), learn and use conditions, costs, cooldown, a target rule and effects
## from the closed vocabulary below. Passive and triggered skills reuse the talent
## power vocabulary (Talents.check_powers) and run on the same TalentRuntime.
## Anything unknown is a pending capability: listed, never learnable, never executed.
const Data = preload("res://src/data/json_data.gd")
const PATH := "res://content/skill_rules.json"
const TYPES := ["active", "passive", "triggered"]
## Target kind -> effects its handlers can execute.
const TARGETS := {"self": ["heal", "need", "status", "restore"], "creature": ["strike", "stun"], "tile": ["blink"]}
const CONDITIONS := ["level", "stat", "skill_known", "talent", "item", "equipped", "hp_below_percent", "hp_at_least_percent", "need_below", "any_of"]
const RELATIONS := ["prerequisite", "conflicts", "follow_up"]
const NEED_LEVELS := ["fine", "warning", "danger", "depleted"]
var rules: Dictionary = {}
var last_error := ""

func load_rules(path: String = PATH) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("rules_version") != 1 or not parsed.get("resources") is Dictionary or parsed.resources.is_empty():
		return _fail("Skill rules are missing or unsupported")
	for id in parsed.resources:
		var resource: Variant = parsed.resources[id]
		if not Data.identifier("r:" + str(id)) or not resource is Dictionary or not resource.get("name") is String or not resource.get("short") is String:
			return _fail("Skill resource %s needs an id, name and short label" % id)
		for field in [["base_max", 1, 10000], ["per_level", 0, 1000], ["regen_per_turn", 0, 100], ["rest_regen_per_turn", 0, 100]]:
			if not _int_in(resource.get(field[0]), field[1], field[2]):
				return _fail("Skill resource %s.%s must be %d..%d" % [id, field[0], field[1], field[2]])
	if not parsed.get("learning") is Dictionary or not _int_in(parsed.learning.get("max_known"), 0, 10000):
		return _fail("Skill learning.max_known must be 0 (no limit) or more")
	rules = parsed
	last_error = ""
	return true

func resource_ids() -> Array:
	var ids: Array = rules.resources.keys()
	ids.sort()
	return ids

func max_resource(resource_id: String, level: int) -> int:
	var resource: Dictionary = rules.resources[resource_id]
	return int(resource.base_max) + int(resource.per_level) * maxi(0, level - 1)

func catalog(registry: RefCounted, world_id: String, context: Dictionary) -> Dictionary:
	## {definitions: {"id@v": skill}, supported: {"id@v": true}, pending: [...], books:
	## {"item@v": skill_book}} or {error}. context: stats, needs, slots, talents (rules).
	var definitions := {}
	var supported := {}
	var pending: Array = []
	var books := {}
	var headers: Array = registry.list_definitions(world_id)
	for header in headers:
		if header.kind != "skill":
			continue
		var definition: Dictionary = registry.load_definition(world_id, header.content_id, int(header.version))
		if definition.is_empty():
			return {"error": registry.last_error}
		var key := "%s@%d" % [header.content_id, int(header.version)]
		definitions[key] = definition
		var verdict := classify(definition, context, registry, world_id)
		if not verdict.problem.is_empty():
			return {"error": "%s: %s" % [key, verdict.problem]}
		if verdict.missing.is_empty():
			supported[key] = true
		else:
			pending.append({"content_id": header.content_id, "version": int(header.version), "missing": verdict.missing})
	for header in headers:
		if header.kind != "item" or header.status != "active":
			continue
		var item: Dictionary = registry.load_definition(world_id, header.content_id, int(header.version))
		var payload: Dictionary = item.get("payload", {})
		for modifier in payload.get("equipment", {}).get("skill_modifiers", []):
			var problem: String = "Invalid skill modifier" if not modifier is Dictionary else context.talents.check_skill_modifier(modifier)
			if not problem.is_empty():
				return {"error": "%s: %s" % [header.content_id, problem]}
		if not payload.has("skill_book"):
			continue
		var book: Variant = payload.skill_book
		var skill: Variant = book.get("skill") if book is Dictionary else null
		if not skill is Dictionary or not Data.identifier(skill.get("content_id")) or not Data.integer(skill.get("version")) or not book.get("consume_on_learn", true) is bool:
			return {"error": "%s: skill_book needs skill {content_id, version} and consume_on_learn" % header.content_id}
		var pinned: bool = item.get("dependencies", []).any(func(dependency: Dictionary) -> bool: return dependency.content_id == skill.content_id and int(dependency.version) == int(skill.version))
		if not pinned or not definitions.has("%s@%d" % [skill.content_id, int(skill.version)]):
			return {"error": "%s: a skill book must pin an existing skill as a dependency" % header.content_id}
		books["%s@%d" % [header.content_id, int(header.version)]] = book
	return {"definitions": definitions, "supported": supported, "pending": pending, "books": books}

func classify(definition: Dictionary, context: Dictionary, registry: RefCounted = null, world_id: String = "") -> Dictionary:
	var missing: Array = []
	if definition.get("status") != "active":
		missing.append_array(definition.get("missing_capabilities", []))
		if missing.is_empty():
			missing.append("status:" + str(definition.get("status")))
	var payload: Variant = definition.get("payload")
	if not payload is Dictionary or not payload.get("type") is String:
		return {"missing": missing, "problem": "Skill payload needs a type"}
	if not payload.get("tags", []) is Array or not payload.get("tags", []).all(func(tag: Variant) -> bool: return tag is String):
		return {"missing": missing, "problem": "Skill tags must be strings"}
	var learn: Variant = payload.get("learn", {})
	if not learn is Dictionary:
		return {"missing": missing, "problem": "Skill learn must be an object"}
	var problem := check_conditions(learn.get("conditions", []), context, missing)
	if not problem.is_empty():
		return {"missing": missing, "problem": "learn: " + problem}
	if not payload.get("relations", []) is Array:
		return {"missing": missing, "problem": "Skill relations must be an array"}
	for relation in payload.get("relations", []):
		if not relation is Dictionary or not Data.identifier(relation.get("skill")) or not relation.get("type") is String:
			return {"missing": missing, "problem": "Skill relations need type and skill"}
		if relation.type not in RELATIONS:
			missing.append("skill.relation." + relation.type)
	if payload.type not in TYPES:
		missing.append("skill.type." + payload.type)
		return {"missing": missing, "problem": ""}
	if payload.type != "active":
		if payload.get("passive", []).is_empty() and payload.get("abilities", []).is_empty():
			return {"missing": missing, "problem": "A passive or triggered skill needs passive effects or abilities"}
		for field in ["passive", "abilities"]:
			if not payload.get(field, []) is Array or payload.get(field, []).size() > 8:
				return {"missing": missing, "problem": "Skill %s must be an array of at most 8" % field}
		return {"missing": missing, "problem": context.talents.check_powers(definition, payload, context.stats, context.needs, registry, world_id, missing)}
	var use: Variant = payload.get("use")
	if not use is Dictionary or not use.get("cost", {}) is Dictionary or not use.get("target") is Dictionary or not use.target.get("kind") is String:
		return {"missing": missing, "problem": "An active skill needs use {cost, target {kind}}"}
	problem = check_conditions(use.get("conditions", []), context, missing)
	if not problem.is_empty():
		return {"missing": missing, "problem": "use: " + problem}
	if not _int_in(use.get("cooldown_turns", 0), 0, 10000):
		return {"missing": missing, "problem": "cooldown_turns must be 0..10000"}
	for key in use.cost:
		if key == "hp":
			if not _int_in(use.cost.hp, 0, 1000):
				return {"missing": missing, "problem": "hp cost must be 0..1000"}
		elif key == "items":
			if not use.cost.items is Array:
				return {"missing": missing, "problem": "item costs must be an array"}
			for item in use.cost.items:
				if not item is Dictionary or not Data.identifier(item.get("content_id")) or not Data.integer(item.get("version")) or not _int_in(item.get("quantity"), 1, 1000):
					return {"missing": missing, "problem": "item costs need content_id, version, quantity"}
				if not definition.get("dependencies", []).any(func(dependency: Dictionary) -> bool: return dependency.content_id == item.content_id and int(dependency.version) == int(item.version)):
					return {"missing": missing, "problem": "an item cost must be a pinned dependency: " + item.content_id}
		elif rules.resources.has(key):
			if not _int_in(use.cost[key], 0, 10000):
				return {"missing": missing, "problem": "%s cost must be 0..10000" % key}
		else:
			missing.append("skill.resource." + str(key)) # e.g. mana, qi: not implemented yet.
	var target: Dictionary = use.target
	if not TARGETS.has(target.kind):
		missing.append("skill.target." + target.kind)
		return {"missing": missing, "problem": ""}
	if target.kind != "self" and (not _int_in(target.get("range"), 1, 20) or not target.get("line_of_sight", true) is bool):
		return {"missing": missing, "problem": "creature/tile targets need range 1..20"}
	if not target.get("dispositions", []) is Array:
		return {"missing": missing, "problem": "target dispositions must be an array"}
	if not payload.get("effects") is Array or payload.effects.is_empty() or payload.effects.size() > 8:
		return {"missing": missing, "problem": "An active skill needs 1..8 effects"}
	for effect in payload.effects:
		problem = _check_effect(effect, target.kind, context, missing)
		if not problem.is_empty():
			return {"missing": missing, "problem": problem}
	return {"missing": missing, "problem": ""}

func _check_effect(effect: Variant, kind: String, context: Dictionary, missing: Array) -> String:
	if not effect is Dictionary or not effect.get("type") is String:
		return "Invalid effect"
	if effect.type not in TARGETS[kind]:
		missing.append("skill.effect.%s.%s" % [kind, effect.type])
		return ""
	match effect.type:
		"strike":
			return "" if _int_in(effect.get("attack_percent", 100), 1, 1000) and _int_in(effect.get("flat", 0), 0, 1000) else "strike needs attack_percent 1..1000, flat 0..1000"
		"stun":
			return "" if _int_in(effect.get("turns"), 1, 20) else "stun needs turns 1..20"
		"heal":
			return "" if (effect.has("amount") and _int_in(effect.amount, 1, 1000)) != (effect.has("percent_of_max") and _int_in(effect.percent_of_max, 1, 100)) else "heal needs amount 1..1000 or percent_of_max 1..100"
		"need":
			return "" if effect.get("need") in context.needs and _int_in(effect.get("amount"), -1000, 1000) and effect.amount != 0 else "need needs a known need and non-zero amount"
		"status":
			if not effect.get("status") is String or not Data.identifier("s:" + effect.status) or effect.get("stat") not in context.stats or not _int_in(effect.get("duration"), 1, 100):
				return "status needs status id, known stat and duration 1..100"
			return "" if _int_in(effect.get("add", 0), -1000, 1000) and _int_in(effect.get("percent", 0), -90, 500) and (effect.get("add", 0) != 0 or effect.get("percent", 0) != 0) else "status needs add or percent"
		"restore":
			return "" if rules.resources.has(effect.get("resource")) and _int_in(effect.get("amount"), 1, 10000) else "restore needs a known resource and amount"
	return "" # blink: no parameters.

func check_conditions(conditions: Variant, context: Dictionary, missing: Array) -> String:
	if not conditions is Array or conditions.size() > 8:
		return "conditions must be an array of at most 8"
	for condition in conditions:
		if not condition is Dictionary or not condition.get("type") is String:
			return "Invalid condition"
		if condition.type not in CONDITIONS:
			missing.append("skill.condition." + condition.type) # Never treated as met.
			continue
		var ok := true
		match condition.type:
			"level":
				ok = _int_in(condition.get("min"), 1, 100000)
			"stat":
				ok = condition.get("stat") in context.stats and _int_in(condition.get("min"), 0, 100000)
			"skill_known":
				ok = Data.identifier(condition.get("content_id"))
			"talent":
				ok = condition.get("values") is Array and not condition.values.is_empty() and condition.values.all(func(value: Variant) -> bool: return Data.identifier(value))
			"item":
				ok = Data.identifier(condition.get("content_id")) and Data.integer(condition.get("version")) and _int_in(condition.get("quantity", 1), 1, 1000)
			"equipped":
				ok = condition.get("slot") in context.slots
			"hp_below_percent", "hp_at_least_percent":
				ok = _int_in(condition.get("value"), 1, 100)
			"need_below":
				ok = condition.get("need") in context.needs and condition.get("level") in NEED_LEVELS.slice(1)
			"any_of":
				var problem := check_conditions(condition.get("conditions"), context, missing)
				if not problem.is_empty() or condition.conditions.is_empty():
					return "any_of needs valid conditions"
		if not ok:
			return "Invalid %s condition" % condition.type
	return ""

func evaluate(conditions: Array, character: Dictionary) -> Array:
	## Unmet requirements as readable text ([] = all met). character: level, stats
	## (effective), skills, talents (ID sets), inventory, equipment, hp, max_hp,
	## need_level. Unknown condition types are always unmet.
	var unmet: Array = []
	for condition in conditions:
		if not met(condition, character):
			unmet.append(describe(condition))
	return unmet

func met(condition: Dictionary, character: Dictionary) -> bool:
	match condition.get("type"):
		"level":
			return int(character.level) >= int(condition.min)
		"stat":
			return int(character.stats.get(condition.stat, 0)) >= int(condition.min)
		"skill_known":
			return character.skills.has(condition.content_id)
		"talent":
			return condition.values.any(func(id: String) -> bool: return character.talents.has(id))
		"item":
			var entry: Dictionary = character.inventory.get(condition.content_id, {})
			return int(entry.get("version", 0)) == int(condition.version) and int(entry.get("quantity", 0)) >= int(condition.get("quantity", 1))
		"equipped":
			return character.equipment.has(condition.slot)
		"hp_below_percent":
			return int(character.hp) * 100 < int(condition.value) * int(character.max_hp)
		"hp_at_least_percent":
			return int(character.hp) * 100 >= int(condition.value) * int(character.max_hp)
		"need_below":
			return int(character.need_level.call(condition.need)) < NEED_LEVELS.find(condition.level)
		"any_of":
			return condition.conditions.any(func(inner: Dictionary) -> bool: return met(inner, character))
	return false

static func describe(condition: Dictionary) -> String:
	match condition.get("type"):
		"level":
			return "level %d" % int(condition.min)
		"stat":
			return "%s %d+" % [str(condition.stat).capitalize(), int(condition.min)]
		"skill_known":
			return "knows " + str(condition.content_id).get_slice("/", 1).capitalize()
		"talent":
			return "talent: " + ", ".join(condition.values.map(func(id: String) -> String: return id.get_slice("/", 1).capitalize()))
		"item":
			return "carry %s x%d" % [str(condition.content_id).get_slice(":", 1).capitalize(), int(condition.get("quantity", 1))]
		"equipped":
			return "%s equipped" % str(condition.slot)
		"hp_below_percent":
			return "HP below %d%%" % int(condition.value)
		"hp_at_least_percent":
			return "HP at least %d%%" % int(condition.value)
		"need_below":
			return "%s below %s" % [condition.need, condition.level]
		"any_of":
			return "one of (" + " or ".join(condition.conditions.map(func(inner: Dictionary) -> String: return describe(inner))) + ")"
	return "unsupported requirement: " + str(condition.get("type"))

static func record(definition: Dictionary, source: Dictionary, turn: int) -> Dictionary:
	## Stored per Run: what was learned, from where, plus counters. Effects are not stored.
	return {"content_id": definition.content_id, "version": int(definition.version), "learned_turn": turn, "source": source, "cooldown_until": 0, "state": {}}

func normalize(character: Dictionary, level: int) -> Dictionary:
	## Older saves: no skills, resources full, no timed statuses.
	var result := character.duplicate(true)
	if not result.has("skills"):
		result.skills = []
	if not result.has("statuses"):
		result.statuses = []
	if not result.has("resources"):
		result.resources = {}
	for id in resource_ids():
		if not result.resources.has(id):
			result.resources[id] = {"value": max_resource(id, level), "progress": 0}
	return result

func validate(character: Dictionary, definition_for: Callable, stats: Array) -> String:
	if not character.get("skills") is Array or not character.get("statuses") is Array or not character.get("resources") is Dictionary:
		return "Character skills/statuses must be arrays and resources an object"
	var known := {}
	for entry in character.skills:
		if not entry is Dictionary or not Data.identifier(entry.get("content_id")) or not _int_in(entry.get("version"), 1, 1000000) or not _int_in(entry.get("learned_turn"), 0, 1000000000) or not _int_in(entry.get("cooldown_until"), 0, 1000000000) or not entry.get("source") is Dictionary or not entry.get("state") is Dictionary:
			return "Invalid learned skill record"
		if known.has(entry.content_id):
			return "Skill learned twice: " + entry.content_id
		known[entry.content_id] = true
		var definition: Dictionary = definition_for.call(entry.content_id, int(entry.version))
		if definition.get("kind") != "skill":
			return "Learned skill is missing: " + entry.content_id
		var abilities := {}
		for ability in definition.get("payload", {}).get("abilities", []):
			abilities[ability.get("id")] = true
		for ability_id in entry.state:
			if not abilities.has(ability_id) or not entry.state[ability_id] is Dictionary:
				return "Skill state for an unknown ability: " + str(ability_id)
	for id in character.resources:
		var resource: Variant = character.resources[id]
		if not rules.resources.has(id) or not resource is Dictionary or not _int_in(resource.get("value"), 0, 1000000) or not _int_in(resource.get("progress"), 0, 99):
			return "Invalid skill resource " + str(id)
	for status in character.statuses:
		if not status is Dictionary or not status.get("id") is String or not Data.identifier(status.get("source")) or status.get("stat") not in stats or not _int_in(status.get("add", 0), -1000, 1000) or not _int_in(status.get("percent", 0), -90, 500) or not _int_in(status.get("until_turn"), 0, 1000000000):
			return "Invalid timed status"
	return ""

static func _int_in(value: Variant, low: int, high: int) -> bool:
	return Data.integer(value) and value >= low and value <= high

func _fail(message: String) -> bool:
	last_error = message
	return false
