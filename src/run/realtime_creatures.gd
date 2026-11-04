extends RefCounted
## Milestone 03 B prototype: creatures act on their own gameplay-time timers instead of
## once per player action. Decisions, steps and hits reuse CreatureRoster/CreatureAI,
## so species data, leash, flee, talents, elements and on-hit statuses are unchanged.
##
## Per creature: think -> move (step duration from species speed) or attack. An attack
## is announced by a `telegraph` event and lands only after `windup_ms` if the player
## is still on a cardinal neighbour; otherwise it is a `dodge`. At most `max_windups`
## creatures wind up at once, and each waits `attack_interval_ms` between attacks, so
## hits never stack without warning. Timers are transient (never saved): after a load
## every creature simply thinks again.
const Loot = preload("res://src/core/loot_table.gd")
var rules: Dictionary = {}
var timers: Dictionary = {} # instance_id -> {next_ms, ready_ms, seq, blocked}
var windups: Dictionary = {} # instance_id -> {until, key}
var moved := false # A creature changed tile during the last update (render hint).

func configure(creature_rules: Dictionary) -> void:
	rules = creature_rules
	timers.clear()
	windups.clear()

func update(session: RefCounted, now_ms: int) -> Array:
	moved = false
	var events: Array = []
	if session.is_dead():
		windups.clear()
		return events
	var radius := int(rules.active_radius)
	var ids: Array = []
	for creature in session.roster.creatures.values():
		if not creature.dead and maxi(absi(creature.position.x - session.position.x), absi(creature.position.y - session.position.y)) <= radius:
			ids.append(creature.instance_id)
	ids.sort()
	var active := {}
	for id in ids:
		active[id] = true
		if int(session.stats().hp) <= 0:
			break
		var creature: Dictionary = session.roster.creatures[id]
		if not timers.has(id):
			# Staggered start so a group never acts in lockstep.
			timers[id] = {"next_ms": now_ms + Loot.number("rt-start/" + id) % int(rules.think_ms), "ready_ms": 0, "seq": 0, "blocked": false}
		var timer: Dictionary = timers[id]
		if windups.has(id):
			if now_ms >= int(windups[id].until):
				events.append_array(_land(session, creature, timer, now_ms))
			continue
		if now_ms < int(timer.next_ms):
			continue
		var factor: int = session.statuses.skip_factor(session, id)
		if int(creature.stunned_until) > int(session.run.state.turn) or factor == 1:
			if not timer.blocked:
				events.append({"type": "stunned", "target": id, "name": creature.definition.name, "position": _point(creature.position)})
			timer.blocked = true
			timer.next_ms = now_ms + int(rules.blocked_poll_ms)
			continue
		timer.blocked = false
		var slow := maxi(1, factor)
		timer.seq = int(timer.seq) + 1
		var key := "rt-ai-v1/%d/%d/%s/%d" % [int(session.world.seed), int(session.run.seed), id, int(timer.seq)]
		var decision: Dictionary = session.roster.decide(session, creature, key, 0)
		events.append_array(session.roster.after_decision(session, creature, decision))
		if decision.type == "charge":
			# A rush is one fast dash; the following wind-up lands the heavy blow.
			var dash: Array = session.roster.charge(session, creature, decision.to)
			events.append_array(dash)
			if not dash.is_empty():
				creature.step_ms = step_ms(creature, "chase") / 2
				moved = true
			timer.next_ms = now_ms + int(rules.think_ms)
		elif decision.type == "move":
			if session.roster.move_creature(session, creature, decision.to):
				var step := step_ms(creature, decision.state) * slow
				creature.step_ms = step # Read by the map view to tween exactly one step.
				timer.next_ms = now_ms + step
				moved = true
			else:
				timer.next_ms = now_ms + int(rules.think_ms)
		elif decision.type in ["attack", "ranged"]:
			var ranged: bool = decision.type == "ranged"
			var reaches: bool = session.roster.ranged_reaches(session, creature) if ranged else _adjacent(session, creature)
			if reaches and now_ms >= int(timer.ready_ms) and windups.size() < int(rules.max_windups):
				if ranged and not session.roster.begin_ranged(session, creature):
					timer.next_ms = now_ms + int(rules.think_ms)
					continue
				var windup := int(rules.windup_ms) * slow
				windups[id] = {"until": now_ms + windup, "key": key + "/attack", "ranged": ranged, "target": session.position}
				events.append({"type": "telegraph", "attacker": id, "name": creature.definition.name, "windup_ms": windup, "position": _point(creature.position), "ranged": ranged, "target_position": _point(session.position)})
			else:
				timer.next_ms = now_ms + 120 # Recovering, or waiting for an attack slot.
		else:
			timer.next_ms = now_ms + int(rules.think_ms) + Loot.number(key + "/think") % (int(rules.think_jitter_ms) + 1)
	for id in timers.keys():
		if not active.has(id):
			timers.erase(id) # Dead, unloaded or out of range: frozen, as in the turn model.
			windups.erase(id)
	return events

func _land(session: RefCounted, creature: Dictionary, timer: Dictionary, now_ms: int) -> Array:
	## End of a wind-up: the blow lands only if the player is still within reach.
	var id: String = creature.instance_id
	var key: String = windups[id].key
	var shot: Dictionary = windups[id]
	windups.erase(id)
	var slow := maxi(1, session.statuses.skip_factor(session, id))
	timer.ready_ms = now_ms + (int(rules.attack_interval_ms) - int(rules.windup_ms)) * slow
	timer.next_ms = now_ms + 200
	var stunned: bool = int(creature.stunned_until) > int(session.run.state.turn) or session.statuses.skip_factor(session, id) == 1
	var reaches: bool = session.position == shot.get("target") and session.roster.ranged_reaches(session, creature) if shot.get("ranged", false) else _adjacent(session, creature)
	if creature.dead or stunned or not reaches:
		return [{"type": "dodge", "attacker": id, "name": creature.definition.name, "position": _point(session.position)}]
	return session.roster.creature_strike(session, creature, key)

func step_ms(creature: Dictionary, state: String) -> int:
	## Species speed: move_per_10000 (the v1 chance to step per turn) scales duration.
	var base := int(rules.get(state + "_step_ms", rules.wander_step_ms))
	var speed := maxi(1, int(creature.definition.payload.movement.get("move_per_10000", 10000)))
	return clampi(base * 10000 / speed, int(rules.min_step_ms), int(rules.max_step_ms))

func _adjacent(session: RefCounted, creature: Dictionary) -> bool:
	return absi(creature.position.x - session.position.x) + absi(creature.position.y - session.position.y) == 1

static func _point(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}
