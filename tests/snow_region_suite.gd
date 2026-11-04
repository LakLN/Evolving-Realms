extends SceneTree
## Full-region content: legacy isolation, real encounter/loot/craft/learning paths,
## authored homes, ranged counterplay and persistence. Disposable databases only.
const Store = preload("res://src/data/game_store.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Data = preload("res://src/data/json_data.gd")
const Survey = preload("res://src/world/land_survey.gd")
const Creatures = preload("res://src/world/world_creatures.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const Inventory = preload("res://src/core/inventory.gd")
const Same = preload("res://src/acceptance/standalone_check.gd")
const RT = preload("res://src/run/realtime_creatures.gd")
var store := Store.new()
var checks := 0
var failures := 0
var census := {}

func check(ok: bool, label: String) -> bool:
	checks += 1
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1
	return ok

func _initialize() -> void:
	Session.auto_awaken = false
	if not check(store.open(ProjectSettings.globalize_path("user://snow-region-tests/" + Data.uuid() + ".sqlite")), "Open disposable production database"): return _finish()
	var world := Atlas.create_world(store, "Full Snow", 4242)
	var atlas := Atlas.new()
	atlas.open(store.content, world)
	var proposal: Dictionary = atlas.propose_layout_land("landpkg:snow_mountain/full_region")
	if not check(not proposal.is_empty() and atlas.activate(proposal, {"by": "disposable region suite"}), "Validate and activate full-region plan: " + atlas.last_error): return _finish()
	var plan: Dictionary = proposal.land
	check(int(plan.atlas_version) == 2 and int(plan.layout.version) == 6 and int(plan.terrain_version) == 2, "New plan version; frozen terrain algorithm unchanged")
	var future: Dictionary = plan.duplicate(true)
	future.atlas_version = 99
	check(not Atlas.supported_plan(future), "Unknown future plan version refused")
	var s := Session.new(store)
	if not check(s.start_new(world.world_id, 919, plan.land_id, "normal", "turn"), "Start a certified full-region Run: " + s.last_error): return _finish()
	s.autosave_interval = 0
	_streaming(s)
	_census(s, plan)
	_legacy()
	_sites(s, plan)
	_rewards(s, plan)
	_activities(world.world_id, plan)
	_ranged(s, plan)
	var saved: Dictionary = s.run.state.duplicate(true)
	check(s.save(), "Save encounter cooldowns, loot and exploration choices")
	var resumed := Session.new(store)
	check(resumed.resume(s.run.run_id) and Same.same(saved.inventory, resumed.run.state.inventory) and Same.same(saved.entity_mutations, resumed.run.state.entity_mutations), "Reload preserves exact loot, creature state and site receipts")
	var fresh := Session.new(store)
	check(fresh.start_new(world.world_id, 920, plan.land_id, "normal", "turn") and not fresh.run.state.inventory.has("snow:book/glass_lance") and not fresh.run.state.character.get("skills", []).any(func(r: Dictionary) -> bool: return str(r.content_id).begins_with("snow:")), "New Run inherits no rewards or learned techniques")
	_finish()

func _finish() -> void:
	print("SNOW REGION: %d checks, %d failures" % [checks, failures])
	store.close()
	quit(1 if failures else 0)

func _streaming(s: RefCounted) -> void:
	# Idle prefetch is pure: same placements as load time, no writes, no region pins.
	var before: Dictionary = s.run.state.duplicate(true)
	var ring: Vector2i = s.cache.center + Vector2i(2, 0)
	var known: int = s.locations.ledger.established(ring)
	for i in 80: s.prefetch_step()
	check(Same.same(before, s.run.state) and s.locations.ledger.established(ring) == known and known == -1, "Idle prefetch writes no Run state and establishes no region")
	check(s.objects._ahead.has(ring) and Same.same(s.objects._ahead[ring], s.objects.generate_chunk(ring)), "Prefetched objects equal load-time generation")

func _census(s: RefCounted, plan: Dictionary) -> void:
	var start := Vector2i(int(plan.slot.x), int(plan.slot.y)) * 16
	var by_area := {}
	var duplicates := false
	var authored := 0
	var stray_slingers := 0
	for y in 16:
		for x in 16:
			var chunk := start + Vector2i(x, y)
			var homes: Array = s.roster.layer.native_chunk(chunk)
			var occupied := {}
			for home in homes:
				var tile := Vector2i(int(home.position.x), int(home.position.y))
				duplicates = duplicates or occupied.has(tile)
				occupied[tile] = true
				var area := int(s.terrain.region_at(tile).index)
				if not by_area.has(area): by_area[area] = {}
				by_area[area][home.content_id] = int(by_area[area].get(home.content_id, 0)) + 1
				census[home.content_id] = int(census.get(home.content_id, 0)) + 1
				if str(home.instance_id).begins_with("crt:atlas/"): authored += 1
				elif home.content_id == "snow:relay_slinger" and plan.regions[area].name == "Broken Relay": stray_slingers += 1
			if x % 5 == 0 and y % 5 == 0:
				check(Same.same(s.roster.layer.generate_chunk(chunk), _old_predicate_order(s.roster.layer, chunk)), "Optimized home generation matches old predicate order " + str(chunk))
	for area in by_area: print("REGION CENSUS ", plan.regions[area].name, ": ", by_area[area])
	check(not duplicates and authored >= 20, "Authored encounter groups coexist without replacing v1 homes: %d" % authored)
	check(stray_slingers == 0, "Broken Relay shooters hold authored camps instead of the whole area")
	check(census.size() >= 13, "Reference seed contains diverse roles, not only definitions: " + str(census))
	check(not by_area[0].keys().any(func(id: String) -> bool: return s._definition(id, 1).payload.disposition == "hostile"), "Arrival basin remains free of hostile homes")

func _old_predicate_order(layer: RefCounted, chunk: Vector2i) -> Array:
	# Baseline before the hash-first optimization. Complete dictionaries must match.
	var bytes: PackedByteArray = layer.terrain.generate_chunk(chunk)
	var result: Array = []
	for y in 32:
		for x in 32:
			var ground: int = bytes[y * 32 + x]
			var habitat: String = Surfaces.HABITAT_OF.get(ground, "")
			if habitat.is_empty(): continue
			var point := chunk * 32 + Vector2i(x, y)
			for rule in layer.rules:
				var spawn: Dictionary = rule.definition.payload.spawn
				if not ((habitat in spawn.biomes and not rule.ecology_only) or layer.terrain.ecology_hosts(ground, point, rule.definition.content_id)) or layer.terrain.coordinate_hash(point.x, point.y, rule.stream) % 10000 >= int(spawn.per_10000): continue
				result.append({"instance_id": "crt:v1/%d/%d/%d_%d" % [chunk.x, chunk.y, x, y], "content_id": rule.definition.content_id, "version": 1, "position": {"x": point.x, "y": point.y}, "origin": "procedural", "metadata": {"creature_generation_version": 1}})
				break
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.instance_id < b.instance_id)
	return result.slice(0, 6)

func _legacy() -> void:
	var world := Atlas.create_world(store, "Legacy Snow", 4242)
	var atlas := Atlas.new()
	atlas.open(store.content, world)
	var proposal: Dictionary = atlas.propose_layout_land("landpkg:snow_mountain/layout")
	if not check(not proposal.is_empty() and atlas.activate(proposal, {"by": "legacy fixture"}), "Legacy v4 plan remains available"): return
	var plan: Dictionary = proposal.land
	var before: Dictionary = plan.duplicate(true)
	var layer := Creatures.new()
	layer.configure(world, atlas.terrain(), store.content)
	var chunk := Terrain.chunk_of(Vector2i(int(plan.center.x), int(plan.center.y)))
	var old: Array = layer.native_chunk(chunk)
	check(preload("res://src/content/starter_pack.gd").new().install(store.content, world.world_id, "res://content/land_packages/snow_mountain/fauna_pack.json"), "Install additional definitions in legacy fixture without rewriting its plan")
	layer.configure(world, atlas.terrain(), store.content)
	check(Same.same(old, layer.native_chunk(chunk)) and Same.same(before, atlas.lands[plan.land_id]) and not plan.has("creature_homes"), "Legacy plan and homes unchanged after new definitions")

func _sites(s: RefCounted, plan: Dictionary) -> void:
	var report: Dictionary = Survey.survey(s.terrain, plan, s.position)
	check(plan.sites.size() == 18 and plan.sites.all(func(site: Dictionary) -> bool: return report.reached_set.has(Vector2i(int(site.position.x), int(site.position.y)))), "Every original and new authored site is reachable from the certified start")
	check(plan.creature_homes.all(func(home: Dictionary) -> bool: return report.reached_set.has(Vector2i(int(home.position.x), int(home.position.y)))), "All authored encounter homes are on the reachable land")

func _site(plan: Dictionary, name: String) -> Dictionary:
	for site in plan.sites:
		if str(site.instance_id).ends_with("/" + name): return site
	return {}

func _go(s: RefCounted, site: Dictionary) -> void:
	var tile := Vector2i(int(site.position.x), int(site.position.y))
	for d in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT]:
		if s.terrain.walkable(tile + d):
			tile += d
			break
	s.position = tile
	s.run.state.character.position = {"x": tile.x, "y": tile.y}
	s.cache.follow(tile)
	s.objects.follow(tile)
	s.locations.follow(tile, s.cache.chunks)
	s.roster.follow(tile, s.cache.chunks)
	s.roster.creatures.clear() # Interaction fixture; combat has its own live actors.
	s._reveal()
	s.places.tick(s)

