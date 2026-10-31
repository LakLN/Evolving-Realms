extends RefCounted
## Data-driven item effects. Definitions (kind item_use) only carry data such as
## {"type": "heal", "amount": 5}; each effect type has exactly one handler here.
## New effects (cure, buff, temperature, poison...) are new handler branches.
const Data = preload("res://src/data/json_data.gd")
const TYPES := {"heal": "hp", "sate": "hunger", "quench": "thirst"}

static func validate(effects: Variant) -> String:
	if not effects is Array or effects.is_empty() or effects.size() > 8:
		return "Item use needs 1..8 effects"
	for effect in effects:
		if effect is Dictionary and effect.get("type") in ["apply_status", "cleanse"]:
			if effect.type == "apply_status" and (not Data.identifier(effect.get("content_id")) or not Data.integer(effect.get("version"))): return "Status needs content_id/version"
			if effect.type == "cleanse" and not effect.get("harmful", true) is bool: return "Cleanse needs harmful bool"
			continue
		if not effect is Dictionary or effect.get("type") not in TYPES:
			return "Unsupported item effect: " + str(effect.get("type") if effect is Dictionary else effect)
		if not Data.integer(effect.get("amount")) or effect.amount < 1 or effect.amount > 100000:
			return "Item effect amount must be 1..100000"
	return ""

static func apply(stats: Dictionary, effects: Array, max_hp: int = -1) -> Array:
	## Mutates stats; returns only real changes [{type, stat, before, after}].
	var changes: Array = []
	for effect in effects:
		if not TYPES.has(effect.type): continue # Session owns shared status effects.
		var stat: String = TYPES[effect.type]
		var before := int(stats[stat])
		match effect.type:
			"heal":
				stats.hp = mini(max_hp if max_hp > 0 else int(stats.max_hp), before + int(effect.amount))
			"sate", "quench":
				stats[stat] = maxi(0, before - int(effect.amount))
		if int(stats[stat]) != before:
			changes.append({"type": effect.type, "stat": stat, "before": before, "after": int(stats[stat])})
	return changes
