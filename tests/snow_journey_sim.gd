extends "res://tests/playtest_sim.gd"
## Snow Mountain journey probe (diagnostic, like playtest_sim; not a pass/fail balance
## oracle). A bounded scripted explorer plays real Runs on disposable databases through
## the normal actions: walking the area route, searching on the game's own cue, visiting
## and reusing places it has discovered, gathering, crafting, learning, equipping,
## spending attribute points per build, sheltering from storms, heeding warning
## postures, saving and continuing. It uses only knowledge the character has earned:
## the land's area layout (the World Map) and places discovered by sight or search. It
## never reads hidden site positions; reachability of hidden content is the
## developer-only check in snow_region_suite.
## Env: JOURNEY_SEEDS="931:932", JOURNEY_TURNS=7000, JOURNEY_BUILDS="might:spirit".
const Atlas = preload("res://src/world/world_atlas.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const FOOD := ["snow:trough_char", "core:roast_meat", "snow:trail_stew", "snow:bark_ration", "core:berries", "core:raw_meat"]
const DWELL := 320
const ROUTE := ["Leefoot Basin", "Pitchpine Reach", "Mirror Trough", "Broken Relay", "Windcut Stair", "White Choir", "Crown Shelf"]
const NOTABLE := ["discovery", "location", "creature_death", "craft", "learn", "level_up", "creature_warning", "stirring", "creature_return", "knowledge"]

func _initialize() -> void:
	Session.auto_awaken = true
	var env := func(key: String, fallback: String) -> String: return OS.get_environment(key) if OS.get_environment(key) != "" else fallback
	var seeds: Array = Array(env.call("JOURNEY_SEEDS", "931:932").split(":")).map(func(v: String) -> int: return int(v))
	var builds: Array = Array(env.call("JOURNEY_BUILDS", "might:spirit").split(":"))
	var turns := int(env.call("JOURNEY_TURNS", "7000"))
	var store := Store.new()
	store.open(ProjectSettings.globalize_path("user://snow-journey/" + Data.uuid() + ".sqlite"))
	var world := Atlas.create_world(store, "Snow journey", 4242)
	var atlas := Atlas.new()
	atlas.open(store.content, world)
	var proposal: Dictionary = atlas.propose_layout_land("landpkg:snow_mountain/full_region")
	if proposal.is_empty() or not atlas.activate(proposal, {"by": "journey probe"}):
		print("ACTIVATE FAILED ", atlas.last_error)
		quit(1)
		return
	for i in seeds.size():
		print("JOURNEY ", JSON.stringify(journey(store, world, proposal.land, int(seeds[i]), str(builds[i % builds.size()]), turns)))
	store.close()
	print("SNOW JOURNEY: %d runs, %d failures" % [seeds.size(), failures])
	quit(0 if failures == 0 else 1)

func journey(store: RefCounted, world: Dictionary, plan: Dictionary, run_seed: int, build: String, turns: int) -> Dictionary:
	var s := Session.new(store)
	if not s.start_new(world.world_id, run_seed, plan.land_id, "normal", "turn"):
		failures += 1
		return {"seed": run_seed, "error": s.last_error}
	s.autosave_interval = 0
	var goals: Array = []
	for name in ROUTE:
		for region in plan.regions:
			if region.name == name: goals.append({"name": name, "tile": Vector2i(int(region.seed.x), int(region.seed.y))})
	var j := {"seed": run_seed, "build": build, "areas": {}, "reached": [], "levels": [], "crafted": {}, "learned": [], "skill_uses": 0, "uses": {}, "refusals": {},
		"warnings": 0, "avoided": 0, "storm_shelter": 0, "exposure_hp": 0, "cues": {}, "longest_quiet": 0, "quiet_area": "", "resumed": false,
		"died": false, "cause": "", "kills": {}, "discovered": 0, "searches": 0, "search_finds": 0}
	var m := {"kills": {}, "skills": 0, "skill_uses": 0, "equips": 0, "rests": 0, "ate": 0, "drank": 0, "stuck": 0}
	var warned := {}
	var known := {} # instance_id -> true: places this character discovered
	var goal := 0
	var dwell := 0
	var route: Array = []
	var target := Vector2i.ZERO
	var quiet := 0
	var last_hit := ""
	var level := 1
	var sense := {} # {"dir": Vector2i, "until": turn}: a heard cue the explorer follows
	var guard := 0
	while int(s.run.state.turn) < turns and not s.is_dead() and guard < turns * 3:
		guard += 1
		if not j.resumed and int(s.run.state.turn) >= turns / 2:
			# Save and continue in a fresh session, exactly as quitting and reloading would.
			var saved: Dictionary = s.run.state.duplicate(true)
			var again := Session.new(store)
			if not s.save() or not again.resume(s.run.run_id) or not Acceptance.same(saved, again.run.state):
				failures += 1
				j.persist_error = s.last_error + again.last_error
			s = again
			s.autosave_interval = 0
			route = []
			j.resumed = true
		var area := str(s.terrain.region_at(s.position).name)
		if not j.areas.has(area): j.areas[area] = {"turns": 0, "events": 0, "kills": 0, "places": 0, "xp": 0, "damage": 0, "first_turn": int(s.run.state.turn), "level_in": s.character_rules.level(s.run.state.character)}
		var acted := _spend_points(s, build) or _shelter(s, j) or _needs(s, m) or _craft(s, j) or _place(s, known, j, build) or _hunt(s, warned, j, m) or step(s, m)
		if not acted and not sense.is_empty() and int(s.run.state.turn) < int(sense.until):
			# Follow the cue a few steps, searching as a player would.
			if int(s.run.state.turn) % 3 == 0:
				j.searches += 1
				acted = s.search()
			else:
				acted = _follow(s, _path(s, s.position + sense.dir))
		if not acted and s.places.search_cue(s):
			j.searches += 1
			acted = s.search()
		if not acted and goal < goals.size():
			var here: Dictionary = goals[goal]
			if dwell == 0 and s.position.distance_to(here.tile) < 12:
				j.reached.append("%s@%d L%d" % [here.name, int(s.run.state.turn), s.character_rules.level(s.run.state.character)])
				dwell = DWELL
			if dwell > 0:
				dwell -= 1
				if dwell == 0:
					goal += 1
					route = []
				elif target == Vector2i.ZERO or s.position.distance_to(target) < 3 or route.is_empty():
					var k := int(s.run.state.turn) / 30
					target = here.tile + Vector2i(Loot_number("jx/%d/%d" % [run_seed, k]) % 49 - 24, Loot_number("jy/%d/%d" % [run_seed, k]) % 49 - 24)
					route = _path(s, target)
				if dwell % 45 == 0:
					j.searches += 1
					acted = s.search()
			else:
				if route.is_empty(): route = _path(s, here.tile)
			if not acted: acted = _follow(s, route)
		if not acted:
			s.wait_turn()
		# Bookkeeping from the turn's events.
		var a: Dictionary = j.areas[area]
		a.turns += 1
		var notable := false
		for event in s.last_events:
			var type := str(event.get("type", ""))
			if type in NOTABLE: notable = true
			match type:
				"hit":
					if event.get("target") == "player":
						a.damage += int(event.damage)
						last_hit = str(event.get("name", "?"))
				"creature_death":
					a.kills += 1
					j.kills[event.name] = int(j.kills.get(event.name, 0)) + 1
				"discovery":
					known[str(event.target)] = true
					j.discovered += 1
					a.places += 1
				"search":
					if not event.get("found", []).is_empty(): j.search_finds += 1
				"location":
					a.events += 1
				"xp":
					a.xp += int(event.get("amount", 0))
				"place_sense":
					var dirs := {"east": Vector2i(1, 0), "south-east": Vector2i(1, 1), "south": Vector2i(0, 1), "south-west": Vector2i(-1, 1), "west": Vector2i(-1, 0), "north-west": Vector2i(-1, -1), "north": Vector2i(0, -1), "north-east": Vector2i(1, -1)}
					sense = {"dir": dirs.get(str(event.direction), Vector2i.ZERO) * 3, "until": int(s.run.state.turn) + 24}
					j.cues["sense"] = int(j.cues.get("sense", 0)) + 1
				"creature_warning":
					warned[str(event.target)] = true
					j.warnings += 1
				"stirring", "creature_return":
					j.cues[type + ":" + str(event.get("state", ""))] = int(j.cues.get(type + ":" + str(event.get("state", "")), 0)) + 1
				"environment":
					if event.get("kind") == "exposure":
						j.exposure_hp += -int(event.amount)
						last_hit = "exposure"
				"starvation": last_hit = "starvation"
		quiet = 0 if notable else quiet + 1
		if quiet > j.longest_quiet:
			j.longest_quiet = quiet
			j.quiet_area = area
		var now := s.character_rules.level(s.run.state.character)
		if now != level:
			level = now
			j.levels.append("L%d@%d %s" % [now, int(s.run.state.turn), area])
	j.turns = int(s.run.state.turn)
	j.died = s.is_dead()
	j.cause = last_hit if j.died else ""
	j.died_in = str(s.terrain.region_at(s.position).name) if j.died else ""
	j.level = s.character_rules.level(s.run.state.character)
	j.stats = s.combat_stats()
	j.skill_uses = m.skill_uses
	j.learned = s.run.state.character.get("skills", []).map(func(r: Dictionary) -> String: return str(r.content_id).get_slice(":", 1))
	j.gear = s.run.state.character.get("equipment", {}).values().map(func(e: Variant) -> String: return str(e.get("content_id", "")) if e is Dictionary else str(e))
	return j

func _spend_points(s: RefCounted, build: String) -> bool:
	if s.character_rules.attribute_points(s.run.state.character).free < 1: return false
	var pick := "might" if build == "might" else "spirit"
	if int(s.run.state.character.get("attributes", {}).get(pick, 0)) % 3 == 2: pick = "vitality" # Every third point keeps the body alive.
	s.allocate_attribute(pick)
	return false # No turn.

func _shelter(s: RefCounted, j: Dictionary) -> bool:
	## Storm sense: when exposed and hurt, step to the nearest cover within 8 tiles.
	var status: Dictionary = s.environment.exposure(s)
	if not status.exposed or int(s.stats().hp) * 100 >= int(s.combat_stats().max_hp) * 70: return false
	var best := Vector2i.ZERO
	var best_d := 99
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var tile: Vector2i = s.position + Vector2i(dx, dy)
			if absi(dx) + absi(dy) >= best_d or not s.terrain.walkable(tile) or not s.roster.living_at(tile).is_empty(): continue
			for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if Surfaces.NAME_OF.get(s.cache.tile_at(tile + offset), "") in ["pine", "rock", "tree", "basalt", "cliff", "timber"] or s.cache.tile_at(tile) == Surfaces.FLOOR:
					best = tile
					best_d = absi(dx) + absi(dy)
	if best == Vector2i.ZERO: return false
	if best == s.position:
		return s.rest() or s.wait_turn()
	var path := _path(s, best)
	if path.is_empty(): return false
	j.storm_shelter += 1
	return _follow(s, path)

func _needs(s: RefCounted, m: Dictionary) -> bool:
	if int(s.stats().thirst) >= 500:
		for id in s.run.state.inventory.keys():
			if "water" in str(id) and s.use_item(id):
				return true
	if int(s.stats().hunger) >= 500:
		for id in FOOD:
			if s.run.state.inventory.has(id) and s.use_item(id):
				return true
	if int(s.stats().hp) * 100 < int(s.combat_stats().max_hp) * 35:
		for id in ["snow:marrow_tonic", "snow:pine_salve", "core:herbal_poultice", "core:herb"]:
			if s.run.state.inventory.has(id) and s.use_item(id): return true
	if int(s.stats().thirst) >= 450 or int(s.stats().hunger) >= 450:
		var found := Acceptance.route_to_object(s, "gather", [], "snow:water_cache" if int(s.stats().thirst) >= int(s.stats().hunger) else "snow:ration_shrub")
		if not found.is_empty() and not found.route.is_empty() and found.route.size() <= 40:
			return s.try_move(found.route[0] - s.position)
	return false

func _craft(s: RefCounted, j: Dictionary) -> bool:
	if int(s.run.state.turn) % 20 != 0: return false
	for recipe in s.recipes():
		var out: Dictionary = recipe.payload.output
		var gear: bool = s._definition(out.content_id, int(out.version)).get("payload", {}).has("equipment")
		if gear and (s.run.state.inventory.has(out.content_id) or JSON.stringify(s.run.state.character.get("equipment", {})).contains(str(out.content_id))): continue # One of each piece of gear.
		if recipe.payload.inputs.all(func(i: Dictionary) -> bool: return int(s.run.state.inventory.get(i.content_id, {}).get("quantity", 0)) >= int(i.get("quantity", 1))):
			if s.perform_action({"type": "craft", "recipe_id": recipe.content_id}):
				j.crafted[recipe.name] = int(j.crafted.get(recipe.name, 0)) + 1
				return true
	return false

func _place(s: RefCounted, known: Dictionary, j: Dictionary, build: String) -> bool:
	## Visit a discovered place within 40 tiles that can be used now (its requirements met).
	var best: Dictionary = {}
	var best_d := 41
	for instance in s.locations.loaded():
		if not known.has(instance.instance_id) and not s.places.discovered(s, instance.instance_id): continue
		known[instance.instance_id] = true
		var interaction := _choice(s, instance, build)
		if interaction.is_empty(): continue
		var tile := Vector2i(int(instance.position.x), int(instance.position.y))
		var d := absi(tile.x - s.position.x) + absi(tile.y - s.position.y)
		if d < best_d:
			best = instance
			best_d = d
	if best.is_empty(): return false
	if best_d <= 1:
		var interaction := _choice(s, best, build)
		var used: bool = s.perform_action({"type": "interact", "instance_id": best.instance_id, "interaction": interaction.id})
		var key := "%s/%s" % [str(best.content_id).get_slice("/", 1), interaction.id]
		if used: j.uses[key] = int(j.uses.get(key, 0)) + 1
		else: j.refusals[s.last_error.left(70)] = int(j.refusals.get(s.last_error.left(70), 0)) + 1
		return used
	return _follow(s, _path(s, Vector2i(int(best.position.x), int(best.position.y)) + Vector2i(0, 1)))

func _choice(s: RefCounted, instance: Dictionary, build: String) -> Dictionary:
	## The interaction a player of this build would pick now: requirements and costs met;
	## among exclusive choices, the one matching the build.
	var options: Array = s.places.available(s, instance, "interact")
	options = options.filter(func(i: Dictionary) -> bool:
		var event: Dictionary = s.locations.event(i.event)
		if not s.places.unmet(s, event.payload.get("conditions", [])).is_empty(): return false
		if i.has("world_method") and i.world_method == "force" and int(s.combat_stats().attack) < int(s.locations.definition_for(instance).payload.world_properties.fracture_attack): return false
		return event.payload.get("cost", {}).get("items", []).all(func(c: Dictionary) -> bool: return int(s.run.state.inventory.get(c.content_id, {}).get("quantity", 0)) >= int(c.get("quantity", 1))))
	if options.is_empty(): return {}
	for option in options:
		if build == "spirit" and option.id in ["elemental", "heat", "wrapped", "answer"]: return option
		if build == "might" and option.id in ["martial", "force"]: return option
	return options[0]

func _hunt(s: RefCounted, warned: Dictionary, j: Dictionary, m: Dictionary) -> bool:
	## Hunt nearby creatures while healthy; heed warning postures until much stronger.
	if int(s.stats().hp) * 100 < int(s.combat_stats().max_hp) * 60: return false
	var prey := Acceptance.nearest_creature(s, ["hostile", "neutral", "passive"])
	if prey.is_empty() or absi(prey.position.x - s.position.x) + absi(prey.position.y - s.position.y) > 7: return false
	if warned.has(prey.instance_id) and s.character_rules.level(s.run.state.character) < 9:
		j.avoided += 1
		return false
	for entry in s.run.state.character.get("skills", []):
		# Learned techniques first (range permitting), like a player using the hotbar.
		var definition: Dictionary = s.skill_definition(entry.content_id, int(entry.version))
		if definition.get("payload", {}).get("type") == "active" and definition.payload.use.get("target", {}).get("kind") == "creature" and s.skills.use_check(s, definition).is_empty():
			if s.perform_action({"type": "skill", "skill_id": entry.content_id, "target_id": prey.instance_id}):
				m.skill_uses += 1
				return true
	if absi(prey.position.x - s.position.x) + absi(prey.position.y - s.position.y) == 1 and s.visible.has(prey.position):
		return s.attack_target(prey.instance_id)
	var toward := Acceptance.step_toward_creature(s, prey)
	return toward != Vector2i.ZERO and s.try_move(toward)

func _follow(s: RefCounted, route: Array) -> bool:
	while not route.is_empty() and route[0] == s.position: route.pop_front()
	if route.is_empty() or absi(route[0].x - s.position.x) + absi(route[0].y - s.position.y) != 1 or not s.roster.living_at(route[0]).is_empty():
		route.clear()
		return false
	var next: Vector2i = route.pop_front()
	return s.try_move(next - s.position)

func _path(s: RefCounted, goal: Vector2i) -> Array:
	## BFS over walkable ground toward the goal (bounded); up to 50 steps.
	var start: Vector2i = s.position
	var came := {start: start}
	var queue: Array = [start]
	var best := start
	var head := 0
	while head < queue.size() and head < 50000:
		var at: Vector2i = queue[head]
		head += 1
		if at.distance_squared_to(goal) < best.distance_squared_to(goal): best = at
		if at == goal: break
		for d in Spawn.DIRECTIONS:
			var next: Vector2i = at + d
			if came.has(next) or not s.terrain.walkable(next) or absi(next.x - start.x) + absi(next.y - start.y) > 150: continue
			came[next] = at
			queue.append(next)
	var path: Array = []
	var at := best
	while at != start:
		path.push_front(at)
		at = came[at]
	return path.slice(0, 50)
