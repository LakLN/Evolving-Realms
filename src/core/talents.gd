extends RefCounted
## Talent ranks and awakening (content/talent_rules.json) plus validation of talent
## definitions (Registry kind "talent"). A talent is data only: a rank, a unique flag,
## awakening weight/conditions, passive effects and triggered abilities built from the
## closed vocabulary below. Anything outside it is kept as pending capability: listed,
## never awakened, never executed. Effect handlers are trusted engine code in
## talent_runtime.gd and exploration_session.gd; content never supplies code.
const Data = preload("res://src/data/json_data.gd")
const Loot = preload("res://src/core/loot_table.gd")
const ItemEffects = preload("res://src/core/item_effects.gd")
const PATH := "res://content/talent_rules.json"
const AWAKENING_VERSION := 1
const STYLES := ["plain", "platinum", "black_gold", "rainbow"]
## Supported triggers and the effect types their handlers execute.
const TRIGGERS := {
	"on_turn": ["heal", "need"],
	"on_explore": ["grant_item", "heal", "need"],
	"on_attack": ["bonus_damage", "lifesteal"],
	"on_kill": ["heal", "xp_bonus", "extra_loot_roll", "grow_stat"],
	"on_hit_taken": ["negate_hit", "damage_reduction", "survive_lethal", "heal"],
	"on_gather": ["yield_bonus", "extra_loot_roll", "grant_item"],
	"on_open": ["yield_bonus", "extra_loot_roll", "grant_item"],
	"on_use_item": ["use_bonus", "heal", "need"],
}
const PASSIVE_EFFECTS := ["stat", "perception"]
## Condition type -> triggers that provide its context ([] = every trigger).
const CONDITIONS := {
	"chance_per_10000": [], "hp_below_percent": [], "hp_at_least_percent": [], "every_turns": [],
	"biome": [], "need_at_least": [],
	"target_category": ["on_attack", "on_kill"], "target_disposition": ["on_attack", "on_kill"],
	"item_category": ["on_use_item"], "effect_type": ["on_use_item"], "lethal": ["on_hit_taken"],
}
const AWAKENING_CONDITIONS := ["mode", "spawn_biome"]
## A hit taken resolves in three passes, each seeing the previous result:
## mitigation, then escaping death, then recovery. An ability belongs to one pass.
const HIT_PHASES := [["negate_hit", "damage_reduction"], ["survive_lethal"], ["heal"]]
const NEED_LEVELS := ["fine", "warning", "danger", "depleted"]
var ranks: Array = []
var by_id: Dictionary = {}
var awakening: Dictionary = {}
var last_error := ""

func load_rules(path: String = PATH) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("rules_version") != 1 or not parsed.get("ranks") is Array or parsed.ranks.is_empty():
		return _fail("Talent rules are missing or unsupported")
	var seen := {}
	var previous := 0
	for rank in parsed.ranks:
		if not rank is Dictionary or not rank.get("id") is String or rank.id.is_empty() or seen.has(rank.id):
			return _fail("Talent ranks need unique ids")
		if not Data.integer(rank.get("order")) or rank.order <= previous or not rank.get("name") is String or rank.name.is_empty():
			return _fail("Talent ranks need increasing order and a name: " + str(rank.id))
		if not rank.get("color") is String or not rank.color.is_valid_html_color() or rank.get("style", "plain") not in STYLES:
			return _fail("Talent rank color/style invalid: " + str(rank.id))
		previous = int(rank.order)
		seen[rank.id] = rank
	var config: Variant = parsed.get("awakening")
	if not config is Dictionary or not Data.integer(config.get("talents_per_run")) or config.talents_per_run < 0 or config.talents_per_run > 8 or not config.get("rank_weights") is Dictionary:
		return _fail("Talent awakening needs talents_per_run 0..8 and rank_weights")
	for rank_id in config.rank_weights:
		if not seen.has(rank_id) or not Data.integer(config.rank_weights[rank_id]) or config.rank_weights[rank_id] < 0 or config.rank_weights[rank_id] > 1000000:
			return _fail("Awakening rank weights need known ranks and 0..1000000")
	ranks = parsed.ranks
	by_id = seen
	awakening = config
	last_error = ""
	return true

