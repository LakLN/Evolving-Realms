extends "res://tests/long_thaw_n4_suite.gd"
const Residency = preload("res://src/run/resident_ecology.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const Traits = preload("res://src/core/creature_traits.gd")
const Inventory = preload("res://src/core/inventory.gd")
var plan: Dictionary
var sites: Dictionary

func _run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = ProjectSettings.globalize_path("user://long-thaw-n6/" + Data.uuid() + ".sqlite")
	root.add_child(app)
	for unused in 1200:
		if app.session != null: break
		await process_frame
	print("N6 DB: ", app.database_path)
	if not check(app.session != null, "N6 isolated opt-in starts: " + app._status.text): return _finish()
	var s: RefCounted = app.session
	s.autosave_interval = 0
	plan = s.terrain.land_at(s.position)
	for site in plan.sites: sites[str(site.instance_id).get_slice("/site/", 1)] = site
	check(int(plan.layout.version) == 4 and int(plan.atlas_version) == 5 and plan.regions.size() == 7, "N6 appends layout v4 / atlas v5 without extra areas")
	if "--visual-only" in OS.get_cmdline_user_args():
		await _visual(s)
		return _finish()
	var known := {}
	for home in plan.creature_homes:
		var definition: Dictionary = s.roster.layer.definition_for(home)
		if known.has(home.content_id): continue
		known[home.content_id] = true
		if not check(not definition.is_empty() and s.roster.layer.validate(definition), "Valid pinned species " + home.content_id): return _finish()
	check(known.size() == 4 and Traits.validate(Traits.rules()).is_empty(), "Four N2 species and valid shared traits")
	var reached := _reach(s, _tile(plan.starts[0]))
	var habitats_ok := true
	var coverage := {}
	var ids := {}
	for home in plan.creature_homes:
		var tile := _tile(home)
		habitats_ok = habitats_ok and reached.has(tile) and s.terrain.walkable(tile) and not s.terrain.variants.footprint.has(tile) and not ids.has(home.instance_id)
		var definition: Dictionary = s.roster.layer.definition_for(home)
		habitats_ok = habitats_ok and Surfaces.hosts(s.terrain,s.terrain.tile_at(tile),tile,home.content_id,definition.payload.movement.biomes)
		ids[home.instance_id] = true
		coverage[s.terrain.region_at(tile).region_id] = true
	check(habitats_ok and coverage.size() == 7, "All seven areas have unique, reachable homes on stable dry habitat")
	var ordered := []
	var chunks := {}
	for home in plan.creature_homes: chunks[TerrainV1.chunk_of(_tile(home))] = true
	for chunk in chunks: ordered.append_array(s.roster.layer.native_chunk(chunk))
	var reversed := []
	var order: Array = chunks.keys(); order.reverse()
	for chunk in order: reversed.append_array(s.roster.layer.native_chunk(chunk))
	ordered.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.instance_id < b.instance_id)
	reversed.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.instance_id < b.instance_id)
	check(Same.same(ordered, reversed), "Home identity is independent of chunk visit order")
	for region in plan.regions:
		_go(s, {"position":region.seed})
		s.roster.refresh(s)
	check(plan.creature_homes.filter(func(h:Dictionary)->bool:return not h.metadata.has("world_state")).all(func(h:Dictionary)->bool:return s.roster.creatures.has(h.instance_id)), "Baseline residents appear across all seven areas")
	var market := _home("market_sluiceback")
	var orchard := _home("orchard_sluiceback")
	check(not s.roster.creatures.has(market.instance_id) and not s.roster.creatures.has(orchard.instance_id), "Water-conditioned arrivals absent in baseline")
	_behaviors(s)
	for branch in ["open", "brace", "spill"]:
		var branch_run := Session.new(app.store)
		check(branch_run.start_new(s.world.world_id, 500 + checks, plan.land_id), "Independent water/ecology Run")
		branch_run.autosave_interval = 0
		_execute(branch_run, branch)
		_go(branch_run, market); branch_run.roster.refresh(branch_run)
		var market_expected: bool = branch in ["brace", "spill"]
		check(branch_run.roster.creatures.has(market.instance_id) == market_expected, "Market arrivals follow physical water state " + branch)
		_go(branch_run, orchard); branch_run.roster.refresh(branch_run)
		check(branch_run.roster.creatures.has(orchard.instance_id) == (branch in ["open", "spill"]), "Orchard arrivals follow physical water state " + branch)
		var near_water := true
		for h: Dictionary in [market,orchard]:
			if not branch_run.roster.creatures.has(h.instance_id): continue
			var water := false
			var home := _tile(h)
			for y in range(-6,7):
				for x in range(-6,7):
					if branch_run.terrain.tile_at(home+Vector2i(x,y)) == Surfaces.WATER: water=true
			near_water = near_water and water
		check(near_water, "Conditioned bank residents have actual water in their local reach")
		var safe := true
		for creature in branch_run.roster.creatures.values():
			if creature.dead: continue
			safe = safe and branch_run.terrain.walkable(creature.position) and not branch_run.terrain.variants.footprint.has(creature.position)
			for tile in branch_run.terrain.variants.footprint:
				if branch_run.roster._can_enter(branch_run, creature, tile): safe = false
		check(safe, "Residents cannot enter any future flooded footprint")
		check(branch_run.save(), "Save water choice and resident arrivals atomically")
		var resumed := Session.new(app.store)
		check(resumed.resume(branch_run.run.run_id) and Same.same(resumed.run.state.entity_mutations, branch_run.run.state.entity_mutations), "Load preserves resident positions, water receipts and encounters")
		var before: Dictionary = resumed.run.state.entity_mutations.duplicate(true)
		_go(resumed, sites.alder_oath_bridge); _go(resumed, orchard); resumed.roster.refresh(resumed)
		check(before.keys().all(func(id:String)->bool:return Same.same(before[id], resumed.run.state.entity_mutations[id])), "Area return never resets, relocates or duplicates established residents")
		check(s.terrain.variants.active.is_empty() and not s.roster.creatures.has(market.instance_id), "Water/ecology state never leaks to the first Run")
	_loot(s)
	var invalid: Dictionary = market.duplicate(true); invalid.metadata.world_state.version = 99
	check(not Residency.validate(invalid, s.terrain).is_empty(), "Unknown resident condition version is refused")
	_finish()

