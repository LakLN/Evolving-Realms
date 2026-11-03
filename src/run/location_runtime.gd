extends RefCounted
## Per-Run discovery and resolution of special places (Milestone 02 I). Methods take
## the owning session (no reference cycle). The World layer says where places are;
## this Run's entity mutation says what the player found and resolved:
##   {"location": 1, "discovered": true, "discovered_turn": 12,
##    "resolved": {"<interaction>": {"turn": 14, "received": [...]}}}
## Everything is planned on copies first; refusals change nothing and spend no turn.
const Data = preload("res://src/data/json_data.gd")
const Events = preload("res://src/core/world_events.gd")
const Skills = preload("res://src/core/skills.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Inventory = preload("res://src/core/inventory.gd")
const ItemEffects = preload("res://src/core/item_effects.gd")
const WorldRules = preload("res://src/core/world_rules.gd")
const Knowledge = preload("res://src/run/player_knowledge.gd")
const Telemetry = preload("res://src/run/interaction_telemetry.gd")
const SEARCH_RADIUS := 2
const STATES := ["undiscovered", "discovered", "interactable", "resolved", "unavailable"]
var layer: RefCounted

func record(session: RefCounted, instance_id: String) -> Dictionary:
	var mutation: Variant = session.run.state.entity_mutations.get(instance_id, {})
	return mutation if mutation is Dictionary and mutation.has("location") else {}

func discovered(session: RefCounted, instance_id: String) -> bool:
	return record(session, instance_id).get("discovered", false)

func validate(session: RefCounted) -> String:
	## Saved location mutations must be well-formed (older saves have none).
	var knowledge_error := Knowledge.validate(session.run.state.character)
	if not knowledge_error.is_empty(): return knowledge_error
	for id in session.run.state.entity_mutations:
		var mutation: Variant = session.run.state.entity_mutations[id]
		if not mutation is Dictionary or not mutation.has("location"): continue
		if not mutation.get("discovered") is bool or not mutation.get("resolved", {}) is Dictionary: return "Corrupt location state in save: " + str(id)
		if mutation.has("world_rule_version") and (mutation.world_rule_version != 1 or mutation.get("world_state") not in ["thawed", "shattered"]): return "Unsupported world rule state: " + str(id)
	return ""

func available(session: RefCounted, instance: Dictionary, trigger: String = "") -> Array:
	## Unresolved interactions whose order and exclusivity allow them now.
	var definition: Dictionary = layer.definition_for(instance)
	var resolved: Dictionary = record(session, instance.instance_id).get("resolved", {})
	var exclusive_taken: bool = definition.payload.interactions.any(func(i: Dictionary) -> bool: return i.get("exclusive", false) and resolved.has(i.id))
	var result: Array = []
	for interaction in definition.payload.interactions:
		if resolved.has(interaction.id) or (not trigger.is_empty() and interaction.get("trigger", "interact") != trigger): continue
		if interaction.has("after") and not resolved.has(interaction.after): continue
		if interaction.get("exclusive", false) and exclusive_taken: continue
		if not unmet(session, interaction.get("reveal_conditions", [])).is_empty(): continue
		result.append(interaction)
	return result

func state(session: RefCounted, instance: Dictionary) -> String:
	if not discovered(session, instance.instance_id):
		return "undiscovered"
	var definition: Dictionary = layer.definition_for(instance)
	var resolved: Dictionary = record(session, instance.instance_id).get("resolved", {})
	var remaining := available(session, instance)
	if remaining.is_empty():
		# Everything done, or the rest was forfeited by an exclusive choice.
		return "resolved" if resolved.size() == definition.payload.interactions.size() else "unavailable"
	for interaction in remaining:
		if interaction.get("trigger", "interact") == "interact" and unmet(session, layer.event(interaction.event).payload.get("conditions", [])).is_empty():
			return "interactable"
	return "discovered"

func unmet(session: RefCounted, conditions: Array) -> Array:
	var view: Dictionary = session.skills.character_view(session)
	var result: Array = []
	for condition in conditions:
		if not _met(session, condition, view):
			result.append(Events.describe_condition(condition))
	return result

func _met(session: RefCounted, condition: Dictionary, view: Dictionary) -> bool:
	match condition.get("type"):
		"perception":
			return session.talents.perception().hidden
		"status":
			return session.run.state.character.get("statuses", []).any(func(s: Variant) -> bool: return s is Dictionary and s.get("id") == condition.status)
		"biome":
			return session.terrain.biome_at(session.position) in condition.values
		"any_of":
			return condition.conditions.any(func(inner: Dictionary) -> bool: return _met(session, inner, view))
	return condition.get("type") in Skills.CONDITIONS and session.skill_rules.met(condition, view)

func _detects(session: RefCounted, instance: Dictionary, searching: bool) -> bool:
	var tile := Vector2i(int(instance.position.x), int(instance.position.y))
	if not session.visible.has(tile):
		return false # Sight always matters: no second fog.
	var rule: Dictionary = layer.definition_for(instance).payload.get("discovery", {"mode": "visible"})
	var distance := maxi(absi(tile.x - session.position.x), absi(tile.y - session.position.y))
	var radius := int(rule.get("radius", 1))
	var close := false
	match rule.mode:
		"visible": close = true
		"proximity", "hidden": close = distance <= radius or (searching and distance <= maxi(radius, SEARCH_RADIUS))
		"search": close = searching and distance <= maxi(radius, SEARCH_RADIUS)
	return close and unmet(session, rule.get("conditions", [])).is_empty()

func tick(session: RefCounted) -> Array:
	## After an accepted action: discoveries in sight, then "enter" events on this tile.
	var events: Array = []
	for instance in layer.loaded():
		if int(session.stats().hp) <= 0: break
		if not discovered(session, instance.instance_id) and _detects(session, instance, false):
			events.append_array(_discover(session, instance))
		if Vector2i(int(instance.position.x), int(instance.position.y)) == session.position:
			for interaction in available(session, instance, "enter"):
				var event: Dictionary = layer.event(interaction.event)
				if not unmet(session, event.payload.get("conditions", [])).is_empty(): continue
				if not discovered(session, instance.instance_id): events.append_array(_discover(session, instance))
				var outcome := resolve(session, instance, interaction)
				events.append_array(outcome.get("events", []))
	return events

func search(session: RefCounted) -> Array:
	## Declared rule: searching always spends one turn, found or not.
	var found: Array = []
	var events: Array = []
	for instance in layer.loaded():
		if not discovered(session, instance.instance_id) and _detects(session, instance, true):
			events.append_array(_discover(session, instance))
			found.append(layer.definition_for(instance).name)
	events.push_front({"type": "search", "found": found})
	return events

func search_cue(session: RefCounted) -> bool:
	## A vague cue (never the place or its tile) when an undiscovered search-only place
	## is within searching range and in sight, so X is worth pressing.
	for instance in layer.loaded():
		if discovered(session, instance.instance_id) or layer.definition_for(instance).payload.get("discovery", {}).get("mode") != "search":
			continue
		var tile := Vector2i(int(instance.position.x), int(instance.position.y))
		var rule: Dictionary = layer.definition_for(instance).payload.discovery
		if session.visible.has(tile) and maxi(absi(tile.x - session.position.x), absi(tile.y - session.position.y)) <= maxi(int(rule.get("radius", 1)), SEARCH_RADIUS):
			return true
	return false

func _discover(session: RefCounted, instance: Dictionary) -> Array:
	if not layer.materialize(instance):
		return [{"type": "location_error", "error": layer.last_error}]
	var definition: Dictionary = layer.definition_for(instance)
	var mutation := record(session, instance.instance_id)
	if mutation.is_empty():
		mutation = {"location": 1, "discovered": false, "resolved": {}}
	mutation.discovered = true
	mutation.discovered_turn = int(session.run.state.turn)
	session.run.state.entity_mutations[instance.instance_id] = mutation
	Telemetry.record(session, {"type": "discovery", "target": instance.instance_id, "definition": definition.content_id, "definition_version": int(definition.version)})
	session.dirty = true
	var events: Array = [{"type": "discovery", "target": instance.instance_id, "name": instance.get("metadata", {}).get("title", definition.name), "description": definition.description + " " + layer.clue(instance), "category": definition.payload.category, "position": instance.position.duplicate()}]
	for interaction in available(session, instance, "discover"):
		if unmet(session, layer.event(interaction.event).payload.get("conditions", [])).is_empty():
			events.append_array(resolve(session, instance, interaction).get("events", []))
	return events

func targets(session: RefCounted) -> Array:
	## Discovered places on this tile or a cardinal neighbor, in sight, nearest first.
	var result: Array = []
	for instance in layer.loaded():
		var tile := Vector2i(int(instance.position.x), int(instance.position.y))
		if discovered(session, instance.instance_id) and session.visible.has(tile) and absi(tile.x - session.position.x) + absi(tile.y - session.position.y) <= 1:
			result.append(instance)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := absi(int(a.position.x) - session.position.x) + absi(int(a.position.y) - session.position.y)
		var db := absi(int(b.position.x) - session.position.x) + absi(int(b.position.y) - session.position.y)
		return da < db or (da == db and a.instance_id < b.instance_id))
	return result

