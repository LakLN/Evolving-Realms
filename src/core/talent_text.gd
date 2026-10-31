extends RefCounted
## Readable talent text, generated from the definition data and the Run's counters.
## Content supplies names, descriptions and limitation notes; all rules text is
## derived from the same data the handlers execute, so UI and behavior cannot drift.
const TalentRuntime = preload("res://src/core/talent_runtime.gd")
const TRIGGERS := {"on_turn": "Each turn", "on_explore": "While exploring", "on_attack": "When you strike", "on_kill": "When you slay a creature", "on_hit_taken": "When you are hit", "on_gather": "When you gather or pick up", "on_open": "When you open a chest", "on_use_item": "When you use an item"}

static func rank_title(rules: RefCounted, rank_id: String) -> String:
	return "%s · %s" % [rank_id, rules.rank(rank_id).get("name", "?")]

static func label(rules: RefCounted, definition: Dictionary) -> String:
	return "[%s] %s" % [rank_title(rules, definition.payload.rank), definition.name]

static func details(rules: RefCounted, definition: Dictionary, record: Dictionary, turn: int, stat_names: Dictionary, item_name: Callable, supported: bool) -> PackedStringArray:
	var lines := PackedStringArray()
	var payload: Dictionary = definition.payload
	if not supported:
		lines.append("Dormant: this engine lacks a capability it needs, so it is never executed.")
	if payload.get("unique", false):
		lines.append("Unique: held at most once per run.")
	var passive := PackedStringArray()
	for effect in payload.get("passive", []):
		passive.append(effect_text(effect, stat_names, item_name))
	if not passive.is_empty():
		lines.append("Always: " + ", ".join(passive) + ".")
	for ability in payload.get("abilities", []):
		lines.append("• " + ability_text(ability, stat_names, item_name) + status(ability, record, turn))
	if not payload.get("limitations", []).is_empty():
		lines.append("Limitations: " + " ".join(payload.limitations))
	return lines

static func ability_text(ability: Dictionary, stat_names: Dictionary, item_name: Callable) -> String:
	var head := str(TRIGGERS.get(ability.trigger, ability.trigger))
	var conditions := PackedStringArray()
	for condition in ability.get("conditions", []):
		conditions.append(condition_text(condition))
	var limits: Dictionary = ability.get("limits", {})
	if limits.has("every_tiles"):
		conditions.append("every %d new tiles" % int(limits.every_tiles))
	if not conditions.is_empty():
		head += " (" + ", ".join(conditions) + ")"
	var effects := PackedStringArray()
	for effect in ability.effects:
		effects.append(effect_text(effect, stat_names, item_name))
	var notes := PackedStringArray()
	if int(limits.get("cooldown_turns", 0)) > 0:
		notes.append("cooldown %d turns" % int(limits.cooldown_turns))
	if int(limits.get("charges", 0)) > 0:
		notes.append("%d per run" % int(limits.charges))
	return "%s: %s.%s" % [head, ", ".join(effects), "" if notes.is_empty() else " Limit: " + ", ".join(notes) + "."]

static func status(ability: Dictionary, record: Dictionary, turn: int) -> String:
	## Stored counters of this Run, e.g. "[1/2 left, recharging 12 turns]".
	var state := TalentRuntime.state(record, ability.id)
	var limits: Dictionary = ability.get("limits", {})
	var parts := PackedStringArray()
	if int(limits.get("charges", 0)) > 0:
		parts.append("%d/%d left" % [maxi(0, int(limits.charges) - state.used), int(limits.charges)])
	if state.cooldown_until > turn:
		parts.append("recharging %d turns" % (state.cooldown_until - turn))
	if limits.has("every_tiles"):
		parts.append("%d/%d tiles" % [state.progress, int(limits.every_tiles)])
	for effect in ability.effects:
		if effect.type == "grow_stat":
			parts.append("x%d/%d" % [mini(state.used, int(effect.max_stacks)), int(effect.max_stacks)])
			break
	return "" if parts.is_empty() else "  [" + ", ".join(parts) + "]"

static func condition_text(condition: Dictionary) -> String:
	match condition.type:
		"chance_per_10000":
			return "%s%% chance" % str(snappedf(int(condition.value) / 100.0, 0.01)).trim_suffix(".0")
		"hp_below_percent":
			return "HP below %d%%" % int(condition.value)
		"hp_at_least_percent":
			return "HP at least %d%%" % int(condition.value)
		"every_turns":
			return "every %d turns" % int(condition.value)
		"need_at_least":
			return "%s at %s or worse" % [condition.need, condition.level]
		"lethal":
			return "if the blow would kill you"
		"target_category", "target_disposition":
			return "against %s" % "/".join(condition.values)
		"item_category":
			return "%s items" % "/".join(condition.values)
		"effect_type":
			return "items that %s" % "/".join(condition.values)
		"biome":
			return "in %s" % "/".join(condition.values)
	return str(condition.type)

static func effect_text(effect: Dictionary, stat_names: Dictionary, item_name: Callable) -> String:
	var stat := str(stat_names.get(effect.get("stat", ""), effect.get("stat", "")))
	match effect.type:
		"stat":
			var parts := PackedStringArray()
			if int(effect.get("add", 0)) != 0:
				parts.append("%+d %s" % [int(effect.add), stat])
			if int(effect.get("percent", 0)) != 0:
				parts.append("%+d%% %s" % [int(effect.percent), stat])
			return ", ".join(parts)
		"perception":
			var parts := PackedStringArray()
			if effect.get("hidden", false):
				parts.append("see hidden objects")
			if int(effect.get("sense_radius", 0)) > 0:
				parts.append("sense objects through fog within %d tiles" % int(effect.sense_radius))
			return ", ".join(parts)
		"heal":
			return "+%d HP" % int(effect.amount) if effect.has("amount") else "heal %d%% of max HP" % int(effect.percent_of_max)
		"need":
			return "%s %+d" % [effect.need, int(effect.amount)]
		"grant_item":
			return "find %s x%d" % [item_name.call(effect.content_id, int(effect.version)), int(effect.quantity)]
		"bonus_damage", "damage_reduction":
			var sign := "+" if effect.type == "bonus_damage" else "-"
			var parts := PackedStringArray()
			if int(effect.get("amount", 0)) > 0:
				parts.append("%s%d" % [sign, int(effect.amount)])
			if int(effect.get("percent", 0)) > 0:
				parts.append("%s%d%%" % [sign, int(effect.percent)])
			return " ".join(parts) + (" damage" if effect.type == "bonus_damage" else " damage taken")
		"lifesteal":
			return "heal %d%% of the damage you deal" % int(effect.percent)
		"xp_bonus":
			return "+%d%% XP" % int(effect.percent)
		"extra_loot_roll":
			return "one extra loot roll"
		"grow_stat":
			return "permanently %+d %s (up to %d times)" % [int(effect.amount), stat, int(effect.max_stacks)]
		"negate_hit":
			return "the blow never happened"
		"survive_lethal":
			return "survive with %d HP" % int(effect.get("hp", 1))
		"yield_bonus":
			return "+%d%% yield of stackable items" % int(effect.percent)
		"use_bonus":
			return "%+d%% %s strength" % [int(effect.percent), "/".join(effect.get("effect_types", ["effect"]))]
	return str(effect.type)
