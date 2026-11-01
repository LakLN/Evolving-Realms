extends RefCounted
## Session passed explicitly: no ownership cycle. All state belongs to one Run.
const Effects = preload("res://src/core/effects.gd")

func actor(session: RefCounted, id: String) -> Dictionary:
	if id == "player":
		var view: Dictionary = session.combat_stats()
		view.statuses = session.run.state.character.statuses
		view.modifiers = modifiers(session)
		return view
	var creature: Dictionary = session.roster.creatures.get(id, {})
	if creature.is_empty(): return {}
	return {"hp": creature.hp, "max_hp": creature.max_hp, "statuses": creature.get("statuses", []), "modifiers": creature.definition.payload.get("effect_modifiers", [])}

func modifiers(session: RefCounted) -> Array:
	var result: Array = []
	for held in session.talents.held:
		if held.active:
			for effect in held.definition.payload.get("passive", []):
				if effect.type == "effect_modifier": result.append(effect.modifier)
	for record in session.run.state.character.equipment.values():
		result.append_array(session._definition(record.content_id, int(record.version)).payload.equipment.get("effect_modifiers", []))
	return result

func definition(session: RefCounted, record: Dictionary) -> Dictionary:
	return session._definition(record.id, int(record.version))

func supported(def: Dictionary) -> bool:
	var checked := Effects.classify(def)
	return def.get("kind") == "status" and def.get("status") == "active" and checked.problem.is_empty() and checked.missing.is_empty()

func validate(session: RefCounted) -> String:
	var actors := {"player": session.run.state.character.statuses}
	for id in session.roster.creatures:
		actors[id] = session.roster.creatures[id].get("statuses", [])
	for id in actors:
		var seen := {}
		for record in actors[id]:
			if not record.has("remaining"): continue # Checkpoint E records retain their semantics.
			if not Effects.valid_record(record) or record.target != id or seen.has(record.id) or int(record.last_tick) > int(session.run.state.turn) or int(record.get("last_aged", 0)) > int(session.run.state.turn):
				return "Invalid or duplicate active status for " + id
			seen[record.id] = true
			var def := definition(session, record)
			if def.get("kind") != "status": return "Missing pinned status " + record.id
			var checked := Effects.classify(def)
			if not checked.problem.is_empty(): return checked.problem
			if record.source.actor != "player" and not session.roster.creatures.has(record.source.actor): return "Missing status source actor"
			if record.source.actor != "player" and id != "player": return "Unsupported creature-to-creature status target"
			var source: Dictionary = session._definition(record.source.content_id, int(record.source.version))
			if source.is_empty(): return "Missing pinned status source"
	return ""

func apply(session: RefCounted, effect: Dictionary, source: Dictionary, target: String, power: int = 100) -> Array:
	if str(source.get("actor", "player")) != "player" and target != "player":
		return [{"type": "status_error", "target": target, "error": "Missing capability effect.creature_to_creature"}]
	var victim := actor(session, target)
	if victim.is_empty() or int(victim.hp) <= 0 or actor(session, str(source.get("actor", ""))).is_empty(): return []
	if str(source.actor) != "player" and not session.roster._ensure_materialized(session.roster.creatures[source.actor]): return []
	if str(source.actor) != "player": session.roster._commit(session, session.roster.creatures[source.actor])
	var def: Dictionary = session._definition(effect.content_id, int(effect.version))
	if not supported(def): return []
	if target != "player" and def.payload.get("modifiers", []).any(func(m: Dictionary) -> bool: return m.stat == "max_hp"):
		return [{"type": "status_error", "target": target, "error": "Missing capability effect.creature.max_hp_modifier"}]
	if target != "player" and not session.roster._ensure_materialized(session.roster.creatures[target]): return []
	var p: Dictionary = def.payload
	var giver := actor(session, str(source.actor))
	var duration := int(p.duration)
	var cap := int(p.get("max_stacks", 1))
	for m in giver.get("modifiers", []):
		if Effects.matches(m, giver, victim, [p.get("element", "neutral")], def.content_id):
			if m.type == "status_duration": duration += int(m.get("add", 0))
			if m.type == "status_stacks": cap += int(m.get("add", 0))
	duration = clampi(duration, 1, 100)
	cap = clampi(cap, 1, 20)
	var statuses: Array = victim.statuses
	for record in statuses:
		if record.id != def.content_id: continue
		# Version identity is pinned until expiration; do not reinterpret an old instance.
		if int(record.version) != int(def.version): return []
		record.stacks = mini(cap, int(record.stacks) + 1)
		record.inputs.max_stacks = cap
		record.inputs.power = clampi(power, 0, 1000)
		record.source = source.duplicate(true)
		record.last_aged = int(session.run.state.turn)
		match p.get("refresh", "refresh"):
			"refresh": record.remaining = duration
			"extend": record.remaining = mini(100, int(record.remaining) + duration)
		commit(session, target)
		session.refresh_stats()
		return [{"type": "status_apply", "target": target, "status": def.name, "stacks": record.stacks, "remaining": record.remaining}]
	statuses.append({"id": def.content_id, "version": int(def.version), "source": source.duplicate(true), "target": target, "remaining": duration, "stacks": 1, "last_tick": int(session.run.state.turn), "last_aged": int(session.run.state.turn), "inputs": {"power": clampi(power, 0, 1000), "max_stacks": cap}})
	commit(session, target)
	session.refresh_stats()
	return [{"type": "status_apply", "target": target, "status": def.name, "stacks": 1, "remaining": duration}]