func has(rank_id: Variant) -> bool:
	return rank_id is String and by_id.has(rank_id)

func order(rank_id: String) -> int:
	return int(by_id[rank_id].order) if by_id.has(rank_id) else 0

func rank(rank_id: String) -> Dictionary:
	return by_id.get(rank_id, {})

func color(rank_id: String, time_seconds: float = 0.0) -> Color:
	var entry: Dictionary = by_id.get(rank_id, {})
	if entry.is_empty():
		return Color("d0d0d0")
	if entry.get("style") == "rainbow":
		return Color.from_hsv(fmod(time_seconds * 0.25, 1.0), 0.65, 1.0)
	return Color(entry.color)

func catalog(registry: RefCounted, world_id: String, stats: Array, needs: Array) -> Dictionary:
	## {pool: latest supported version per talent ID, pending: [{content_id, version,
	## missing}], definitions: {"id@v": definition}, supported: {"id@v": true}} or {error}.
	## Structurally invalid talents stop the session explicitly, like other content.
	var latest := {}
	var pending: Array = []
	var definitions := {}
	var supported := {}
	for header in registry.list_definitions(world_id):
		if header.kind != "talent":
			continue
		var definition: Dictionary = registry.load_definition(world_id, header.content_id, int(header.version))
		if definition.is_empty():
			return {"error": registry.last_error}
		var key := "%s@%d" % [header.content_id, int(header.version)]
		definitions[key] = definition
		var verdict := classify(definition, stats, needs, registry, world_id)
		if not verdict.problem.is_empty():
			return {"error": "%s: %s" % [key, verdict.problem]}
		if verdict.missing.is_empty():
			supported[key] = true
			latest[header.content_id] = definition # Headers are ordered by version.
		else:
			pending.append({"content_id": header.content_id, "version": int(header.version), "missing": verdict.missing})
	var ids: Array = latest.keys()
	ids.sort()
	return {"pool": ids.map(func(id: String) -> Dictionary: return latest[id]), "pending": pending, "definitions": definitions, "supported": supported}

