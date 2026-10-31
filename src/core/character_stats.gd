extends RefCounted
## Character rules (stats, equipment slots, progression tracks, starting kit) from
## content/character_rules.json, and the ONE place effective stats are derived.
## Stored state is only base stats (character.stats), progression track levels and
## equipped item records. Effective values are recomputed from scratch every time:
##   total = (base + growth + gear flat) * (100 + gear percent) / 100
## so reloading or re-equipping can never stack modifiers. Future power paths
## (cultivation, magic, inheritance) add tracks or modifier sources here; talents
## arrive as a modifier source (see effective()).
const Data = preload("res://src/data/json_data.gd")
const PATH := "res://content/character_rules.json"
var rules: Dictionary = {}
var quality: RefCounted
var last_error := ""

func load_rules(quality_rules: RefCounted, path: String = PATH) -> bool:
	quality = quality_rules
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("rules_version") != 1:
		return _fail("Character rules are missing or unsupported")
	if not parsed.get("stats") is Dictionary or not parsed.stats.has("max_hp") or not parsed.stats.has("attack") or not parsed.stats.has("defense"):
		return _fail("Character stats must include max_hp, attack and defense")
	if not parsed.get("slots") is Array or parsed.slots.is_empty():
		return _fail("Character rules need equipment slots")
	var slots := {}
	for slot in parsed.slots:
		if not slot is Dictionary or not slot.get("id") is String or slot.id.is_empty() or slots.has(slot.id):
			return _fail("Equipment slots need unique ids")
		slots[slot.id] = true
	if not parsed.get("tracks") is Dictionary or not parsed.tracks.has("adventurer"):
		return _fail("Character rules need the adventurer progression track")
	for track_id in parsed.tracks:
		var track: Variant = parsed.tracks[track_id]
		if not track is Dictionary or not Data.integer(track.get("max_level", 0)) or track.get("max_level", 0) < 0:
			return _fail("Track %s: max_level must be >= 0 (0 = no cap)" % track_id)
		var curve: Variant = track.get("xp_curve")
		if not curve is Dictionary or not Data.integer(curve.get("base")) or curve.base < 1 or not Data.integer(curve.get("growth_percent")) or curve.growth_percent < 0 or curve.growth_percent > 1000:
			return _fail("Track %s: xp_curve needs base >= 1 and growth_percent 0..1000" % track_id)
		for stat in track.get("kill_xp", {}):
			if not Data.integer(track.kill_xp[stat]) or track.kill_xp[stat] < 0:
				return _fail("Track %s: kill_xp weights must be >= 0" % track_id)
		for step in track.get("growth", []):
			if not step is Dictionary or not parsed.stats.has(step.get("stat")) or not Data.integer(step.get("amount")) or not Data.integer(step.get("every")) or step.every < 1:
				return _fail("Track %s: growth needs known stat, integer amount, every >= 1" % track_id)
	for item in parsed.get("starting_items", []):
		if not item is Dictionary or not Data.identifier(item.get("content_id")) or not Data.integer(item.get("version")) or (item.has("quality") and not quality.has(item.quality)):
			return _fail("Invalid starting item")
	rules = parsed
	last_error = ""
	return true

func slot_ids() -> Array:
	return rules.slots.map(func(slot: Dictionary) -> String: return slot.id)

func slot_name(slot_id: String) -> String:
	for slot in rules.slots:
		if slot.id == slot_id:
			return slot.name
	return slot_id

func normalize(character: Dictionary) -> Dictionary:
	## Older saves: no equipment, every track at level 1 with 0 XP.
	var result := character.duplicate(true)
	if not result.has("equipment"):
		result.equipment = {}
	if not result.has("progression"):
		result.progression = {}
	for track_id in rules.tracks:
		if not result.progression.has(track_id):
			result.progression[track_id] = {"xp": 0, "level": 1}
	return result