func cleanse(session: RefCounted, target: String, harmful: bool = true, only: String = "") -> Array:
	var victim := actor(session, target)
	if victim.is_empty() or int(victim.hp) <= 0: return []
	var events: Array = []
	for i in range(victim.statuses.size() - 1, -1, -1):
		var record: Dictionary = victim.statuses[i]
		if not record.has("remaining"): continue
		var def := definition(session, record)
		if (only.is_empty() and def.payload.get("harmful", true) == harmful) or record.id == only:
			events.append({"type": "status_dispel", "target": target, "status": def.name})
			victim.statuses.remove_at(i)
	commit(session, target)
	session.refresh_stats()
	return events

func react(session: RefCounted, target: String, elements: Array) -> Array:
	var events: Array = []
	for reaction in Effects.rules().reactions:
		if reaction.element in elements:
			events.append_array(cleanse(session, target, true, reaction.remove_status))
	return events

func blocked(session: RefCounted, target: String) -> bool:
	var view := actor(session, target)
	for record in view.get("statuses", []):
		if not record.has("remaining"): continue
		var def := definition(session, record)
		if not supported(def): continue
		var every := int(def.payload.get("skip_every", 0))
		if every > 0 and int(session.run.state.turn) % every == 0: return true
	return false

func skip_factor(session: RefCounted, target: String) -> int:
	## Real-time reading of `skip_every` (M03 B): 1 = cannot act (stun), n >= 2 = every
	## step/attack interval takes n times as long (slow), 0 = unaffected. The turn model
	## keeps blocked() (skip every n-th global turn) unchanged.
	var result := 0
	for record in actor(session, target).get("statuses", []):
		if not record.has("remaining"): continue
		var def := definition(session, record)
		if not supported(def): continue
		var every := int(def.payload.get("skip_every", 0))
		if every == 1: return 1
		result = maxi(result, every)
	return result

func source_name(session: RefCounted, record: Dictionary) -> String:
	## Damage attribution for ticks: who applied the status.
	var actor_id := str(record.get("source", {}).get("actor", ""))
	if actor_id == "player": return "you"
	var creature: Dictionary = session.roster.creatures.get(actor_id, {})
	return str(creature.definition.name) if not creature.is_empty() else ""

func stat_modifiers(session: RefCounted, statuses: Array) -> Dictionary:
	var result := {"flat": {}, "percent": {}}
	for record in statuses:
		if not record.has("remaining"): continue
		var def := definition(session, record)
		if not supported(def): continue
		for m in def.payload.get("modifiers", []):
			result.flat[m.stat] = int(result.flat.get(m.stat, 0)) + int(m.get("add", 0)) * int(record.stacks)
			result.percent[m.stat] = int(result.percent.get(m.stat, 0)) + int(m.get("percent", 0)) * int(record.stacks)
	return result

