extends RefCounted
## Runtime creatures of one Run: generated home placements overlaid with this Run's
## entity mutations. Methods take the owning session to avoid reference cycles.
## Only creatures within ACTIVE_RADIUS of the player act, in instance-ID order, so
## results depend on Run state and player position — never on chunk load order.
const Effects = preload("res://src/core/effects.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Data = preload("res://src/data/json_data.gd")
const AI = preload("res://src/core/creature_ai.gd")
const Combat = preload("res://src/core/combat.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Inventory = preload("res://src/core/inventory.gd")
const ACTIVE_RADIUS := 12
const SAFE_RADIUS := 6 # No creature homes this close to the Run's spawn.
var layer: RefCounted
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
			loaded[chunk] = chunks[chunk] if chunks.has(chunk) else layer.generate_chunk(chunk, terrain_chunks.get(chunk, PackedByteArray()))
	chunks = loaded
	center = next
	for id in creatures.keys():
		# Untouched creatures are derived data; touched ones stay as Run state.
		if not creatures[id].mutated and not chunks.has(Terrain.chunk_of(creatures[id].home)):
			creatures.erase(id)
	for chunk in chunks:
		for instance in chunks[chunk]:
			var home := Vector2i(int(instance.position.x), int(instance.position.y))
			if creatures.has(instance.instance_id) or maxi(absi(home.x - spawn.x), absi(home.y - spawn.y)) <= SAFE_RADIUS:
				continue
			var creature := _runtime(instance)
			if creature.is_empty():
				return false
			creatures[instance.instance_id] = creature
	return true

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
	var reach := int(options.get("range", 1))
	var distance := _distance(creature.position, session.position)
	if not options.get("status_tick", false) and (distance < 1 or distance > reach or not session.visible.has(creature.position)):
		return _refuse(("Target is not on a visible cardinal neighbor" if reach == 1 else "Target is out of range (%d) or not visible" % reach) + " — no turn spent")
	if not options.get("status_tick", false) and reach > 1 and options.get("line_of_sight", true) and not session.line_clear(session.position, creature.position):
		return _refuse("No clear line of sight to the target — no turn spent")
	var definition: Dictionary = creature.definition
	var key := "hit-v1/%d/%d/%s/%d%s" % [session.world.seed, session.run.seed, creature.instance_id, int(session.run.state.turn), str(options.get("key", ""))]
	var attacker: Dictionary = session.combat_stats()
	attacker.attack = int(attacker.attack) * int(options.get("attack_percent", 100)) / 100 + int(options.get("flat", 0))
	var defense := creature_stats(session, creature)
	var base := Combat.resolve(attacker, {"hp": creature.hp, "defense": defense.defense}, key)
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
		events.append({"type": "creature_death", "target": creature.instance_id, "name": definition.name, "received": award.received, "position": _point(creature.position)})
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
			continue # Stunned (skill): no decision this turn.
		var key := "ai-v1/%d/%d/%s/%d" % [session.world.seed, session.run.seed, id, int(session.run.state.turn)]
		var radius := int(creature.definition.payload.ai.detect_radius)
		var offset: Vector2i = session.position - creature.position
		var context := {
			"player": session.position,
			"sees_player": offset.x * offset.x + offset.y * offset.y <= radius * radius and session.line_clear(creature.position, session.position),
			"roll": Loot.number(key) % 10000, "direction": Loot.number(key + "/dir") % 4, "move_roll": Loot.number(key + "/move") % 10000,
			"can_enter": func(tile: Vector2i) -> bool: return _can_enter(session, creature, tile),
		}
		var decision := AI.decide(creature, creature.definition, context)
		creature.state = decision.state
		if decision.type == "move":
			if not _ensure_materialized(creature):
				continue # Storage failure: this creature skips its turn, nothing changes.
			creature.position = decision.to
			_commit(session, creature)
		elif decision.type == "attack" and _distance(creature.position, session.position) == 1:
			var result := Combat.resolve(creature_stats(session, creature), player, key + "/attack")
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
	if tile == session.position or not living_at(tile).is_empty() or _distance(tile, creature.home) > int(creature.definition.payload.movement.leash):
		return false
	var ground: int = session.cache.tile_at(tile)
	return ground in [Terrain.FOREST, Terrain.BEACH, Terrain.MEADOW] and Terrain.BIOMES[ground] in creature.definition.payload.movement.biomes

func _runtime(instance: Dictionary) -> Dictionary:
	var definition: Dictionary = layer.definition_for(instance)
	if definition.is_empty():
		_fail("Creature needs an active, valid creature definition: " + str(instance.get("instance_id")) + " " + layer.last_error)
		return {}
	var home := Vector2i(int(instance.position.x), int(instance.position.y))
	var max_hp := int(definition.payload.stats.max_hp)
	return {"instance_id": instance.instance_id, "content_id": instance.content_id, "version": int(instance.version), "instance": instance, "definition": definition, "home": home, "position": home, "hp": max_hp, "max_hp": max_hp, "dead": false, "provoked": false, "state": "idle", "mutated": false, "loot": [], "received": [], "stunned_until": 0, "statuses": []}

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
