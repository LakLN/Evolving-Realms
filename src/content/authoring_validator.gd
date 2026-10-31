extends RefCounted
## Authoring boundary. Structural preflight precedes the actual engine validators.
const Contracts = preload("res://src/content/authoring_contracts.gd")
const Data = preload("res://src/data/json_data.gd")
const Skills = preload("res://src/core/skills.gd")
const Talents = preload("res://src/core/talents.gd")
const Effects = preload("res://src/core/effects.gd")
const Quality = preload("res://src/core/item_quality.gd")
const Stats = preload("res://src/core/character_stats.gd")
const Survival = preload("res://src/core/survival.gd")
const Items = preload("res://src/core/item_effects.gd")
const Creatures = preload("res://src/world/world_creatures.gd")
const Encounters = preload("res://src/world/world_encounters.gd")
const Locations = preload("res://src/world/world_locations.gd")
const Events = preload("res://src/core/world_events.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Capabilities = preload("res://src/content/capability_registry.gd")
const Registry = preload("res://src/content/content_registry.gd")
const PAYLOAD_FIELDS := {
	"item": ["stackable", "stack_limit", "quality", "equipment", "skill_book"],
	"skill": ["type", "tags", "elements", "learn", "use", "effects", "relations", "passive", "abilities"],
	"talent": ["rank", "unique", "awakening", "passive", "abilities", "limitations"],
	"creature": ["visual", "disposition", "stats", "movement", "ai", "spawn", "loot", "elements", "effect_modifiers", "on_hit_effects"],
	"status": ["element", "duration", "max_stacks", "refresh", "harmful", "tick", "skip_every", "modifiers"],
	"item_use": ["item", "consume", "verb", "effects"], "loot_extension": ["source", "chance_per_10000", "table"],
	"encounter": Encounters.FIELDS, "location": Locations.FIELDS, "world_event": Events.FIELDS}
const OBJECT_ARRAYS := ["dependencies", "effects", "passive", "abilities", "conditions", "relations", "modifiers", "effect_modifiers", "skill_modifiers", "on_hit_effects", "entries", "guaranteed"]
const ARRAYS := ["required_capabilities", "elements", "effect_types", "dispositions", "biomes", "tags", "skills", "values", "limitations"]
const OBJECTS := ["stats", "equipment", "requirements", "skill_book", "item", "use", "learn", "cost", "target", "awakening", "limits", "ai", "movement", "spawn", "loot", "table", "source", "modifier", "tick"]

class View extends RefCounted:
	var base: RefCounted
	var definitions: Dictionary = {}
	var last_error := ""
	func load_definition(world_id: String, id: String, version: int) -> Dictionary:
		return definitions.get("%s@%d" % [id, version], {}) if definitions.has("%s@%d" % [id, version]) else base.load_definition(world_id, id, version)
	func list_definitions(world_id: String) -> Array:
		var result: Array = base.list_definitions(world_id)
		for def in definitions.values(): result.append({"content_id": def.content_id, "version": def.version, "kind": def.kind, "status": def.status})
		return result

static func shape(value: Variant, depth: int = 0) -> String:
	if depth > 12: return "JSON nesting exceeds 12"
	if value is String: return "String exceeds 4096 characters" if value.length() > 4096 else ""
	if value is Array:
		if value.size() > 64: return "Array exceeds 64 entries"
		for child in value:
			var problem := shape(child, depth + 1)
			if not problem.is_empty(): return problem
	if value is Dictionary:
		if value.size() > 64: return "Object exceeds 64 fields"
		for key in value:
			var child: Variant = value[key]
			if key in OBJECT_ARRAYS and (not child is Array or not child.all(func(e: Variant) -> bool: return e is Dictionary)): return key + " must be an object array"
			if key in ARRAYS and not child is Array: return key + " must be an array"
			if key in OBJECTS and not child is Dictionary: return key + " must be an object"
			var problem := shape(child, depth + 1)
			if not problem.is_empty(): return problem
	return ""

static func key(def: Dictionary) -> String:
	return "%s@%d" % [def.content_id, int(def.version)]

static func fingerprint(def: Dictionary) -> String:
	return JSON.stringify({"kind": def.kind, "payload": def.payload, "category": def.get("metadata", {}).get("category", "")}, "", true).sha256_text()

func validate(registry: RefCounted, world_id: String, content: Variant) -> Dictionary:
	var report := {"status": "valid", "errors": [], "missing_capabilities": [], "ordered": [], "fingerprints": {}}
	if not content is Dictionary or not Data.valid(content) or JSON.stringify(content).to_utf8_buffer().size() > 200000 or content.get("schema_version") != 1 or not content.get("definitions") is Array or content.definitions.is_empty() or content.definitions.size() > 24:
		return {"status": "invalid", "errors": [{"category": "schema", "message": "Expected schema 1 with 1..24 bounded definitions"}], "missing_capabilities": [], "ordered": []}
	var view := View.new()
	view.base = registry
	var todo: Array = []
	var by_id := {}
	for value in content.definitions:
		var problem := _header(value)
		if not problem.is_empty():
			report.errors.append({"category": "schema", "message": problem})
			continue
		var def: Dictionary = value.duplicate(true)
		for field in ["metadata", "provenance"]: def[field] = def.get(field, {})
		for field in ["dependencies", "required_capabilities"]: def[field] = def.get(field, [])
		def.status = "active" # Provider cannot approve/activate itself.
		if by_id.has(def.content_id): report.errors.append({"category": "conflict", "message": "Duplicate content ID: " + def.content_id})
		by_id[def.content_id] = true
		todo.append(def)
	if not report.errors.is_empty():
		report.status = "invalid"
		return report
	# Registry commits dependencies first; detect cycles/missing references before writes.
	while not todo.is_empty():
		var progress := false
		for def in todo.duplicate():
			if def.dependencies.any(func(dep: Dictionary) -> bool: return view.load_definition(world_id, dep.content_id, int(dep.version)).is_empty()): continue
			view.definitions[key(def)] = def
			report.ordered.append(def)
			todo.erase(def)
			progress = true
		if not progress:
			report.errors.append({"category": "dependency", "message": "Missing or cyclic pinned dependency"})
			break
	var quality := Quality.new()
	quality.load_rules()
	var stats := Stats.new()
	stats.load_rules(quality)
	var survival := Survival.new()
	survival.load_rules()
	var talents := Talents.new()
	talents.load_rules()
	var skills := Skills.new()
	skills.load_rules()
	var use_owners := {}
	for header in view.list_definitions(world_id):
		if header.kind == "item_use" and header.status == "active":
			var use: Dictionary = view.load_definition(world_id, header.content_id, int(header.version))
			var target := JSON.stringify(use.payload.get("item", {}), "", true)
			if use_owners.has(target) and use_owners[target] != use.content_id: report.errors.append({"category": "conflict", "message": "Multiple item-use rules target the same item"})
			use_owners[target] = use.content_id
	var context := {"stats": stats.rules.stats.keys(), "needs": survival.rules.needs.keys(), "slots": stats.slot_ids(), "talents": talents}
	var existing_hashes := {}
	var latest := {}
	for header in registry.list_definitions(world_id):
		latest[header.content_id] = int(header.version)
		if header.status == "active" and header.kind != "generation_proposal":
			var existing: Dictionary = registry.load_definition(world_id, header.content_id, int(header.version))
			existing_hashes[fingerprint(existing)] = existing.content_id
	for def in report.ordered:
		if int(def.version) != int(latest.get(def.content_id, 0)) + 1:
			report.errors.append({"category": "conflict", "message": "Version is not the next append-only version: " + key(def)})
		if latest.has(def.content_id):
			var previous: Dictionary = registry.load_definition(world_id, def.content_id, latest[def.content_id])
			if previous.provenance.get("origin") != "ai": report.errors.append({"category": "conflict", "message": "Cannot supersede authored content"})
		var hash_value := fingerprint(def)
		if existing_hashes.has(hash_value): report.errors.append({"category": "conflict", "message": "Gameplay duplicate of " + existing_hashes[hash_value]})
		existing_hashes[hash_value] = def.content_id
		report.fingerprints[key(def)] = hash_value
		for capability in def.required_capabilities:
			if not Capabilities.supports(capability): report.missing_capabilities.append(capability)
		if not PAYLOAD_FIELDS.has(def.kind):
			report.missing_capabilities.append("authoring.kind." + def.kind)
			continue
		for field in def.payload:
			if field not in PAYLOAD_FIELDS[def.kind]: report.missing_capabilities.append("payload.%s.%s" % [def.kind, field])
		Contracts.scan(def.payload, "payload", report.missing_capabilities)
		var reference_problem := _references(def.payload, def, view, world_id)
		if not reference_problem.is_empty(): report.errors.append({"category": "dependency", "message": reference_problem})
		var verdict := {"problem": "", "missing": []}
		match def.kind:
			"skill": verdict = skills.classify(def, context, view, world_id)
			"talent": verdict = talents.classify(def, context.stats, context.needs, view, world_id)
			"status": verdict = Effects.classify(def)
			"item": verdict.problem = _item(def, view, world_id, stats, quality, report.missing_capabilities)
			"item_use": verdict = _use(def, view, world_id, report.missing_capabilities)
			"creature":
				verdict = _creature(def, view, world_id)
				# The frozen v1 layer never admits new species; distribution is an encounter.
				if def.payload.has("spawn"): report.missing_capabilities.append("creature.payload_spawn")
			"encounter": verdict = Encounters.classify(def, view, world_id)
			"location": verdict = Locations.classify(def, view, world_id, context, skills)
			"world_event": verdict = Events.classify(def, view, world_id, context, skills)
			"loot_extension": verdict.problem = _loot(def, view, world_id, quality)
		report.missing_capabilities.append_array(verdict.missing)
		if not verdict.problem.is_empty(): report.errors.append({"category": "rule", "content_id": def.content_id, "message": verdict.problem})
		for dep in def.dependencies:
			var dependency: Dictionary = view.load_definition(world_id, dep.content_id, int(dep.version))
			if dependency.get("status") != "active": report.missing_capabilities.append("dependency:" + key(dep))
	report.status = "invalid" if not report.errors.is_empty() else ("pending_capability" if not report.missing_capabilities.is_empty() else "valid")
	return report

func _header(value: Variant) -> String:
	if not value is Dictionary or not Data.identifier(value.get("content_id")) or not value.content_id.begins_with("ai:") or not Data.integer(value.get("version")) or value.version < 1 or value.version > 1000000 or value.get("schema_version") != 1 or not value.get("kind") is String or not value.get("name") is String or value.name.strip_edges().is_empty() or not value.get("description", "") is String or not value.get("payload") is Dictionary:
		return "Definition needs ai: ID, positive version, schema 1, kind, name and payload"
	if not value.get("metadata", {}) is Dictionary or not value.get("provenance", {}) is Dictionary: return "Metadata/provenance must be objects"
	for field in ["dependencies", "required_capabilities"]:
		if not value.get(field, []) is Array: return field + " must be an array"
	var seen := {}
	for dep in value.get("dependencies", []):
		if not dep is Dictionary or not Data.identifier(dep.get("content_id")) or not Data.integer(dep.get("version")) or dep.version < 1: return "Dependency needs pinned ID/version"
		if dep.content_id == value.content_id or seen.has(key(dep)): return "Self/duplicate dependency"
		seen[key(dep)] = true
	if not value.get("required_capabilities", []).all(func(c: Variant) -> bool: return c is String and not c.is_empty()): return "Capability names must be strings"
	return shape(value.payload)

func _item(def: Dictionary, view: RefCounted, world_id: String, stats: RefCounted, quality: RefCounted, missing: Array) -> String:
	var p: Dictionary = def.payload
	if not p.get("stackable", false) is bool or not Effects.integer(p.get("stack_limit", 1), 1, 1000): return "Invalid item stacking"
	if p.has("quality") and not quality.has(p.quality): return "Unknown quality"
	if p.has("equipment"):
		var problem: String = stats.validate_equipment(def)
		if not problem.is_empty(): return problem
		for m in p.equipment.get("effect_modifiers", []):
			problem = Effects.check_modifier(m)
			if problem.begins_with("Unknown"):
				missing.append("effect.modifier." + str(m.get("type", "unknown")))
				continue
			if not problem.is_empty(): return problem
		for m in p.equipment.get("skill_modifiers", []):
			problem = Talents.check_skill_modifier(m)
			if not problem.is_empty(): return problem
	if p.has("skill_book"):
		var ref: Variant = p.skill_book.get("skill")
		if not ref is Dictionary or not Data.identifier(ref.get("content_id")) or not Data.integer(ref.get("version")): return "Book needs skill ID/version"
		if not p.skill_book.get("consume_on_learn", true) is bool: return "Invalid book consumption"
		if not _pinned(def, ref) or view.load_definition(world_id, ref.content_id, int(ref.version)).get("kind") != "skill": return "Book must pin an existing skill"
	return ""

func _use(def: Dictionary, view: RefCounted, world_id: String, missing: Array) -> Dictionary:
	var p: Dictionary = def.payload
	var known: Array = []
	var problem := ""
	if not p.get("effects") is Array or p.effects.is_empty() or p.effects.size() > 8: problem = "Item use needs 1..8 effects"
	else:
		for effect in p.effects:
			if not effect.get("type") is String: problem = "Item effect needs a type"
			elif effect.type in Items.TYPES or effect.type in ["apply_status", "cleanse"]: known.append(effect)
			else: missing.append("item.effect." + effect.type)
	if not known.is_empty(): problem = Items.validate(known)
	if not p.get("item") is Dictionary or not Data.identifier(p.item.get("content_id")) or not Data.integer(p.item.get("version")) or not _pinned(def, p.item) or view.load_definition(world_id, p.item.content_id, int(p.item.version)).get("kind") != "item": problem = "Item use needs a pinned item"
	if not Effects.integer(p.get("consume", 1), 1, 100): problem = "Consume must be 1..100"
	for effect in p.get("effects", []):
		if effect.get("type") == "apply_status":
			var error := Effects.check_application(effect, def, view, world_id, missing)
			if not error.is_empty(): problem = error
	return {"problem": problem, "missing": []}

func _creature(def: Dictionary, view: RefCounted, world_id: String) -> Dictionary:
	var projected: Dictionary = def.duplicate(true)
	var missing: Array = []
	var elements: Array = projected.payload.get("elements", ["neutral"])
	for element in elements:
		if not Effects.rules().elements.has(element): missing.append("effect.element." + str(element))
	projected.payload.elements = elements.filter(func(e: Variant) -> bool: return Effects.rules().elements.has(e))
	var modifiers: Array = []
	for modifier in projected.payload.get("effect_modifiers", []):
		var problem := Effects.check_modifier(modifier)
		if problem.begins_with("Unknown"): missing.append("effect.modifier." + str(modifier.get("type", "unknown")))
		else: modifiers.append(modifier)
	projected.payload.effect_modifiers = modifiers
	var hits: Array = []
	for effect in projected.payload.get("on_hit_effects", []):
		if not effect.get("type") is String: return {"problem": "Hit effect needs type", "missing": missing}
		if effect.type != "apply_status": missing.append("creature.hit_effect." + effect.type)
		else:
			var needs: Array = []
			var problem := Effects.check_application(effect, def, view, world_id, needs)
			if not problem.is_empty(): return {"problem": problem, "missing": missing}
			missing.append_array(needs)
			if needs.is_empty(): hits.append(effect)
	projected.payload.on_hit_effects = hits
	var layer := Creatures.new()
	layer.registry = view
	layer.world = {"world_id": world_id}
	return {"problem": "" if layer.validate(projected) else layer.last_error, "missing": missing}

func _loot(def: Dictionary, view: RefCounted, world_id: String, quality: RefCounted) -> String:
	var p: Dictionary = def.payload
	if not p.get("source") is Dictionary or not Data.identifier(p.source.get("content_id")) or not Data.integer(p.source.get("version")) or not _pinned(def, p.source): return "Loot source must be pinned"
	var source: Dictionary = view.load_definition(world_id, p.source.content_id, int(p.source.version))
	if source.get("kind") not in ["resource", "chest", "creature"] or not source.payload.has("loot"): return "Loot source must be an object/creature"
	if not Effects.integer(p.get("chance_per_10000", 10000), 0, 10000): return "Invalid loot chance"
	var loot := Loot.new()
	if not loot.validate(p.get("table"), view, world_id): return loot.last_error
	for entry in p.table.get("entries", []) + p.table.get("guaranteed", []):
		if not _pinned(def, entry): return "Loot must pin each item"
		for tier in entry.get("quality", {}):
			if not quality.has(tier): return "Unknown loot quality"
	return ""

func _pinned(def: Dictionary, ref: Dictionary) -> bool:
	return def.dependencies.any(func(dep: Dictionary) -> bool: return dep.content_id == ref.content_id and int(dep.version) == int(ref.version))

func _references(value: Variant, def: Dictionary, view: RefCounted, world_id: String) -> String:
	if value is Array:
		for child in value:
			var problem := _references(child, def, view, world_id)
			if not problem.is_empty(): return problem
	if value is Dictionary:
		var ids: Array = []
		for field in ["content_id", "status", "skill"]:
			if value.get(field) is String and Data.identifier(value[field]): ids.append(value[field])
		if value.get("type") == "talent": ids.append_array(value.get("values", []))
		for id in ids:
			var matches: Array = def.dependencies.filter(func(dep: Dictionary) -> bool: return dep.content_id == id and (not value.has("version") or int(dep.version) == int(value.version)))
			if matches.is_empty() or view.load_definition(world_id, id, int(matches[0].version)).is_empty(): return "Reference must resolve to a pinned dependency: " + str(id)
		for child in value.values():
			var problem := _references(child, def, view, world_id)
			if not problem.is_empty(): return problem
	return ""
