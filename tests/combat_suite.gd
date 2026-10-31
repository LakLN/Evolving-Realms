extends SceneTree
## Milestone 02 Checkpoint A: creatures, AI, damage, death, loot and persistence.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Data = preload("res://src/data/json_data.gd")
const Pack = preload("res://src/content/starter_pack.gd")
const Creatures = preload("res://src/world/world_creatures.gd")
const Roster = preload("res://src/run/creature_roster.gd")
const AI = preload("res://src/core/creature_ai.gd")
const Combat = preload("res://src/core/combat.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
var checks := 0
var failures := 0
var directory := ""

func _initialize() -> void:
	Session.auto_awaken = false # Baseline rules: this suite predates talents (see TALENTS.md).
	directory = ProjectSettings.globalize_path("user://m02a_tests/" + Data.uuid())
	DirAccess.make_dir_recursive_absolute(directory)
	print("Combat artifacts: ", directory)
	_test_rules()
	_test_ai()
	_test_generation()
	_test_hunt_and_persistence()
	_test_turn_bounds_and_order()
	_test_death("normal")
	_test_death("permadeath")
	print("M02 CHECKPOINT A COMBAT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, label: String) -> bool:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)
	return condition

func _test_rules() -> void:
	var a := Combat.resolve({"attack": 5}, {"hp": 14, "defense": 1}, "k1")
	var again := Combat.resolve({"attack": 5}, {"hp": 14, "defense": 1}, "k1")
	check(a == again and a.damage >= 4 and a.damage <= 5 and a.hp == 14 - a.damage, "Damage = attack + variance(0..attack/3) - defense, deterministic per key")
	check(Combat.resolve({"attack": 1}, {"hp": 3, "defense": 9}, "k").damage == 1, "Damage is at least 1")
	var lethal := Combat.resolve({"attack": 9}, {"hp": 2, "defense": 0}, "k")
	check(lethal.killed and lethal.hp == 0, "Lethal hit clamps HP at 0 and reports kill")
	var stats := Combat.player_stats({"custom": 1})
	check(stats.hp == 30 and stats.max_hp == 30 and stats.custom == 1 and Combat.valid_stats(stats, true), "Player defaults fill missing combat stats, keep unknown keys")
	check(not Combat.valid_stats({"max_hp": 0, "attack": 1, "defense": 0}) and not Combat.valid_stats({"max_hp": 5, "attack": 1, "defense": 0, "hp": 9}, true), "Invalid combat stats rejected")

func _definition(disposition: String, flee_radius: int = 0) -> Dictionary:
	return {"name": "Test", "payload": {"disposition": disposition, "stats": {"max_hp": 10, "attack": 3, "defense": 0}, "movement": {"biomes": ["forest"], "leash": 10}, "ai": {"detect_radius": 6, "wander_per_10000": 10000, "flee_radius": flee_radius, "flee_below_percent": 0}}}

func _creature(at: Vector2i, provoked: bool = false) -> Dictionary:
	return {"position": at, "home": at, "hp": 10, "provoked": provoked}

func _context(player: Vector2i, sees: bool, roll: int = 9999, can_enter: Callable = func(_t: Vector2i) -> bool: return true) -> Dictionary:
	return {"player": player, "sees_player": sees, "roll": roll, "direction": 1, "can_enter": can_enter}

func _test_ai() -> void:
	var origin := Vector2i(10, 10)
	check(AI.decide(_creature(origin), _definition("hostile"), _context(origin + Vector2i.RIGHT, true)).type == "attack", "Hostile attacks an adjacent visible player")
	var chase := AI.decide(_creature(origin), _definition("hostile"), _context(origin + Vector2i(4, 0), true))
	check(chase.type == "move" and chase.to == origin + Vector2i.RIGHT and chase.state == "chase", "Hostile chases a detected player one cardinal step")
	check(AI.decide(_creature(origin), _definition("hostile"), _context(origin + Vector2i(4, 0), false)).state != "chase", "No chase without line of sight")
	check(AI.decide(_creature(origin), _definition("hostile"), _context(origin + Vector2i(9, 0), true)).state != "chase", "No chase beyond detect radius")
	check(AI.decide(_creature(origin), _definition("neutral"), _context(origin + Vector2i.RIGHT, true)).type != "attack", "Unprovoked neutral does not attack")
	check(AI.decide(_creature(origin, true), _definition("neutral"), _context(origin + Vector2i.RIGHT, true)).type == "attack", "Provoked neutral fights back")
	var flee := AI.decide(_creature(origin, true), _definition("passive"), _context(origin + Vector2i.RIGHT, true))
	check(flee.type == "move" and flee.to.distance_to(origin + Vector2i.RIGHT) > 1 and flee.state == "flee", "Provoked passive creature flees away")
	check(AI.decide(_creature(origin), _definition("passive", 2), _context(origin + Vector2i(2, 0), true)).state == "flee", "Shy passive creature flees inside its flee radius")
	var stuck := AI.decide(_creature(origin), _definition("hostile"), _context(origin + Vector2i(4, 0), true, 0, func(_t: Vector2i) -> bool: return false))
	check(stuck.type == "wait", "Blocked creature waits instead of looping or crossing terrain")
	var far := _creature(origin + Vector2i(6, 0))
	far.home = origin
	var back := AI.decide(far, _definition("passive"), _context(origin + Vector2i(30, 30), false))
	check(back.type == "move" and back.to == origin + Vector2i(5, 0) and back.state == "return", "Creature outside wander radius returns home")
	check(AI.decide(_creature(origin), _definition("passive"), _context(origin + Vector2i(30, 30), false, 0)).state == "wander", "Low roll wanders")
	var slow := _definition("passive")
	slow.payload.movement["move_per_10000"] = 6000
	var context := _context(origin + Vector2i.RIGHT, true)
	var fled := AI.decide(_creature(origin, true), slow, context)
	context["move_roll"] = 6000
	var paused := AI.decide(_creature(origin, true), slow, context)
	check(fled.type == "move" and paused.type == "wait" and paused.state == "flee", "move_per_10000 makes slower species skip steps (catchable)")

func _world(store: RefCounted, name: String) -> Dictionary:
	return store.create_world(name, 1847, 1, Pack.blueprint(1847))

func _test_generation() -> void:
	var store := Store.new()
	check(store.open(directory + "/generation.sqlite"), "Open generation database")
	var world := _world(store, "Creatures")
	var terrain := Terrain.new()
	terrain.configure(1847, 1)
	var layer := Creatures.new()
	check(layer.configure(world, terrain, store.content) and layer.rules.size() == 5, "Creature pack installs five active data-driven species")
	check(store.content.load_definition(world.world_id, "core:wolf", 1).status == "active", "definition.creature capability makes species active")
	var dispositions := {}
	var valid := true
	var counts_ok := true
	var unique := {}
	var total := 0
	var forward := {}
	for y in range(-3, 4):
		for x in range(-3, 4):
			var chunk := Vector2i(x, y)
			var placed := layer.generate_chunk(chunk)
			forward[chunk] = placed
			counts_ok = counts_ok and placed.size() <= Creatures.MAX_PER_CHUNK
			for instance in placed:
				total += 1
				var tile := Vector2i(instance.position.x, instance.position.y)
				var definition: Dictionary = layer.definition_for(instance)
				dispositions[definition.payload.disposition] = true
				valid = valid and terrain.walkable(tile) and terrain.biome_at(tile) in definition.payload.spawn.biomes and Terrain.chunk_of(tile) == chunk and not unique.has(instance.instance_id)
				unique[instance.instance_id] = true
	check(valid and total > 20, "Creatures spawn only on walkable tiles of their biome, unique IDs (%d placed in 49 chunks)" % total)
	check(counts_ok, "Density capped per chunk")
	check(dispositions.size() == 3, "Hostile, neutral and passive species all appear")
	var same := true
	var keys: Array = forward.keys()
	keys.reverse()
	for chunk in keys:
		same = same and Acceptance.same(layer.generate_chunk(chunk), forward[chunk])
	check(same, "Reverse chunk order gives identical creature placements")
	var bad: Dictionary = store.content.load_definition(world.world_id, "core:wolf", 1)
	bad.payload.disposition = "berserk"
	check(not layer.validate(bad), "Unknown disposition rejected")
	bad = store.content.load_definition(world.world_id, "core:wolf", 1)
	bad.payload.spawn.biomes = ["beach"]
	check(not layer.validate(bad), "Spawn biome outside movement biomes rejected")
	bad = store.content.load_definition(world.world_id, "core:wolf", 1)
	bad.payload.stats.max_hp = 0
	check(not layer.validate(bad), "Invalid creature stats rejected")
	# Runs: creatures never occupy or crowd the spawn.
	var crowded := 0
	for seed_value in [11, 22, 33, 44, 55, 66]:
		for biome in ["forest", "meadow", "beach"]:
			var session := Session.new(store)
			if not session.start_new(world.world_id, seed_value, biome):
				continue
			for creature in session.roster.creatures.values():
				if maxi(absi(creature.home.x - session.position.x), absi(creature.home.y - session.position.y)) <= Roster.SAFE_RADIUS:
					crowded += 1
	check(crowded == 0, "No creature home within the safe radius of 18 Run spawns")
	store.close()

func _approach(session: RefCounted, id: String, limit: int = 200) -> bool:
	for _step in limit:
		var creature: Dictionary = session.roster.creatures.get(id, {})
		if creature.is_empty() or creature.dead or session.is_dead():
			return false
		var direction: Vector2i = Acceptance.step_toward_creature(session, creature)
		if direction == Vector2i.ZERO:
			if session.visible.has(creature.position) and absi(creature.position.x - session.position.x) + absi(creature.position.y - session.position.y) == 1:
				return true
			session.wait_turn()
		elif not session.try_move(direction):
			session.wait_turn()
	return false

func _test_hunt_and_persistence() -> void:
	var store := Store.new()
	store.open(directory + "/hunt.sqlite")
	var world := _world(store, "Hunt")
	var session := Session.new(store)
	check(session.start_new(world.world_id, 101, "forest"), "Start forest run")
	var turn := int(session.run.state.turn)
	check(not session.attack_target() and int(session.run.state.turn) == turn, "Attack with no adjacent creature spends no turn")
	check(not session.perform_action({"type": "attack", "target_id": "crt:v1/0/0/0_0"}) and int(session.run.state.turn) == turn, "Attack on unknown creature spends no turn")
	check(session.wait_turn() and int(session.run.state.turn) == turn + 1, "Wait spends exactly one turn")
	var prey := Acceptance.nearest_creature(session, ["neutral"])
	if not check(not prey.is_empty(), "A neutral creature lives near the forest spawn"):
		return
	var id: String = prey.instance_id
	check(_approach(session, id), "Walk next to %s with real moves" % prey.definition.name)
	var far := Acceptance.nearest_creature(session, ["hostile", "neutral", "passive"])
	var hp_before: int = session.roster.creatures[id].hp
	turn = int(session.run.state.turn)
	check(session.attack_target(id) and int(session.run.state.turn) == turn + 1, "Attack spends exactly one turn")
	var victim: Dictionary = session.roster.creatures[id]
	check(victim.hp < hp_before and victim.provoked and session.last_events[0].type == "hit", "Hit reduces creature HP, provokes it, and is reported")
	check(session.save(), "Save mid-combat")
	var resumed := Session.new(store)
	check(resumed.resume(session.run.run_id) and resumed.roster.creatures[id].hp == victim.hp and resumed.roster.creatures[id].provoked and resumed.roster.creatures[id].position == victim.position, "Damaged creature HP/position/provocation survive reload")
	check(Acceptance.same(resumed.stats(), session.stats()), "Player HP survives reload")
	var expected_loot := Loot.new().roll(victim.definition.payload.loot, "creature-loot-v1/%d/%d/%d/%s@%d/%s" % [world.seed, 1, session.run.seed, victim.content_id, 1, id])
	var kills := 0
	for _blow in 20:
		if session.roster.creatures[id].dead or session.is_dead():
			break
		if not _approach(session, id, 30):
			break
		if session.attack_target(id):
			kills += 1
	victim = session.roster.creatures[id]
	if not check(victim.dead and not session.is_dead(), "Creature killed in combat (%d blows)" % kills):
		return
	var received := 0
	for item in victim.received:
		received += int(item.quantity)
	var expected := 0
	for item in expected_loot:
		expected += int(item.quantity)
	check(received == expected and received > 0, "Loot from table awarded exactly as derived (%d items)" % received)
	var inventory: Dictionary = session.run.state.inventory.duplicate(true)
	turn = int(session.run.state.turn)
	check(not session.attack_target(id) and int(session.run.state.turn) == turn and Acceptance.same(session.run.state.inventory, inventory), "Dead creature cannot be attacked again or loot twice; no turn spent")
	check(session.roster.living_at(victim.position).is_empty(), "Dead creature no longer blocks its tile")
	for _i in 5:
		session.wait_turn()
	check(session.roster.creatures[id].position == victim.position and session.roster.creatures[id].dead, "Dead creature takes no further actions")
	check(session.save(), "Save after kill")
	# Chunk eviction and return: touched creatures persist, untouched regenerate identically.
	var snapshot := {}
	for key in session.roster.creatures:
		snapshot[key] = _shape(session.roster.creatures[key])
	var far_tile := session.position + Vector2i(200, 0)
	session.roster.follow(far_tile, {})
	check(session.roster.creatures.has(id) and session.roster.creatures[id].dead, "Killed creature stays dead while its chunk is unloaded")
	session.roster.follow(session.position, session.cache.chunks)
	var restored := true
	for key in snapshot:
		restored = restored and session.roster.creatures.has(key) and Acceptance.same(_shape(session.roster.creatures[key]), snapshot[key])
	check(restored and session.roster.creatures.size() == snapshot.size(), "Unload/reload chunks keeps every creature state and position")
	var reloaded := Session.new(store)
	check(reloaded.resume(session.run.run_id) and reloaded.roster.creatures[id].dead and Acceptance.same(reloaded.run.state.inventory, session.run.state.inventory), "After reload the creature is still dead and loot is not duplicated")
	var mutation: Dictionary = store.load_run(session.run.run_id).state.entity_mutations[id]
	check(mutation.dead and mutation.creature == 1 and not mutation.received.is_empty(), "Death and loot receipt persisted as a run mutation")
	var run_b := Session.new(store)
	check(run_b.start_new(world.world_id, 202, "meadow") and run_b.run.state.inventory.is_empty(), "Run B starts with empty inventory")
	run_b.roster.follow(Vector2i(int(victim.home.x), int(victim.home.y)), {})
	var fresh: Dictionary = run_b.roster.creatures.get(id, {})
	check(not fresh.is_empty() and not fresh.dead and fresh.hp == fresh.max_hp and fresh.position == victim.home, "Run B sees the same creature alive at full HP at its home")
	check(Acceptance.same(store.load_world(world.world_id).blueprint, world.blueprint), "Combat never changes the World Blueprint")
	store.close()

func _shape(creature: Dictionary) -> Dictionary:
	return {"position": creature.position, "hp": creature.hp, "dead": creature.dead, "provoked": creature.provoked}

func _test_turn_bounds_and_order() -> void:
	var store := Store.new()
	store.open(directory + "/turns.sqlite")
	var world := _world(store, "Turns")
	var session := Session.new(store)
	session.start_new(world.world_id, 303, "forest")
	session.save()
	var twin := Session.new(store)
	twin.resume(session.run.run_id)
	# Load chunks in a different order before acting; outcomes must not change.
	twin.roster.follow(twin.position + Vector2i(96, -96), {})
	twin.roster.follow(twin.position, twin.cache.chunks)
	var bounded := true
	var legal := true
	for _turn in 60:
		var before := {}
		for key in session.roster.creatures:
			before[key] = session.roster.creatures[key].position
		if not session.wait_turn() or not twin.wait_turn():
			break
		var occupied := {}
		for key in session.roster.creatures:
			var creature: Dictionary = session.roster.creatures[key]
			if before.has(key):
				bounded = bounded and absi(creature.position.x - before[key].x) + absi(creature.position.y - before[key].y) <= 1
			if creature.dead:
				continue
			var ground: int = session.cache.tile_at(creature.position)
			legal = legal and session.terrain.walkable(creature.position) and Terrain.BIOMES[ground] in creature.definition.payload.movement.biomes and creature.position != session.position and not occupied.has(creature.position) and absi(creature.position.x - creature.home.x) + absi(creature.position.y - creature.home.y) <= int(creature.definition.payload.movement.leash)
			occupied[creature.position] = true
	check(bounded, "Each creature moves at most one tile per turn")
	check(legal, "Creatures stay on walkable tiles of their movement biomes, within leash, never stacked or on the player")
	check(Acceptance.same(session.run.state.entity_mutations, twin.run.state.entity_mutations) and Acceptance.same(session.stats(), twin.stats()), "Same actions give identical creature and player state regardless of chunk load order")
	store.close()

func _test_death(mode: String) -> void:
	var store := Store.new()
	store.open(directory + "/death-" + mode + ".sqlite")
	var world := _world(store, "Death " + mode)
	var session := Session.new(store)
	check(session.start_new(world.world_id, 101, "forest", mode) and session.run.mode == mode, "Start %s run" % mode)
	var prey := Acceptance.nearest_creature(session, ["neutral", "hostile"])
	if prey.is_empty() or not _approach(session, prey.instance_id):
		check(false, "Reach a creature for the %s death test" % mode)
		return
	check(session.save(), "Save a living state before the fatal fight")
	var saved: Dictionary = store.load_run(session.run.run_id)
	session.stats().hp = 1 # Low-health setup; the fatal blow comes from real AI.
	for _turn in 10:
		if session.is_dead():
			break
		if not session.attack_target(prey.instance_id):
			session.wait_turn()
	if not check(session.is_dead(), "%s: creature attack kills the player at 0 HP" % mode):
		return
	check(session.last_events.back().type == "player_death" and int(session.stats().hp) == 0, "%s: death event reported" % mode)
	var turn := int(session.run.state.turn)
	check(not session.wait_turn() and not session.try_move(Vector2i.RIGHT) and int(session.run.state.turn) == turn, "%s: dead player cannot act" % mode)
	var stored: Dictionary = store.load_run(session.run.run_id)
	if mode == "normal":
		check(not session.save() and stored.state.status == "alive" and stored.revision == saved.revision, "Normal: death is not saved over the living save")
		var forced: Dictionary = session.run.state.duplicate(true)
		check(not store.save_run(session.run.run_id, int(stored.revision), forced) and store.last_error.contains("Normal-mode death"), "Normal: GameStore refuses a dead state directly")
		var again := Session.new(store)
		check(again.resume(session.run.run_id) and not again.is_dead() and Acceptance.same(again.run.state.inventory, saved.state.inventory) and int(again.stats().hp) == int(saved.state.character.stats.hp), "Normal: load returns to the last living save")
	else:
		check(stored.state.status == "dead" and not session.dirty, "Permadeath: death is recorded immediately")
		var again := Session.new(store)
		check(not again.resume(session.run.run_id) and again.last_error.contains("ended"), "Permadeath: dead run cannot be continued")
		stored.state.status = "alive"
		check(not store.save_run(session.run.run_id, int(stored.revision), stored.state), "Permadeath: data layer refuses resurrection")
		var next := Session.new(store)
		check(next.start_new(world.world_id, 909, "forest", "permadeath") and not next.is_dead(), "Permadeath: a new run in the same world starts alive")
		check(store.list_runs(world.world_id)[0].status == "dead", "Permadeath: run list reports the ended run")
	check(Acceptance.same(store.load_world(world.world_id).blueprint, world.blueprint), "%s: death leaves World Blueprint unchanged" % mode)
	store.close()
