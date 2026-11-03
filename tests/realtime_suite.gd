extends SceneTree
## Milestone 03 B: real-time prototype (gameplay clock, creature timers, cooldowns,
## pulses, death/healing, statuses by time, save isolation). Headless; drives the
## RealtimeController exactly as the scene does, with fixed 16 ms frames.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Controller = preload("res://src/run/realtime_controller.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Data = preload("res://src/data/json_data.gd")
const Pack = preload("res://src/content/starter_pack.gd")
const FRAME := 16
const WALKABLE := [Terrain.FOREST, Terrain.BEACH, Terrain.MEADOW]
const CARDINAL := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
var checks := 0
var failures := 0
var directory := ""
var store := Store.new()
var world: Dictionary
var _wolves := 0

func _initialize() -> void:
	Session.auto_awaken = false # Baseline numbers: no talent modifies damage or healing.
	directory = ProjectSettings.globalize_path("user://m03b_tests/" + Data.uuid())
	DirAccess.make_dir_recursive_absolute(directory)
	print("Real-time artifacts: ", directory)
	if not check(store.open(directory + "/realtime.sqlite"), "Open isolated test database"):
		quit(1)
		return
	world = store.create_world("Realtime", 1847, 1, Pack.blueprint(1847))
	_test_rules_and_model()
	_test_movement()
	_test_creature_loop()
	_test_cooldowns_and_kill()
	_test_statuses_and_pause()
	_test_death()
	_test_save_isolation()
	store.close()
	print("M03 REALTIME: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, label: String) -> bool:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)
	return condition

# --- helpers ---------------------------------------------------------------------

func _start(seed_value: int, mode: String = "normal") -> RefCounted:
	var session := Session.new(store)
	if not session.start_new(world.world_id, seed_value, "forest", mode, "realtime-v1"):
		printerr(session.last_error)
		return null
	_isolate(session)
	return session

func _controller(session: RefCounted) -> RefCounted:
	var controller := Controller.new()
	controller.configure(session)
	return controller

func _isolate(session: RefCounted) -> void:
	## Remove untouched natural creatures so a scenario only contains what it places.
	for id in session.roster.creatures.keys():
		if not session.roster.creatures[id].mutated:
			session.roster.creatures.erase(id)

func _free(session: RefCounted, tile: Vector2i) -> bool:
	return session.cache.tile_at(tile) in WALKABLE and session.roster.living_at(tile).is_empty() and tile != session.position

func _wolf(session: RefCounted, tile: Vector2i) -> Dictionary:
	_wolves += 1
	var instance := {"instance_id": "crt:v1/rt_test/wolf_%d" % _wolves, "content_id": "core:wolf", "version": 1, "position": {"x": tile.x, "y": tile.y}, "origin": "procedural", "metadata": {"creature_generation_version": 1}}
	var creature: Dictionary = session.roster._runtime(instance)
	session.roster.creatures[instance.instance_id] = creature
	return creature

func _wolf_lane(session: RefCounted, distance: int) -> Dictionary:
	## A wolf `distance` tiles away on a straight, clear forest/meadow line.
	for direction in CARDINAL:
		var ok := true
		for step in range(1, distance + 1):
			var tile: Vector2i = session.position + direction * step
			ok = ok and _free(session, tile) and session.terrain.biome_at(tile) in ["forest", "meadow"]
		if ok and session.line_clear(session.position, session.position + direction * distance):
			return _wolf(session, session.position + direction * distance)
	return {}

func _run(controller: RefCounted, ms: int, direction: Vector2i = Vector2i.ZERO, log: Array = [], stop: Callable = Callable()) -> void:
	var elapsed := 0
	while elapsed < ms:
		for event in controller.update(FRAME, direction):
			event = event.duplicate()
			event.at = controller.now_ms
			log.append(event)
		elapsed += FRAME
		if stop.is_valid() and stop.call():
			return

# --- tests -----------------------------------------------------------------------

func _test_rules_and_model() -> void:
	check(not Controller.load_rules().is_empty(), "Real-time rules file loads and validates")
	var session := Session.new(store)
	check(not session.start_new(world.world_id, 5, "forest", "normal", "realtime-v9"), "Unknown time model is refused at Run creation")
	session = _start(31)
	check(session != null and session.realtime and session.run.spawn.time_model == "realtime-v1", "Real-time Run stores time_model in its spawn")
	if session == null: return
	var turn := int(session.run.state.turn)
	check(not session.wait_turn() and int(session.run.state.turn) == turn, "Wait is explicitly unsupported in real time (no turn passes)")

func _test_movement() -> void:
	var session := _start(41)
	if session == null: return
	var controller := _controller(session)
	var lane := Vector2i.ZERO
	var origin: Vector2i = session.position
	for radius in range(0, 12):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var from: Vector2i = origin + Vector2i(x, y)
				if lane != Vector2i.ZERO or maxi(absi(x), absi(y)) != radius or (from != session.position and not _free(session, from)):
					continue
				for direction in CARDINAL:
					var open := true
					for step in range(1, 9):
						open = open and _free(session, from + direction * step)
					if open and lane == Vector2i.ZERO:
						lane = direction
						session.relocate(from) # Test fixture: start of a clear 8-tile lane.
	if not check(lane != Vector2i.ZERO, "Found an open 8-tile lane for the movement test"):
		return
	var start: Vector2i = session.position
	var turn := int(session.run.state.turn)
	var steps: Array = []
	var elapsed := 0
	while elapsed < 1000:
		controller.update(FRAME, lane)
		if controller.moved: steps.append(controller.now_ms)
		elapsed += FRAME
	var expected := 1000 / int(controller.rules.player.step_ms)
	check(steps.size() >= expected - 1 and steps.size() <= expected + 1 and session.position == start + lane * steps.size(), "Holding a key walks continuously: %d tiles in 1 s at %d ms per step" % [steps.size(), int(controller.rules.player.step_ms)])
	var spaced := true
	for i in range(1, steps.size()):
		spaced = spaced and int(steps[i]) - int(steps[i - 1]) >= int(controller.rules.player.step_ms) - FRAME and int(steps[i]) - int(steps[i - 1]) <= int(controller.rules.player.step_ms) + FRAME
	check(spaced, "Steps chain back to back at the step duration (no gaps, no speed-up)")
	check(int(session.run.state.turn) == turn + 1, "Exactly one world pulse (turn) per gameplay second, independent of steps taken")
	var here: Vector2i = session.position
	_run(controller, 500)
	check(session.position == here, "Releasing the keys stops the hero")
	# Walls: walk into the nearest blocked tile; diagonal corner cutting is refused.
	var blocked_direction := Vector2i.ZERO
	var corner := {}
	for y in range(-6, 7):
		for x in range(-6, 7):
			var tile: Vector2i = session.position + Vector2i(x, y)
			if session.cache.tile_at(tile) not in WALKABLE or not session.roster.living_at(tile).is_empty():
				continue
			for diagonal in Session.DIAGONALS:
				var side_a := tile + Vector2i(diagonal.x, 0)
				var side_b := tile + Vector2i(0, diagonal.y)
				if corner.is_empty() and _free(session, tile + diagonal) and (session.cache.tile_at(side_a) not in WALKABLE) != (session.cache.tile_at(side_b) not in WALKABLE):
					corner = {"from": tile, "diagonal": diagonal}
	if check(not corner.is_empty(), "Found a wall corner near the hero"):
		session.relocate(corner.from)
		check(not session.try_move(corner.diagonal) and session.position == corner.from, "Diagonal step that would cut a wall corner is refused")
		var slid := Vector2i(corner.diagonal.x, 0) if session.cache.tile_at(corner.from + Vector2i(corner.diagonal.x, 0)) in WALKABLE else Vector2i(0, corner.diagonal.y)
		controller.step_until = 0
		controller.update(FRAME, corner.diagonal)
		check(session.position == corner.from + slid, "Holding a blocked diagonal slides along the wall instead")
	for direction in CARDINAL:
		if session.cache.tile_at(session.position + direction) not in WALKABLE:
			blocked_direction = direction
	if blocked_direction != Vector2i.ZERO:
		var before: Vector2i = session.position
		_run(controller, 600, blocked_direction)
		check(session.position == before, "Walking into water/trees/rocks never moves the hero")

func _test_creature_loop() -> void:
	var session := _start(51)
	if session == null: return
	var controller := _controller(session)
	var wolf := _wolf_lane(session, 4)
	if not check(not wolf.is_empty(), "Placed a hostile wolf 4 tiles from a stationary hero"):
		return
	var id: String = wolf.instance_id
	var hero: Vector2i = session.position
	var log: Array = []
	var legal := true
	var hits := 0
	var moved_before_hit := false
	var elapsed := 0
	while elapsed < 6000 and hits < 3 and not session.is_dead():
		for event in controller.update(FRAME):
			event = event.duplicate()
			event.at = controller.now_ms
			log.append(event)
			if event.type == "hit" and event.target == "player":
				hits += 1
		elapsed += FRAME
		var tile: Vector2i = session.roster.creatures[id].position
		moved_before_hit = moved_before_hit or (hits == 0 and tile != wolf.home)
		legal = legal and session.cache.tile_at(tile) in WALKABLE and tile != session.position
	check(session.position == hero, "The hero never moved (no player input at all)")
	check(moved_before_hit, "The wolf chases on its own timer while the hero stands still")
	check(hits >= 2, "The wolf attacks repeatedly without any player action (%d hits)" % hits)
	check(legal, "The wolf only ever stood on walkable, unoccupied tiles")
	var warned := true
	var spaced := true
	var last_hit := -100000
	for i in log.size():
		var event: Dictionary = log[i]
		if event.type != "hit" or event.target != "player": continue
		var telegraph := -1
		for j in range(i - 1, -1, -1):
			if log[j].type == "telegraph" and log[j].attacker == id:
				telegraph = int(log[j].at)
				break
		warned = warned and telegraph >= 0 and int(event.at) - telegraph >= int(controller.rules.creatures.windup_ms) and int(event.at) - telegraph <= int(controller.rules.creatures.windup_ms) + FRAME
		spaced = spaced and int(event.at) - last_hit >= int(controller.rules.creatures.attack_interval_ms) - FRAME
		last_hit = int(event.at)
	check(warned, "Every hit is announced by a telegraph exactly one wind-up earlier")
	check(spaced, "Consecutive hits respect the creature attack interval (%d ms)" % int(controller.rules.creatures.attack_interval_ms))
	# Dodge: step out of reach during a wind-up and the blow misses.
	var dodged := false
	for _attempt in 6:
		var wound := {}
		_run(controller, 3000, Vector2i.ZERO, [], func() -> bool: return controller.creatures.windups.has(id))
		if not controller.creatures.windups.has(id) or session.is_dead(): break
		var hp := int(session.stats().hp)
		var away := Vector2i.ZERO
		for direction in CARDINAL:
			var next: Vector2i = session.position + direction
			if _free(session, next) and absi(next.x - session.roster.creatures[id].position.x) + absi(next.y - session.roster.creatures[id].position.y) > 1:
				away = direction
		if away == Vector2i.ZERO: continue
		var events: Array = []
		controller.step_until = 0
		_run(controller, int(controller.rules.creatures.windup_ms), away, events)
		dodged = events.any(func(e: Dictionary) -> bool: return e.type == "dodge" and e.attacker == id) and int(session.stats().hp) >= hp - 0
		if dodged: break
	check(dodged, "Leaving melee reach during the wind-up makes the attack miss (dodge)")
	# Blockers in a long simulation with several creatures.
	var crowd := _start(52)
	if crowd == null: return
	var crowd_controller := _controller(crowd)
	for direction in CARDINAL:
		var tile: Vector2i = crowd.position + direction * 5
		if _free(crowd, tile): _wolf(crowd, tile)
	crowd.stats().max_hp = 500
	crowd.stats().hp = 500
	crowd.refresh_stats()
	var clean := true
	var most_windups := 0
	var elapsed_crowd := 0
	while elapsed_crowd < 8000 and not crowd.is_dead():
		crowd_controller.update(FRAME)
		elapsed_crowd += FRAME
		most_windups = maxi(most_windups, crowd_controller.creatures.windups.size())
		var seen := {}
		for creature in crowd.roster.creatures.values():
			if creature.dead: continue
			clean = clean and crowd.cache.tile_at(creature.position) in WALKABLE and creature.position != crowd.position and not seen.has(creature.position)
			seen[creature.position] = true
	check(clean, "Several creatures for 8 s: never on water/trees/rocks, the hero or each other")
	check(most_windups >= 1 and most_windups <= int(crowd_controller.rules.creatures.max_windups), "Four attackers, at most %d wind-ups at once (peak %d)" % [int(crowd_controller.rules.creatures.max_windups), most_windups])

func _test_cooldowns_and_kill() -> void:
	var session := _start(61)
	if session == null: return
	var controller := _controller(session)
	var wolf := _wolf_lane(session, 1)
	if not check(not wolf.is_empty(), "Placed a wolf next to the hero"):
		return
	var id: String = wolf.instance_id
	session.stats().hp = 200 # Survive the exchange; this test is about player timing.
	session.stats().max_hp = 200
	session.refresh_stats()
	check(controller.attack(id), "Basic attack lands")
	var first: int = session.roster.creatures[id].hp
	check(not controller.attack(id) and session.roster.creatures[id].hp == first, "A second attack inside the attack interval is refused and deals nothing")
	_run(controller, int(controller.rules.player.attack_interval_ms) - 2 * FRAME)
	check(not controller.attack(id), "Still refused just before the interval ends")
	_run(controller, 3 * FRAME)
	var kills := 0
	var strikes := 0
	var elapsed := 0
	while elapsed < 20000 and not session.roster.creatures[id].dead:
		if controller.attack(id): strikes += 1
		controller.update(FRAME)
		elapsed += FRAME
	var dead: bool = session.roster.creatures[id].dead
	check(dead and strikes >= 1, "Attacks on cooldown kill the wolf (%d more strikes)" % strikes)
	check(dead and not session.roster.creatures[id].received.is_empty(), "Kill awards the species loot once")
	check(not controller.attack(id), "A dead creature cannot be attacked again")
	# Healing: rest recovery over gameplay time, interrupted by moving.
	session.stats().hp = 150
	check(session.set_resting(true), "Resting starts when no threat is in sight")
	var hp := int(session.stats().hp)
	_run(controller, 8000)
	check(int(session.stats().hp) > hp, "Resting heals over gameplay time (%d -> %d HP)" % [hp, int(session.stats().hp)])
	for direction in CARDINAL:
		if _free(session, session.position + direction):
			controller.step_until = 0
			controller.update(FRAME, direction)
			break
	check(not session.resting, "Moving ends the rest")

func _test_statuses_and_pause() -> void:
	var session := _start(71)
	if session == null: return
	var controller := _controller(session)
	session.stats().hp = 30
	var effect := {"type": "apply_status", "content_id": "core:status/poison", "version": 1}
	var applied: Array = session.statuses.apply(session, effect, {"content_id": "core:status/poison", "version": 1, "actor": "player"}, "player")
	if not check(not applied.is_empty() and applied[0].type == "status_apply", "Poison applied to the hero"):
		return
	var record: Dictionary = session.run.state.character.statuses.filter(func(s: Dictionary) -> bool: return s.id == "core:status/poison")[0]
	var remaining := int(record.remaining)
	var hp := int(session.stats().hp)
	for _frame in 200:
		controller.update(0) # Paused/zero-time frames: no gameplay time passes.
	check(int(record.remaining) == remaining and int(session.stats().hp) == hp, "Zero gameplay time (paused) never ticks a status")
	var ticks: Array = []
	_run(controller, 992, Vector2i.ZERO, ticks)
	check(not ticks.any(func(e: Dictionary) -> bool: return e.type == "status_tick"), "No tick before the first gameplay second")
	ticks.clear()
	_run(controller, 1024, Vector2i.ZERO, ticks) # Crosses the 1 s and 2 s pulses only.
	var poison := ticks.filter(func(e: Dictionary) -> bool: return e.type == "status_tick" and e.target == "player")
	check(poison.size() == 2 and int(session.stats().hp) < hp, "Two more gameplay seconds = two poison ticks (%d HP -> %d)" % [hp, int(session.stats().hp)])
	check(poison.all(func(e: Dictionary) -> bool: return e.get("source", "") == "you"), "Ticks carry damage attribution (source)")
	_run(controller, 15000)
	check(not session.run.state.character.statuses.any(func(s: Dictionary) -> bool: return s.id == "core:status/poison"), "Poison expires after its duration in gameplay seconds")
	# Skills: buff duration and cooldown are gameplay seconds; using one spends no turn.
	var guard: Dictionary = session.store.content.load_definition(session.world.world_id, "core:skill/iron_guard", 1)
	if check(session.skills.learn(session, guard, {"kind": "test"}).is_empty(), "Learn Iron Guard (DEF +3, 5 turns, cooldown 12)"):
		var defense := int(session.combat_stats().defense)
		var turn := int(session.run.state.turn)
		check(session.perform_action({"type": "skill", "skill_id": "core:skill/iron_guard"}) and int(session.run.state.turn) == turn and int(session.combat_stats().defense) == defense + 3, "Using a skill applies at once and spends no turn")
		check(not session.perform_action({"type": "skill", "skill_id": "core:skill/iron_guard"}) and session.last_error.contains("recharging") and session.last_error.contains(" s)"), "Immediate reuse is refused, cooldown shown in seconds")
		_run(controller, 6000)
		check(int(session.combat_stats().defense) == defense, "The guard wore off after its duration in gameplay seconds")
		check(not session.perform_action({"type": "skill", "skill_id": "core:skill/iron_guard"}), "Still recharging after 6 s")
		_run(controller, 8000)
		check(session.perform_action({"type": "skill", "skill_id": "core:skill/iron_guard"}), "Usable again once the cooldown seconds passed")
	# Slow doubles the hero's step duration; stun blocks movement.
	session.statuses.apply(session, {"type": "apply_status", "content_id": "core:status/stun", "version": 1}, {"content_id": "core:status/stun", "version": 1, "actor": "player"}, "player")
	var lane := Vector2i.ZERO
	for direction in CARDINAL:
		if _free(session, session.position + direction) and _free(session, session.position + direction * 2): lane = direction
	if lane != Vector2i.ZERO:
		var here: Vector2i = session.position
		controller.step_until = 0
		controller.update(FRAME, lane)
		check(session.position == here, "Stunned: movement is blocked")

func _test_death() -> void:
	var session := _start(81)
	if session == null: return
	var controller := _controller(session)
	var wolf := _wolf_lane(session, 1)
	if not check(not wolf.is_empty(), "Placed a wolf next to a nearly dead hero"):
		return
	session.stats().hp = 1
	var log: Array = []
	_run(controller, 4000, Vector2i.ZERO, log, func() -> bool: return session.is_dead())
	check(session.is_dead() and log.any(func(e: Dictionary) -> bool: return e.type == "player_death"), "A creature hit kills the hero without any player input")
	check(controller.update(FRAME).is_empty() and controller.update(1000).is_empty(), "After death no creature acts and no pulse runs")
	check(not session.save(), "Normal-mode death is never saved (last living save stays)")
	var hardcore := _start(82, "permadeath")
	if hardcore == null: return
	var hardcore_controller := _controller(hardcore)
	if _wolf_lane(hardcore, 1).is_empty(): return
	hardcore.stats().hp = 1
	_run(hardcore_controller, 4000, Vector2i.ZERO, [], func() -> bool: return hardcore.is_dead())
	var stored: Dictionary = store.load_run(hardcore.run.run_id)
	check(hardcore.is_dead() and stored.state.status == "dead", "Permadeath death is committed immediately")

func _test_save_isolation() -> void:
	var session := _start(91)
	if session == null: return
	var controller := _controller(session)
	_run(controller, 3000)
	for direction in CARDINAL:
		if _free(session, session.position + direction):
			controller.step_until = 0
			controller.update(FRAME, direction)
			break
	check(session.save(), "Save a real-time Run")
	var resumed := Session.new(store)
	check(resumed.resume(session.run.run_id) and resumed.realtime and resumed.position == session.position and int(resumed.run.state.turn) == int(session.run.state.turn), "Resume keeps the real-time model, position and world time")
	var legacy := Session.new(store)
	check(legacy.start_new(world.world_id, 92, "forest") and not legacy.realtime and not legacy.run.spawn.has("time_model"), "Default Runs stay turn-based (Run 01 behaviour)")
	var turn := int(legacy.run.state.turn)
	check(legacy.wait_turn() and int(legacy.run.state.turn) == turn + 1, "Turn model unchanged: one action = one turn")
	var foreign: Dictionary = store.create_run(world.world_id, 93, {"position": session.run.spawn.position, "biome": "forest", "time_model": "realtime-v7"})
	var before: Dictionary = store.load_run(foreign.run_id)
	var refused := Session.new(store)
	check(not refused.resume(foreign.run_id) and refused.last_error.contains("time model"), "A Run with an unknown time model is refused explicitly")
	check(Data.valid(before) and store.load_run(foreign.run_id).revision == before.revision, "Refusing it leaves the save untouched")