func tick(session: RefCounted) -> Array:
	# One global tick, including materialized distant creatures; never on resume.
	var ids: Array = session.roster.creatures.keys()
	ids.sort()
	ids.push_front("player")
	var events: Array = []
	var turn := int(session.run.state.turn)
	for id in ids:
		var victim := actor(session, id)
		if int(victim.get("hp", 0)) <= 0: continue
		for record in victim.statuses:
			if not record.has("remaining") or int(record.last_tick) >= turn: continue
			var def := definition(session, record)
			if not supported(def): continue # Pending state is dormant, not silently executed.
			var previous_tick := int(record.last_tick)
			record.last_tick = turn
			var p: Dictionary = def.payload
			if p.has("tick"):
				var amount := int(p.tick.amount) * int(record.stacks) * int(record.inputs.power) / 100
				if p.tick.type == "damage":
					if id == "player":
						amount = Effects.damage(amount, [p.get("element", "neutral")], actor(session, str(record.source.actor)), actor(session, id))
						session.stats().hp = maxi(0, int(session.stats().hp) - amount)
						events.append({"type": "status_tick", "target": id, "status": def.name, "amount": -amount, "source": source_name(session, record)})
					else:
						# Same kill/loot/XP path, without on_attack/lifesteal procs.
						var hit: Dictionary = session.strike(id, {"status_tick": true, "direct_damage": amount, "elements": [p.get("element", "neutral")], "source_actor": record.source.actor})
						if hit.is_empty():
							record.last_tick = previous_tick
							events.append({"type": "status_error", "target": id, "error": session.last_error})
						else:
							events.append_array(hit.get("events", []))
				elif int(actor(session, id).hp) > 0:
					var source := actor(session, str(record.source.actor))
					var percent := 0
					var flat := 0
					for m in source.get("modifiers", []):
						if m.type == "healing" and Effects.matches(m, source, victim, [p.get("element", "neutral")]):
							percent += int(m.get("percent", 0))
							flat += int(m.get("add", 0))
					amount = maxi(0, (amount + flat) * (100 + percent) / 100)
					if id == "player": session.stats().hp = mini(int(session.combat_stats().max_hp), int(session.stats().hp) + amount)
					else: session.roster.creatures[id].hp = mini(int(victim.max_hp), int(victim.hp) + amount)
					events.append({"type": "status_tick", "target": id, "status": def.name, "amount": amount})
			commit(session, id)
			if int(actor(session, id).hp) <= 0: break
	return events

func finish_turn(session: RefCounted) -> Array:
	var ids: Array = session.roster.creatures.keys()
	ids.sort()
	ids.push_front("player")
	var events: Array = []
	for id in ids:
		var view := actor(session, id)
		if int(view.hp) <= 0:
			for record in view.statuses:
				if record.has("remaining"): events.append({"type": "status_end", "target": id, "status": definition(session, record).name})
			view.statuses.clear()
			commit(session, id)
			continue
		for i in range(view.statuses.size() - 1, -1, -1):
			var record: Dictionary = view.statuses[i]
			if not record.has("remaining") or not supported(definition(session, record)) or int(record.last_tick) != int(session.run.state.turn) or int(record.get("last_aged", -1)) >= int(session.run.state.turn): continue
			record.last_aged = int(session.run.state.turn)
			record.remaining = int(record.remaining) - 1
			if record.remaining <= 0 or int(view.hp) <= 0:
				events.append({"type": "status_end", "target": id, "status": definition(session, record).name})
				view.statuses.remove_at(i)
		commit(session, id)
	session.refresh_stats()
	return events

func commit(session: RefCounted, id: String) -> void:
	if id != "player" and (session.roster.creatures[id].mutated or not session.roster.creatures[id].get("statuses", []).is_empty()):
		session.roster._commit(session, session.roster.creatures[id])

func describe(session: RefCounted, statuses: Array) -> String:
	var parts := PackedStringArray()
	for record in statuses:
		if record.has("remaining"):
			var def := definition(session, record)
			parts.append("%s [%s] x%d %dt%s" % [def.get("name", record.id), def.payload.get("element", "neutral"), int(record.stacks), int(record.remaining), " (pending)" if not supported(def) else ""])
	return "; ".join(parts)
