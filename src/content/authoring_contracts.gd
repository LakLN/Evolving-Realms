extends RefCounted
## Parameter vocabulary for authoring. Values/bounds are checked by actual engines.
## Extra parameters never silently become gameplay rules: they require capability.
const FIELDS := {
	"use": ["conditions", "cost", "target", "cooldown_turns"], "learn": ["conditions"],
	"target": ["kind", "range", "line_of_sight", "dispositions"],
	"equipment": ["slot", "stats", "modifiers", "requirements", "skill_modifiers", "effect_modifiers"],
	"requirements": ["level"], "skill_book": ["skill", "consume_on_learn"],
	"awakening": ["weight", "conditions"], "ability": ["id", "trigger", "conditions", "effects", "limits", "quiet"],
	"limits": ["cooldown_turns", "charges", "every_tiles"],
	"movement": ["biomes", "leash", "move_per_10000"],
	"ai": ["detect_radius", "wander_per_10000", "flee_radius", "flee_below_percent"],
	"spawn": ["biomes", "per_10000", "priority"], "loot": ["rolls", "entries", "guaranteed"],
	"reference": ["content_id", "version"], "relation": ["type", "skill"],
	"loot_entry": ["content_id", "version", "min", "max", "weight", "quality"],
	"stat_modifier": ["stat", "add", "percent"], "stats": ["max_hp", "attack", "defense"],
	"effect_modifier": ["type", "element", "status", "percent", "add", "conditions"],
	"skill_modifier": ["type", "tags", "skills", "power_percent", "cost_percent", "range_add"]}
const EFFECTS := {
	"strike": ["attack_percent", "flat"], "stun": ["turns"], "heal": ["amount", "percent_of_max"],
	"need": ["need", "amount"], "status": ["status", "stat", "duration", "add", "percent"],
	"restore": ["resource", "amount"], "blink": [], "apply_status": ["content_id", "version"],
	"cleanse": ["harmful"], "stat": ["stat", "add", "percent"], "grow_stat": ["stat", "amount", "max_stacks"],
	"perception": ["hidden", "sense_radius"], "skill_modifier": ["tags", "skills", "power_percent", "cost_percent", "range_add"],
	"effect_modifier": ["modifier"], "grant_item": ["content_id", "version", "quantity"],
	"bonus_damage": ["amount", "percent"], "damage_reduction": ["amount", "percent"],
	"lifesteal": ["percent"], "xp_bonus": ["percent"], "yield_bonus": ["percent"],
	"use_bonus": ["percent", "effect_types"], "survive_lethal": ["hp"],
	"negate_hit": [], "extra_loot_roll": [], "sate": ["amount"], "quench": ["amount"], "damage": ["amount"]}
const CONDITIONS := {
	"level": ["min"], "stat": ["stat", "min"], "skill_known": ["content_id"], "talent": ["values"],
	"item": ["content_id", "version", "quantity"], "equipped": ["slot"],
	"hp_below_percent": ["value"], "hp_at_least_percent": ["value"], "need_below": ["need", "level"],
	"any_of": ["conditions"], "chance_per_10000": ["value"], "every_turns": ["value"],
	"need_at_least": ["need", "level"], "biome": ["values"], "target_category": ["values"],
	"target_disposition": ["values"], "item_category": ["values"], "effect_type": ["values"], "lethal": [],
	"source_status": ["status"], "target_status": ["status"], "mode": ["values"], "spawn_biome": ["values"]}

static func scan(value: Variant, label: String, missing: Array) -> void:
	if not value is Dictionary: return
	var allowed: Array = FIELDS.get(label, [])
	var checked := FIELDS.has(label)
	if label in ["effect", "condition"]:
		var table: Dictionary = EFFECTS if label == "effect" else CONDITIONS
		if table.has(value.get("type")):
			allowed = ["type"] + table[value.type]
			checked = true
	if checked:
		for key in value:
			if key not in allowed: missing.append("parameter.%s.%s" % [label, key])
	for key in value:
		var child: Variant = value[key]
		var next: String = {"modifier": "effect_modifier", "table": "loot", "source": "reference", "item": "reference", "skill": "reference", "tick": "effect"}.get(key, key)
		if child is Dictionary: scan(child, next, missing)
		elif child is Array:
			next = {"effects": "effect", "passive": "effect", "on_hit_effects": "effect", "conditions": "condition", "abilities": "ability", "relations": "relation", "modifiers": "stat_modifier", "effect_modifiers": "effect_modifier", "skill_modifiers": "skill_modifier", "entries": "loot_entry", "guaranteed": "loot_entry"}.get(key, key)
			for entry in child: scan(entry, next, missing)
