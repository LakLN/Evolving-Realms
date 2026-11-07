extends RefCounted
## Bounded authored Run overlays v1. Definitions live in copied atlas plans;
## only ordinary execution receipts persist. Effective cells/availability are derived.
const Surfaces = preload("res://src/world/surfaces.gd")
const Data = preload("res://src/data/json_data.gd")
var definitions: Array = []
var cells: Dictionary = {}
var footprint: Dictionary = {} # Union of every authored state, for resident safety.
var active: Dictionary = {}
var revision := 0

static func compile(source: Dictionary, sites: Array, rotation: int) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	var ids := {}
	for site in sites: ids[str(site.instance_id).get_slice("/site/", 1)] = site
	result.source = ids[source.source_site].instance_id
	for group in [result.baseline] + result.variants.map(func(v: Dictionary) -> Array: return v.cells):
		for c in group:
			var anchor: Dictionary = ids[c.site].position
			var offset := Vector2i(int(c.offset[0]), int(c.offset[1]))
			for unused in rotation: offset = Vector2i(-offset.y, offset.x)
			c.position = {"x": int(anchor.x) + offset.x, "y": int(anchor.y) + offset.y}
	for variant in result.variants:
		for requirement in variant.requires: requirement.instance_id = ids[requirement.site].instance_id
		for rule in variant.availability: rule.instance_id = ids[rule.site].instance_id
	return result

func configure(plans: Array) -> String:
	definitions.clear()
	footprint.clear()
	for plan in plans:
		if not plan.has("state_variants"): continue
		var d: Dictionary = plan.state_variants
		if not Data.integer(d.get("version")) or int(d.version) != 1: return "Unsupported world-state variant version"
		if not Data.identifier(d.get("id")) or not d.get("source") is String or not d.get("baseline") is Array or not d.get("variants") is Array: return "Invalid world-state definition"
		var site_ids := {}
		for site in plan.sites: site_ids[site.instance_id] = true
		if not site_ids.has(d.source): return "Unknown world-state source site"
		var receipts := {}
		for v in d.variants:
			if receipts.has(v.receipt) or not v.get("requires") is Array or not v.get("availability") is Array: return "Invalid world-state variant"
			if not v.get("receipt") is String or not v.get("recommendation") is String or not v.get("id") is String: return "Invalid world-state receipt"
			for r in v.requires:
				if not r is Dictionary or not site_ids.has(r.get("instance_id", "")) or not r.get("interaction") is String: return "Invalid world-state evidence reference"
			for r in v.availability:
				if not r is Dictionary or not site_ids.has(r.get("instance_id", "")) or not r.get("enabled") is bool or not r.get("interactions") is Array: return "Invalid world-state interaction filter"
			receipts[v.receipt] = true
		for group in [d.baseline] + d.variants.map(func(v: Dictionary) -> Array: return v.cells):
			if group.size() > 1024: return "World-state overlay exceeds bounded size"
			var used := {}
			for c in group:
				if not Data.position(c.get("position")) or c.get("surface") not in Surfaces.BY_NAME: return "Invalid world-state cell"
				var tile := Vector2i(int(c.position.x), int(c.position.y))
				if used.has(tile) or floori(float(tile.x) / 512) != int(plan.slot.x) or floori(float(tile.y) / 512) != int(plan.slot.y): return "Overlapping or out-of-land world-state cells"
				used[tile] = true
				footprint[tile] = true
		definitions.append(d)
	return ""

func rebuild(mutations: Dictionary) -> String:
	var next := {}
	var states := {}
	for d in definitions:
		var resolved: Dictionary = mutations.get(d.source, {}).get("resolved", {})
		var chosen := {}
		for v in d.variants:
			if resolved.has(v.receipt):
				if not chosen.is_empty() or not resolved.has(v.recommendation): return "Conflicting world-state execution receipts"
				chosen = v
		if not chosen.is_empty():
			var recommendations := 0
			for v in d.variants:
				if resolved.has(v.recommendation): recommendations += 1
			if recommendations != 1: return "Conflicting world-state recommendations"
		for c in d.baseline + chosen.get("cells", []):
			next[Vector2i(int(c.position.x), int(c.position.y))] = int(Surfaces.BY_NAME[c.surface])
		if not chosen.is_empty(): states[d.id] = chosen
	cells = next
	active = states
	revision += 1
	return ""

func allowed(instance_id: String, interaction: String) -> bool:
	for variant in active.values():
		for rule in variant.availability:
			if rule.instance_id == instance_id and interaction in rule.interactions: return rule.enabled
	for d in definitions:
		if instance_id != d.source: continue
		for v in d.variants:
			if interaction == v.receipt and active.has(d.id): return false
	return true

func requirement(mutations: Dictionary, instance_id: String, interaction: String, position: Vector2i) -> String:
	for d in definitions:
		if d.source != instance_id: continue
		for v in d.variants:
			if v.receipt != interaction: continue
			if active.has(d.id): return "The waterworks have already been changed"
			var resolved: Dictionary = mutations.get(d.source, {}).get("resolved", {})
			if not resolved.has(v.recommendation): return "Record the matching recommendation before physical work"
			for r in v.requires:
				if not mutations.get(r.instance_id, {}).get("resolved", {}).has(r.interaction): return "Physical work needs further field evidence"
			# Refuse rather than teleport anyone caught by newly flooded cells.
			for c in v.cells:
				if Vector2i(int(c.position.x), int(c.position.y)) == position and not Surfaces.walkable(Surfaces.BY_NAME[c.surface]): return "Move to dry control ground before physical work"
	return ""
