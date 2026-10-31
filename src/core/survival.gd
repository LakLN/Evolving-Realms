extends RefCounted
## Turn-based survival: hunger, thirst, HP recovery and starvation, configured by
## content/survival_rules.json. Every accepted action calls tick() once. Needs grow
## from 0 (fine) to `scale` (depleted). Future needs/conditions (temperature,
## disease, environment, poison) add entries to `needs` or extra tick steps here —
## never in UI, item or creature code.
const Data = preload("res://src/data/json_data.gd")
const PATH := "res://content/survival_rules.json"
const LEVELS := ["fine", "warning", "danger", "depleted"]
const DEFAULTS := {"hunger": 0, "thirst": 0, "recovery": 0, "starvation": 0}
var rules: Dictionary = {}
var last_error := ""

func load_rules(path: String = PATH) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("rules_version") != 1 or not _valid(parsed):
		return _fail("Survival rules are missing, unsupported or invalid: " + last_error)
	rules = parsed
	last_error = ""
	return true

func _valid(candidate: Dictionary) -> bool:
	var scale: Variant = candidate.get("scale")
	if not Data.integer(scale) or scale < 100 or scale > 100000 or not candidate.get("needs") is Dictionary or candidate.needs.is_empty():
		return _fail("scale 100..100000 and needs required")
	for need in candidate.needs:
		var config: Variant = candidate.needs[need]
		if not config is Dictionary or not config.get("per_action") is Dictionary or not config.per_action.has("default"):
			return _fail(need + " needs per_action with default")
		for action in config.per_action:
			if not Data.integer(config.per_action[action]) or config.per_action[action] < 0 or config.per_action[action] > scale:
				return _fail(need + " per_action values must be 0..scale")
		if not Data.integer(config.get("warning")) or not Data.integer(config.get("danger")) or not (0 < config.warning and config.warning < config.danger and config.danger < scale):
			return _fail(need + " needs 0 < warning < danger < scale")
	for field in [["recovery", "per_turn", 0, 100], ["recovery", "rest_per_turn", 0, 100], ["starvation", "damage_per_turn", 1, 100], ["rest", "max_turns", 1, 50], ["autosave", "normal_interval", 0, 1000], ["autosave", "safe_hp_percent", 0, 100], ["autosave", "permadeath_safe_interval", 1, 100], ["autosave", "permadeath_risk_hp_percent", 0, 100]]:
		var section: Variant = candidate.get(field[0])
		var value: Variant = section.get(field[1]) if section is Dictionary else null
		if not Data.integer(value) or value < field[2] or value > field[3]:
			return _fail("%s.%s must be %d..%d" % field)
	return true

func normalize(stats: Dictionary) -> Dictionary:
	## Copy with missing survival keys defaulted (older saves start fed and watered).
	var result := stats.duplicate(true)
	for key in DEFAULTS:
		if not result.has(key):
			result[key] = DEFAULTS[key]
	for need in rules.needs:
		if not result.has(need):
			result[need] = 0
	return result

func valid_stats(stats: Dictionary) -> bool:
	for need in rules.needs:
		if not Data.integer(stats.get(need)) or stats[need] < 0 or stats[need] > rules.scale:
			return false
	return Data.integer(stats.get("recovery")) and stats.recovery >= 0 and stats.recovery < 100 and Data.integer(stats.get("starvation")) and stats.starvation >= 0 and stats.starvation < 100

func level(stats: Dictionary, need: String) -> int:
	var value := int(stats[need])
	var config: Dictionary = rules.needs[need]
	if value >= int(rules.scale):
		return 3
	return 2 if value >= int(config.danger) else (1 if value >= int(config.warning) else 0)

func worst_level(stats: Dictionary) -> int:
	var worst := 0
	for need in rules.needs:
		worst = maxi(worst, level(stats, need))
	return worst

func tick(stats: Dictionary, action_type: String) -> Array:
	## One turn: needs grow by the action's cost, then recovery or starvation.
	## Mutates stats; returns UI events. Recovery needs every need below warning.
	var events: Array = []
	var needs: Array = rules.needs.keys()
	needs.sort()
	for need in needs:
		var config: Dictionary = rules.needs[need]
		var before := level(stats, need)
		stats[need] = mini(int(rules.scale), int(stats[need]) + int(config.per_action.get(action_type, config.per_action.default)))
		var after := level(stats, need)
		if after > before:
			events.append({"type": "survival", "need": need, "level": LEVELS[after]})
	var worst := worst_level(stats)
	if worst == 3:
		stats.recovery = 0
		stats.starvation = int(stats.starvation) + int(rules.starvation.damage_per_turn)
		if stats.starvation >= 100 and int(stats.hp) > 0:
			stats.starvation -= 100
			stats.hp = int(stats.hp) - 1
			events.append({"type": "starvation", "damage": 1, "hp": stats.hp})
		return events
	stats.starvation = 0
	if worst > 0 or int(stats.hp) <= 0 or int(stats.hp) >= int(stats.max_hp):
		stats.recovery = 0
		return events
	stats.recovery = int(stats.recovery) + int(rules.recovery.rest_per_turn if action_type == "rest" else rules.recovery.per_turn)
	if stats.recovery >= 100:
		stats.recovery -= 100
		stats.hp = int(stats.hp) + 1
		events.append({"type": "regen", "hp": stats.hp})
	return events

func percent(stats: Dictionary, need: String) -> int:
	return int(stats[need]) * 100 / int(rules.scale)

func _fail(message: String) -> bool:
	last_error = message
	return false
