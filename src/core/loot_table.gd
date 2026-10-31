extends RefCounted
const Data = preload("res://src/data/json_data.gd")
var last_error := ""

static func number(key: String) -> int:
	return (key.sha256_text().substr(0, 8).hex_to_int()) & 0x7fffffff

func validate(table: Variant, registry: RefCounted, world_id: String) -> bool:
	if not table is Dictionary or not Data.valid(table) or not Data.integer(table.get("rolls", 0)) or table.get("rolls", 0) < 0 or table.get("rolls", 0) > 16:
		return _fail("Loot table requires 0..16 integer rolls")
	if not table.get("guaranteed", []) is Array or not table.get("entries", []) is Array:
		return _fail("Loot entries and guaranteed loot must be arrays")
	if table.get("guaranteed", []).size() > 16 or table.get("entries", []).size() > 64 or (table.get("rolls", 0) > 0 and table.get("entries", []).is_empty()):
		return _fail("Empty or excessive loot table")
	for group in ["guaranteed", "entries"]:
		for entry in table.get(group, []):
			if not entry is Dictionary or not Data.identifier(entry.get("content_id")) or not Data.integer(entry.get("version")) or not Data.integer(entry.get("min")) or not Data.integer(entry.get("max")):
				return _fail("Invalid loot item reference or quantity")
			if entry.version < 1 or entry.min < 1 or entry.max < entry.min or entry.max > 1000:
				return _fail("Loot quantities must satisfy 1 <= min <= max <= 1000")
			if group == "entries" and (not Data.integer(entry.get("weight")) or entry.weight < 1 or entry.weight > 1000000):
				return _fail("Loot weights must be positive integers <= 1000000")
			var definition: Dictionary = registry.load_definition(world_id, entry.content_id, int(entry.version))
			if definition.is_empty() or definition.get("kind") != "item" or definition.get("status") != "active":
				return _fail("Loot references a missing or inactive item: " + str(entry.content_id))
	if table.get("rolls", 0) == 0 and table.get("guaranteed", []).is_empty():
		return _fail("Loot table would never produce an item")
	last_error = ""
	return true

func roll(table: Dictionary, seed_key: String) -> Array:
	# Call validate first. Independent SHA256 draw keys; no mutable RNG state.
	var selected: Array = table.get("guaranteed", []).duplicate(true)
	var total := 0
	for entry in table.get("entries", []):
		total += int(entry.weight)
	for index in int(table.get("rolls", 0)):
		var ticket := number(seed_key + "/pick/" + str(index)) % total
		for entry in table.entries:
			ticket -= int(entry.weight)
			if ticket < 0:
				selected.append(entry)
				break
	var awards: Array = []
	for index in selected.size():
		var entry: Dictionary = selected[index]
		var quantity := int(entry.min) + number(seed_key + "/quantity/" + str(index)) % (int(entry.max) - int(entry.min) + 1)
		awards.append({"content_id": entry.content_id, "version": int(entry.version), "quantity": quantity})
	return awards

func _fail(message: String) -> bool:
	last_error = message
	return false
