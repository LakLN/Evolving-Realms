extends RefCounted
## Runtime creatures of one Run: generated home placements overlaid with this Run's
## entity mutations. Methods take the owning session to avoid reference cycles.
## Only creatures within ACTIVE_RADIUS of the player act, in instance-ID order, so
## results depend on Run state and player position — never on chunk load order.
const Effects = preload("res://src/core/effects.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const Data = preload("res://src/data/json_data.gd")
const AI = preload("res://src/core/creature_ai.gd")
const Traits = preload("res://src/core/creature_traits.gd")
const Combat = preload("res://src/core/combat.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Inventory = preload("res://src/core/inventory.gd")
const ACTIVE_RADIUS := 12
const SAFE_RADIUS := 6 # No creature homes this close to the Run's spawn.
## Dynamic authored homes (layout v7 plan metadata, 2026-11-04), resolved by refresh():
##   weather [ids]  present only while the land's weather is one of them; an untouched
##                  one is simply absent, a wounded one keeps its Run state for the next.
##   returns {every, times}  `every` turns after its death a new individual takes the
##                  home (instance id "<home>/r<n>", own loot), at most `times` times,
##                  and never inside the active radius. Death turns are Run state.
## Presentation memory (never saved): who already showed a warning posture or was
## announced as returned, so cues fire once per approach, not every turn.
var _warned: Dictionary = {}
var _announced: Dictionary = {}
var layer: RefCounted
var dynamic: Array = []
var creatures: Dictionary = {}
var chunks: Dictionary = {}
var center := Vector2i(2147483647, 2147483647)
var spawn := Vector2i.ZERO
var last_error := ""

func configure(world_layer: RefCounted, run: Dictionary) -> bool:
	layer = world_layer
	spawn = Vector2i(int(run.spawn.position.x), int(run.spawn.position.y))
	creatures.clear()
	chunks.clear()
	center = Vector2i(2147483647, 2147483647)
	for id in run.state.entity_mutations:
		var mutation: Variant = run.state.entity_mutations[id]
		if not mutation is Dictionary or not mutation.has("creature"):
			continue
		var instance: Dictionary = layer.registry.load_instance(layer.world.world_id, id)
		if instance.is_empty():
			return _fail(layer.registry.last_error)
		var creature := _runtime(instance)
		if creature.is_empty():
			return false
		if not _apply(creature, mutation):
			return _fail("Corrupt creature state in save: " + str(id))
		creatures[id] = creature
	return true

func follow(tile: Vector2i, terrain_chunks: Dictionary) -> bool:
	var next := Terrain.chunk_of(tile)
	if next == center:
		return true
	var loaded := {}
	for y in range(next.y - 1, next.y + 2):
		for x in range(next.x - 1, next.x + 2):
			var chunk := Vector2i(x, y)
			if chunks.has(chunk):
				loaded[chunk] = chunks[chunk]
				continue
			# Established-region aware: v1 homes plus the chunk's pinned encounters.
			loaded[chunk] = layer.chunk_creatures(chunk, terrain_chunks.get(chunk, PackedByteArray()))
			if not layer.last_error.is_empty():
				return _fail(layer.last_error)
	chunks = loaded
	center = next
	dynamic = []
	for id in creatures.keys():
		# Untouched creatures are derived data; touched ones stay as Run state.
		if not creatures[id].mutated and not chunks.has(Terrain.chunk_of(creatures[id].home)):
			creatures.erase(id)
	for chunk in chunks:
		for instance in chunks[chunk]:
			var home := Vector2i(int(instance.position.x), int(instance.position.y))
			if maxi(absi(home.x - spawn.x), absi(home.y - spawn.y)) <= SAFE_RADIUS:
				continue
			var meta: Dictionary = instance.get("metadata", {})
			if meta.has("weather") or meta.has("returns"):
				dynamic.append(instance) # Presence decided per turn by refresh().
				continue
			if creatures.has(instance.instance_id):
				continue
			var creature := _runtime(instance)
			if creature.is_empty():
				return false
			creatures[instance.instance_id] = creature
	return true

func refresh(session: RefCounted) -> Array:
	## Weather-bound and returning homes in the loaded chunks; pure in Run state. Returns
	## presentation cues: storm shapes arriving/leaving near the player, and a returned
	## individual the first time it is seen.
	var weather := ""
	var arrived := 0
	var left := 0
	var events: Array = []
	for instance in dynamic:
		var meta: Dictionary = instance.metadata
		var id := _current(session, instance)
		var present := not id.is_empty()
		if present and meta.has("weather"):
			if weather.is_empty(): weather = session.places.weather_id(session)
			present = weather in meta.weather
		var near := maxi(absi(int(instance.position.x) - session.position.x), absi(int(instance.position.y) - session.position.y)) <= ACTIVE_RADIUS * 2
		if not present:
			if not id.is_empty() and creatures.has(id) and not creatures[id].dead:
				creatures.erase(id)
				if near and meta.has("weather"): left += 1
			continue
		if creatures.has(id):
			if id != instance.instance_id and not _announced.has(id) and not creatures[id].dead and session.visible.has(creatures[id].position):
				_announced[id] = true
				events.append({"type": "creature_return", "target": id, "name": creatures[id].definition.name, "position": _point(creatures[id].position)})
			continue
		var copy: Dictionary = instance.duplicate(true)
		copy.instance_id = id
		var creature := _runtime(copy)
		if creature.is_empty(): continue
		var mutation: Variant = session.run.state.entity_mutations.get(id)
		if mutation is Dictionary and mutation.has("creature") and not _apply(creature, mutation): continue
		creatures[id] = creature
		if near and meta.has("weather"): arrived += 1
	if arrived > 0: events.append({"type": "stirring", "state": "arrive", "weather": weather})
	if left > 0: events.append({"type": "stirring", "state": "depart", "weather": weather})
	return events

func warnings(session: RefCounted) -> Array:
	## Warning postures (trait `warning`): a dangerous creature that has not engaged yet
	## shows itself once per approach when the player comes within its radius in sight.
	var events: Array = []
	for creature in creatures.values():
		if creature.dead: continue
		var warning: Dictionary = Traits.of(creature.definition).warning
		if warning.is_empty(): continue
		var distance := _distance(creature.position, session.position)
		if distance > int(warning.radius) + 4:
			_warned.erase(creature.instance_id)
			continue
		if _warned.has(creature.instance_id) or distance > int(warning.radius) or not session.visible.has(creature.position) or creature.provoked or int(creature.alerted_until) > int(session.run.state.turn) or str(creature.state) in ["chase", "attack", "charge"]:
			continue
		_warned[creature.instance_id] = true
		events.append({"type": "creature_warning", "target": creature.instance_id, "name": creature.definition.name, "text": warning.text, "position": _point(creature.position)})
	return events

func _current(session: RefCounted, instance: Dictionary) -> String:
	## The home's individual for now: "" once every allowed individual is dead, or while
	## the next one has not yet arrived.
	var returns: Dictionary = instance.metadata.get("returns", {})
	var times := int(returns.get("times", 0))
	var mutations: Dictionary = session.run.state.entity_mutations
	var index := 0
	while index < times and mutations.get(generation(instance.instance_id, index), {}).get("dead", false): index += 1
	var id := generation(instance.instance_id, index)
	if mutations.get(id, {}).get("dead", false): return id if creatures.has(id) else ""
	if index > 0 and not creatures.has(id) and not mutations.has(id):
		var home := Vector2i(int(instance.position.x), int(instance.position.y))
		if int(session.run.state.turn) < int(mutations.get(generation(instance.instance_id, index - 1), {}).get("died_turn", 0)) + int(returns.every): return ""
		if maxi(absi(home.x - session.position.x), absi(home.y - session.position.y)) <= ACTIVE_RADIUS: return ""
	return id

static func generation(home_id: String, index: int) -> String:
	return home_id if index == 0 else "%s/r%d" % [home_id, index]

func living_at(tile: Vector2i) -> Dictionary:
	for creature in creatures.values():
		if not creature.dead and creature.position == tile:
			return creature
	return {}

func aggressive(creature: Dictionary) -> bool:
	var disposition: String = creature.definition.payload.disposition
	return disposition == "hostile" or (disposition == "neutral" and creature.provoked)

func targets(session: RefCounted) -> Array:
	## Living, visible creatures on a cardinal neighbor of the player, by ID.
	var result: Array = []
	for creature in creatures.values():
		if not creature.dead and _distance(creature.position, session.position) == 1 and session.visible.has(creature.position):
			result.append(creature)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.instance_id < b.instance_id)
	return result

func attack(session: RefCounted, target_id: String, options: Dictionary = {}) -> Dictionary:
	## Player attack. Validates and plans loot before any mutation; {} = refused.
	## options (skills): range (Manhattan, default 1), line_of_sight, attack_percent,
	## flat, key (extra draw-key suffix). Talents react to every strike the same way.
	var creature: Dictionary = creatures.get(target_id, {})
	if creature.is_empty() or creature.dead:
		return _refuse("No living creature to attack")
	if not options.get("status_tick", false) and not session.terrain.can_reach(session.position, creature.position): return _refuse("The height edge blocks the attack")
	var reach := int(options.get("range", 1))
	var distance := _distance(creature.position, session.position)
	if not options.get("status_tick", false) and (distance < 1 or distance > reach or not session.visible.has(creature.position)):
		return _refuse(("Target is not on a visible cardinal neighbor" if reach == 1 else "Target is out of range (%d) or not visible" % reach) + " — no turn spent")
	if not options.get("status_tick", false) and reach > 1 and options.get("line_of_sight", true) and not session.line_clear(session.position, creature.position):
		return _refuse("No clear line of sight to the target — no turn spent")
	var definition: Dictionary = creature.definition
	var key := "hit-v1/%d/%d/%s/%d%s" % [session.world.seed, session.run.seed, creature.instance_id, int(session.run.state.turn), str(options.get("key", ""))]
	var attacker: Dictionary = session.combat_stats()
	if options.get("damage_kind", "physical") == "magic":
		attacker.attack = int(attacker.get("magic_attack", attacker.attack))
	attacker.attack = int(attacker.attack) * int(options.get("attack_percent", 100)) / 100 + int(options.get("flat", 0))
	var defense := creature_stats(session, creature)
	var defense_value := int(defense.get("magic_defense", defense.defense)) if options.get("damage_kind", "physical") == "magic" else int(defense.defense)
	var base := Combat.resolve(attacker, {"hp": creature.hp, "defense": defense_value, "evasion": int(defense.get("evasion", 0))}, key)
	if options.has("direct_damage"): base.damage = int(options.direct_damage)
	var strike: Dictionary = session.talent_strike(creature, base, options.get("status_tick", false), options) # Planned only; committed by the session.
	var result: Dictionary = strike.result
	var loot: Array = []
	var award := {}
	if result.killed:
		var seed_key := "creature-loot-v1/%d/%d/%d/%s@%d/%s" % [session.world.seed, session.world.generation_version, session.run.seed, creature.content_id, creature.version, creature.instance_id]
		loot = session.talent_loot(definition, seed_key, session.loot_for(definition, seed_key), strike.kill) # Base + extensions + talents.
		var inventory := Inventory.new()
		award = inventory.award(layer.registry, session.world.world_id, session.run.state.inventory, loot, "run:" + session.run.run_id + "/source/" + creature.instance_id)
		if award.is_empty():
			return _refuse(inventory.last_error)
	if not _ensure_materialized(creature):
		return _refuse(last_error)
	creature.hp = result.hp
	creature.provoked = true
	var events: Array = [{"type": "hit", "attacker": "player", "target": creature.instance_id, "name": definition.name, "damage": result.damage, "hp": result.hp, "max_hp": creature.max_hp, "position": _point(creature.position)}]
	if result.killed:
		creature.dead = true
		creature.state = "dead"
		creature.loot = loot
		creature.received = award.received
		session.run.state.inventory = award.inventory
		events.append({"type": "creature_death", "target": creature.instance_id, "name": definition.name, "received": award.received, "display_received": award.display_received, "position": _point(creature.position)})
	_commit(session, creature)
	return {"type": "attack", "target": creature.instance_id, "events": events, "talent": strike}

func take_turn(session: RefCounted) -> Array:
	## Each active living creature makes at most one decision, in ID order.
	var events: Array = []
	var ids: Array = []
	for creature in creatures.values():
		if not creature.dead and maxi(absi(creature.position.x - session.position.x), absi(creature.position.y - session.position.y)) <= ACTIVE_RADIUS:
			ids.append(creature.instance_id)
	ids.sort()
	for id in ids:
		var player: Dictionary = session.combat_stats() # Effective defense from gear/growth.
		if int(player.hp) <= 0:
			break
		var creature: Dictionary = creatures[id]
		if int(creature.stunned_until) > int(session.run.state.turn) or session.statuses.blocked(session, id):
			events.append({"type": "stunned", "target": id, "name": creature.definition.name, "position": _point(creature.position)})
			if creature.has("aim"): # Binding a shooter spoils its aimed shot.
				creature.erase("aim")
				_commit(session, creature)
			continue # Stunned (skill): no decision this turn.
		var key := "ai-v1/%d/%d/%s/%d" % [session.world.seed, session.run.seed, id, int(session.run.state.turn)]
		if creature.has("aim"):
			events.append_array(release_shot(session, creature, key + "/shot"))
			continue # A committed shot is this turn's whole action.
		var decision := decide(session, creature, key)
		events.append_array(after_decision(session, creature, decision))
		if decision.type == "move":
			move_creature(session, creature, decision.to)
		elif decision.type == "charge":
			events.append_array(charge(session, creature, decision.to))
			if _distance(creature.position, session.position) == 1:
				events.append_array(creature_strike(session, creature, key + "/attack"))
		elif decision.type == "attack" and _distance(creature.position, session.position) == 1:
			events.append_array(creature_strike(session, creature, key + "/attack"))
		elif decision.type == "ranged" and ranged_reaches(session, creature) and begin_ranged(session, creature):
			# Turn model wind-up: aim at the player's tile now, release next turn.
			creature.aim = session.position
			_commit(session, creature)
			events.append({"type": "telegraph", "attacker": id, "name": creature.definition.name, "windup_ms": 600, "position": _point(creature.position), "ranged": true, "target_position": _point(session.position)})
	return events

func release_shot(session: RefCounted, creature: Dictionary, key: String) -> Array:
	## The aimed shot lands only if the player stayed on the aimed tile in clear sight.
	var aim: Vector2i = creature.aim
	creature.erase("aim")
	_commit(session, creature)
	if session.position != aim or not ranged_reaches(session, creature):
		return [{"type": "dodge", "attacker": creature.instance_id, "name": creature.definition.name, "position": _point(session.position)}]
	return creature_strike(session, creature, key)

func after_decision(session: RefCounted, creature: Dictionary, decision: Dictionary) -> Array:
	## Shared by both time models: record the state; a pack caller that starts hunting
	## alerts its kin within radius (they hunt even out of their own sight).
	var before: String = creature.state
	creature.state = decision.state
	var call: Dictionary = Traits.of(creature.definition).call_allies
	if call.is_empty() or decision.state not in ["chase", "attack", "charge"] or before in ["chase", "attack", "charge", "wary"]:
		return []
	var answered := 0
	for other in creatures.values():
		if other.dead or other.instance_id == creature.instance_id or other.content_id != creature.content_id or _distance(other.position, creature.position) > int(call.radius):
			continue
		if not _ensure_materialized(other):
			continue
		other.alerted_until = int(session.run.state.turn) + int(call.alert_turns)
		_commit(session, other)
		answered += 1
	return [{"type": "call_allies", "attacker": creature.instance_id, "name": creature.definition.name, "answered": answered, "position": _point(creature.position)}]

func charge(session: RefCounted, creature: Dictionary, to: Vector2i) -> Array:
	## Rush to the tile beside the player; the next blow uses the trait's attack_percent.
	var traits := Traits.of(creature.definition)
	if not move_creature(session, creature, to):
		return []
	creature.charged = true
	creature.charge_ready = int(session.run.state.turn) + int(traits.charge.cooldown_turns)
	_commit(session, creature)
	return [{"type": "charge", "attacker": creature.instance_id, "name": creature.definition.name, "position": _point(creature.position)}]

func decide(session: RefCounted, creature: Dictionary, key: String, move_roll: int = -1) -> Dictionary:
	## One AI decision (shared by the turn model and real time). move_roll -1 draws the
	## v1 speed roll; real time passes 0 and expresses speed as step duration instead.
	var radius := int(creature.definition.payload.ai.detect_radius)
	var offset: Vector2i = session.position - creature.position
	var context := {
		"player": session.position,
		"sees_player": offset.x * offset.x + offset.y * offset.y <= radius * radius and session.line_clear(creature.position, session.position),
		"roll": Loot.number(key) % 10000, "direction": Loot.number(key + "/dir") % 4, "move_roll": Loot.number(key + "/move") % 10000 if move_roll < 0 else move_roll,
		"can_enter": func(tile: Vector2i) -> bool: return _can_enter(session, creature, tile),
	}
	var traits := Traits.of(creature.definition)
	var wielded: Array = session._equipped("weapon").get("payload", {}).get("equipment", {}).get("damage_elements", [])
	context.afraid = traits.fears.any(func(element: String) -> bool: return element in wielded)
	context.alerted = int(creature.get("alerted_until", 0)) > int(session.run.state.turn)
	context.ranged = traits.ranged
	context.ranged_ready = int(creature.get("ranged_ready", 0)) <= int(session.run.state.turn)
	context.line_clear = context.sees_player
	if not traits.charge.is_empty() and int(creature.get("charge_ready", 0)) <= int(session.run.state.turn):
		context.charge = traits.charge
	return AI.decide(creature, creature.definition, context)

func begin_ranged(session: RefCounted, creature: Dictionary) -> bool:
	var ranged: Dictionary = Traits.of(creature.definition).ranged
	if ranged.is_empty() or int(creature.get("ranged_ready", 0)) > int(session.run.state.turn) or not _ensure_materialized(creature): return false
	creature.ranged_ready = int(session.run.state.turn) + int(ranged.cooldown_turns)
	_commit(session, creature)
	return true

func ranged_reaches(session: RefCounted, creature: Dictionary) -> bool:
	var ranged: Dictionary = Traits.of(creature.definition).ranged
	var distance := _distance(creature.position, session.position)
	return not ranged.is_empty() and distance >= int(ranged.min) and distance <= int(ranged.max) and session.line_clear(creature.position, session.position)

func move_creature(session: RefCounted, creature: Dictionary, to: Vector2i) -> bool:
	if not _ensure_materialized(creature):
		return false # Storage failure: this creature skips its move, nothing changes.
	creature.position = to
	_commit(session, creature)
	return true

func creature_strike(session: RefCounted, creature: Dictionary, key: String) -> Array:
	## One creature hit on the player: combat formula, elements, talent guards, on-hit statuses.
	if not session.terrain.can_reach(creature.position, session.position): return []
	var id: String = creature.instance_id
	var player: Dictionary = session.combat_stats() # Effective defense from gear/growth.
	var events: Array = []
	var attacker := creature_stats(session, creature)
	if creature.get("charged", false):
		attacker.attack = int(attacker.attack) * int(Traits.of(creature.definition).charge.get("attack_percent", 100)) / 100
		creature.charged = false
	var result := Combat.resolve(attacker, player, key)
	result.damage = Effects.damage(int(result.damage), creature.definition.payload.get("elements", ["neutral"]), session.statuses.actor(session, id), session.statuses.actor(session, "player"))
	result.hp = maxi(0, int(player.hp) - int(result.damage))
	result.killed = result.hp == 0
	var guarded: Dictionary = session.talent_guard(creature, player, result) # Talent reactions to the hit.
	session.stats().hp = guarded.hp
	events.append({"type": "hit", "attacker": id, "name": creature.definition.name, "target": "player", "damage": guarded.damage, "hp": guarded.hp, "max_hp": player.max_hp, "position": _point(session.position)})
	events.append_array(guarded.events)
	if int(guarded.damage) > 0 and int(guarded.hp) > 0:
		for effect in creature.definition.payload.get("on_hit_effects", []):
			events.append_array(session.statuses.apply(session, effect, {"content_id": creature.content_id, "version": int(creature.version), "actor": id}, "player"))
	return events

func stun(session: RefCounted, target_id: String, turns: int) -> Dictionary:
	## Creature skips its next `turns` decisions; stored in its Run mutation.
	var creature: Dictionary = creatures.get(target_id, {})
	if creature.is_empty() or creature.dead:
		return _refuse("No living creature to bind")
	if not _ensure_materialized(creature):
		return _refuse(last_error)
	creature.stunned_until = maxi(int(creature.stunned_until), int(session.run.state.turn) + 1 + turns)
	creature.provoked = true
	_commit(session, creature)
	return {"type": "stun", "target": target_id, "name": creature.definition.name, "turns": turns, "position": _point(creature.position)}

func _can_enter(session: RefCounted, creature: Dictionary, tile: Vector2i) -> bool:
	if not session.terrain.can_step(creature.position, tile): return false
	if tile == session.position or not living_at(tile).is_empty() or _distance(tile, creature.home) > int(creature.definition.payload.movement.leash):
		return false
	var ground: int = session.cache.tile_at(tile)
	# Authored routes are transit surfaces, never spawn habitats. Spatial creatures
	# may use them while retaining their own leash and the same directed height edges.
	if not session.terrain.spatial_cell(tile).is_empty() and ground in [Surfaces.TRAIL, Surfaces.FLOOR]: return true
	return Surfaces.hosts(session.terrain, ground, tile, str(creature.definition.content_id), creature.definition.payload.movement.biomes)

func _runtime(instance: Dictionary) -> Dictionary:
	var definition: Dictionary = layer.definition_for(instance)
	if definition.is_empty():
		_fail("Creature needs an active, valid creature definition: " + str(instance.get("instance_id")) + " " + layer.last_error)
		return {}
	var home := Vector2i(int(instance.position.x), int(instance.position.y))
	var max_hp := int(definition.payload.stats.max_hp)
	return {"instance_id": instance.instance_id, "content_id": instance.content_id, "version": int(instance.version), "instance": instance, "definition": definition, "home": home, "position": home, "hp": max_hp, "max_hp": max_hp, "dead": false, "provoked": false, "state": "idle", "mutated": false, "loot": [], "received": [], "stunned_until": 0, "statuses": [], "charge_ready": 0, "alerted_until": 0, "charged": false}

func _apply(creature: Dictionary, mutation: Dictionary) -> bool:
	if not Data.integer(mutation.get("hp")) or mutation.hp < 0 or mutation.hp > creature.max_hp or not Data.position(mutation.get("position")) or not mutation.get("dead") is bool or not mutation.get("provoked", false) is bool:
		return false
	creature.position = Vector2i(int(mutation.position.x), int(mutation.position.y))
	creature.hp = int(mutation.hp)
	creature.dead = mutation.dead or creature.hp == 0
	creature.provoked = mutation.get("provoked", false)
	creature.state = "dead" if creature.dead else str(mutation.get("state", "idle"))
	creature.loot = mutation.get("loot", [])
	creature.received = mutation.get("received", [])
	creature.stunned_until = int(mutation.get("stunned_until", 0)) if Data.integer(mutation.get("stunned_until", 0)) else 0
	if mutation.has("died_turn"):
		if not Data.integer(mutation.died_turn) or int(mutation.died_turn) < 0: return false
		creature.died_turn = int(mutation.died_turn)
	for timer in ["charge_ready", "alerted_until", "ranged_ready"]:
		if not Data.integer(mutation.get(timer, 0)) or int(mutation.get(timer, 0)) < 0: return false
		creature[timer] = int(mutation.get(timer, 0))
	creature.erase("aim")
	if mutation.has("aim"):
		if not Data.position(mutation.aim): return false
		creature.aim = Vector2i(int(mutation.aim.x), int(mutation.aim.y))
	var statuses: Variant = mutation.get("statuses", [])
	if not statuses is Array: return false
	creature.statuses = statuses.duplicate(true)
	for status in creature.statuses:
		if not status is Dictionary or not Effects.valid_record(status): return false
	creature.mutated = true
	return true

func _ensure_materialized(creature: Dictionary) -> bool:
	return creature.mutated or layer.materialize(creature.instance) or _fail(layer.last_error)

func _commit(session: RefCounted, creature: Dictionary) -> void:
	creature.mutated = true
	session.run.state.entity_mutations[creature.instance_id] = {"creature": 1, "hp": creature.hp, "position": _point(creature.position), "state": creature.state, "provoked": creature.provoked, "dead": creature.dead, "loot": creature.loot.duplicate(true), "received": creature.received.duplicate(true)}
	if not creature.get("statuses", []).is_empty():
		session.run.state.entity_mutations[creature.instance_id].statuses = creature.statuses.duplicate(true)
	if int(creature.stunned_until) > 0:
		session.run.state.entity_mutations[creature.instance_id].stunned_until = int(creature.stunned_until)
	for timer in ["charge_ready", "alerted_until", "ranged_ready"]:
		if int(creature.get(timer, 0)) > 0:
			session.run.state.entity_mutations[creature.instance_id][timer] = int(creature[timer])
	if creature.has("aim"):
		session.run.state.entity_mutations[creature.instance_id].aim = _point(creature.aim)
	if creature.dead and creature.instance.get("metadata", {}).has("returns"):
		# Kept from the first commit after death: returning homes count from it.
		creature.died_turn = int(creature.get("died_turn", session.run.state.turn))
		session.run.state.entity_mutations[creature.instance_id].died_turn = creature.died_turn

func creature_stats(session: RefCounted, creature: Dictionary) -> Dictionary:
	return session.character_rules.apply_sources(creature.definition.payload.stats, [session.statuses.stat_modifiers(session, creature.statuses)])

func _point(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _refuse(message: String) -> Dictionary:
	last_error = message
	return {}

func _fail(message: String) -> bool:
	last_error = message
	return false
