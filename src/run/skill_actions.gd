extends RefCounted
## Learning and using skills inside ExplorationSession: trusted handlers for the data
## validated in src/core/skills.gd. Every action validates and plans first; books,
## costs, cooldowns and effects change only once the whole action is accepted, and
## an accepted action spends exactly one turn (the session's turn order).
## Strikes go through session.strike(), so loot, XP and talent reactions are shared
## with basic attacks; passive/triggered skills run on the talent engine.
const Inventory = preload("res://src/core/inventory.gd")
const Skills = preload("res://src/core/skills.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

func known(session: RefCounted) -> Array:
	return session.run.state.character.skills

func record_of(session: RefCounted, content_id: String) -> Dictionary:
	for entry in known(session):
		if entry.content_id == content_id:
			return entry
	return {}

func character_view(session: RefCounted) -> Dictionary:
	## What learn/use conditions may look at (effective stats, never stored values).
	var character: Dictionary = session.run.state.character
	var skill_ids := {}
	for entry in character.skills:
		skill_ids[entry.content_id] = true
	var talent_ids := {}
	for entry in character.talents:
		talent_ids[entry.content_id] = true
	return {"level": session.character_rules.level(character), "stats": session.effective_stats().stats, "skills": skill_ids, "talents": talent_ids, "inventory": session.run.state.inventory, "equipment": character.equipment, "hp": int(session.stats().hp), "max_hp": int(session.combat_stats().max_hp), "need_level": func(need: String) -> int: return session.survival.level(session.stats(), need)}

func missing_capabilities(session: RefCounted, definition: Dictionary) -> Array:
	for entry in session.skill_catalog.pending:
		if entry.content_id == definition.get("content_id") and int(entry.version) == int(definition.get("version", 0)):
			return entry.missing
	return []

# --- Learning ---------------------------------------------------------------

func book_for(session: RefCounted, content_id: String) -> Dictionary:
	var entry: Variant = session.run.state.inventory.get(content_id)
	return {} if not entry is Dictionary else session.skill_catalog.books.get("%s@%d" % [content_id, int(entry.version)], {})

func learn_check(session: RefCounted, definition: Dictionary) -> Array:
	## Everything that blocks learning, as text ([] = can learn). Unsupported
	## requirements and capabilities always block: they are never assumed met.
	if definition.is_empty():
		return ["unknown skill"]
	var missing := missing_capabilities(session, definition)
	if not missing.is_empty():
		return ["needs unsupported capability: " + ", ".join(missing)]
	if not record_of(session, definition.content_id).is_empty():
		return ["already known"]
	var limit := int(session.skill_rules.rules.learning.max_known)
	if limit > 0 and known(session).size() >= limit:
		return ["no room for more skills (%d)" % limit]
	var view := character_view(session)
	var unmet: Array = []
	for relation in definition.payload.get("relations", []):
		var name := str(relation.skill).get_slice("/", 1).capitalize()
		if relation.type == "prerequisite" and not view.skills.has(relation.skill):
			unmet.append("requires skill " + name)
		elif relation.type == "conflicts" and view.skills.has(relation.skill):
			unmet.append("conflicts with " + name)
	unmet.append_array(session.skill_rules.evaluate(definition.payload.get("learn", {}).get("conditions", []), view))
	return unmet

func learn_action(session: RefCounted, action: Dictionary) -> bool:
	## {"type": "learn", "content_id": <skill book item>}. Refusals keep the book and the turn.
	if not action.get("content_id") is String or not session.run.state.inventory.has(action.content_id):
		return session._fail("You do not have that book (no turn spent)")
	var book := book_for(session, action.content_id)
	if book.is_empty():
		return session._fail("That item teaches no skill (no turn spent)")
	var definition: Dictionary = session.skill_definition(book.skill.content_id, int(book.skill.version))
	var unmet := learn_check(session, definition)
	if not unmet.is_empty():
		return session._fail("Cannot learn %s: %s (no turn spent, book kept)" % [definition.get("name", "?"), "; ".join(unmet)])
	var inventory: Dictionary = session.run.state.inventory
	var source := {"kind": "book", "content_id": action.content_id, "version": int(inventory[action.content_id].version)}
	if book.get("consume_on_learn", true):
		var removal := Inventory.new().remove(inventory, action.content_id, 1)
		if removal.is_empty():
			return session._fail("The book could not be used (no turn spent)")
		inventory = removal.inventory
	session.run.state.inventory = inventory
	_add(session, definition, source)
	session.last_result = {"type": "learn", "events": [{"type": "learn", "name": definition.name, "skill": definition.content_id, "consumed": book.get("consume_on_learn", true)}]}
	return true

func learn(session: RefCounted, definition: Dictionary, source: Dictionary) -> String:
	## Learning without a book (future teachers, relics, research, inheritance): the
	## same checks and record, no item. Spends no turn by itself. "" = learned.
	var unmet := learn_check(session, definition)
	if not unmet.is_empty():
		return "; ".join(unmet)
	_add(session, definition, source)
	session.dirty = true
	return ""

func _add(session: RefCounted, definition: Dictionary, source: Dictionary) -> void:
	known(session).append(Skills.record(definition, source, int(session.run.state.turn)))
	session.reload_talents() # Passive/triggered skills join the shared engine; stats re-derived.

# --- Using ------------------------------------------------------------------

func modifiers(session: RefCounted, definition: Dictionary) -> Dictionary:
	## Talents, passive skills and worn gear can change skills: power %, cost %, range.
	var result := {"power_percent": 0, "cost_percent": 0, "range_add": 0}
	var sources: Array = session.talents.skill_modifiers()
	for slot in session.run.state.character.equipment:
		var record: Dictionary = session.run.state.character.equipment[slot]
		sources.append_array(session._definition(record.content_id, int(record.version)).get("payload", {}).get("equipment", {}).get("skill_modifiers", []))
	var tags: Array = definition.payload.get("tags", [])
	for modifier in sources:
		var tagged: Array = modifier.get("tags", [])
		if not tagged.is_empty() and not tagged.any(func(tag: String) -> bool: return tag in tags):
			continue
		if not modifier.get("skills", []).is_empty() and definition.content_id not in modifier.skills:
			continue
		for key in result:
			result[key] = int(result[key]) + int(modifier.get(key, 0))
	return result

func costs(session: RefCounted, definition: Dictionary) -> Dictionary:
	var cost: Dictionary = definition.payload.use.get("cost", {}).duplicate(true)
	var percent := 100 + int(modifiers(session, definition).cost_percent)
	for key in cost:
		if session.skill_rules.rules.resources.has(key):
			cost[key] = maxi(0, int(cost[key]) * percent / 100)
	return cost

func reach(session: RefCounted, definition: Dictionary) -> int:
	var target: Dictionary = definition.payload.use.target
	return 0 if target.kind == "self" else maxi(1, int(target.range) + int(modifiers(session, definition).range_add))

func resource(session: RefCounted, id: String) -> int:
	return mini(int(session.run.state.character.resources[id].value), resource_max(session, id))

func resource_max(session: RefCounted, id: String) -> int:
	return session.skill_rules.max_resource(id, session.character_rules.level(session.run.state.character))

func use_check(session: RefCounted, definition: Dictionary) -> String:
	## First reason the skill cannot be used now ("" = usable, target aside).
	var entry := record_of(session, definition.get("content_id", ""))
	if entry.is_empty():
		return "You have not learned that skill"
	if definition.payload.get("type") != "active":
		return "%s is %s: it works on its own" % [definition.name, definition.payload.get("type")]
	if not missing_capabilities(session, definition).is_empty():
		return "%s needs an unsupported capability" % definition.name
	var turn := int(session.run.state.turn)
	if int(entry.cooldown_until) > turn:
		return "%s is recharging (%d %s)" % [definition.name, int(entry.cooldown_until) - turn, "s" if session.realtime else "turns"]
	var unmet: Array = session.skill_rules.evaluate(definition.payload.use.get("conditions", []), character_view(session))
	if not unmet.is_empty():
		return "%s needs: %s" % [definition.name, "; ".join(unmet)]
	var cost := costs(session, definition)
	for key in cost:
		if session.skill_rules.rules.resources.has(key) and resource(session, key) < int(cost[key]):
			return "Not enough %s (%d/%d)" % [session.skill_rules.rules.resources[key].name, resource(session, key), int(cost[key])]
	if int(cost.get("hp", 0)) > 0 and int(session.stats().hp) <= int(cost.hp):
		return "Not enough HP to pay %d" % int(cost.hp)
	for item in cost.get("items", []):
		var held: Dictionary = session.run.state.inventory.get(item.content_id, {})
		if int(held.get("version", 0)) != int(item.version) or int(held.get("quantity", 0)) < int(item.quantity):
			return "%s needs %s x%d" % [definition.name, session._definition(item.content_id, int(item.version)).get("name", item.content_id), int(item.quantity)]
	return ""

func targets(session: RefCounted, definition: Dictionary) -> Array:
	## Valid targets now: creatures [{instance_id, ...creature}] or tiles [{tile, direction}].
	var target: Dictionary = definition.payload.use.target
	var distance_limit := reach(session, definition)
	var result: Array = []
	if target.kind == "creature":
		for creature in session.roster.creatures.values():
			var distance := absi(creature.position.x - session.position.x) + absi(creature.position.y - session.position.y)
			if creature.dead or distance < 1 or distance > distance_limit or not session.visible.has(creature.position):
				continue
			if not target.get("dispositions", []).is_empty() and creature.definition.payload.disposition not in target.dispositions:
				continue
			if distance > 1 and target.get("line_of_sight", true) and not session.line_clear(session.position, creature.position):
				continue
			result.append(creature)
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var da := absi(a.position.x - session.position.x) + absi(a.position.y - session.position.y)
			var db := absi(b.position.x - session.position.x) + absi(b.position.y - session.position.y)
			return da < db or (da == db and a.instance_id < b.instance_id))
	elif target.kind == "tile":
		for direction in DIRECTIONS:
			var best := Vector2i.ZERO
			for step in range(1, distance_limit + 1):
				var tile: Vector2i = session.position + direction * step
				if session.cache.tile_at(tile) not in [Terrain.FOREST, Terrain.BEACH, Terrain.MEADOW] or not session.roster.living_at(tile).is_empty() or not session.visible.has(tile):
					break # A straight, clear and visible line only.
				best = tile
			if best != Vector2i.ZERO:
				result.append({"tile": best, "direction": direction})
	return result