func validate(character: Dictionary) -> String:
	if not character.get("equipment") is Dictionary or not character.get("progression") is Dictionary:
		return "Character equipment/progression must be objects"
	for slot in character.equipment:
		var record: Variant = character.equipment[slot]
		if slot not in slot_ids() or not record is Dictionary or not Data.identifier(record.get("content_id")) or not Data.integer(record.get("version")) or not Data.identifier(record.get("instance_id")) or not record.get("metadata", {}) is Dictionary:
			return "Invalid equipped item in slot " + str(slot)
	for track_id in character.progression:
		var track: Variant = character.progression[track_id]
		if not track is Dictionary or not Data.integer(track.get("xp")) or track.xp < 0 or not Data.integer(track.get("level")) or track.level < 1:
			return "Invalid progression track " + str(track_id)
	return ""

func level(character: Dictionary, track_id: String = "adventurer") -> int:
	return int(character.get("progression", {}).get(track_id, {}).get("level", 1))

func xp_to_next(track_id: String, at_level: int) -> int:
	var curve: Dictionary = rules.tracks[track_id].xp_curve
	var need := int(curve.base)
	for _step in mini(at_level - 1, 200):
		need = need * (100 + int(curve.growth_percent)) / 100
	return maxi(1, need)

func kill_xp(creature_stats: Dictionary, track_id: String = "adventurer") -> int:
	var total := 0
	var weights: Dictionary = rules.tracks[track_id].get("kill_xp", {})
	for stat in weights:
		total += int(creature_stats.get(stat, 0)) * int(weights[stat])
	return total

func gain_xp(character: Dictionary, amount: int, track_id: String = "adventurer") -> Array:
	## Mutates character.progression; returns xp/level_up events. No hard cap
	## unless the track's max_level (data) is > 0.
	var track: Dictionary = character.progression[track_id]
	var cap := int(rules.tracks[track_id].get("max_level", 0))
	track.xp = int(track.xp) + amount
	var events: Array = [{"type": "xp", "track": track_id, "amount": amount}]
	while (cap == 0 or int(track.level) < cap) and int(track.xp) >= xp_to_next(track_id, int(track.level)):
		track.xp = int(track.xp) - xp_to_next(track_id, int(track.level))
		track.level = int(track.level) + 1
		events.append({"type": "level_up", "track": track_id, "level": track.level, "name": rules.tracks[track_id].get("name", track_id)})
	if cap > 0 and int(track.level) >= cap:
		track.xp = 0
	return events

func gear_bonus(definition: Dictionary, metadata: Dictionary) -> Dictionary:
	## Flat stats scaled by the item's quality tier, plus percent modifiers.
	var equipment: Dictionary = definition.payload.equipment
	var tier: String = quality.of(definition, metadata)
	var scale: int = 100 + quality.bonus_percent(tier)
	var flat := {}
	for stat in equipment.get("stats", {}):
		var value := int(equipment.stats[stat])
		flat[stat] = value * scale / 100 if value >= 0 else value
	var percent := {}
	for modifier in equipment.get("modifiers", []):
		percent[modifier.stat] = int(percent.get(modifier.stat, 0)) + int(modifier.get("percent", 0))
		flat[modifier.stat] = int(flat.get(modifier.stat, 0)) + int(modifier.get("add", 0))
	return {"flat": flat, "percent": percent, "quality": tier}