func next_interaction(session: RefCounted, instance: Dictionary, wanted: String = "") -> Dictionary:
	for interaction in available(session, instance, "interact"):
		if wanted.is_empty() or interaction.id == wanted:
			return interaction
	return {}

func interact(session: RefCounted, instance_id: String, wanted: String = "") -> Dictionary:
	## The E action on a place. {} plus session.last_error = refused (nothing changes).
	var instance: Dictionary = layer.find(instance_id)
	if instance.is_empty():
		return _refuse(session, "That place is not in the loaded region")
	var tile := Vector2i(int(instance.position.x), int(instance.position.y))
	if not discovered(session, instance_id) or not session.visible.has(tile) or absi(tile.x - session.position.x) + absi(tile.y - session.position.y) > 1:
		return _refuse(session, "Nothing you know of is within reach — no turn spent")
	var interaction := next_interaction(session, instance, wanted)
	var definition: Dictionary = layer.definition_for(instance)
	if interaction.is_empty():
		return _refuse(session, "%s holds nothing more for you (%s) — no turn spent" % [definition.name, state(session, instance)])
	var outcome := resolve(session, instance, interaction)
	if outcome.has("error"):
		Telemetry.record(session, {"type": "interaction", "target": instance_id, "method": interaction.get("world_method", interaction.id), "outcome": "refused", "reason": outcome.error})
		return _refuse(session, outcome.error + " — no turn spent")
	return {"type": "interact", "place": true, "name": definition.name, "received": outcome.received, "events": outcome.events}

