extends SceneTree
## Bounded, real-scene reference-area review. No personal data, export or long tour.
const Atlas = preload("res://src/world/world_atlas.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Data = preload("res://src/data/json_data.gd")
const Inventory = preload("res://src/core/inventory.gd")
const Survey = preload("res://src/world/land_survey.gd")
const Spatial = preload("res://src/world/spatial_layout.gd")
const Same = preload("res://src/acceptance/standalone_check.gd")
var app: Control
var checks := 0
var failures := 0

func _initialize() -> void:
	Session.auto_awaken = false
	call_deferred("_run")

func check(ok: bool, text: String) -> bool:
	checks += 1
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
	return ok

func _run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = ProjectSettings.globalize_path("user://reference-area/"+Data.uuid()+".sqlite")
	root.add_child(app)
	await process_frame
	var old := _create("landpkg:snow_mountain/full_region", "Before")
	if old.is_empty(): return _finish()
	var old_plan: Dictionary = old.plan
	var anchor := Vector2i.ZERO
	for house in old_plan.geography.shelters:
		if str(house.shelter_id).ends_with("/relay_outpost"): anchor = Vector2i(int(house.rect.x)+int(house.rect.w)/2,int(house.rect.y)+int(house.rect.h)/2)
	var old_session: RefCounted = old.session
	app._enter_map(old_session)
	_go(old_session, anchor+Vector2i(-2,-3))
	await _capture("reference-before.png")
	var next := _create("landpkg:snow_mountain/reference", "After")
	if next.is_empty(): return _finish()
	var s: RefCounted = next.session
	var plan: Dictionary = next.plan
	var origin := Vector2i(int(plan.spatial.origin.x),int(plan.spatial.origin.y))
	check(int(plan.terrain_version)==3 and int(plan.atlas_version)==3 and int(plan.layout.version)==10, "Reference has explicit new terrain/plan/layout versions")
	check(old_plan.get("spatial",{}).is_empty() and old_session.terrain.elevation(anchor)==0, "Older world retains flat geometry")
	app._enter_map(s)
	_go(s, origin+Vector2i(15,22))
	s.roster.creatures.clear() # Controlled traversal fixture, no combat noise.
	check(s.terrain.elevation(s.position)==0 and s.try_move(Vector2i.UP) and s.terrain.elevation(s.position)==1, "Real action climbs the main stone stairs")
	check(s.try_move(Vector2i.DOWN) and s.terrain.elevation(s.position)==0, "Stairs descend normally")
	_go(s, origin+Vector2i(32,23))
	s.roster.creatures.clear()
	var before: Dictionary = s.run.state.duplicate(true)
	check(not s.try_move(Vector2i.UP) and Same.same(before,s.run.state), "One-way ledge cannot be climbed; refusal spends nothing")
	check(not s.line_clear(origin+Vector2i(32,23),origin+Vector2i(32,22)), "Height edge blocks targeting/line of sight")
	var invalid: Dictionary = plan.spatial.duplicate(true)
	invalid.version=999
	check(not Spatial.validate(invalid).is_empty(), "Unknown spatial versions are explicitly rejected")
	var foe := {"instance_id":"reference:edge", "position":origin+Vector2i(32,22), "home":origin+Vector2i(32,22), "dead":false, "definition":{"payload":{"movement":{"leash":20}}}}
	s.roster.creatures[foe.instance_id]=foe
	check(s.roster.attack(s,foe.instance_id).is_empty() and s.roster.creature_strike(s,foe,"reference").is_empty(), "Player and creature attacks both refuse the height edge")
	check(s.roster._can_enter(s,foe,origin+Vector2i(33,22)) and not s.roster._can_enter(s,foe,origin+Vector2i(32,23)), "Creature navigation uses authored routes and refuses the occupied landing")
	s.roster.creatures.clear()
	s.position=origin+Vector2i(22,17)
	foe.position=origin+Vector2i(32,23)
	check(not s.roster._can_enter(s,foe,origin+Vector2i(32,22)), "Creature cannot climb the one-way ledge")
	foe.position=origin+Vector2i(15,22)
	check(s.roster._can_enter(s,foe,origin+Vector2i(15,21)), "Creature can climb the same stairs as the player")
	_go(s, origin+Vector2i(32,22))
	s.roster.creatures.clear()
	check(s.try_move(Vector2i.DOWN) and s.terrain.elevation(s.position)==0, "Real action drops from the ledge to the lower return route")
	_go(s, origin+Vector2i(34,9))
	s.roster.creatures.clear()
	check(s.try_move(Vector2i.UP) and s.terrain.elevation(s.position)==2, "Second staircase reaches the higher lookout")
	check(not s.terrain.can_step(origin+Vector2i(33,23),origin+Vector2i(32,22)), "Diagonal movement cannot bypass a height boundary")
	check(s.terrain.can_step(origin+Vector2i(23,32),origin+Vector2i(24,32)) and not s.terrain.walkable(origin+Vector2i(25,28)), "Bridge crosses the blocking ravine")
	var report: Dictionary = Survey.survey(s.terrain,plan,Vector2i(int(plan.starts[0].position.x),int(plan.starts[0].position.y)))
	check(report.reached_set.has(origin+Vector2i(34,6)) and report.shelters.values().all(func(v: bool) -> bool:return v), "Height-aware navigation reaches lookout and every shelter door")
	var locker: Dictionary = plan.sites.filter(func(site: Dictionary) -> bool:return str(site.instance_id).ends_with("/relay_locker"))[0]
	check(report.reached_set.has(Vector2i(int(locker.position.x),int(locker.position.y))), "The existing relay discovery remains reachable")
	# Windcut Stair (v10 composed area): ledges above a ground-level road.
	var areas: Array = plan.get("spatial_areas", [])
	if check(areas.size() == 1 and str(areas[0].id) == "windcut", "Layout v10 adds the Windcut Stair composed area"):
		var wc := Vector2i(int(areas[0].origin.x), int(areas[0].origin.y))
		_go(s, wc+Vector2i(30,18))
		s.roster.creatures.clear()
		check(s.try_move(Vector2i.UP) and s.try_move(Vector2i.UP) and s.terrain.elevation(s.position)==1, "Real moves climb the carved stair to the north shelf")
		_go(s, wc+Vector2i(24,12))
		s.roster.creatures.clear()
		check(s.try_move(Vector2i.UP) and s.try_move(Vector2i.UP) and s.terrain.elevation(s.position)==2, "The eyrie stair reaches the high shelf")
		_go(s, wc+Vector2i(42,17))
		s.roster.creatures.clear()
		before = s.run.state.duplicate(true)
		check(not s.try_move(Vector2i.UP) and Same.same(before, s.run.state), "The shelf drop cannot be climbed; refusal spends nothing")
		_go(s, wc+Vector2i(42,16))
		s.roster.creatures.clear()
		check(s.try_move(Vector2i.DOWN) and s.terrain.elevation(s.position)==0, "Real action drops from the shelf to the road")
		var climber := {"instance_id":"windcut:edge", "position":wc+Vector2i(42,17), "home":wc+Vector2i(42,17), "dead":false, "definition":{"payload":{"movement":{"leash":20}}}}
		s.position = wc+Vector2i(30,22)
		check(not s.roster._can_enter(s, climber, wc+Vector2i(42,16)) and s.roster._can_enter(s, climber, wc+Vector2i(42,18)), "Creatures cannot climb the shelf drop either")
		var hits := {}
		for site in plan.sites:
			for name in ["/ashmaw_nest", "/rime_ledge", "/old_kiln"]:
				if str(site.instance_id).ends_with(name): hits[name] = report.reached_set.has(Vector2i(int(site.position.x), int(site.position.y)))
		check(hits.size() == 3 and hits.values().all(func(v: bool) -> bool: return v), "Windcut nest, rime ledge and kiln sites are reachable: %s" % str(hits))
		var drake: Array = plan.creature_homes.filter(func(h: Dictionary) -> bool: return str(h.instance_id).ends_with("/nest_drake"))
		check(drake.size() == 1 and s.terrain.elevation(Vector2i(int(drake[0].position.x), int(drake[0].position.y))) == 2, "The ashmaw keeps the high eyrie")
		_go(s, wc+Vector2i(46,20))
		s.roster.creatures.clear()
		await _capture("reference-windcut-defile.png")
		_go(s, wc+Vector2i(30,15))
		s.roster.creatures.clear()
		await _capture("reference-windcut-shelf.png")
	_go(s,origin+Vector2i(22,17))
	s.roster.creatures.clear() # Comparable view: nothing carried over from Windcut.
	await _capture("reference-after.png")
	_go(s,origin+Vector2i(26,32))
	await _capture("reference-bridge.png")
	_go(s,origin+Vector2i(35,8))
	await _capture("reference-lookout.png")
	_go(s,Vector2i(int(locker.position.x),int(locker.position.y)))
	s.roster.creatures.clear()
	check(s.perform_action({"type":"interact","instance_id":locker.instance_id,"interaction":"ledger"}), "Existing discovery interaction works in the rebuilt shelter")
	before=s.run.state.duplicate(true)
	check(not s.perform_action({"type":"interact","instance_id":locker.instance_id,"interaction":"ledger"}) and Same.same(before,s.run.state), "Repeating the resolved discovery spends nothing and duplicates nothing")
	# Slot 0 is the real tenth learned skill, with real cost, status and cooldown.
	_go(s,origin+Vector2i(22,14))
	s.roster.creatures.clear()
	s.gain_xp(200)
	var books: Array = []
	for name in ["power_strike","stone_throw","ember","venom","lacerate","renewal","purify","water_jet","frost","iron_guard"]: books.append({"content_id":"core:book/"+name,"version":1,"quantity":1})
	books.append({"content_id":"core:berries","version":1,"quantity":2})
	books.append({"content_id":"core:fresh_water","version":1,"quantity":2})
	var award := Inventory.new().award(app.store.content,s.world.world_id,s.run.state.inventory,books,"reference:control-fixture")
	if not check(not award.is_empty(),"Control fixture uses real books/items"):return _finish()
	s.run.state.inventory = award.inventory
	for book in books.slice(0,10): check(s.perform_action({"type":"learn","content_id":book.content_id}),"Learn control fixture "+book.content_id)
	app._update_info()
	check(app._hud._skill_slots.size()==10 and app._hud._skill_slots[9].key=="0" and not app._hp_label.text.contains("ATK"), "Ten slots, key 0, no permanent ATK/DEF clutter")
	var energy := int(s.run.state.character.resources.energy.value)
	await _key(KEY_0)
	check(int(s.run.state.character.skills[9].cooldown_until)>int(s.run.state.turn) and int(s.run.state.character.resources.energy.value)<energy, "Key 0 really activates Iron Guard, spends Energy and starts cooldown")
	var turn := int(s.run.state.turn)
	await _key(KEY_0)
	check(int(s.run.state.turn)==turn,"Key 0 respects cooldown")
	s.set_quick_item("q","core:berries")
	s.set_quick_item("z","core:fresh_water")
	s.stats().hunger=700
	s.stats().thirst=700
	await _key(KEY_Q)
	await _key(KEY_Z)
	check(int(s.stats().hunger)<700 and int(s.stats().thirst)<700,"Q/Z quick items still work")
	_go(s,origin+Vector2i(22,17))
	app._update_info()
	await _capture("reference-hud.png")
	check(s.save(),"Save the reference-area position, inventory and skills")
	var saved: Dictionary = s.run.state.duplicate(true)
	var reload := Session.new(app.store)
	check(reload.resume(s.run.run_id) and Same.same(saved.inventory,reload.run.state.inventory) and Same.same(saved.character.skills,reload.run.state.character.skills) and reload.position==s.position,"Reload preserves items, tenth skill, cooldown and position")
	_finish()

func _create(layout: String, label: String) -> Dictionary:
	var world := Atlas.create_world(app.store,label,4242)
	var atlas := Atlas.new()
	atlas.open(app.store.content,world)
	var proposal: Dictionary = atlas.propose_layout_land(layout)
	if not check(not proposal.is_empty() and atlas.activate(proposal,{"by":"bounded disposable reference review"}),label+" proposal/activation: "+atlas.last_error):return {}
	var s := Session.new(app.store)
	if not check(s.start_new(world.world_id,919,proposal.land.land_id,"normal","turn"),label+" Run starts: "+s.last_error):return {}
	s.run.state.turn=60 # Matched calm-weather phase for comparable native views.
	s.autosave_interval=0
	return {"session":s,"plan":proposal.land}

func _go(s: RefCounted,tile: Vector2i) -> void:
	s.position=tile
	s.run.state.character.position={"x":tile.x,"y":tile.y}
	s.cache.follow(tile)
	s.objects.follow(tile)
	s.locations.follow(tile,s.cache.chunks)
	s.roster.follow(tile,s.cache.chunks)
	s._reveal()
	s.places.tick(s)
	app.map_view.refresh()
	app.map_view.paint_pending(1024)
	app._update_info()

func _key(code: int) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	app._unhandled_key_input(event)
	await process_frame
	await process_frame

func _capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://.tools/"+name)==OK,"Capture "+name)

func _finish() -> void:
	print("REFERENCE AREA: %d checks, %d failures" %[checks,failures])
	quit(1 if failures else 0)
