extends SceneTree
## Milestone 05 Stage D: Snow Mountain native content and discovery chains, headless.
## Pack isolation (one World, ecology_only, site_only), native ecology per area, fixed
## chain sites, Carrier's Debt (fallen pine -> clasp -> locker: return or force) and The
## Bell That Remembers (cairn shard -> silent bell -> rime mantle), refusals without
## side effects, exclusivity, repeat protection, spoiler-safe discovery and save/load.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const TerrainV1 = preload("res://src/world/terrain_v1.gd")
const Surfaces = preload("res://src/world/surfaces.gd")
const Objects = preload("res://src/world/world_objects.gd")
const Creatures = preload("res://src/world/world_creatures.gd")
const Chunks = preload("res://src/world/chunk_cache.gd")
const Data = preload("res://src/data/json_data.gd")
const LAYOUT := "landpkg:snow_mountain/layout"
var checks := 0
var failures := 0
var store := Store.new()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)
	return ok

func _initialize() -> void:
	Session.auto_awaken = false
	check(store.open(ProjectSettings.globalize_path("user://snow-content-tests/" + Data.uuid() + ".sqlite")), "Open isolated test DB")
	var other := Atlas.create_world(store, "Plain realm", 777)
	var world := Atlas.create_world(store, "Snow realm", 4242)
	var atlas := Atlas.new()
	if not check(not world.is_empty() and not other.is_empty() and atlas.open(store.content, world), "Two disposable atlas Worlds"):
		return _finish()
	var proposal: Dictionary = atlas.propose_layout_land(LAYOUT)
	if not check(not proposal.is_empty() and atlas.activate(proposal, {"by": "content suite"}), "Chart Snow Mountain in one World: " + atlas.last_error):
		return _finish()
	var plan: Dictionary = atlas.lands[proposal.land.land_id]
	_isolation(world, other, atlas, plan)
	_ecology(world, atlas, plan)
	_sites(plan, atlas)
	_carriers_debt(world, plan)
	_force_branch(world, plan)
	_bell(world, plan)
	_finish()