func use_action(session: RefCounted, action: Dictionary) -> bool:
	## {"type": "skill", "skill_id", "target_id"? (creature), "target"? {x, y} (tile)}.
	var definition: Dictionary = {}
	var entry := record_of(session, str(action.get("skill_id", "")))
	if not entry.is_empty():
		definition = session.skill_definition(entry.content_id, int(entry.version))
	if definition.is_empty():
		return session._fail("You have not learned that skill (no turn spent)")
	var problem := use_check(session, definition)
	if not problem.is_empty():
		return session._fail(problem + " (no turn spent)")
	var kind: String = definition.payload.use.target.kind
	var valid := targets(session, definition)
	var target_name := ""
	var tile := Vector2i.ZERO
	if kind == "creature":
		var picked: Array = valid.filter(func(creature: Dictionary) -> bool: return creature.instance_id == action.get("target_id"))
		if picked.is_empty():
			return session._fail("No valid target for %s within %d tiles in sight (no turn spent)" % [definition.name, reach(session, definition)])
		target_name = picked[0].definition.name
	elif kind == "tile":
		var point: Variant = action.get("target")
		var picked: Array = valid.filter(func(option: Dictionary) -> bool: return point is Dictionary and option.tile == Vector2i(int(point.get("x", 0)), int(point.get("y", 0))))
		if picked.is_empty():
			return session._fail("Choose a free, visible tile in a straight line within %d (no turn spent)" % reach(session, definition))
		tile = picked[0].tile
	var power := 100 + int(modifiers(session, definition).power_percent)
	var cost := costs(session, definition)
	var plan := _plan_self(session, definition, power)
	if kind == "self" and plan.changes.is_empty() and not definition.payload.effects.any(func(e: Dictionary) -> bool: return e.type == "apply_status" or (e.type == "cleanse" and session.run.state.character.statuses.any(func(s: Dictionary) -> bool: return s.has("remaining") and session.statuses.definition(session, s).payload.get("harmful", true) == e.get("harmful", true)))):
		return session._fail("%s would have no effect right now (no turn spent)" % definition.name)
	var inventory: Dictionary = session.run.state.inventory
	for item in cost.get("items", []):
		var removal := Inventory.new().remove(inventory, item.content_id, int(item.quantity))
		if removal.is_empty():
			return session._fail("%s needs its items (no turn spent)" % definition.name)
		inventory = removal.inventory
	if kind == "creature" and definition.payload.effects.any(func(e: Dictionary) -> bool: return e.type == "apply_status"):
		if not session.roster._ensure_materialized(session.roster.creatures[action.target_id]): return session._fail(session.roster.last_error)
	# Everything is validated: apply the effects in data order, then pay.
	var events: Array = []
	var victim := str(action.get("target_id", "player")) if kind == "creature" else "player"
	if kind in ["self", "creature"]:
		events.append_array(session.statuses.react(session, victim, definition.payload.get("elements", ["neutral"])))
	var parts := PackedStringArray()
	for effect in definition.payload.effects:
		match effect.type:
			"strike":
				var result: Dictionary = session.strike(action.target_id, {"range": reach(session, definition), "line_of_sight": definition.payload.use.target.get("line_of_sight", true), "attack_percent": int(effect.get("attack_percent", 100)) * power / 100, "flat": int(effect.get("flat", 0)), "key": "/skill/" + definition.content_id, "elements": definition.payload.get("elements", ["neutral"])})
				if result.is_empty():
					if events.is_empty():
						return false # Refused before anything changed.
					break
				events.append_array(result.events)
			"stun":
				var stunned: Dictionary = session.roster.stun(session, action.target_id, int(effect.turns))
				if not stunned.is_empty():
					events.append(stunned)
					parts.append("bound %d turns" % int(effect.turns))
			"blink":
				if not session.relocate(tile):
					return false
				parts.append("moved to (%d, %d)" % [tile.x, tile.y])
	if kind == "self":
		_apply_self(session, definition, plan)
		parts.append_array(plan.summary)
	for effect in definition.payload.effects:
		if effect.type == "apply_status":
			events.append_array(session.statuses.apply(session, effect, {"content_id": definition.content_id, "version": int(definition.version), "actor": "player"}, victim, power))
		elif effect.type == "cleanse":
			events.append_array(session.statuses.cleanse(session, victim, effect.get("harmful", true)))
	# Pay only now. Items: taken from the current inventory (loot can only have added).
	for item in cost.get("items", []):
		session.run.state.inventory = Inventory.new().remove(session.run.state.inventory, item.content_id, int(item.quantity)).inventory
	for key in cost:
		if session.skill_rules.rules.resources.has(key):
			session.run.state.character.resources[key].value = resource(session, key) - int(cost[key])
	if int(cost.get("hp", 0)) > 0:
		session.stats().hp = maxi(1, int(session.stats().hp) - int(cost.hp))
	entry.cooldown_until = int(session.run.state.turn) + 1 + int(definition.payload.use.get("cooldown_turns", 0))
	session.refresh_stats()
	events.push_front({"type": "skill", "name": definition.name, "skill": definition.content_id, "target": target_name, "summary": ", ".join(parts), "cost": cost})
	session.last_result = {"type": "skill", "skill": definition.content_id, "events": events}
	return true

