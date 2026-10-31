extends SceneTree
## Milestone 02 I: special places, hidden discoveries and environmental events in real
## gameplay; Region Ledger revisions; per-Run state; mock AI location end to end.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Pipeline = preload("res://src/content/authoring_pipeline.gd")
const Packs = preload("res://src/content/starter_pack.gd")
const Data = preload("res://src/data/json_data.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const FogMask = preload("res://src/run/fog_mask.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
const Ledger = preload("res://src/world/region_ledger.gd")
const Inventory = preload("res://src/core/inventory.gd")
var checks := 0
var failures := 0
var store := Store.new()
var path := ""
var world: Dictionary

func check(ok: bool, label: String) -> bool:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)
	return ok

func _initialize() -> void:
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.tools/ai/mock_location_bundle.json"))
	if not envelope is Dictionary:
		check(false, "Run the offline Python provider tests first to write the location fixture")
		return finish()
	Session.auto_awaken = false
	path = ProjectSettings.globalize_path("user://discovery-i-" + Data.uuid() + ".sqlite")
	check(store.open(path), "Open isolated native SQLite fixture")
	world = store.create_world("Discovery laboratory", 1847, 1, Packs.blueprint(1847))

	# A Run saved before the ledger existed, and a region recorded by Checkpoint H code.
	var terrain := Terrain.new()
	terrain.configure(1847, 1)
	var legacy_spawn := Spawn.select(terrain, 99, "meadow")
	var legacy: Dictionary = store.create_run(world.world_id, 99, legacy_spawn)
	legacy.state.explored = [legacy_spawn.position.duplicate()]
	store.save_run(legacy.run_id, legacy.revision, legacy.state)
	var legacy_chunk := Terrain.chunk_of(Vector2i(int(legacy_spawn.position.x), int(legacy_spawn.position.y)))

	var a := Session.new(store)
	if not check(a.start_new(world.world_id, 7301, "forest"), "Start Run A: " + a.last_error): return finish()
	a.autosave_interval = 0
	var ledger: RefCounted = a.locations.ledger
	check(ledger.layers(legacy_chunk).is_empty() and a.locations.preview_chunk(legacy_chunk, ledger.established(legacy_chunk), ledger.layers(legacy_chunk)).is_empty(), "Regions explored before Checkpoint I (baseline) never gain places")
	var h_chunk := Terrain.chunk_of(a.position) + Vector2i(40, -40)
	store.content.create_instance(world.world_id, {"instance_id": Ledger.record_id(h_chunk), "content_id": "core:region_record", "version": 1, "position": {"x": h_chunk.x * 32, "y": h_chunk.y * 32}, "origin": "procedural", "metadata": {"ledger_version": 1, "encounter_revision": 0, "chunk": {"x": h_chunk.x, "y": h_chunk.y}}})
	check(Ledger.new().configure(store.content, world.world_id) and a.locations.preview_chunk(h_chunk, 0, ledger.layers(h_chunk)).is_empty() and a.roster.layer.ledger.established(a.roster.chunks.keys()[0]) == 0 and a.locations.ledger.layers(Terrain.chunk_of(a.position)) == ["locations-v1"], "H-era region records keep no place layer; new regions carry locations-v1")

	# Distribution rules over a wide area at the current revision.
	var home := Terrain.chunk_of(a.position)
	var found := {}
	var valid := true
	var deterministic := true
	for dy in range(-12, 13):
		for dx in range(-12, 13):
			var chunk := home + Vector2i(dx, dy)
			if ledger.established(chunk) >= 0 and ledger.layers(chunk).is_empty(): continue
			var places: Array = a.locations.preview_chunk(chunk, ledger.revision, Ledger.LAYERS)
			deterministic = deterministic and Acceptance.same(places, a.locations.preview_chunk(chunk, ledger.revision, Ledger.LAYERS))
			valid = valid and places.size() <= 1
			for place in places:
				var tile := Vector2i(int(place.position.x), int(place.position.y))
				var definition: Dictionary = a.locations.definition_for(place)
				valid = valid and terrain.walkable(tile) and terrain.biome_at(tile) in definition.payload.spawn.biomes and Terrain.chunk_of(tile) == chunk and str(place.instance_id) == "loc:v1/%d/%d/%d_%d" % [chunk.x, chunk.y, posmod(tile.x, 32), posmod(tile.y, 32)]
				valid = valid and a.objects.generate_chunk(chunk).all(func(o: Dictionary) -> bool: return Vector2i(int(o.position.x), int(o.position.y)) != tile)
				if not found.has(place.content_id): found[place.content_id] = {"chunk": chunk, "place": place}
	check(valid and deterministic, "Places: one per chunk at most, walkable, right biome, never on an object, stable IDs, deterministic")
	check(found.has("core:place/ancient_ruin") and found.has("core:place/buried_shrine") and found.has("core:place/spirit_vein") and found.has("core:place/miasma_vent"), "Every sample place type occurs in the wider world: " + str(found.keys()))
	if found.size() < 4: return finish()

	# 1. Ruin: visible discovery, two-step interaction with a requirement.
	var ruin: Dictionary = found["core:place/ancient_ruin"].place
	var ruin_tile := tile_of(ruin)
	check(a.relocate(near(a, ruin_tile, 5)) and not a.places.discovered(a, ruin.instance_id) and a.places.targets(a).is_empty(), "Undiscovered ruin is neither shown nor targetable")
	a.wait_turn()
	check(a.places.discovered(a, ruin.instance_id) and a.last_events.any(func(e: Dictionary) -> bool: return e.type == "discovery" and e.target == ruin.instance_id) and not store.content.load_instance(world.world_id, ruin.instance_id).is_empty(), "Seeing the ruin discovers it with feedback and establishes its placement")
	a.relocate(near(a, ruin_tile, 1))
	var turn := int(a.run.state.turn)
	check(a.interact(ruin.instance_id) and int(a.run.state.turn) == turn + 1 and a.run.state.inventory.has("core:coin") and a.last_events.any(func(e: Dictionary) -> bool: return e.type == "location" and not e.received.is_empty()), "Searching the storeroom pays loot and XP through existing handlers")
	var coins := int(a.run.state.inventory["core:coin"].quantity)
	turn = int(a.run.state.turn)
	var before_refusal: Dictionary = a.run.state.duplicate(true)
	check(not a.interact(ruin.instance_id) and a.last_error.contains("requires") and int(a.run.state.turn) == turn and Acceptance.same(a.run.state, before_refusal), "Inscription needs level 2 or Spirit Eye: refused with no turn and no change")
	# 2. Hidden spirit vein: only perception (talent), a skill or a stat reveals it.
	var vein: Dictionary = found["core:place/spirit_vein"].place
	a.relocate(near(a, tile_of(vein), 2))
	a.wait_turn()
	a.search()
	check(not a.places.discovered(a, vein.instance_id), "Hidden vein stays unseen without perception, even when searching")
	a.run.state.character.talents = [a.talent_rules.record(a.talent_definition("core:talent/spirit_eye", 1), 0, int(a.run.state.turn))]
	a.reload_talents()
	a.wait_turn()
	check(a.places.discovered(a, vein.instance_id), "Spirit Eye talent reveals the hidden vein")
	a.relocate(near(a, tile_of(vein), 1))
	a.run.state.character.resources.energy.value = 0
	check(a.interact(vein.instance_id) and int(a.skills.resource(a, "energy")) > 0 and a.run.state.character.statuses.any(func(s: Dictionary) -> bool: return s.get("id") == "core:status/ward"), "Absorbing the vein restores energy and grants a status")

	# Back at the ruin: Spirit Eye (and the vein XP, level 2) now meets the requirement.
	a.relocate(near(a, ruin_tile, 1))
	check(a.interact(ruin.instance_id) and a.run.state.inventory.has("core:book/body_tempering") and a.places.state(a, ruin) == "resolved", "Once the requirement is met the inscription is read; the ruin is resolved")
	a.run.state.character.talents = []
	a.reload_talents()
	check(not a.interact(ruin.instance_id) and int(a.run.state.inventory["core:coin"].quantity) == coins, "A resolved ruin pays nothing again")

	# 3. Buried shrine: found only by searching; exclusive offering with an item cost.
	var shrine: Dictionary = found["core:place/buried_shrine"].place
	a.relocate(near(a, tile_of(shrine), 1))
	a.wait_turn()
	check(not a.places.discovered(a, shrine.instance_id), "Buried shrine is not found by walking past")
	turn = int(a.run.state.turn)
	check(a.search() and int(a.run.state.turn) == turn + 1 and a.places.discovered(a, shrine.instance_id), "Searching (X) uncovers the shrine and takes one turn")
	a.run.state.inventory.erase("core:herb")
	var no_herb: Dictionary = a.run.state.duplicate(true)
	check(not a.interact(shrine.instance_id) and a.last_error.contains("needs") and Acceptance.same(a.run.state, no_herb), "Offering without a herb is refused and consumes nothing")
	a.run.state.inventory = Inventory.new().award(store.content, world.world_id, a.run.state.inventory, [{"content_id": "core:herb", "version": 1, "quantity": 1}], "test:herb").inventory
	a.stats().hp = 5
	check(a.interact(shrine.instance_id) and not a.run.state.inventory.has("core:herb") and int(a.stats().hp) > 5 and a.run.state.character.statuses.any(func(s: Dictionary) -> bool: return s.get("id") == "core:status/regeneration"), "Offering spends the herb, heals and blesses")
	check(not a.interact(shrine.instance_id) and a.places.state(a, shrine) == "unavailable", "The exclusive alternative (plunder) is forfeited: the shrine is no longer available")

	# 4. Miasma vent: an environmental event on entering; harmful, once.
	var vent: Dictionary = found["core:place/miasma_vent"].place
	var vent_tile := tile_of(vent)
	var side := near(a, vent_tile, 1)
	a.relocate(side)
	a.stats().hp = int(a.combat_stats().max_hp)
	var hp := int(a.stats().hp)
	a.try_move(vent_tile - side)
	check(a.position == vent_tile and a.places.discovered(a, vent.instance_id) and int(a.stats().hp) < hp and a.run.state.character.statuses.any(func(s: Dictionary) -> bool: return s.get("id") == "core:status/poison") and a.at_risk(), "Stepping on the vent triggers damage and poison (a risky action for autosave)")
	a.try_move(side - vent_tile)
	a.run.state.character.statuses = []
	a.try_move(vent_tile - side)
	check(not a.last_events.any(func(e: Dictionary) -> bool: return e.type == "location") and a.places.state(a, vent) == "resolved", "The vent never fires twice")

	# Persistence: exact reload, chunk unload/return, Run isolation.
	check(a.save(), "Save Run A")
	var snapshot: Dictionary = a.run.state.duplicate(true)
	var run_a: String = a.run.run_id
	store.close()
	store = Store.new()
	store.open(path)
	a = Session.new(store)
	check(a.resume(run_a) and Acceptance.same(a.run.state, snapshot), "Database reopen restores discoveries, resolutions and rewards exactly")
	a.autosave_interval = 0
	a.relocate(far(a, ruin_tile + Vector2i(200, 0)))
	check(a.relocate(near(a, ruin_tile, 1)) and a.places.discovered(a, ruin.instance_id) and a.places.state(a, ruin) == "resolved" and not a.interact(ruin.instance_id), "Unloading and returning keeps the ruin discovered and resolved")
	var b := Session.new(store)
	b.start_new(world.world_id, 404, "meadow")
	b.autosave_interval = 0
	b.relocate(near(b, ruin_tile, 1))
	check(not b.places.discovered(b, ruin.instance_id), "Run B has not discovered Run A's ruin")
	b.wait_turn()
	check(b.places.discovered(b, ruin.instance_id) and b.interact(ruin.instance_id) and b.run.state.inventory.has("core:coin") and b.save() and Acceptance.same(store.load_run(run_a).state, snapshot), "Run B discovers and loots the same ruin independently; Run A is untouched")

	# Mock AI location: pending/invalid ideas, then the full pipeline into a new region.
	var tool := Pipeline.new(store)
	var site_def: Dictionary = envelope.content.definitions[2]
	var omen_def: Dictionary = envelope.content.definitions[1]
	var dream: Dictionary = site_def.duplicate(true)
	dream.content_id = "ai:fixture/dream_site"
	var storm: Dictionary = omen_def.duplicate(true)
	storm.content_id = "ai:fixture/storm"
	storm.payload.outcomes = [{"type": "summon_storm"}]
	dream.payload.discovery = {"mode": "dream"}
	dream.payload.interactions[0].event = {"content_id": storm.content_id, "version": 1}
	dream.dependencies = [{"content_id": storm.content_id, "version": 1}]
	var pending := tool.draft(world.world_id, request(envelope, "pending", [envelope.content.definitions[0], storm, dream]))
	tool.confirm(world.world_id, pending.content_id)
	check(pending.payload.report.status == "pending_capability" and "location.discovery.dream" in pending.payload.report.missing_capabilities and "event.outcome.summon_storm" in pending.payload.report.missing_capabilities and tool.activate(world.world_id, pending.content_id).is_empty(), "Unknown discovery mode or outcome stays a pending proposal")
	var ocean: Dictionary = site_def.duplicate(true)
	ocean.payload.spawn.biomes = ["ocean"]
	var loose: Dictionary = omen_def.duplicate(true)
	loose.dependencies = []
	check(tool.draft(world.world_id, request(envelope, "ocean", [envelope.content.definitions[0], omen_def, ocean])).payload.report.status == "invalid" and tool.draft(world.world_id, request(envelope, "unpinned", [envelope.content.definitions[0], loose])).payload.report.status == "invalid", "Wrong biome or unpinned reward is invalid")
	check(a.save(), "Save Run A before the activation")
	var established_before := {}
	for chunk in a.locations.chunks: established_before[chunk] = a.locations.chunks[chunk].duplicate(true)
	var creatures_before := ids_in(a, a.roster.chunks.keys())
	var draft := tool.draft(world.world_id, envelope)
	check(draft.payload.report.status == "valid" and tool.activate(world.world_id, draft.content_id).is_empty(), "Mock location validates; activation still needs confirmation: " + JSON.stringify(draft.payload.report.errors))
	tool.confirm(world.world_id, draft.content_id)
	var activated := tool.activate(world.world_id, draft.content_id)
	var revision := int(activated.get("payload", {}).get("encounter_revision", 0))
	check(revision == 1 and store.content.load_definition(world.world_id, site_def.content_id, 1).provenance.encounter_revision == 1, "Activation stamps World revision 1 on the location: " + tool.last_error)
	a = Session.new(store)
	a.resume(run_a)
	a.autosave_interval = 0
	var same := true
	for chunk in established_before:
		same = same and Acceptance.same(a.locations.preview_chunk(chunk, a.locations.ledger.established(chunk), a.locations.ledger.layers(chunk)), established_before[chunk])
	check(same and Acceptance.same(ids_in(a, a.roster.chunks.keys()), creatures_before), "Established regions keep their places and creatures after activation")
	var target := find_site(a, site_def.content_id)
	if not check(not target.is_empty(), "An unestablished region holds the AI site at revision 1"): return finish()
	check(a.relocate(near(a, tile_of(target.place), 3)) and a.locations.ledger.established(target.chunk) == 1 and a.locations.find(target.place.instance_id).content_id == site_def.content_id, "Entering the new region establishes it with the AI site")
	a.wait_turn()
	a.relocate(near(a, tile_of(target.place), 1))
	var relic: String = envelope.content.definitions[0].content_id
	check(a.places.discovered(a, target.place.instance_id) and a.interact(target.place.instance_id) and a.run.state.inventory.has(relic), "AI site is discovered by proximity and attuning grants its relic")
	check(a.save(), "Save after the AI site")
	var after_ai: Dictionary = a.run.state.duplicate(true)
	store.close()
	store = Store.new()
	store.open(path)
	a = Session.new(store)
	check(a.resume(run_a) and Acceptance.same(a.run.state, after_ai) and a.places.state(a, a.locations.find(target.place.instance_id)) == "resolved", "Reload keeps the AI site resolved with its reward once")

	# Invariants and old saves.
	var legacy_session := Session.new(store)
	check(legacy_session.resume(legacy.run_id), "Legacy save resumes with places installed: " + legacy_session.last_error)
	var covered := true
	for run_id in [run_a, b.run.run_id, legacy.run_id]:
		for seen in FogMask.chunks(store.load_run(run_id).state.explored): # Tiles or chunk masks.
			covered = covered and a.locations.ledger.established(seen) >= 0
	var keys := {}
	var unique := true
	for header in store.content.list_definitions(world.world_id):
		unique = unique and not keys.has("%s@%d" % [header.content_id, int(header.version)])
		keys["%s@%d" % [header.content_id, int(header.version)]] = true
	check(covered and unique and Acceptance.same(store.load_world(world.world_id), world) and store.content.load_definition(world.world_id, dream.content_id, 1).is_empty(), "Explored ⊆ established, no duplicate IDs, Blueprint unchanged, pending content absent")
	finish()