func resolve(session: RefCounted, instance: Dictionary, interaction: Dictionary) -> Dictionary:
	## Plan conditions, cost, awards and vital changes; commit only if all succeed.
	var event: Dictionary = layer.event(interaction.event)
	var definition: Dictionary = layer.definition_for(instance)
	var p: Dictionary = event.payload
	var method := str(interaction.get("world_method", ""))
	if not method.is_empty():
		var requirement := WorldRules.requirement(session, definition.payload.world_properties, method)
		if not requirement.is_empty(): return {"error": requirement}
		p = WorldRules.response(definition.payload.world_properties, method, p)
	var missing := unmet(session, p.get("conditions", []))
	if not missing.is_empty():
		return {"error": "%s: requires %s" % [interaction.get("verb", "Explore"), ", ".join(missing)]}
	var tools := Inventory.new()
	var inventory: Dictionary = session.run.state.inventory.duplicate(true)
	for item in p.get("cost", {}).get("items", []):
		var entry: Dictionary = inventory.get(item.content_id, {})
		var removal: Dictionary = tools.remove(inventory, item.content_id, int(item.get("quantity", 1))) if int(entry.get("version", 0)) == int(item.version) else {}
		if removal.is_empty():
			return {"error": "%s: needs %s x%d" % [interaction.get("verb", "Explore"), str(session._definition(item.content_id, int(item.version)).get("name", item.content_id)), int(item.get("quantity", 1))]}
		inventory = removal.inventory
	var key := _roll_key(session, event, instance.instance_id, interaction.id)
	# `chance` branches resolve first (fixed per Run and place); nothing else changes.
	var resolved: Dictionary = Events.effective(p.outcomes, key)
	var outcomes: Array = resolved.outcomes
	var grants: Array = []
	for index in outcomes.size():
		var outcome: Dictionary = outcomes[index]
		if outcome.type == "grant_items":
			for item in outcome.items: grants.append({"content_id": item.content_id, "version": int(item.version), "quantity": int(item.get("quantity", 1))})
		elif outcome.type == "loot":
			grants.append_array(Loot.new().roll(outcome.table, "%s/%d" % [key, index]))
	var award := {"inventory": inventory, "received": [], "display_received": []}
	if not grants.is_empty():
		award = tools.award(session.store.content, session.world.world_id, inventory, grants, "run:%s/location/%s/%s" % [session.run.run_id, instance.instance_id, interaction.id])
		if award.is_empty():
			return {"error": tools.last_error}
	var trial: Dictionary = session.stats().duplicate(true)
	var changes := ItemEffects.apply(trial, outcomes.filter(func(o: Dictionary) -> bool: return o.type in ItemEffects.TYPES), int(session.combat_stats().max_hp))
	var damage := 0
	for outcome in outcomes:
		if outcome.type == "damage":
			damage += mini(int(trial.hp), int(outcome.amount))
			trial.hp = maxi(0, int(trial.hp) - int(outcome.amount))
	if not layer.materialize(instance):
		return {"error": layer.last_error}
	# Commit: inventory, vitals, the resolution record, then status/XP/resource handlers.
	session.run.state.inventory = award.inventory
	for stat in trial:
		session.stats()[stat] = trial[stat]
	var mutation := record(session, instance.instance_id)
	if mutation.is_empty():
		mutation = {"location": 1, "discovered": true, "discovered_turn": int(session.run.state.turn), "resolved": {}}
	mutation.discovered = true
	mutation.resolved[interaction.id] = {"turn": int(session.run.state.turn), "event": {"content_id": event.content_id, "version": int(event.version)}, "received": award.received.duplicate(true)}
	session.run.state.entity_mutations[instance.instance_id] = mutation
	session.dirty = true
	var events: Array = [{"type": "location", "target": instance.instance_id, "name": definition.name, "verb": interaction.get("verb", "Explore"), "message": " ".join([p.get("message", ""), layer.clue(instance, true)] + resolved.notes).strip_edges(), "tone": p.get("tone", "neutral"), "received": award.received, "display_received": award.display_received, "changes": changes, "damage": damage, "position": instance.position.duplicate()}]
	if not method.is_empty():
		mutation.world_state = "thawed" if method == "heat" else "shattered"
		mutation.world_rule_version = 1
		var fact := WorldRules.knowledge(method)
		if Knowledge.unlock(session, fact):
			events.append({"type": "knowledge", "name": fact.title})
			Telemetry.record(session, {"type": "knowledge_unlock", "knowledge_id": fact.id})
	Telemetry.record(session, {"type": "interaction", "target": instance.instance_id, "definition": definition.content_id, "definition_version": int(definition.version), "method": method if not method.is_empty() else interaction.id, "outcome": "success", "state": mutation.get("world_state", "resolved"), "received": award.received, "damage": damage})
	var source := {"content_id": event.content_id, "version": int(event.version), "actor": "player"}
	for outcome in outcomes:
		match outcome.type:
			"apply_status": events.append_array(session.statuses.apply(session, outcome, source, "player"))
			"cleanse": events.append_array(session.statuses.cleanse(session, "player", outcome.get("harmful", true)))
			"xp": events.append_array(session.gain_xp(int(outcome.amount))) # Reports its own XP event.
			"restore":
				var resources: Dictionary = session.run.state.character.resources
				var current := int(session.skills.resource(session, outcome.resource))
				resources[outcome.resource].value = mini(int(session.skills.resource_max(session, outcome.resource)), current + int(outcome.amount))
	session.refresh_stats()
	return {"events": events, "received": award.display_received}

