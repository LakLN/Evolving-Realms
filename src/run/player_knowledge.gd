extends RefCounted
## Confirmed, useful facts only; rumors/documents remain in the journal.
static func validate(character: Dictionary) -> String:
	var known: Variant = character.get("knowledge", {})
	if not known is Dictionary: return "Invalid Knowledge state"
	for id in known:
		var entry: Variant = known[id]
		if not entry is Dictionary or entry.get("id") != id or entry.get("version") != 1: return "Unsupported Knowledge entry version"
		for key in ["category", "title", "text"]:
			if not entry.get(key) is String or entry[key].strip_edges().is_empty(): return "Invalid Knowledge text"
	return ""

static func unlock(session: RefCounted, entry: Dictionary) -> bool:
	var character: Dictionary = session.run.state.character
	if not character.has("knowledge"): character.knowledge = {}
	if character.knowledge.has(entry.id): return false
	var saved := entry.duplicate(true)
	saved.turn = int(session.run.state.turn)
	saved.version = 1
	character.knowledge[entry.id] = saved
	session.dirty = true
	return true

static func entries(session: RefCounted) -> Array:
	var result: Array = session.run.state.character.get("knowledge", {}).values().duplicate(true)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.category + a.title < b.category + b.title)
	return result