func _plan_self(session: RefCounted, definition: Dictionary, power: int) -> Dictionary:
	## Self effects computed on copies; nothing changes until _apply_self.
	var trial: Dictionary = session.stats().duplicate(true)
	var resources: Dictionary = session.run.state.character.resources.duplicate(true)
	var statuses: Array = []
	var changes: Array = []
	var summary := PackedStringArray()
	if definition.payload.use.target.kind != "self":
		return {"trial": trial, "resources": resources, "statuses": statuses, "changes": changes, "summary": summary}
	for effect in definition.payload.effects:
		match effect.type:
			"heal", "need":
				var scaled: Dictionary = effect.duplicate()
				if effect.type == "heal":
					if scaled.has("amount"):
						scaled.amount = int(scaled.amount) * power / 100
					else:
						scaled.percent_of_max = mini(100, int(scaled.percent_of_max) * power / 100)
				var vital: Array = session._vital_effects(trial, [scaled])
				changes.append_array(vital)
				if not vital.is_empty():
					summary.append(session._vital_summary(vital))
			"status":
				var turns := int(effect.duration)
				statuses.append({"id": effect.status, "source": definition.content_id, "stat": effect.stat, "add": int(effect.get("add", 0)) * power / 100, "percent": int(effect.get("percent", 0)) * power / 100, "until_turn": int(session.run.state.turn) + 1 + turns})
				changes.append({"type": "status"})
				summary.append("%s %+d for %d turns" % [session.character_rules.rules.stats[effect.stat].name, int(effect.get("add", 0)) * power / 100, turns])
			"restore":
				var current := mini(int(resources[effect.resource].value), resource_max(session, effect.resource))
				var after := mini(resource_max(session, effect.resource), current + int(effect.amount) * power / 100)
				resources[effect.resource].value = after
				if after != current:
					changes.append({"type": "restore"})
					summary.append("%s %+d" % [session.skill_rules.rules.resources[effect.resource].short, after - current])
	return {"trial": trial, "resources": resources, "statuses": statuses, "changes": changes, "summary": summary}