func _act(s: RefCounted, site: Dictionary, action: String) -> bool:
	return s.perform_action({"type": "interact", "instance_id": site.instance_id, "interaction": action})

func _award(s: RefCounted, drops: Array, key: String) -> void:
	var award := Inventory.new().award(store.content, s.world.world_id, s.run.state.inventory, drops, key)
	if check(not award.is_empty(), "Controlled fixture award: " + key): s.run.state.inventory = award.inventory

func _rewards(s: RefCounted, plan: Dictionary) -> void:
	var satchel := _site(plan, "field_satchel")
	_go(s, satchel)
	check(_act(s, satchel, "elemental") and not _act(s, satchel, "martial"), "Field bundle choice pays once and excludes the other reward")
	check(s.perform_action({"type": "learn", "content_id": "core:book/ember"}), "Starter exploration reward teaches a usable elemental technique")
	var bowl := _site(plan, "glass_bowl")
	_go(s, bowl)
	_act(s, bowl, "inspect")
	var before: Dictionary = s.run.state.duplicate(true)
	check(not _act(s, bowl, "offer") and Same.same(before, s.run.state), "Unrevealed offering refuses without state change")
	_award(s, [{"content_id": "snow:stormglass", "version": 1, "quantity": 1}], "glass experiment")
	check(_act(s, bowl, "offer") and not _act(s, bowl, "offer"), "A reachable conditional discovery consumes glass and pays only once")
	check(s.perform_action({"type": "learn", "content_id": "snow:book/glass_lance"}), "Conditional reward teaches Glass Lance")
	for pair in [["old_kiln", "read", "kiln_breath"], ["wind_loom", "read", "rime_stitch"]]:
		var site := _site(plan, pair[0])
		_go(s, site)
		check(_act(s, site, pair[1]) and s.perform_action({"type": "learn", "content_id": "snow:book/" + pair[2]}), "Explore and learn " + pair[2])
	for recipe in s.recipes():
		if not recipe.content_id in ["snow:recipe/tusk_glaive", "snow:recipe/glass_rod", "snow:recipe/rimeweave", "snow:recipe/kiln_maul", "snow:recipe/glass_charm", "snow:recipe/marrow_tonic"]: continue
		_award(s, recipe.payload.inputs, "materials/" + recipe.content_id)
		check(s.perform_action({"type": "craft", "recipe_id": recipe.content_id}), "Craft creature materials into " + recipe.name)
	var drift := _site(plan, "drift_cache")
	_go(s, drift)
	check(not s.places.discovered(s, drift.instance_id) and s.search() and _act(s, drift, "search") and not _act(s, drift, "search"), "Concealed variable reward requires search and never rerolls")

