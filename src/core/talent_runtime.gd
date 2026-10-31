extends RefCounted
## One Run's awakened talents during play. fire() plans which abilities trigger
## (limits first, then conditions) without changing anything; commit() records uses,
## cooldowns and exploration progress only once the action is accepted, so refused
## actions never spend a talent. Passive and growth bonuses are derived from the
## pinned definitions plus stored counters every time; nothing effective is stored.
const Loot = preload("res://src/core/loot_table.gd")
const Talents = preload("res://src/core/talents.gd")
## [{record (live dictionary inside Run state), definition, active}]
var held: Array = []
var seed_key := ""

func configure(records: Array, definition_for: Callable, is_supported: Callable, key: String) -> void:
	held = []
	for record in records:
		var definition: Dictionary = definition_for.call(record.content_id, int(record.version))
		# Unsupported (pending) talents stay in the save but are dormant: never executed.
		held.append({"record": record, "definition": definition, "active": is_supported.call(definition)})
	seed_key = key

func modifiers() -> Dictionary:
	## Effective-stat source: passive stat effects plus grow_stat stacks (= uses).
	var flat := {}
	var percent := {}
	for talent in held:
		if not talent.active:
			continue
		for effect in talent.definition.payload.get("passive", []):
			if effect.type == "stat":
				flat[effect.stat] = int(flat.get(effect.stat, 0)) + int(effect.get("add", 0))
				percent[effect.stat] = int(percent.get(effect.stat, 0)) + int(effect.get("percent", 0))
		for ability in talent.definition.payload.get("abilities", []):
			var used := int(state(talent.record, ability.id).used)
			for effect in ability.effects:
				if effect.type == "grow_stat":
					flat[effect.stat] = int(flat.get(effect.stat, 0)) + int(effect.amount) * mini(used, int(effect.max_stacks))
	return {"flat": flat, "percent": percent}

func perception() -> Dictionary:
	var result := {"hidden": false, "sense_radius": 0}
	for talent in held:
		if talent.active:
			for effect in talent.definition.payload.get("passive", []):
				if effect.type == "perception":
					result.hidden = result.hidden or effect.get("hidden", false)
					result.sense_radius = maxi(result.sense_radius, int(effect.get("sense_radius", 0)))
	return result

static func state(record: Dictionary, ability_id: String) -> Dictionary:
	var stored: Dictionary = record.get("state", {}).get(ability_id, {})
	return {"used": int(stored.get("used", 0)), "cooldown_until": int(stored.get("cooldown_until", 0)), "progress": int(stored.get("progress", 0))}

func fire(trigger: String, context: Dictionary, effect_filter: Array = []) -> Array:
	## Planned activations [{talent, ability, fired, progress}], in held/ability order.
	## on_explore entries with fired=false only carry exploration progress to commit.
	var result: Array = []
	var turn := int(context.get("turn", 0))
	for talent in held:
		if not talent.active:
			continue
		for ability in talent.definition.payload.get("abilities", []):
			if ability.trigger != trigger or (not effect_filter.is_empty() and not ability.effects.any(func(effect: Dictionary) -> bool: return effect.type in effect_filter)):
				continue
			var current := state(talent.record, ability.id)
			var limits: Dictionary = ability.get("limits", {})
			if int(limits.get("charges", 0)) > 0 and current.used >= int(limits.charges):
				continue # Spent for this Run.
			var progress := -1
			var ready: bool = turn >= current.cooldown_until
			if trigger == "on_explore":
				progress = current.progress + int(context.get("new_tiles", 0))
				ready = ready and progress >= int(limits.every_tiles)
			var fired := ready and _conditions(talent, ability, context)
			if fired or (progress >= 0 and progress != current.progress):
				result.append({"talent": talent, "ability": ability, "fired": fired, "progress": progress})
	return result

func commit(activations: Array, turn: int) -> void:
	for activation in activations:
		var record: Dictionary = activation.talent.record
		var ability: Dictionary = activation.ability
		var next := state(record, ability.id)
		var limits: Dictionary = ability.get("limits", {})
		if activation.progress >= 0:
			next.progress = activation.progress
		if activation.fired:
			next.used += 1
			if int(limits.get("cooldown_turns", 0)) > 0:
				next.cooldown_until = turn + int(limits.cooldown_turns)
			if limits.has("every_tiles"):
				next.progress = maxi(0, next.progress - int(limits.every_tiles))
		record.state[ability.id] = next

func _conditions(talent: Dictionary, ability: Dictionary, context: Dictionary) -> bool:
	for condition in ability.get("conditions", []):
		var passed := false
		match condition.type:
			"chance_per_10000":
				var key := "%s/%s/%s/%s" % [seed_key, talent.definition.content_id, ability.id, context.get("key", "")]
				passed = Loot.number(key) % 10000 < int(condition.value)
			"hp_below_percent":
				passed = int(context.hp) * 100 < int(condition.value) * int(context.max_hp)
			"hp_at_least_percent":
				passed = int(context.hp) * 100 >= int(condition.value) * int(context.max_hp)
			"every_turns":
				passed = int(context.turn) % int(condition.value) == 0
			"biome":
				passed = str(context.get("biome", "")) in condition.values
			"need_at_least":
				passed = context.has("need_level") and int(context.need_level.call(condition.need)) >= Talents.NEED_LEVELS.find(condition.level)
			"target_category":
				passed = str(context.get("target", {}).get("category", "")) in condition.values
			"target_disposition":
				passed = str(context.get("target", {}).get("disposition", "")) in condition.values
			"item_category":
				passed = str(context.get("item_category", "")) in condition.values
			"effect_type":
				passed = context.get("effect_types", []).any(func(kind: String) -> bool: return kind in condition.values)
			"lethal":
				passed = context.get("lethal", false)
		if not passed:
			return false
	return true