func _apply_self(session: RefCounted, definition: Dictionary, plan: Dictionary) -> void:
	for key in plan.trial:
		session.stats()[key] = plan.trial[key]
	for id in plan.resources:
		session.run.state.character.resources[id].value = int(plan.resources[id].value)
	var statuses: Array = session.run.state.character.statuses
	for status in plan.statuses:
		# The same status id refreshes instead of stacking (several skills may share it).
		for index in range(statuses.size() - 1, -1, -1):
			if statuses[index].id == status.id:
				statuses.remove_at(index)
		statuses.append(status)

# --- Per turn ---------------------------------------------------------------

func tick(session: RefCounted, action_type: String) -> Array:
	## After the turn counter: expire timed statuses, regenerate skill resources.
	var events: Array = []
	var turn := int(session.run.state.turn)
	var statuses: Array = session.run.state.character.statuses
	for index in range(statuses.size() - 1, -1, -1):
		if not statuses[index].has("remaining") and int(statuses[index].until_turn) <= turn:
			events.append({"type": "status_end", "status": statuses[index].id, "source": statuses[index].source})
			statuses.remove_at(index)
	if not events.is_empty():
		session.refresh_stats()
	for id in session.skill_rules.resource_ids():
		var state: Dictionary = session.run.state.character.resources[id]
		var cap := resource_max(session, id)
		if int(state.value) >= cap:
			state.value = cap
			state.progress = 0
			continue
		var rule: Dictionary = session.skill_rules.rules.resources[id]
		state.progress = int(state.progress) + int(rule.rest_regen_per_turn if action_type == "rest" else rule.regen_per_turn)
		while int(state.progress) >= 100 and int(state.value) < cap:
			state.progress = int(state.progress) - 100
			state.value = int(state.value) + 1
		if int(state.value) >= cap:
			state.progress = 0
	return events

func status_modifiers(session: RefCounted) -> Dictionary:
	## Timed statuses as an effective-stat source (expired ones never count).
	var flat := {}
	var percent := {}
	var turn := int(session.run.state.turn)
	for status in session.run.state.character.get("statuses", []):
		if not status.has("remaining") and int(status.until_turn) > turn:
			flat[status.stat] = int(flat.get(status.stat, 0)) + int(status.get("add", 0))
			percent[status.stat] = int(percent.get(status.stat, 0)) + int(status.get("percent", 0))
	return {"flat": flat, "percent": percent}
