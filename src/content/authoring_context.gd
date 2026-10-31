extends RefCounted
## Bounded retrieval; no Run state, inventory, keys or full database in prompts.
const Capabilities = preload("res://src/content/capability_registry.gd")
const Contracts = preload("res://src/content/authoring_contracts.gd")
const Registry = preload("res://src/content/content_registry.gd")
const Skills = preload("res://src/core/skills.gd")
const Talents = preload("res://src/core/talents.gd")
const Effects = preload("res://src/core/effects.gd")
const Quality = preload("res://src/core/item_quality.gd")
const Stats = preload("res://src/core/character_stats.gd")

static func capabilities() -> Dictionary:
	var quality := Quality.new()
	quality.load_rules()
	var stats := Stats.new()
	stats.load_rules(quality)
	var talents := Talents.new()
	talents.load_rules()
	var skills := Skills.new()
	skills.load_rules()
	return {"version": 1, "definitions": Registry.SUPPORTED_CAPABILITIES, "supported": Capabilities.all_supported(),
		"stats": stats.rules.stats.keys(), "slots": stats.slot_ids(), "qualities": quality.tiers,
		"talent_ranks": talents.ranks, "talent_triggers": Talents.TRIGGERS,
		"talent_passive_effects": Talents.PASSIVE_EFFECTS, "talent_conditions": Talents.CONDITIONS,
		"skill_targets_and_effects": Skills.TARGETS, "skill_conditions": Skills.CONDITIONS,
		"resources": skills.rules.resources, "elements": Effects.rules(),
		"status_ticks": ["damage", "heal"], "status_refresh": ["keep", "refresh", "extend"],
		"effect_modifiers": ["damage", "healing", "resistance", "status_duration", "status_stacks"],
		"modifier_conditions": ["source_status", "target_status", "hp_below_percent", "hp_at_least_percent"],
		"item_effects": ["heal", "sate", "quench", "apply_status", "cleanse"],
		"creature_dispositions": ["passive", "neutral", "hostile"],
		"limits": {"definitions": 24, "effects_per_skill": 8, "status_duration": 100, "status_stacks": 20},
		"unsupported": ["summon", "contracts", "quests", "creature_to_creature_status", "creature_max_hp_status"],
		"parameter_contracts": {"objects": Contracts.FIELDS, "effects": Contracts.EFFECTS, "conditions": Contracts.CONDITIONS},
		"rules": ["Definitions are immutable and version-pinned; reference explicit dependencies.",
			"Do not invent executable code or engine rules. Unknown capabilities stay pending.",
			"Turns are local/offline; generation never runs during movement or load.",
			"Distribution uses loot_extension or explicit authored encounters; no automatic map rewrite.",
			"New content uses ai: IDs. A review and explicit confirmation/activation are required."]}

static func retrieve(store: RefCounted, world_id: String, query: String, related: Array = [], region: String = "") -> Dictionary:
	var world: Dictionary = store.load_world(world_id)
	if world.is_empty(): return {"error": store.last_error}
	if query.length() > 4096 or region.length() > 1024 or related.size() > 12:
		return {"error": "Context request exceeds bounds"}
	var ranked: Array = []
	for header in store.content.list_definitions(world_id):
		if header.kind == "generation_proposal" or header.status != "active": continue
		var definition: Dictionary = store.content.load_definition(world_id, header.content_id, int(header.version))
		var score := 0
		if header.content_id in related: score += 10000
		if header.content_id == "core:wayfarer_cache": score += 50
		var searchable := (str(definition.name) + " " + str(definition.description) + " " + str(definition.kind) + " " + str(definition.payload.keys()) + " " + str(definition.metadata)).to_lower()
		for word in query.to_lower().split(" ", false):
			if word.length() >= 3 and searchable.contains(word): score += 10
		if definition.kind == "status": score += 20
		ranked.append({"definition": definition, "score": score})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score if a.score != b.score else a.definition.content_id < b.definition.content_id)
	var selected: Array = []
	var bytes := 0
	for entry in ranked:
		if selected.size() >= 20: break
		var def: Dictionary = entry.definition.duplicate(true)
		def.erase("provenance")
		var size := JSON.stringify(def).to_utf8_buffer().size()
		if bytes + size > 50000: continue
		selected.append(def)
		bytes += size
	for id in related:
		if not selected.any(func(d: Dictionary) -> bool: return d.content_id == id): return {"error": "Related content missing or exceeds context budget: " + str(id)}
	return {"context_version": 1, "world": {"world_id": world_id, "name": world.name, "generation_version": world.generation_version},
		"region": region, "capabilities": capabilities(), "related_definitions": selected,
		"retrieval": {"limit": 20, "included": selected.size(), "query": query, "truncated": ranked.size() > selected.size()}}