func _finish() -> void:
	print("M05 SNOW CONTENT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

# --- Isolation and ecology -------------------------------------------------------------

func _isolation(world: Dictionary, other: Dictionary, atlas: RefCounted, plan: Dictionary) -> void:
	check(not store.content.load_definition(world.world_id, "snow:scree_wolf", 1).is_empty(), "The land's content pack is active in the charted World")
	check(store.content.load_definition(other.world_id, "snow:scree_wolf", 1).is_empty(), "Another World never receives Snow Mountain content")
	check(plan.content_packs == ["res://content/land_packages/snow_mountain/content_pack.json"] and int(plan.layout.version) == 2, "The stored plan pins layout v2 and its pack")
	var terrain: RefCounted = atlas.terrain()
	var objects := Objects.new()
	var creatures := Creatures.new()
	objects.configure(world, terrain, store.content, Chunks.new(terrain))
	creatures.configure(world, terrain, store.content)
	var leaked := 0
	var scanned := 0
	for other_plan in atlas.lands.values():
		if other_plan.has("geography"): continue
		var center := TerrainV1.chunk_of(Vector2i(int(other_plan.center.x), int(other_plan.center.y)))
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var chunk: Vector2i = center + Vector2i(dx * 2, dy * 2)
				scanned += 1
				for instance in objects.generate_chunk(chunk) + creatures.generate_chunk(chunk):
					if str(instance.content_id).begins_with("snow:"): leaked += 1
	check(scanned > 100 and leaked == 0, "ecology_only: no Snow Mountain resource or creature in %d chunks of the other lands" % scanned)

func _area_census(world: Dictionary, atlas: RefCounted, plan: Dictionary) -> Dictionary:
	## content_id counts per area over the whole land (objects and creature homes).
	var terrain: RefCounted = atlas.terrain()
	var objects := Objects.new()
	var creatures := Creatures.new()
	objects.configure(world, terrain, store.content, Chunks.new(terrain))
	creatures.configure(world, terrain, store.content)
	var census := {}
	var first := Vector2i(int(plan.slot.x), int(plan.slot.y)) * 16
	for cy in 16:
		for cx in 16:
			var chunk := first + Vector2i(cx, cy)
			for instance in objects.generate_chunk(chunk) + creatures.generate_chunk(chunk):
				var tile := Vector2i(int(instance.position.x), int(instance.position.y))
				var area: int = int(terrain.region_at(tile).index)
				if not census.has(area): census[area] = {}
				census[area][instance.content_id] = int(census[area].get(instance.content_id, 0)) + 1
	return census

func _ecology(world: Dictionary, atlas: RefCounted, plan: Dictionary) -> void:
	var census := _area_census(world, atlas, plan)
	for area in range(7): print("CENSUS %s: %s" % [plan.regions[area].name, str(census.get(area, {}))])
	var basin: Dictionary = census.get(0, {})
	check(int(basin.get("snow:ration_shrub", 0)) >= 20 and int(basin.get("snow:water_cache", 0)) >= 20 and int(basin.get("snow:rime_hare", 0)) >= 3, "Leefoot Basin: native rations, water caches and rime hares")
	check(not basin.has("snow:scree_wolf") and not basin.has("core:wolf"), "No wolves in the arrival basin")
	check(int(census.get(1, {}).get("snow:scree_wolf", 0)) >= 2 and int(census.get(1, {}).get("snow:resin_seam", 0)) >= 10, "Pitchpine Reach: scree wolves and resin seams")
	check(int(census.get(6, {}).get("snow:bellback_sentinel", 0)) >= 1 and range(6).all(func(a: int) -> bool: return not census.get(a, {}).has("snow:bellback_sentinel")), "Bellback sentinels guard only the Crown Shelf")
	var core_wolves := 0
	for area in census: core_wolves += int(census[area].get("core:wolf", 0))
	check(core_wolves == 0, "Native scree wolves replace the borrowed grey wolf")

func _sites(plan: Dictionary, atlas: RefCounted) -> void:
	var terrain: RefCounted = atlas.terrain()
	var expected := {"snow:place/lee_shelter": 0, "snow:place/relay_locker": 3, "snow:place/fallen_relay_pine": 1, "snow:place/bell_cairn": 5, "snow:place/summit_bell": 6}
	var ok: bool = plan.sites.size() == expected.size()
	for site in plan.sites:
		var tile := Vector2i(int(site.position.x), int(site.position.y))
		ok = ok and expected.has(site.content_id) and terrain.walkable(tile) and int(terrain.region_at(tile).index) == expected[site.content_id]
	check(ok, "Five fixed sites on walkable tiles of their design areas")
	var locker := _site(plan, "relay_locker")
	var shelter: Dictionary = plan.geography.shelters[1]
	check(Rect2i(int(shelter.rect.x), int(shelter.rect.y), int(shelter.rect.w), int(shelter.rect.h)).has_point(_tile(locker)) and terrain.tile_at(_tile(locker)) == Surfaces.FLOOR, "The carriers' locker stands inside the roofed relay outpost")

# --- Chains --------------------------------------------------------------------------

func _site(plan: Dictionary, id: String) -> Dictionary:
	for site in plan.sites:
		if str(site.instance_id).ends_with("/site/" + id): return site
	return {}

static func _tile(site: Dictionary) -> Vector2i:
	return Vector2i(int(site.position.x), int(site.position.y))

func _session(world: Dictionary, plan: Dictionary, run_seed: int) -> RefCounted:
	var session := Session.new(store)
	if not session.start_new(world.world_id, run_seed, plan.land_id, "normal", "turn"):
		printerr(session.last_error)
		return null
	session.autosave_interval = 0
	session.roster.creatures.clear()
	return session

func _go(session: RefCounted, site: Dictionary) -> void:
	## Stand next to a site (in sight) and let the place layer discover it.
	var tile := _tile(site)
	var spot := tile
	for offset in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		if session.terrain.walkable(tile + offset):
			spot = tile + offset
			break
	session.position = spot
	session.run.state.character.position = {"x": spot.x, "y": spot.y}
	session.cache.follow(spot)
	session.objects.follow(spot)
	session.locations.follow(spot, session.cache.chunks)
	session.roster.follow(spot, session.cache.chunks)
	session.roster.creatures.clear()
	session._reveal()
	session.places.tick(session)
	session.dirty = true

func _act(session: RefCounted, site: Dictionary, interaction: String) -> bool:
	return session.perform_action({"type": "interact", "instance_id": site.instance_id, "interaction": interaction})

func _equip(session: RefCounted, content_id: String) -> bool:
	var records: Array = session.run.state.inventory.get(content_id, {}).get("instances", [])
	return not records.is_empty() and session.perform_action({"type": "equip", "content_id": content_id, "instance_id": records[0].instance_id})

func _count(session: RefCounted, content_id: String) -> int:
	return int(session.run.state.inventory.get(content_id, {}).get("quantity", 0))

func _notes(session: RefCounted, sites: Array) -> Array:
	var ids: Array = sites.map(func(s: Dictionary) -> String: return s.instance_id)
	return session.places.notes(session).filter(func(n: Dictionary) -> bool: return n.target in ids)

func _resolved(session: RefCounted, site: Dictionary) -> Dictionary:
	return session.run.state.entity_mutations.get(site.instance_id, {}).get("resolved", {})

func _carriers_debt(world: Dictionary, plan: Dictionary) -> void:
	var session := _session(world, plan, 501)
	if not check(session != null, "Start a Run for Carrier's Debt"):
		return
	var pine := _site(plan, "fallen_relay_pine")
	var locker := _site(plan, "relay_locker")
	check(not session.places.discovered(session, pine.instance_id) and not session.exploration_leads().any(func(l: Dictionary) -> bool: return str(l.get("instance_id", "")) == pine.instance_id), "Spoiler-safe: the fallen pine is unknown before it is seen")
	check(not _act(session, pine, "search"), "Cannot interact with an undiscovered place: " + session.last_error)
	_go(session, locker)
	var before: Dictionary = session.run.state.inventory.duplicate(true)
	var turn := int(session.run.state.turn)
	check(session.places.discovered(session, locker.instance_id) and not _act(session, locker, "return") and session.last_error.contains("Relay clasp"), "Returning the clasp without it is refused: " + session.last_error)
	check(session.run.state.inventory == before and int(session.run.state.turn) == turn and _resolved(session, locker).is_empty(), "The refusal changes nothing (inventory, turn, place state)")
	check(_notes(session, [locker, pine]).is_empty(), "Journal: no note before anything is read (a refusal writes none)")
	check(_act(session, locker, "ledger") and _resolved(session, locker).has("ledger"), "Read the carrier's ledger: the clue points to the fallen pine")
	var ledger_text: String = store.content.load_definition(world.world_id, "snow:event/relay_ledger", 1).payload.message
	var noted := _notes(session, [locker, pine])
	check(noted.size() == 1 and noted[0].message == ledger_text and noted[0].place == "Carriers' locker" and noted[0].verb == "Read the carrier's ledger" and not noted[0].has("position"), "Journal note keeps the ledger's exact words, with no position")
	_go(session, pine)
	check(session.places.discovered(session, pine.instance_id) and _act(session, pine, "search") and _count(session, "snow:relay_clasp") == 1 and _count(session, "snow:resin") >= 2, "Search the fallen pine: relay clasp, resin and wood")
	check(not _act(session, pine, "search") and _count(session, "snow:relay_clasp") == 1, "The fallen pine pays once per Run")
	check(session.save(), "Save mid-chain: " + session.last_error)
	var resumed := Session.new(store)
	check(resumed.resume(session.run.run_id) and _count(resumed, "snow:relay_clasp") == 1 and _resolved(resumed, pine).has("search"), "Reload keeps the clasp and the resolved pine")
	resumed.autosave_interval = 0
	_go(resumed, pine)
	check(not _act(resumed, pine, "search"), "After reload the pine still refuses to pay again")
	_go(resumed, locker)
	var coins := _count(resumed, "core:coin")
	check(_act(resumed, locker, "return") and _count(resumed, "snow:relay_clasp") == 0 and _count(resumed, "snow:bark_ration") >= 4 and _count(resumed, "core:coin") == coins + 18, "Return the clasp: it is consumed, the locker's stores are yours")
	check(not _act(resumed, locker, "force") and resumed.places.state(resumed, resumed.locations.find(locker.instance_id)) in ["resolved", "unavailable"], "The exclusive choice is final: the locker cannot also be forced")
	check(resumed.save(), "Save the finished chain")
	var again := Session.new(store)
	check(again.resume(session.run.run_id) and _resolved(again, locker).has("return") and not _resolved(again, locker).has("force") and _count(again, "snow:relay_clasp") == 0, "Chain outcome persists across save/load")
	var order: Array = _notes(again, [locker, pine]).map(func(n: Dictionary) -> String: return n.interaction)
	check(order == ["return", "search", "ledger"], "Journal notes survive reload, newest first, never the forfeited choice: " + str(order))
	var fresh := _session(world, plan, 502)
	check(fresh != null and _resolved(fresh, locker).is_empty() and _resolved(fresh, pine).is_empty(), "Another Run starts with both chain sites unresolved")
	check(fresh != null and fresh.places.notes(fresh).is_empty(), "Another Run's journal has no notes from this one")

func _force_branch(world: Dictionary, plan: Dictionary) -> void:
	var session := _session(world, plan, 503)
	if session == null: return
	var locker := _site(plan, "relay_locker")
	_go(session, locker)
	var hp := int(session.stats().hp)
	check(_act(session, locker, "force") and int(session.stats().hp) == hp - 3 and _count(session, "snow:bark_ration") >= 1, "Forcing the locker: fewer stores and a cut hand (-3 HP)")
	check(not _act(session, locker, "return"), "Forcing forfeits the return: a clasp found later can be kept as gear")
	var pine := _site(plan, "fallen_relay_pine")
	_go(session, pine)
	check(_act(session, pine, "search") and _count(session, "snow:relay_clasp") == 1, "The clasp can still be found and kept")
	var defense := int(session.combat_stats().defense)
	check(_equip(session, "snow:relay_clasp") and session.run.state.character.equipment.accessory.content_id == "snow:relay_clasp" and int(session.combat_stats().defense) == defense + 1, "Keep and equip the relay clasp: +1 defense (derived stats): " + session.last_error)

func _bell(world: Dictionary, plan: Dictionary) -> void:
	var cairn := _site(plan, "bell_cairn")
	var bell := _site(plan, "summit_bell")
	var lucky: RefCounted = null
	var unlucky: RefCounted = null
	for run_seed in range(600, 640):
		var session := _session(world, plan, run_seed)
		if session == null: continue
		_go(session, cairn)
		if not _act(session, cairn, "dig"): continue
		if _count(session, "snow:bell_shard") == 1:
			if lucky == null: lucky = session
		elif unlucky == null:
			unlucky = session
		if lucky != null and unlucky != null: break
	check(lucky != null and unlucky != null, "The cairn shard is a Run-keyed chance: some Runs find it, others do not")
	if lucky == null or unlucky == null: return
	# The journal replays this Run's own roll: the found/not-found line matches the inventory.
	var found_note: Array = _notes(lucky, [cairn])
	var empty_note: Array = _notes(unlucky, [cairn])
	check(found_note.size() == 1 and found_note[0].message.contains("Her voice sleeps") and found_note[0].message.contains("curved shard") and not found_note[0].message.contains("Only frozen stones"), "Journal: the lucky dig's note names the shard it found")
	check(empty_note.size() == 1 and empty_note[0].message.contains("Only frozen stones") and not empty_note[0].message.contains("curved shard"), "Journal: the empty dig's note never mentions a shard")
	_go(lucky, cairn)
	check(not _act(lucky, cairn, "dig") and _count(lucky, "snow:bell_shard") == 1, "Digging again never rerolls")
	_go(lucky, bell)
	check(not _act(lucky, bell, "restore"), "The bell must be examined first: " + lucky.last_error)
	check(_act(lucky, bell, "inspect"), "Examine the silent bell")
	var bell_notes: Array = _notes(lucky, [bell])
	check(bell_notes.size() == 1 and bell_notes[0].interaction == "inspect" and not bell_notes[0].message.contains("mantle"), "Journal: examining the bell notes only what was seen, nothing of its restoration")
	check(lucky.save(), "Save before restoring")
	var resumed := Session.new(store)
	check(resumed.resume(lucky.run.run_id), "Reload with the shard in hand")
	resumed.autosave_interval = 0
	_go(resumed, bell)
	check(_act(resumed, bell, "restore") and _count(resumed, "snow:bell_shard") == 0 and _count(resumed, "snow:rime_mantle") == 1, "Restore the bell: shard set, rime mantle received")
	check(not _act(resumed, bell, "restore") and _count(resumed, "snow:rime_mantle") == 1, "The bell is a terminal state: no second mantle")
	var max_hp := int(resumed.combat_stats().max_hp)
	check(_equip(resumed, "snow:rime_mantle") and int(resumed.combat_stats().max_hp) > max_hp, "Equip the rime mantle: more max HP and defense: " + resumed.last_error)
	check(resumed.save(), "Save the restored bell")
	var again := Session.new(store)
	check(again.resume(lucky.run.run_id) and _resolved(again, bell).has("restore"), "Restoration persists after reload")
	# Combat route: a sentinel's loot table can also hold a shard (optional, dangerous).
	var sentinel: Dictionary = store.content.load_definition(world.world_id, "snow:bellback_sentinel", 1)
	check(sentinel.payload.disposition == "hostile" and sentinel.payload.loot.entries.any(func(e: Dictionary) -> bool: return e.content_id == "snow:bell_shard"), "The bellback sentinel may carry a shard: a second, dangerous route")
	var plain := _session(world, plan, 641)
	if plain != null:
		_go(plain, bell)
		check(_act(plain, bell, "inspect") and not _act(plain, bell, "restore") and plain.last_error.contains("Bell shard") and _count(plain, "snow:rime_mantle") == 0, "Without a shard the bell stays silent (no reward, nothing consumed)")