func classify(definition: Dictionary, stats: Array, needs: Array, registry: RefCounted = null, world_id: String = "") -> Dictionary:
	## {missing: capabilities this engine lacks (=> pending), problem: invalid data}.
	var missing: Array = []
	if definition.get("status") != "active":
		missing.append_array(definition.get("missing_capabilities", []))
		if missing.is_empty():
			missing.append("status:" + str(definition.get("status")))
	var payload: Variant = definition.get("payload")
	if not payload is Dictionary:
		return {"missing": missing, "problem": "Talent payload must be an object"}
	if not has(payload.get("rank")):
		return {"missing": missing, "problem": "Unknown talent rank: " + str(payload.get("rank"))}
	if not payload.get("unique", false) is bool:
		return {"missing": missing, "problem": "Talent unique flag must be a boolean"}
	var awaken: Variant = payload.get("awakening", {})
	if not awaken is Dictionary or not Data.integer(awaken.get("weight", 100)) or awaken.get("weight", 100) < 0 or awaken.get("weight", 100) > 1000000 or not awaken.get("conditions", []) is Array:
		return {"missing": missing, "problem": "Talent awakening needs weight 0..1000000 and a conditions array"}
	for condition in awaken.get("conditions", []):
		if not condition is Dictionary or not condition.get("values") is Array or condition.values.is_empty():
			return {"missing": missing, "problem": "Awakening conditions need type and values"}
		if condition.get("type") not in AWAKENING_CONDITIONS:
			missing.append("talent.awakening." + str(condition.get("type")))
	for field in ["passive", "abilities", "limitations"]:
		if not payload.get(field, []) is Array or payload.get(field, []).size() > 8:
			return {"missing": missing, "problem": "Talent %s must be an array of at most 8" % field}
	if payload.get("passive", []).is_empty() and payload.get("abilities", []).is_empty():
		return {"missing": missing, "problem": "A talent needs passive effects or abilities"}
	for note in payload.get("limitations", []):
		if not note is String:
			return {"missing": missing, "problem": "Talent limitations are display strings"}
	var pinned := {}
	for dependency in definition.get("dependencies", []):
		pinned["%s@%d" % [dependency.content_id, int(dependency.version)]] = true
	var context := {"stats": stats, "needs": needs, "pinned": pinned, "registry": registry, "world_id": world_id, "missing": missing}
	for effect in payload.get("passive", []):
		var problem := _check_effect(effect, "passive", context)
		if not problem.is_empty():
			return {"missing": missing, "problem": problem}
	var ability_ids := {}
	for ability in payload.get("abilities", []):
		if not ability is Dictionary or not ability.get("id") is String or not Data.identifier("a:" + ability.id) or ability_ids.has(ability.id):
			return {"missing": missing, "problem": "Talent abilities need unique lowercase ids"}
		ability_ids[ability.id] = true
		var trigger: Variant = ability.get("trigger")
		if not trigger is String or not ability.get("effects") is Array or ability.effects.is_empty() or ability.effects.size() > 8 or not ability.get("conditions", []) is Array or not ability.get("limits", {}) is Dictionary or not ability.get("quiet", false) is bool:
			return {"missing": missing, "problem": "Ability %s needs a trigger, 1..8 effects, conditions, limits" % ability.id}
		if not TRIGGERS.has(trigger):
			missing.append("talent.trigger." + trigger)
			continue
		for condition in ability.get("conditions", []):
			var problem := _check_condition(condition, trigger, context)
			if not problem.is_empty():
				return {"missing": missing, "problem": "%s: %s" % [ability.id, problem]}
		var problem := _check_limits(ability.get("limits", {}), trigger)
		if not problem.is_empty():
			return {"missing": missing, "problem": "%s: %s" % [ability.id, problem]}
		var phases := {}
		for effect in ability.effects:
			problem = _check_effect(effect, trigger, context)
			if not problem.is_empty():
				return {"missing": missing, "problem": "%s: %s" % [ability.id, problem]}
			for index in HIT_PHASES.size():
				if effect is Dictionary and effect.get("type") in HIT_PHASES[index]:
					phases[index] = true
		if trigger == "on_hit_taken" and phases.size() > 1:
			return {"missing": missing, "problem": ability.id + ": a hit ability mixes mitigation, survival and recovery effects"}
	return {"missing": missing, "problem": ""}

func _check_condition(condition: Variant, trigger: String, context: Dictionary) -> String:
	if not condition is Dictionary or not condition.get("type") is String:
		return "Invalid condition"
	if not CONDITIONS.has(condition.type):
		context.missing.append("talent.condition." + condition.type)
		return ""
	if not CONDITIONS[condition.type].is_empty() and trigger not in CONDITIONS[condition.type]:
		return "Condition %s has no context in %s" % [condition.type, trigger]
	match condition.type:
		"chance_per_10000":
			return "" if _int_in(condition.get("value"), 1, 10000) else "chance_per_10000 must be 1..10000"
		"hp_below_percent", "hp_at_least_percent":
			return "" if _int_in(condition.get("value"), 1, 100) else "HP percent must be 1..100"
		"every_turns":
			return "" if _int_in(condition.get("value"), 1, 10000) else "every_turns must be 1..10000"
		"need_at_least":
			return "" if condition.get("need") in context.needs and condition.get("level") in NEED_LEVELS.slice(1) else "need_at_least needs a known need and level"
		"lethal":
			return ""
	return "" if condition.get("values") is Array and not condition.values.is_empty() and condition.values.all(func(value: Variant) -> bool: return value is String) else "Condition %s needs string values" % condition.type

func _check_limits(limits: Dictionary, trigger: String) -> String:
	for key in limits:
		if key not in ["cooldown_turns", "charges", "every_tiles"] or not _int_in(limits[key], 0, 100000):
			return "Limits support cooldown_turns, charges, every_tiles (0..100000)"
	if (trigger == "on_explore") != limits.has("every_tiles") or int(limits.get("every_tiles", 1)) < 1:
		return "every_tiles (>= 1) is required for on_explore and only valid there"
	return ""