func _roll_key(session: RefCounted, event: Dictionary, instance_id: String, interaction_id: String) -> String:
	return "location-v1/%d/%d/%d/%s@%d/%s/%s" % [int(session.world.seed), int(session.world.generation_version), int(session.run.seed), event.content_id, int(event.version), instance_id, interaction_id]

func notes(session: RefCounted) -> Array:
	## Journal: what this Run's resolved places told the player, newest first. Rebuilt from
	## the saved record (pinned event + the same Run-keyed chance roll); nothing new is stored,
	## no position or unresolved text is revealed.
	var result: Array = []
	var mutations: Dictionary = session.run.state.entity_mutations
	for id in mutations:
		var resolved: Dictionary = record(session, str(id)).get("resolved", {})
		if resolved.is_empty(): continue
		var instance: Dictionary = layer.find(str(id))
		if instance.is_empty(): instance = layer.registry.load_instance(session.world.world_id, str(id))
		if instance.is_empty(): continue
		var place := _pinned(session, instance)
		for interaction_id in resolved:
			var entry: Variant = resolved[interaction_id]
			if not entry is Dictionary or not entry.get("event") is Dictionary: continue
			var event := _pinned(session, entry.event)
			if event.is_empty(): continue
			var p: Dictionary = event.payload
			var text := " ".join([p.get("message", "")] + Events.effective(p.get("outcomes", []), _roll_key(session, event, str(id), str(interaction_id))).notes).strip_edges()
			if text.is_empty(): continue
			var verb := str(interaction_id)
			for interaction in place.get("payload", {}).get("interactions", []):
				if interaction.id == interaction_id: verb = str(interaction.get("verb", verb))
			result.append({"turn": int(entry.get("turn", 0)), "target": str(id), "interaction": str(interaction_id), "place": str(place.get("name", "")), "verb": verb, "message": text})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.turn > b.turn or (a.turn == b.turn and (a.target + "/" + a.interaction) < (b.target + "/" + b.interaction)))
	return result

func _pinned(session: RefCounted, ref: Dictionary) -> Dictionary:
	## Active definitions are cached by the layer; an older pinned version still loads.
	var definition: Dictionary = layer.event(ref)
	return definition if not definition.is_empty() else layer.registry.load_definition(session.world.world_id, ref.content_id, int(ref.version))

func _refuse(session: RefCounted, message: String) -> Dictionary:
	session.last_error = message
	return {}

func reveal_start(session: RefCounted) -> Array:
	## New structured Run only: its safe waystone grants clues, never a turn/effect.
	for instance in layer.loaded():
		if instance.content_id == "m03:place/waystone" and int(instance.position.x) == session.position.x and int(instance.position.y) == session.position.y:
			return _discover(session, instance)
	return []