func _home(id: String) -> Dictionary:
	return plan.creature_homes.filter(func(h:Dictionary)->bool:return str(h.instance_id).ends_with("/"+id))[0]

func _behaviors(s: RefCounted) -> void:
	for pair in [["commons_herd_1","flee"],["alder_sluiceback_1","idle"],["orchard_fox_1","chase"],["weirs_maw","chase"]]:
		var h := _home(pair[0]); _go(s,h); s.roster.refresh(s)
		var c: Dictionary = s.roster.creatures[h.instance_id]
		# Pick a legal adjacent approach, then use the live roster's LOS and move rules.
		for d: Vector2i in [Vector2i.DOWN,Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:
			if s.terrain.walkable(c.position+d) and s.roster.living_at(c.position+d).is_empty():
				s.position=c.position+d; s.run.state.character.position={"x":s.position.x,"y":s.position.y}; break
		s._reveal()
		var decision: Dictionary = s.roster.decide(s,c,"n6-ai",0)
		if pair[1]=="flee":
			check(decision.state=="flee" and decision.type=="move" and s.roster._can_enter(s,c,decision.to) and s.roster.move_creature(s,c,decision.to), "Reedhorn really flees and moves on legal habitat")
		elif pair[1]=="idle":
			check(decision.type not in ["attack","charge"] and not s.roster.aggressive(c), "Sluiceback is neutral before provocation")
			s.stats().attack=1; s.refresh_stats()
			check(s.perform_action({"type":"attack","target_id":c.instance_id}) and c.provoked and s.roster.aggressive(c), "A real player hit provokes bank defense")
		else:
			if pair[0]=="orchard_fox_1":
				check(decision.type == "attack", "Healthy silt fox threatens a close visible target")
				c.hp=1
				check(s.roster.decide(s,c,"n6-wounded",0).state=="flee", "Wounded silt fox breaks off combat")
				c.hp=c.max_hp
			else:
				var hp: int=s.stats().hp
				s.roster.take_turn(s)
				check(int(s.stats().hp)<hp, "Bank-maw inflicts real close-range combat damage")
		# Wander is tested outside detection range, rather than while defending/biting.
		s.position=c.position+Vector2i(10,10)
		s.run.state.character.position={"x":s.position.x,"y":s.position.y}
		var legal := false
		for d: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			if s.roster._can_enter(s,c,c.position+d): legal=true
		var moved := false
		for i in 80:
			var wander: Dictionary = s.roster.decide(s,c,"n6-wander/%d"%i,0)
			if wander.type=="move" and s.roster._can_enter(s,c,wander.to) and s.roster.move_creature(s,c,wander.to): moved=true; break
		check(legal and moved, "Species wanders through legal habitat outside player detection")
	# Restore normal base attack after the deliberate nonlethal provocation fixture.
	s.stats().attack=5; s.refresh_stats()

func _execute(s: RefCounted, branch: String) -> void:
	for pair in [["floodline_stones","compare"],["gatehouse_tally","read"],["orchard_seep","inspect"],["underflow_rumble","listen"]]:
		_go(s,sites[pair[0]]); _act(s,sites[pair[0]],pair[1])
	var control: Dictionary=sites.weir_five_control
	_go(s,control); _act(s,control,"inspect"); _act(s,control,branch)
	var award := Inventory.new().award(app.store.content,s.world.world_id,s.run.state.inventory,[{"content_id":"core:wood","version":1,"quantity":8},{"content_id":"core:stone","version":1,"quantity":8}],"n6-test/"+s.run.run_id)
	s.run.state.inventory=award.inventory
	check(_act(s,control,"execute_"+branch), "N5 physical work remains operational")

func _loot(s: RefCounted) -> void:
	var h := _home("commons_herd_2"); _go(s,h); s.roster.refresh(s)
	var c: Dictionary=s.roster.creatures[h.instance_id]
	var hit: Dictionary = s.roster.attack(s,c.instance_id,{"range":3,"direct_damage":999})
	check(not hit.is_empty() and c.dead and not c.received.is_empty(), "Real killing blow grants pinned survival drops")
	var inventory: Dictionary=s.run.state.inventory.duplicate(true)
	check(s.roster.attack(s,c.instance_id).is_empty() and Same.same(inventory,s.run.state.inventory), "A corpse never pays twice")
	check(s.save(), "Save death and loot receipt")
	var resumed := Session.new(app.store)
	check(resumed.resume(s.run.run_id) and resumed.roster.creatures[c.instance_id].dead and Same.same(resumed.run.state.inventory,inventory), "Death and loot survive reload")
	_go(resumed,sites.alder_oath_bridge); _go(resumed,h); resumed.roster.refresh(resumed)
	check(resumed.roster.creatures[c.instance_id].dead and Same.same(resumed.run.state.inventory,inventory), "Area return never respawns a dead resident or repeats loot")

func _finish() -> void:
	print("LONG THAW N6: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _visual(s: RefCounted) -> void:
	_go(s,_home("alder_sluiceback_1")); s.roster.refresh(s)
	app.map_view.refresh(); app.map_view.paint_pending(1024); app._update_info()
	await process_frame; await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://art_exports/LongThaw_N6")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join("resident_tokens.png")) == OK,"Capture native diagnostic resident identity")