func _check_effect(effect: Variant, trigger: String, context: Dictionary) -> String:
	if not effect is Dictionary or not effect.get("type") is String:
		return "Invalid effect"
	var allowed: Array = PASSIVE_EFFECTS if trigger == "passive" else TRIGGERS[trigger]
	if effect.type not in allowed:
		# Unknown to this engine (or not executable from this trigger): keep pending.
		context.missing.append("talent.effect.%s.%s" % [trigger, effect.type])
		return ""
	match effect.type:
		"stat", "grow_stat":
			if effect.get("stat") not in context.stats:
				return "Unknown stat: " + str(effect.get("stat"))
			if effect.type == "grow_stat":
				return "" if _int_in(effect.get("amount"), -100, 100) and effect.amount != 0 and _int_in(effect.get("max_stacks"), 1, 1000) else "grow_stat needs non-zero amount and max_stacks 1..1000"
			return "" if _int_in(effect.get("add", 0), -1000, 1000) and _int_in(effect.get("percent", 0), -90, 500) and (effect.get("add", 0) != 0 or effect.get("percent", 0) != 0) else "stat needs add -1000..1000 or percent -90..500"
		"perception":
			return "" if effect.get("hidden", false) is bool and _int_in(effect.get("sense_radius", 0), 0, 20) else "perception needs hidden bool and sense_radius 0..20"
		"heal":
			return "" if (effect.has("amount") and _int_in(effect.amount, 1, 1000)) != (effect.has("percent_of_max") and _int_in(effect.percent_of_max, 1, 100)) else "heal needs amount 1..1000 or percent_of_max 1..100"
		"need":
			return "" if effect.get("need") in context.needs and _int_in(effect.get("amount"), -1000, 1000) and effect.amount != 0 else "need needs a known need and non-zero amount"
		"grant_item":
			if not Data.identifier(effect.get("content_id")) or not Data.integer(effect.get("version")) or not _int_in(effect.get("quantity"), 1, 100):
				return "grant_item needs content_id, version, quantity 1..100"
			if not context.pinned.has("%s@%d" % [effect.content_id, int(effect.version)]):
				return "grant_item must be a pinned dependency: " + effect.content_id
			if context.registry != null:
				var item: Dictionary = context.registry.load_definition(context.world_id, effect.content_id, int(effect.version))
				if item.get("kind") != "item" or item.get("status") != "active":
					return "grant_item needs an active item: " + effect.content_id
			return ""
		"bonus_damage", "damage_reduction":
			var cap := 100 if effect.type == "damage_reduction" else 1000
			return "" if _int_in(effect.get("amount", 0), 0, 1000) and _int_in(effect.get("percent", 0), 0, cap) and (effect.get("amount", 0) > 0 or effect.get("percent", 0) > 0) else effect.type + " needs amount or percent"
		"lifesteal", "xp_bonus", "yield_bonus":
			return "" if _int_in(effect.get("percent"), 1, 1000) else effect.type + " needs percent 1..1000"
		"use_bonus":
			if not _int_in(effect.get("percent"), -100, 1000) or effect.percent == 0 or not effect.get("effect_types", []) is Array:
				return "use_bonus needs non-zero percent -100..1000"
			for kind in effect.get("effect_types", []):
				if kind not in ItemEffects.TYPES:
					return "use_bonus effect_types must be item effects"
			return ""
		"survive_lethal":
			return "" if _int_in(effect.get("hp", 1), 1, 100) else "survive_lethal hp must be 1..100"
	return "" # negate_hit, extra_loot_roll: no parameters.

func eligible(definition: Dictionary, context: Dictionary, held: Array) -> bool:
	## Awakening conditions (mode, start biome), weight and run-scoped uniqueness.
	var payload: Dictionary = definition.payload
	if int(payload.get("awakening", {}).get("weight", 100)) <= 0:
		return false
	if payload.get("unique", false) and definition.content_id in held:
		return false
	for condition in payload.get("awakening", {}).get("conditions", []):
		if str(context.get(condition.type, "")) not in condition.values:
			return false
	return true