func _activities(world_id: String, plan: Dictionary) -> void:
	# Layout v6 sites: each rewards a different build or preparation, pays once.
	# A fresh level-1 Run so every precondition below is explicit.
	var s := Session.new(store)
	if not check(s.start_new(world_id, 921, plan.land_id, "normal", "turn"), "Fresh Run for regional activities: " + s.last_error): return
	s.autosave_interval = 0
	var box := _site(plan, "relay_strongbox")
	_go(s, box)
	var before: Dictionary = s.run.state.duplicate(true)
	check(int(s.effective_stats().stats.attack) < 9 and not _act(s, box, "force") and Same.same(before.inventory, s.run.state.inventory), "Strongbox: a weak arm cannot wrench it, nothing changes")
	check(_act(s, box, "latch") and not _act(s, box, "force") and not _act(s, box, "latch"), "Strongbox: the patient latch is one exclusive, once-only attempt")
	var nest := _site(plan, "ashmaw_nest")
	_go(s, nest)
	check(not s.run.state.inventory.has("snow:frost_linen") and not _act(s, nest, "wrapped"), "Ember hollow: the safe method stays hidden without frost linen")
	_award(s, [{"content_id": "snow:frost_linen", "version": 1, "quantity": 1}], "linen for the hollow")
	var hearts := int(s.run.state.inventory.get("snow:ember_heart", {}).get("quantity", 0))
	var linen := int(s.run.state.inventory.get("snow:frost_linen", {}).get("quantity", 0))
	check(_act(s, nest, "wrapped") and int(s.run.state.inventory["snow:ember_heart"].quantity) == hearts + 2 and int(s.run.state.inventory.get("snow:frost_linen", {}).get("quantity", 0)) == linen - 1 and not _act(s, nest, "grab"), "Ember hollow: frost linen trades for two ember hearts and excludes the burning grab")
	var ice := _site(plan, "singing_ice")
	_go(s, ice)
	check(not s.places.discovered(s, ice.instance_id) and s.search() and s.places.discovered(s, ice.instance_id), "Singing ice is found only by searching")
	check(_act(s, ice, "listen"), "Singing ice: listening pays a hint and stormglass")
	check(not _act(s, ice, "answer"), "Singing ice: no answer without the right technique")
	_award(s, [{"content_id": "snow:book/rime_stitch", "version": 1, "quantity": 1}], "rime stitch manual")
	check(s.perform_action({"type": "learn", "content_id": "snow:book/rime_stitch"}) and _act(s, ice, "answer") and s.run.state.inventory.has("snow:ancient_marrow"), "Singing ice: a technique learned elsewhere answers it for ancient marrow")
	var den := _site(plan, "prowler_den")
	_go(s, den)
	check(_act(s, den, "search"), "Prowler den: anyone can loot the lair")
	before = s.run.state.duplicate(true)
	check(not _act(s, den, "trail") and Same.same(before.inventory, s.run.state.inventory), "Prowler den: the kill trail needs a tracker's talent or perception")
	var cairn := _site(plan, "rune_cairn")
	_go(s, cairn)
	check(not _act(s, cairn, "read"), "Toll cairn: a novice cannot read the runes")
	while int(s.character_rules.level(s.run.state.character)) < 4: s.gain_xp(50)
	check(_act(s, cairn, "read") and s.run.state.inventory.has("snow:marrow_tonic"), "Toll cairn: an experienced traveller reads it and finds the tonic")
	check(not _act(s, cairn, "tribute"), "Toll cairn: the toll needs ivory from hunting")
	_award(s, [{"content_id": "snow:ivory_tusk", "version": 1, "quantity": 2}], "ivory toll")
	check(_act(s, cairn, "tribute") and s.run.state.inventory.has("snow:rime_mantle") and not s.run.state.inventory.has("snow:ivory_tusk"), "Toll cairn: two tusks buy the frost mantle")