func effective(base_stats: Dictionary, character: Dictionary, definition_for: Callable, sources: Array = []) -> Dictionary:
	## {stats: {stat: total}, breakdown: {stat: {base, growth, gear, talent, percent}}}.
	## sources: further derived modifiers {flat, percent} (talents). breakdown.talent is
	## exactly what the sources add on top of base + growth + gear.
	var growth := {}
	for track_id in rules.tracks:
		var at_level := level(character, track_id)
		for step in rules.tracks[track_id].get("growth", []):
			growth[step.stat] = int(growth.get(step.stat, 0)) + int(step.amount) * ((at_level - 1) / int(step.every))
	var flat := {}
	var percent := {}
	for slot in character.get("equipment", {}):
		var record: Dictionary = character.equipment[slot]
		var definition: Dictionary = definition_for.call(record)
		if definition.is_empty():
			continue
		var bonus := gear_bonus(definition, record.get("metadata", {}))
		for stat in bonus.flat:
			flat[stat] = int(flat.get(stat, 0)) + int(bonus.flat[stat])
		for stat in bonus.percent:
			percent[stat] = int(percent.get(stat, 0)) + int(bonus.percent[stat])
	var extra_flat := {}
	var extra_percent := {}
	for source in sources:
		for stat in source.get("flat", {}):
			extra_flat[stat] = int(extra_flat.get(stat, 0)) + int(source.flat[stat])
		for stat in source.get("percent", {}):
			extra_percent[stat] = int(extra_percent.get(stat, 0)) + int(source.percent[stat])
	var totals := {}
	var breakdown := {}
	for stat in rules.stats:
		var raw := int(base_stats.get(stat, 0)) + int(growth.get(stat, 0)) + int(flat.get(stat, 0))
		var without := _total(stat, raw, int(percent.get(stat, 0)))
		totals[stat] = _total(stat, raw + int(extra_flat.get(stat, 0)), int(percent.get(stat, 0)) + int(extra_percent.get(stat, 0)))
		breakdown[stat] = {"base": int(base_stats.get(stat, 0)), "growth": int(growth.get(stat, 0)), "gear": without - int(base_stats.get(stat, 0)) - int(growth.get(stat, 0)), "talent": totals[stat] - without, "percent": int(percent.get(stat, 0)) + int(extra_percent.get(stat, 0))}
	return {"stats": totals, "breakdown": breakdown}

func _total(stat: String, raw: int, percent: int) -> int:
	return maxi(1 if stat == "max_hp" else 0, raw * (100 + percent) / 100)

func requirement_error(definition: Dictionary, character: Dictionary) -> String:
	var needed: Dictionary = definition.payload.equipment.get("requirements", {})
	if needed.has("level") and level(character) < int(needed.level):
		return "Requires level %d (you are level %d)" % [int(needed.level), level(character)]
	return ""

func validate_equipment(definition: Dictionary) -> String:
	## Definition-level checks for anything that can be worn.
	var payload: Dictionary = definition.get("payload", {})
	var equipment: Variant = payload.get("equipment")
	if not equipment is Dictionary:
		return ""
	if definition.get("kind") != "item" or payload.get("stackable", false) or int(payload.get("stack_limit", 1)) != 1:
		return "Equipment must be a non-stackable item"
	if equipment.get("slot") not in slot_ids():
		return "Unknown equipment slot: " + str(equipment.get("slot"))
	if not equipment.get("stats", {}) is Dictionary or not equipment.get("modifiers", []) is Array:
		return "Equipment stats must be an object and modifiers an array"
	for stat in equipment.get("stats", {}):
		if not rules.stats.has(stat) or not Data.integer(equipment.stats[stat]) or absi(int(equipment.stats[stat])) > 100000:
			return "Unknown equipment stat or invalid value: " + str(stat)
	for modifier in equipment.get("modifiers", []):
		if not modifier is Dictionary or not rules.stats.has(modifier.get("stat")) or not Data.integer(modifier.get("percent", 0)) or not Data.integer(modifier.get("add", 0)) or absi(int(modifier.get("percent", 0))) > 1000:
			return "Invalid equipment modifier"
	var requirements: Variant = equipment.get("requirements", {})
	if not requirements is Dictionary or (requirements.has("level") and (not Data.integer(requirements.level) or requirements.level < 1)):
		return "Equipment requirements must be an object with level >= 1"
	if payload.has("quality") and not quality.has(payload.quality):
		return "Unknown item quality tier: " + str(payload.quality)
	return ""

func _fail(message: String) -> bool:
	last_error = message
	return false
