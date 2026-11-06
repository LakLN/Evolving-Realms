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
const WorldRulesScript = preload("res://src/core/world_rules.gd")
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
	var narrative_only := "--narrative-only" in OS.get_cmdline_user_args()
	var proposal: Dictionary = atlas.propose_layout_land("landpkg:snow_mountain/reference" if narrative_only else LAYOUT)
	if not check(not proposal.is_empty() and atlas.activate(proposal, {"by": "content suite"}), "Chart Snow Mountain in one World: " + atlas.last_error):
		return _finish()
	var plan: Dictionary = atlas.lands[proposal.land.land_id]
	if narrative_only:
		_narrative_foundation(world)
		return _finish()
	if "--economy-only" in OS.get_cmdline_user_args():
		_regional_crafting(world, other, plan)
		return _finish()
	if "--rules-only" in OS.get_cmdline_user_args():
		_world_rules(world, plan)
		return _finish()
	_isolation(world, other, atlas, plan)
	_ecology(world, atlas, plan)
	_sites(plan, atlas)
	_carriers_debt(world, plan)
	_force_branch(world, plan)
	_bell(world, plan)
	_world_rules(world, plan)
	_regional_crafting(world, other, plan)
	_finish()

func _finish() -> void:
	print("M05 SNOW CONTENT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _narrative_foundation(world: Dictionary) -> void:
	var pairs := [
		["snow:event/lee_marks", "snow:place/lee_shelter"],
		["snow:event/hunters_camp", "snow:place/hunters_camp"],
		["snow:event/choir_notes", "snow:place/wind_loom"],
		["snow:event/camp_stash", "snow:place/bandit_stash"],
		["snow:event/runes_read", "snow:place/rune_cairn"],
	]
	var versions_ok := true
	var rewards_ok := true
	for pair in pairs:
		for content_id in pair:
			var v1_exists := not store.content.load_definition(world.world_id, content_id, 1).is_empty()
			var v2_exists := not store.content.load_definition(world.world_id, content_id, 2).is_empty()
			versions_ok = versions_ok and v1_exists and v2_exists
		var event_v1: Dictionary = store.content.load_definition(world.world_id, pair[0], 1)
		var event_v2: Dictionary = store.content.load_definition(world.world_id, pair[0], 2)
		rewards_ok = rewards_ok and event_v1.payload.get("outcomes", []) == event_v2.payload.get("outcomes", [])
		rewards_ok = rewards_ok and event_v1.payload.get("conditions", []) == event_v2.payload.get("conditions", [])
	check(versions_ok, "Narrative N1 keeps every v1 definition and installs five additive v2 event/location pairs")
	check(rewards_ok, "Narrative N1 changes no event reward or condition")
	var stash_v1: Dictionary = store.content.load_definition(world.world_id, "snow:place/bandit_stash", 1)
	var stash_v2: Dictionary = store.content.load_definition(world.world_id, "snow:place/bandit_stash", 2)
	var cairn_v2: Dictionary = store.content.load_definition(world.world_id, "snow:place/rune_cairn", 2)
	check(stash_v1.payload.interactions[0].repeat == stash_v2.payload.interactions[0].repeat and cairn_v2.payload.interactions[1].event.version == 1, "N1 preserves stash repeat cadence and the established cairn tribute branch")
	var relay_message: String = store.content.load_definition(world.world_id, "snow:event/camp_stash", 2).payload.message
	var choir_message: String = store.content.load_definition(world.world_id, "snow:event/choir_notes", 2).payload.message
	check(relay_message.contains("occupied now") and relay_message.contains("not restored as a settlement"), "Broken Relay text identifies a currently occupied old relay, not a town")
	check(choir_message.contains("does not say whether") and choir_message.contains("people, wind, ice, or something else"), "Wind-loom clue links motifs without deciding the cause of the voices")
	var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/land_layouts/snow_mountain_reference_v11.json"))
	var pinned := {}
	if layout is Dictionary:
		for site in layout.get("sites", []):
			pinned[str(site.get("content_id", ""))] = int(site.get("version", 1))
	var pins_ok := true
	for pair in pairs:
		pins_ok = pins_ok and int(pinned.get(pair[1], 0)) == 2
	check(pins_ok, "The v11 source layout pins all five Narrative N1 locations to version 2")

# --- Isolation and ecology -------------------------------------------------------------

func _isolation(world: Dictionary, other: Dictionary, atlas: RefCounted, plan: Dictionary) -> void:
	check(not store.content.load_definition(world.world_id, "snow:scree_wolf", 1).is_empty(), "The land's content pack is active in the charted World")
	check(store.content.load_definition(other.world_id, "snow:scree_wolf", 1).is_empty(), "Another World never receives Snow Mountain content")
	check(plan.content_packs == ["res://content/land_packages/snow_mountain/content_pack.json"] and int(plan.layout.version) == 4, "The stored plan pins layout v4 and its pack")
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
	var expected := {"snow:place/lee_shelter": 0, "snow:place/relay_locker": 3, "snow:place/fallen_relay_pine": 1, "snow:place/bell_cairn": 5, "snow:place/summit_bell": 6, "snow:place/icebound_provisions": 0, "snow:place/frozen_medicine": 1}
	var ok: bool = plan.sites.size() == expected.size()
	for site in plan.sites:
		var tile := Vector2i(int(site.position.x), int(site.position.y))
		ok = ok and expected.has(site.content_id) and terrain.walkable(tile) and int(terrain.region_at(tile).index) == expected[site.content_id]
	check(ok, "Seven fixed sites on walkable tiles of their design areas")
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
	check(cairn.content_id == "snow:place/bell_cairn" and int(cairn.version) == 2, "New plans pin the v2 bell cairn")
	# V1 package (decision D1): the shard is always under the cairn, but only for whoever digs there.
	var lucky: RefCounted = null
	var tried := 0
	var found := 0
	for run_seed in range(600, 606):
		var session := _session(world, plan, run_seed)
		if session == null: continue
		tried += 1
		_go(session, cairn)
		if _count(session, "snow:bell_shard") == 0 and _act(session, cairn, "dig") and _count(session, "snow:bell_shard") == 1: found += 1
		if lucky == null: lucky = session
	check(tried > 0 and found == tried, "Every Run that reaches and digs the cairn finds the shard (%d/%d)" % [found, tried])
	if lucky == null: return
	var found_note: Array = _notes(lucky, [cairn])
	check(found_note.size() == 1 and found_note[0].message.contains("Her voice sleeps") and found_note[0].message.contains("curved shard"), "Journal: the dig's note keeps the inscription and names the shard")
	# Plans that pin v1 keep the chance dig unchanged, and its saved records still replay.
	var v1: Dictionary = store.content.load_definition(world.world_id, "snow:event/cairn_dig", 1)
	check(v1.get("status") == "active" and v1.payload.outcomes.any(func(o: Dictionary) -> bool: return o.type == "chance"), "The v1 chance dig stays installed for plans that pin it")
	var old := _session(world, plan, 650)
	if old != null:
		old.run.state.entity_mutations[cairn.instance_id] = {"location": 1, "discovered": true, "discovered_turn": 1, "resolved": {"dig": {"turn": 2, "event": {"content_id": "snow:event/cairn_dig", "version": 1}, "received": []}}}
		var replay: Array = _notes(old, [cairn])
		check(replay.size() == 1 and replay[0].message.begins_with(v1.payload.message) and replay[0].message.contains("curved shard") != replay[0].message.contains("Only frozen stones"), "A v1 dig record still replays its own words and exactly one branch")
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

func _world_rules(world: Dictionary, plan: Dictionary) -> void:
	var s := _session(world, plan, 919)
	if not check(s != null, "Start isolated rules Run"): return
	var supplies := _site(plan, "icebound_provisions")
	var medicine := _site(plan, "frozen_medicine")
	_go(s, supplies)
	s.stats().attack = 1
	s.refresh_stats()
	var original: Dictionary = s.locations.definition_for(supplies)
	var hidden: Dictionary = original.payload.interactions[0].duplicate(true)
	hidden.id = "unseen"
	hidden.verb = "Unseen choice"
	hidden.reveal_conditions = [{"type": "stat", "stat": "attack", "min": 999}]
	original.payload.interactions.append(hidden)
	check(not s.places.available(s, supplies, "interact").any(func(i: Dictionary) -> bool: return i.id == "unseen") and s.places.next_interaction(s, supplies, "unseen").is_empty(), "Hidden choice is neither offered nor explicitly callable before its discovery condition")
	original.payload.interactions.pop_back()
	var turn := int(s.run.state.turn)
	var before_refusal: Dictionary = s.run.state.duplicate(true)
	check(not _act(s, supplies, "force") and s.last_error.contains("Attack 8+") and int(s.run.state.turn) == turn and preload("res://src/acceptance/standalone_check.gd").same(s.run.state, before_refusal), "Weak force refused with a concrete threshold and exactly unchanged gameplay state")
	check(not _act(s, supplies, "heat") and _resolved(s, supplies).is_empty(), "Thaw without fuel refuses without resolving or awarding")
	check(s.save() and store.load_run(s.run.run_id).state.character.interaction_history.any(func(e: Dictionary) -> bool: return e.get("outcome") == "refused") and s.pending_interaction_events.is_empty(), "Explicit save persists buffered refusals without needing a later successful interaction")
	s.run.state.inventory["snow:resin"] = {"version": 1, "quantity": 2}
	s.run.state.inventory["core:wood"] = {"version": 1, "quantity": 2}
	var hp := int(s.stats().hp)
	check(_act(s, supplies, "heat") and _count(s, "snow:bark_ration") == 3 and _count(s, "snow:resin") == 1 and int(s.stats().hp) == hp, "Heat consumes fuel and preserves all three supplies without injury")
	check(s.places.record(s, supplies.instance_id).world_state == "thawed" and s.run.state.character.knowledge.has("rules:ice_heat_v1"), "Persistent thawed state and useful Knowledge unlocked by action")
	var inventory: Dictionary = s.run.state.inventory.duplicate(true)
	check(not _act(s, supplies, "force") and not _act(s, supplies, "heat") and inventory == s.run.state.inventory, "Neither method can pay twice or bypass exclusivity")
	_go(s, medicine)
	s.stats().attack = 8
	s.refresh_stats()
	check(not _act(s, medicine, "force"), "Bare-handed attack below the second object's threshold refuses")
	var award: Dictionary = preload("res://src/core/inventory.gd").new().award(store.content, world.world_id, s.run.state.inventory, [{"content_id": "core:traveler_blade", "version": 1, "quantity": 1}], "rules-test-blade")
	s.run.state.inventory = award.inventory
	check(_equip(s, "core:traveler_blade") and int(s.combat_stats().attack) >= 12, "Equipping a real blade raises derived force capability")
	hp = int(s.stats().hp)
	check(_act(s, medicine, "force") and _count(s, "core:herb") == 1 and int(s.stats().hp) == hp - 2, "Second definition reuses force rule: threshold 12, one surviving herb and 2 HP cost")
	check(s.places.record(s, medicine.instance_id).world_state == "shattered" and s.run.state.character.knowledge.size() == 2, "Different method records shattered state and a separate scoped fact")
	check(s.save(), "Save world rules, Knowledge and diagnostic history")
	var resumed := Session.new(store)
	check(resumed.resume(s.run.run_id) and JSON.stringify(JSON.parse_string(JSON.stringify(resumed.run.state.character.knowledge)), "", true) == JSON.stringify(JSON.parse_string(JSON.stringify(s.run.state.character.knowledge)), "", true) and resumed.places.record(resumed, medicine.instance_id).world_state == "shattered", "Reload preserves learned text and world consequences: " + resumed.last_error)
	var report: Dictionary = preload("res://src/tools/run_telemetry.gd").build(world, resumed.run)
	var events: Array = report.development_interactions.events
	check(events.any(func(e: Dictionary) -> bool: return e.get("method") == "force" and e.get("outcome") == "refused") and events.any(func(e: Dictionary) -> bool: return e.get("method") == "heat" and e.get("outcome") == "success"), "Offline telemetry includes failed and successful approaches")
	var fresh := _session(world, plan, 920)
	check(not fresh.run.state.character.has("knowledge") and _resolved(fresh, supplies).is_empty() and not fresh.run.state.character.get("interaction_history", []).any(func(e: Dictionary) -> bool: return e.get("method") in ["heat", "force"]), "Fresh Run inherits no Knowledge, object mutations or interaction history")
	_go(fresh, supplies)
	fresh.stats().attack = 6
	fresh.refresh_stats()
	check(_act(fresh, supplies, "force") and _count(fresh, "snow:bark_ration") == 1 and s.places.record(s, supplies.instance_id).world_state == "thawed", "Same obstacle supports force in another Run while the first Run stays thawed")
	_go(fresh, medicine)
	fresh.run.state.inventory["snow:resin"] = {"version": 1, "quantity": 1}
	fresh.run.state.inventory["core:wood"] = {"version": 1, "quantity": 1}
	check(_act(fresh, medicine, "heat") and _count(fresh, "core:herb") == 3, "The second object also supports heat, preserving three herbs instead of one")
	# Chemistry v1: heat is the element, not the fuel. A carried flame thaws the same ice.
	var flame := _session(world, plan, 733)
	if check(flame != null, "Start a Run for carried-flame thawing"):
		var kit: Dictionary = preload("res://src/core/inventory.gd").new().award(store.content, flame.world.world_id, flame.run.state.inventory, [{"content_id": "core:tallow_torch", "version": 1, "quantity": 1}, {"content_id": "core:book/ember", "version": 1, "quantity": 1}], "test:flame-kit")
		flame.run.state.inventory = kit.inventory
		check(_equip(flame, "core:tallow_torch"), "Equip a crafted tallow torch")
		_go(flame, supplies)
		var props: Dictionary = flame.locations.definition_for(supplies).payload.world_properties
		check(WorldRulesScript.heat_sources(flame, props).any(func(source: Dictionary) -> bool: return source.id == "flame"), "A fire weapon is offered as a heat source")
		check(flame.perform_action({"type": "interact", "instance_id": supplies.instance_id, "interaction": "heat", "heat_source": "flame"}) and _count(flame, "snow:bark_ration") == 3 and _count(flame, "snow:resin") == 0, "The torch thaws the supplies with no fuel and keeps all three rations")
		check(flame.places.record(flame, supplies.instance_id).world_state == "thawed" and flame.run.state.character.knowledge.has("rules:ice_heat_flame_v1"), "Thawed state and the carried-flame Knowledge are recorded")
		check(flame.perform_action({"type": "learn", "content_id": "core:book/ember"}), "Learn the Ember fire skill")
		check(flame.perform_action({"type": "unequip", "slot": "weapon"}), "Put the torch away")
		_go(flame, medicine)
		flame.run.state.character.resources.mana.value = 0
		var before_skill: Dictionary = flame.run.state.duplicate(true)
		check(not flame.perform_action({"type": "interact", "instance_id": medicine.instance_id, "interaction": "heat", "heat_source": "skill"}) and flame.last_error.contains("Mana") and preload("res://src/acceptance/standalone_check.gd").same(flame.run.state, before_skill), "A fire skill without Mana is refused and changes nothing")
		flame.run.state.character.resources.mana.value = 10
		check(flame.perform_action({"type": "interact", "instance_id": medicine.instance_id, "interaction": "heat", "heat_source": "skill"}) and _count(flame, "core:herb") == 3 and int(flame.run.state.character.resources.mana.value) < 10, "Ember thaws the medicine case for its Mana cost, keeping all herbs")
	var missing: Array = []
	var problem: String = preload("res://src/core/world_rules.gd").validate({"version": 99, "material": "ordinary_ice", "fracture_attack": 8, "thaw_fuel": [{"content_id": "core:wood", "version": 1, "quantity": 1}]}, missing)
	check(problem.is_empty() and not missing.is_empty(), "Unknown rule version remains unsupported rather than running")

func _regional_crafting(world: Dictionary, other: Dictionary, plan: Dictionary) -> void:
	var s := _session(world, plan, 929)
	if not check(s != null, "Start a regional crafting expedition"): return
	var recipes: Array = s.recipes().filter(func(r: Dictionary) -> bool: return str(r.content_id).begins_with("snow:recipe/"))
	check(recipes.size() == 9 and store.content.load_definition(other.world_id, "snow:pitchbrand", 1).is_empty(), "Nine regional recipes installed only with Snow Mountain")
	var cache: Dictionary = s._definition("snow:water_cache", 1)
	var salvage := false
	for sample in 24:
		var loot: Array = s.loot_for(cache, "test:regional-cache/" + str(sample))
		salvage = salvage or loot.any(func(drop: Dictionary) -> bool: return drop.content_id == "snow:bronze_scrap")
	check(salvage, "Regional supply cache loot actually supplies bronze for crafting")
	var before: Dictionary = s.run.state.duplicate(true)
	check(not s.perform_action({"type": "craft", "recipe_id": "snow:recipe/pitchbrand"}) and preload("res://src/acceptance/standalone_check.gd").same(before, s.run.state), "Missing regional materials refuse without any state change")
	for recipe in recipes:
		var award: Dictionary = preload("res://src/core/inventory.gd").new().award(store.content, world.world_id, s.run.state.inventory, recipe.payload.inputs, "test:snow-materials/" + recipe.content_id)
		if not check(not award.is_empty(), "Obtain inputs for " + recipe.name): continue
		s.run.state.inventory = award.inventory
		var turn := int(s.run.state.turn)
		check(s.perform_action({"type": "craft", "recipe_id": recipe.content_id}) and int(s.run.state.turn) == turn + 1 and _count(s, recipe.payload.output.content_id) >= int(recipe.payload.output.quantity), "Craft usable " + recipe.name + " through the real action")
	check(_equip(s, "snow:pitchbrand"), "Equip regional fire weapon")
	var supplies := _site(plan, "icebound_provisions")
	_go(s, supplies)
	check(s.perform_action({"type": "interact", "instance_id": supplies.instance_id, "interaction": "heat", "heat_source": "flame"}) and _count(s, "snow:bark_ration") == 3, "Crafted Pitchbrand also thaws actual regional supplies")
	check(_equip(s, "snow:rime_focus"), "Equip regional elemental focus")
	var frost: Dictionary = s.skill_definition("core:skill/frost", 1)
	check(int(s.skills.modifiers(s, frost).power_percent) == 35 and int(s.skills.costs(s, frost).mana) == 1, "Regional focus changes Frost power and Mana cost through shared rules")
	s.stats().hp = 1
	check(s.perform_action({"type": "use", "content_id": "snow:pine_salve"}) and int(s.stats().hp) > 1 and _count(s, "snow:pine_salve") == 0, "Crafted salve heals and is consumed once")
	s.stats().hunger = 800
	s.stats().thirst = 800
	check(s.perform_action({"type": "use", "content_id": "snow:trail_stew"}) and int(s.stats().hunger) < 300 and int(s.stats().thirst) < 650, "Crafted expedition food addresses food and water")
	var saved: Dictionary = s.run.state.inventory.duplicate(true)
	var gear: Dictionary = s.run.state.character.equipment.duplicate(true)
	check(s.save(), "Save regional crafted equipment and supplies")
	var resumed := Session.new(store)
	check(resumed.resume(s.run.run_id) and preload("res://src/acceptance/standalone_check.gd").same(saved, resumed.run.state.inventory) and preload("res://src/acceptance/standalone_check.gd").same(gear, resumed.run.state.character.equipment), "Reload preserves exact regional items and equipment identities")