func _ranged(s: RefCounted, plan: Dictionary) -> void:
	# A real authored slinger, on open terrain near its home; no synthetic species.
	var home: Dictionary = plan.creature_homes.filter(func(h: Dictionary) -> bool: return h.content_id == "snow:relay_slinger")[0]
	var base := Vector2i(int(home.position.x), int(home.position.y))
	var origin := base
	var found := false
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var tile := base + Vector2i(dx, dy)
			if range(5).all(func(i: int) -> bool: return s.terrain.walkable(tile + Vector2i.RIGHT * i)):
				origin = tile
				found = true
				break
		if found: break
	if not check(found, "Open lane for the real slinger"): return
	_go(s, {"position": {"x": origin.x, "y": origin.y}})
	s.position = origin
	s.run.state.character.position = {"x": origin.x, "y": origin.y}
	s._reveal()
	var foe: Dictionary = s.roster._runtime(home)
	foe.position = origin + Vector2i.RIGHT * 3
	foe.home = foe.position
	s.roster.creatures[foe.instance_id] = foe
	var decision: Dictionary = s.roster.decide(s, foe, "test/shot")
	check(decision.type == "ranged", "Slinger aims from range rather than using melee chase")
	var rt := RT.new()
	var rules: Dictionary = preload("res://src/run/realtime_controller.gd").load_rules()
	rt.configure(rules.creatures)
	rt.update(s, 0)
	rt.timers[foe.instance_id].next_ms = 0
	var events := rt.update(s, 1)
	check(events.any(func(e: Dictionary) -> bool: return e.type == "telegraph" and e.get("ranged", false)), "Ranged shot telegraphs before damage")
	var hp := int(s.stats().hp)
	s.position += Vector2i.RIGHT
	s.run.state.character.position = {"x": s.position.x, "y": s.position.y}
	events = rt.update(s, int(rules.creatures.windup_ms) + 2)
	check(int(s.stats().hp) == hp and events.any(func(e: Dictionary) -> bool: return e.type == "dodge"), "Moving away from the aimed tile avoids the shot")
	check(int(foe.ranged_ready) > int(s.run.state.turn) and not s.roster.begin_ranged(s, foe), "Shot cooldown blocks repeated launch and is saved")
	s.run.state.turn = int(foe.ranged_ready)
	s.position = origin
	s.run.state.character.position = {"x": origin.x, "y": origin.y}
	rt.configure(rules.creatures)
	rt.update(s, 0)
	rt.timers[foe.instance_id].next_ms = 0
	rt.update(s, 1)
	rt.update(s, int(rules.creatures.windup_ms) + 2)
	check(int(s.stats().hp) < hp, "Standing on the aimed tile takes real ranged damage")
	# Turn model: the same trait aims on one turn and releases on the shooter's next.
	var place := func(tile: Vector2i) -> void:
		s.position = tile
		s.run.state.character.position = {"x": tile.x, "y": tile.y}
	foe.position = origin + Vector2i.RIGHT * 3
	place.call(origin)
	s.run.state.turn = int(foe.ranged_ready)
	hp = int(s.stats().hp)
	events = s.roster.take_turn(s)
	check(events.any(func(e: Dictionary) -> bool: return e.type == "telegraph" and e.ranged) and foe.has("aim") and int(s.stats().hp) == hp, "Turn model: shooter marks the player's tile before any damage")
	check(s.run.state.entity_mutations[foe.instance_id].has("aim"), "Turn model: a pending aim is saved, so reloading cannot cancel it")
	place.call(origin + Vector2i.RIGHT)
	s.run.state.turn += 1
	events = s.roster.take_turn(s)
	check(int(s.stats().hp) == hp and events.any(func(e: Dictionary) -> bool: return e.type == "dodge") and not foe.has("aim"), "Turn model: stepping off the aimed tile dodges the shot")
	place.call(origin)
	s.run.state.turn = int(foe.ranged_ready)
	s.roster.take_turn(s)
	foe.stunned_until = int(s.run.state.turn) + 2
	s.run.state.turn += 1
	s.roster.take_turn(s)
	check(not foe.has("aim") and int(s.stats().hp) == hp, "Turn model: binding a shooter spoils its aimed shot")
	foe.stunned_until = 0
	s.run.state.turn = int(foe.ranged_ready)
	s.roster.take_turn(s)
	s.run.state.turn += 1
	s.roster.take_turn(s)
	check(int(s.stats().hp) < hp, "Turn model: staying on the aimed tile is hit")
	# Three learned regional techniques exercise the same creature/element pipeline.
	foe.hp = foe.max_hp
	s.stats().hp = s.combat_stats().max_hp
	s.run.state.character.resources.energy.value = s.skills.resource_max(s, "energy")
	check(s.perform_action({"type": "skill", "skill_id": "snow:skill/glass_lance", "target_id": foe.instance_id}) and int(foe.stunned_until) > int(s.run.state.turn), "Exploration-learned Glass Lance damages and interrupts an actual enemy")