func awaken(pool: Array, context: Dictionary, held: Array, key: String, count: int = -1) -> Array:
	## Deterministic weighted draw (awakening v1): first a rank by its configured
	## weight among ranks that still have an eligible talent, then a talent of that
	## rank by its own weight. Pool order is sorted by ID, so the result depends only
	## on the key and the data. held: content IDs already held in this Run.
	var result: Array = []
	var taken: Array = held.duplicate()
	for slot in (int(awakening.get("talents_per_run", 1)) if count < 0 else count):
		var by_rank := {}
		for definition in pool:
			if eligible(definition, context, taken):
				if not by_rank.has(definition.payload.rank):
					by_rank[definition.payload.rank] = []
				by_rank[definition.payload.rank].append([definition, int(definition.payload.get("awakening", {}).get("weight", 100))])
		var choices: Array = []
		for entry in ranks:
			var weight := int(awakening.rank_weights.get(entry.id, 0))
			if weight > 0 and by_rank.has(entry.id):
				choices.append([entry.id, weight])
		if choices.is_empty():
			break
		var picked_rank: String = pick(choices, "%s/%d/rank" % [key, slot])
		var picked: Dictionary = pick(by_rank[picked_rank], "%s/%d/talent" % [key, slot])
		result.append(picked)
		taken.append(picked.content_id)
	return result

static func pick(weighted: Array, key: String) -> Variant:
	var total := 0
	for entry in weighted:
		total += int(entry[1])
	var ticket := Loot.number(key) % total
	for entry in weighted:
		ticket -= int(entry[1])
		if ticket < 0:
			return entry[0]
	return weighted.back()[0]

func record(definition: Dictionary, slot: int, turn: int) -> Dictionary:
	## Stored per Run. Effects are never stored: they derive from the pinned definition
	## and these counters. state: ability id -> {used, cooldown_until, progress}.
	return {"content_id": definition.content_id, "version": int(definition.version), "rank": definition.payload.rank, "slot": slot, "awakened_turn": turn, "awakening_version": AWAKENING_VERSION, "state": {}}

func validate_records(records: Variant, definition_for: Callable) -> String:
	if not records is Array or records.size() > 8:
		return "Character talents must be an array"
	var unique := {}
	for entry in records:
		if not entry is Dictionary or not Data.identifier(entry.get("content_id")) or not Data.integer(entry.get("version")) or entry.version < 1 or not Data.integer(entry.get("slot")) or entry.slot < 0 or not Data.integer(entry.get("awakened_turn")) or entry.awakened_turn < 0:
			return "Invalid talent record"
		if entry.get("awakening_version") != AWAKENING_VERSION:
			return "Unsupported talent awakening version: " + str(entry.get("awakening_version"))
		var definition: Dictionary = definition_for.call(entry.content_id, int(entry.version))
		if definition.get("kind") != "talent" or not has(entry.get("rank")) or definition.get("payload", {}).get("rank") != entry.rank:
			return "Talent %s is missing or its rank does not match" % entry.content_id
		if definition.payload.get("unique", false):
			if unique.has(entry.content_id):
				return "Unique talent held twice: " + entry.content_id
			unique[entry.content_id] = true
		if not entry.get("state") is Dictionary:
			return "Invalid talent state"
		var abilities := {}
		for ability in definition.payload.get("abilities", []):
			abilities[ability.get("id")] = true
		for ability_id in entry.state:
			var state: Variant = entry.state[ability_id]
			if not abilities.has(ability_id) or not state is Dictionary:
				return "Talent state for an unknown ability: " + str(ability_id)
			for counter in ["used", "cooldown_until", "progress"]:
				if not _int_in(state.get(counter, 0), 0, 1000000000):
					return "Invalid talent counter %s.%s" % [ability_id, counter]
	return ""

static func _int_in(value: Variant, low: int, high: int) -> bool:
	return Data.integer(value) and value >= low and value <= high

func _fail(message: String) -> bool:
	last_error = message
	return false
