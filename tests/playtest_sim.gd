extends SceneTree
## Milestone 02 balance probe: a simple bot plays real Runs through perform_action
## (explore, eat/drink, gather, fight, rest, learn, equip, search, interact with places)
## and reports survival/combat/progression metrics per seed. A diagnostic tool, not a
## pass/fail balance oracle: it fails only on engine errors or lost/duplicated state.
## Args after `--`: --seeds=a,b,c --turns=N --mode=normal|permadeath
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Packs = preload("res://src/content/starter_pack.gd")
const Data = preload("res://src/data/json_data.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
var failures := 0
var trace := false
var aggressive := false
var _log: FileAccess

func note(text: String) -> void:
	if not trace: return
	if _log == null: _log = FileAccess.open("res://.tools/bot-trace.log", FileAccess.WRITE)
	_log.store_line("%d %s" % [Time.get_ticks_msec(), text])
	_log.flush()

func _initialize() -> void:
	var seeds: Array = [101, 202, 303, 404, 505, 606]
	var turns := 1500
	var mode := "normal"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="): seeds = Array(arg.get_slice("=", 1).split(":")).map(func(s: String) -> int: return int(s)) # ':' (PowerShell splits commas)
		if arg.begins_with("--turns="): turns = int(arg.get_slice("=", 1))
		if arg.begins_with("--mode="): mode = arg.get_slice("=", 1)
		if arg == "--trace": trace = true
		if arg == "--aggressive": aggressive = true
	var store := Store.new()
	store.open(ProjectSettings.globalize_path("user://playtest-" + Data.uuid() + ".sqlite"))
	var world: Dictionary = store.create_world("Playtest", 1847, 1, Packs.blueprint(1847))
	for run_seed in seeds:
		var report := play(store, world, int(run_seed), turns, mode)
		print("RUN %s" % JSON.stringify(report))
	store.close()
	print("PLAYTEST SIM: %d seeds, %d failures" % [seeds.size(), failures])
	quit(0 if failures == 0 else 1)

func play(store: RefCounted, world: Dictionary, run_seed: int, turns: int, mode: String) -> Dictionary:
	var s := Session.new(store)
	note("start_new")
	if not s.start_new(world.world_id, run_seed, "any", mode):
		failures += 1
		return {"seed": run_seed, "error": s.last_error}
	var m := {"seed": run_seed, "talent": s.run.state.character.talents.map(func(t: Dictionary) -> String: return "%s %s" % [t.rank, t.content_id.get_slice("/", 1)]),
		"turns": 0, "died": false, "cause": "", "min_hp_pct": 100, "kills": {}, "level": 1, "places": 0, "resolved": 0,
		"ate": 0, "drank": 0, "rests": 0, "skills": 0, "skill_uses": 0, "equips": 0, "max_thirst": 0, "max_hunger": 0,
		"starving_turns": 0, "saves": 0, "max_save_ms": 0.0, "explored": 0, "stuck": 0, "hits_taken": 0, "damage_taken": 0}
	var waypoint := Vector2i.ZERO
	var last_hit := ""
	var guard := 0
	while int(s.run.state.turn) < turns and not s.is_dead() and guard < turns * 3:
		guard += 1
		var before := int(s.run.state.turn)
		var tick := Time.get_ticks_msec()
		var acted := step(s, m)
		if not acted:
			# Explore: walk toward a far waypoint, re-picked when reached or blocked.
			if waypoint == Vector2i.ZERO or s.position.distance_to(waypoint) < 4 or m.stuck > 6:
				var angle := float(Loot_number("wp/%d/%d" % [run_seed, before]) % 628) / 100.0
				waypoint = s.position + Vector2i(int(cos(angle) * 60), int(sin(angle) * 60))
				m.stuck = 0
			acted = walk_toward(s, waypoint)
			if not acted:
				m.stuck += 1
				s.wait_turn()
		note("turn %d acted=%s %d ms pos=%s" % [int(s.run.state.turn), acted, Time.get_ticks_msec() - tick, s.position])
		for event in s.last_events:
			if event.get("type") == "hit" and event.get("target") == "player":
				m.hits_taken += 1
				m.damage_taken += int(event.damage)
				last_hit = str(event.get("name", "?"))
			if event.get("type") == "creature_death":
				m.kills[event.name] = m.kills.get(event.name, 0) + 1
			if event.get("type") == "discovery": m.places += 1
			if event.get("type") == "location": m.resolved += 1
			if event.get("type") == "autosave": m.saves += 1
			if event.get("type") == "starvation":
				m.starving_turns += 1
				last_hit = "starvation"
		var max_hp := int(s.combat_stats().max_hp)
		m.min_hp_pct = mini(m.min_hp_pct, int(s.stats().hp) * 100 / maxi(1, max_hp))
		m.max_thirst = maxi(m.max_thirst, int(s.stats().thirst))
		m.max_hunger = maxi(m.max_hunger, int(s.stats().hunger))
	m.turns = int(s.run.state.turn)
	m.died = s.is_dead()
	m.cause = last_hit if m.died else ""
	m.level = s.character_rules.level(s.run.state.character)
	m.explored = s.explored.size()
	m.attack = int(s.combat_stats().attack)
	m.defense = int(s.combat_stats().defense)
	m.max_hp = int(s.combat_stats().max_hp)
	m.items = s.run.state.inventory.size()
	# Persistence check after a long session: save, reload, compare.
	if not m.died or mode == "permadeath":
		var t0 := Time.get_ticks_usec()
		var saved: bool = s.save()
		m.final_save_ms = (Time.get_ticks_usec() - t0) / 1000.0
		var again := Session.new(store)
		var ok: bool = saved and (again.resume(s.run.run_id) if not m.died else true)
		if not m.died and (not ok or not Acceptance.same(again.run.state, s.run.state)):
			failures += 1
			m.persist_error = s.last_error + again.last_error
	return m

func step(s: RefCounted, m: Dictionary) -> bool:
	var max_hp := int(s.combat_stats().max_hp)
	var hp := int(s.stats().hp)
	note("needs")
	# 1. Needs first: drink/eat when warned, heal with herbs when hurt.
	if int(s.stats().thirst) >= 500 and s.run.state.inventory.has("core:fresh_water") and s.use_item("core:fresh_water"):
		m.drank += 1
		return true
	if int(s.stats().hunger) >= 500:
		for food in ["core:berries", "core:raw_meat"]:
			if s.run.state.inventory.has(food) and s.use_item(food):
				m.ate += 1
				return true
	if hp * 100 < max_hp * 40 and s.run.state.inventory.has("core:herb") and s.use_item("core:herb"):
		return true
	note("fight")
	# 2. Fight adjacent aggressive creatures (skill first when possible).
	var targets: Array = s.roster.targets(s).filter(func(c: Dictionary) -> bool: return s.roster.aggressive(c))
	if not targets.is_empty():
		for entry in s.run.state.character.skills:
			var definition: Dictionary = s.skill_definition(entry.content_id, int(entry.version))
			if definition.get("payload", {}).get("type") == "active" and definition.payload.use.get("target", {}).get("kind") == "creature" and s.skills.use_check(s, definition).is_empty():
				if s.perform_action({"type": "skill", "skill_id": entry.content_id, "target_id": targets[0].instance_id}):
					m.skill_uses += 1
					return true
		return s.attack_target(targets[0].instance_id)
	# 2b. Aggressive policy: hunt hostile/neutral creatures within 8 tiles while healthy.
	if aggressive and hp * 100 >= max_hp * 50:
		var prey := Acceptance.nearest_creature(s, ["hostile", "neutral"])
		if not prey.is_empty() and absi(prey.position.x - s.position.x) + absi(prey.position.y - s.position.y) <= 8:
			if absi(prey.position.x - s.position.x) + absi(prey.position.y - s.position.y) == 1 and s.visible.has(prey.position):
				return s.attack_target(prey.instance_id)
			var toward := Acceptance.step_toward_creature(s, prey)
			if toward != Vector2i.ZERO and s.try_move(toward):
				return true
	note("rest")
	# 3. Rest when hurt and safe.
	if hp * 100 < max_hp * 60 and not s.threatened() and s.survival.worst_level(s.stats()) == 0:
		if s.rest():
			m.rests += 1
			return true
	note("learn")
	# 4. Learn books, equip better gear (free actions or one turn).
	for content_id in s.run.state.inventory.keys():
		if s.skill_catalog.books.has("%s@%d" % [content_id, int(s.run.state.inventory[content_id].version)]) and s.perform_action({"type": "learn", "content_id": content_id}):
			m.skills += 1
			return true
		var definition: Dictionary = s._definition(content_id, int(s.run.state.inventory[content_id].version))
		if definition.get("payload", {}).has("equipment"):
			for record in s.run.state.inventory[content_id].get("instances", []):
				var diff: Dictionary = s.compare_equipment(content_id, record.instance_id)
				var gain := 0
				for stat in diff.get("after", {}):
					gain += int(diff.after[stat]) - int(diff.get("before", {}).get(stat, 0))
				if gain > 0 and s.equip_item(content_id, record.instance_id):
					m.equips += 1
					return true
	note("places")
	# 5. Known places and objects in reach.
	var place: Dictionary = s.location_target()
	if not place.is_empty():
		var next: Dictionary = s.places.next_interaction(s, place)
		if s.places.unmet(s, s.locations.event(next.event).payload.get("conditions", [])).is_empty() and s.interact(place.instance_id):
			return true
	if not s.interaction_target().is_empty() and s.interact():
		return true
	note("seek")
	# 6. Seek water/food when warned; otherwise the nearest visible object or place.
	var wanted := ""
	if int(s.stats().thirst) >= 450: wanted = "core:fresh_spring"
	elif int(s.stats().hunger) >= 450: wanted = "core:berry_bush"
	var found := Acceptance.route_to_object(s, "gather", [], wanted) if not wanted.is_empty() else {}
	if found.is_empty() and wanted.is_empty():
		found = Acceptance.route_to_object(s, "open")
	if not found.is_empty() and found.route.size() <= 30 and not found.route.is_empty():
		return s.try_move(found.route[0] - s.position)
	if int(s.run.state.turn) % 30 == 0:
		return s.search()
	return false

func walk_toward(s: RefCounted, goal: Vector2i) -> bool:
	var best := Vector2i.ZERO
	var best_distance: int = s.position.distance_squared_to(goal)
	for direction in Spawn.DIRECTIONS:
		var next: Vector2i = s.position + direction
		if s.terrain.walkable(next) and s.roster.living_at(next).is_empty() and next.distance_squared_to(goal) < best_distance:
			best = direction
			best_distance = next.distance_squared_to(goal)
	return best != Vector2i.ZERO and s.try_move(best)

static func Loot_number(key: String) -> int:
	return (key.sha256_text().substr(0, 8).hex_to_int()) & 0x7fffffff