func finish() -> void:
	store.close()
	print("M02 CHECKPOINT I DISCOVERIES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func tile_of(place: Dictionary) -> Vector2i:
	return Vector2i(int(place.position.x), int(place.position.y))

func near(session: RefCounted, tile: Vector2i, distance: int) -> Vector2i:
	## A walkable tile at about this distance with a clear line to the target.
	for d in range(distance, distance + 6):
		for dx in range(-d, d + 1):
			for sign in [1, -1]:
				var candidate := tile + Vector2i(dx, sign * (d - absi(dx)))
				if session.terrain.walkable(candidate) and candidate != tile and session.line_clear(candidate, tile) and session.roster.living_at(candidate).is_empty():
					return candidate
	return tile

func far(session: RefCounted, tile: Vector2i) -> Vector2i:
	for radius in 40:
		for dx in range(-radius, radius + 1):
			for dy in [-radius, radius]:
				if session.terrain.walkable(tile + Vector2i(dx, dy)): return tile + Vector2i(dx, dy)
	return tile

func request(envelope: Dictionary, id: String, definitions: Array) -> Dictionary:
	var result: Dictionary = envelope.duplicate(true)
	result.request.request_id = id
	result.content = {"schema_version": 1, "definitions": definitions}
	return result

func ids_in(session: RefCounted, chunks: Array) -> Array:
	var result: Array = []
	for creature in session.roster.creatures.values():
		if Terrain.chunk_of(creature.home) in chunks: result.append("%s=%s" % [creature.instance_id, creature.content_id])
	result.sort()
	return result

func find_site(session: RefCounted, content_id: String) -> Dictionary:
	var origin := Terrain.chunk_of(session.position)
	for radius in range(4, 40):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius: continue
				var chunk := origin + Vector2i(dx, dy)
				var free := true
				for y in range(-1, 2):
					for x in range(-1, 2): free = free and session.locations.ledger.established(chunk + Vector2i(x, y)) == -1
				if not free: continue
				for place in session.locations.preview_chunk(chunk, session.locations.ledger.revision, Ledger.LAYERS):
					if place.content_id == content_id: return {"chunk": chunk, "place": place}
	return {}
