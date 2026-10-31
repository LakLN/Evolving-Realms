extends SceneTree
## Milestone 02 H: mock AI creature -> confirm -> activate -> encounter in an unestablished
## region -> combat -> loot -> save/reopen -> return, with established regions, legacy
## exploration, revisions and Runs kept consistent. Offline mock fixture only.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Pipeline = preload("res://src/content/authoring_pipeline.gd")
const Context = preload("res://src/content/authoring_context.gd")
const Packs = preload("res://src/content/starter_pack.gd")
const Data = preload("res://src/data/json_data.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const FogMask = preload("res://src/run/fog_mask.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
const Ledger = preload("res://src/world/region_ledger.gd")
const Encounters = preload("res://src/world/world_encounters.gd")
const Region = preload("res://src/world/region_context.gd")
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
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.tools/ai/mock_creature_bundle.json"))
	if not envelope is Dictionary:
		check(false, "Run the offline Python provider tests first to write the creature fixture")
		return finish()
	Session.auto_awaken = false
	path = ProjectSettings.globalize_path("user://ai-h-" + Data.uuid() + ".sqlite")
	check(store.open(path), "Open isolated native SQLite fixture")
	world = store.create_world("Encounter laboratory", 1847, 1, Packs.blueprint(1847))
	var creature_def: Dictionary = envelope.content.definitions.filter(func(d: Dictionary) -> bool: return d.kind == "creature")[0]
	var encounter_def: Dictionary = envelope.content.definitions.filter(func(d: Dictionary) -> bool: return d.kind == "encounter")[0]
	var trophy_id: String = creature_def.payload.loot.guaranteed[0].content_id
	var status_id: String = creature_def.payload.on_hit_effects[0].content_id

	# A Run saved before Checkpoint H: explored tiles but no region ledger yet.
	var terrain := Terrain.new()
	terrain.configure(1847, 1)
	var legacy_spawn := Spawn.select(terrain, 99, "meadow")
	var legacy: Dictionary = store.create_run(world.world_id, 99, legacy_spawn)
	legacy.state.explored = [legacy_spawn.position.duplicate()]
	check(store.save_run(legacy.run_id, legacy.revision, legacy.state) and store.content.load_instance(world.world_id, Ledger.BASELINE_ID).is_empty(), "Legacy Run exists without any region ledger")
	var legacy_chunk := Terrain.chunk_of(Vector2i(int(legacy_spawn.position.x), int(legacy_spawn.position.y)))

	var a := Session.new(store)
	if not check(a.start_new(world.world_id, 7301, "forest"), "Start Run A: " + a.last_error): return finish()
	a.autosave_interval = 0
	var ledger: RefCounted = a.roster.layer.ledger
	var home_chunk := Terrain.chunk_of(a.position)
	check(not store.content.load_instance(world.world_id, Ledger.BASELINE_ID).is_empty() and ledger.established(legacy_chunk) == 0 and ledger.established(legacy_chunk + Vector2i.ONE) == 0, "First H session seals every Run's earlier exploration at revision 0")
	check(a.roster.chunks.keys().all(func(c: Vector2i) -> bool: return ledger.established(c) == 0), "Loaded chunks are established at the current revision (0)")
	var v1_before := {}
	for chunk in a.roster.chunks: v1_before[chunk] = a.roster.layer.generate_chunk(chunk)
	var seen_before := ids_in(a, a.roster.chunks.keys())
	for step in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]: a.try_move(step)
	check(a.save(), "Save Run A before activation")
	var run_a_saved: Dictionary = store.load_run(a.run.run_id).duplicate(true)

	# Pending capability: an unsupported element makes creature and encounter pending.
	var tool := Pipeline.new(store)
	var void_beast: Dictionary = creature_def.duplicate(true)
	void_beast.content_id = "ai:fixture/void_beast"
	void_beast.payload.elements = ["void"]
	var void_haunt: Dictionary = encounter_def.duplicate(true)
	void_haunt.content_id = "ai:fixture/void_haunt"
	void_haunt.payload.creature = {"content_id": void_beast.content_id, "version": 1}
	void_haunt.dependencies = [{"content_id": void_beast.content_id, "version": 1}]
	var odd_haunt: Dictionary = void_haunt.duplicate(true)
	odd_haunt.content_id = "ai:fixture/moon_haunt"
	odd_haunt.payload.creature = {"content_id": creature_def.content_id, "version": 1}
	odd_haunt.dependencies = [{"content_id": creature_def.content_id, "version": 1}]
	odd_haunt.payload.conditions = [{"type": "moon_phase", "values": ["full"]}]
	var trophy_def: Dictionary = envelope.content.definitions[0]
	var pending := tool.draft(world.world_id, request(envelope, "pending", [trophy_def, void_beast, void_haunt]))
	tool.confirm(world.world_id, pending.content_id)
	var unknown := tool.draft(world.world_id, request(envelope, "unknown-condition", [trophy_def, creature_def, odd_haunt]))
	check(pending.payload.report.status == "pending_capability" and "effect.element.void" in pending.payload.report.missing_capabilities and tool.activate(world.world_id, pending.content_id).is_empty() and Encounters.current_revision(store.content, world.world_id) == 0 and unknown.payload.report.status == "pending_capability" and "encounter.condition.moon_phase" in unknown.payload.report.missing_capabilities, "Pending creature or unknown spawn condition stays a proposal; no encounter revision")
	var wrong_biome: Dictionary = encounter_def.duplicate(true)
	wrong_biome.payload.biomes = ["beach"]
	var invalid := tool.draft(world.world_id, request(envelope, "wrong-biome", [trophy_def, creature_def, wrong_biome]))
	check(invalid.payload.report.status == "invalid", "Encounter outside the creature's movement biomes is invalid")

	# Activate the mock creature bundle.
	var draft := tool.draft(world.world_id, envelope)
	check(draft.payload.report.status == "valid", "Mock creature + encounter pass engine validation: " + JSON.stringify(draft.payload.report.errors))
	check(tool.activate(world.world_id, draft.content_id).is_empty(), "Activation still requires explicit confirmation")
	tool.confirm(world.world_id, draft.content_id)
	var activated := tool.activate(world.world_id, draft.content_id)
	var installed: Dictionary = store.content.load_definition(world.world_id, encounter_def.content_id, 1)
	check(not activated.is_empty() and activated.payload.encounter_revision == 1 and installed.status == "active" and installed.provenance.encounter_revision == 1 and installed.provenance.proposal_id == draft.content_id, "Activation stamps encounter revision 1, traceable to the proposal: " + tool.last_error)
	var count := store.content.list_definitions(world.world_id).size()
	tool.activate(world.world_id, draft.content_id)
	check(store.content.list_definitions(world.world_id).size() == count and Encounters.current_revision(store.content, world.world_id) == 1, "Repeated activation adds nothing and keeps revision 1")
	check(Acceptance.same(store.load_world(world.world_id), world) and Acceptance.same(store.load_run(a.run.run_id), run_a_saved), "Activation changes neither Blueprint nor saved Run")

	# Established regions are untouched by the new revision.
	var run_a: String = a.run.run_id
	a = Session.new(store)
	check(a.resume(run_a) and a.roster.layer.encounters.revision == 1, "Run A resumes and sees revision 1 rules: " + a.last_error)
	a.autosave_interval = 0
	ledger = a.roster.layer.ledger
	var unchanged := true
	for chunk in v1_before:
		unchanged = unchanged and Acceptance.same(a.roster.layer.generate_chunk(chunk), v1_before[chunk]) and Acceptance.same(a.roster.layer.preview_chunk(chunk, ledger.established(chunk)), v1_before[chunk])
	check(unchanged and Acceptance.same(ids_in(a, v1_before.keys()), seen_before), "Explored chunks keep creature-generation v1 homes and gain no AI encounters")
	check(a.roster.layer.preview_chunk(legacy_chunk, ledger.established(legacy_chunk)).all(func(p: Dictionary) -> bool: return not str(p.instance_id).begins_with("enc:")), "Legacy-explored region stays at revision 0")
	check(a.roster.chunks.keys().all(func(c: Vector2i) -> bool: return ledger.established(c) == 0), "Reload does not re-establish known chunks")

	# Find a not-yet-established region where the encounter places the AI creature.
	var target := find_encounter(a, home_chunk, creature_def.content_id)
	if not check(not target.is_empty(), "An unestablished forest/meadow region holds the AI encounter at revision 1"): return finish()
	var chunk: Vector2i = target.chunk
	var preview: Array = a.roster.layer.preview_chunk(chunk, 1)
	var reversed: Array = []
	for c in [chunk + Vector2i.LEFT, chunk, chunk + Vector2i.UP]: reversed.append(a.roster.layer.preview_chunk(c, 1))
	check(Acceptance.same(a.roster.layer.preview_chunk(chunk, 1), preview) and Acceptance.same(reversed[1], preview), "Encounter placement is deterministic and independent of chunk order")
	check(rules_hold(a, chunk, preview, encounter_def), "AI homes respect biome, conditions, free walkable tiles and density caps")
	var start := approach_tile(a, target.placement, preview)
	check(ledger.established(chunk) == -1 and a.relocate(start) and ledger.established(chunk) == 1, "Entering the unexplored region establishes it at revision 1")
	var id: String = target.placement.instance_id
	check(a.roster.creatures.has(id) and a.roster.creatures[id].definition.provenance.origin == "ai", "AI creature appears through the encounter rule as a registry definition")

	# Detect, approach and fight with the real turn system.
	var hit_by_ai := false
	var slowed := false
	var turns := 0
	for turn in 120:
		var creature: Dictionary = a.roster.creatures[id]
		if creature.dead: break
		turns += 1
		if int(a.stats().hp) <= 10: a.stats().hp = int(a.combat_stats().max_hp) # Test sustain only; the fight itself is real.
		var adjacent: bool = absi(creature.position.x - a.position.x) + absi(creature.position.y - a.position.y) == 1 and a.visible.has(creature.position)
		if adjacent: a.attack_target(id)
		else:
			var step := Acceptance.step_toward_creature(a, creature)
			if step == Vector2i.ZERO or not a.try_move(step): a.wait_turn()
		hit_by_ai = hit_by_ai or a.last_events.any(func(e: Dictionary) -> bool: return e.get("type") == "hit" and e.get("attacker") == id and int(e.get("damage", 0)) > 0)
		slowed = slowed or a.run.state.character.get("statuses", []).any(func(s: Variant) -> bool: return s is Dictionary and s.get("id") == status_id)
	var dead: Dictionary = a.roster.creatures[id]
	print("TRACE: %s (%s, hp %d) in chunk %s danger %d, start %s, fight %d turns, loot %s" % [id, dead.definition.name, dead.max_hp, chunk, Region.danger(a.terrain, chunk), start, turns, JSON.stringify(dead.received)])
	check(hit_by_ai and slowed, "Hostile AI creature detects, chases and hits with its declared on-hit status")
	check(dead.dead and a.run.state.inventory.has(trophy_id) and a.run.state.entity_mutations[id].dead and not a.run.state.entity_mutations[id].received.is_empty(), "AI creature dies and drops its declared trophy through the loot system")
	var dead_at: Dictionary = a.run.state.entity_mutations[id].position.duplicate()
	var trophies := int(a.run.state.inventory[trophy_id].quantity)
	check(a.save(), "Save after the encounter")
	var snapshot: Dictionary = a.run.state.duplicate(true)
	var in_chunk := ids_in(a, [chunk])

	store.close()
	store = Store.new()
	store.open(path)
	a = Session.new(store)
	check(a.resume(run_a) and Acceptance.same(a.run.state, snapshot), "Database reopen restores the exact Run")
	a.autosave_interval = 0
	check(a.roster.creatures[id].dead and Acceptance.same(a.run.state.entity_mutations[id].position, dead_at) and int(a.run.state.inventory[trophy_id].quantity) == trophies and Acceptance.same(ids_in(a, [chunk]), in_chunk), "Dead stays dead at its position, loot is not duplicated, no extra copies")
	var far: Vector2i = find_walkable(a, a.position + Vector2i(160, 0))
	check(a.relocate(far) and not a.roster.chunks.has(chunk) and a.roster.layer.ledger.established(chunk) == 1, "Leaving unloads the chunk but its establishment is remembered")
	check(a.relocate(start) and Acceptance.same(ids_in(a, [chunk]), in_chunk) and a.roster.creatures[id].dead, "Returning shows the same encounter, nothing respawned or duplicated")

	# A second activation only affects regions established afterwards.
	var second: Dictionary = encounter_def.duplicate(true)
	second.content_id = "ai:fixture/second_haunt"
	second.payload.per_10000 = 150
	second.payload.biomes = ["forest", "meadow"]
	second.payload.conditions = [{"type": "danger", "min": 0, "max": 3}]
	var more: Dictionary = tool_for().draft(world.world_id, request(envelope, "second", [second]))
	tool_for().confirm(world.world_id, more.content_id)
	check(tool_for().activate(world.world_id, more.content_id).payload.get("encounter_revision") == 2, "Second encounter activation becomes revision 2")
	a = Session.new(store)
	a.resume(run_a)
	a.autosave_interval = 0
	check(a.roster.layer.ledger.established(chunk) == 1 and Acceptance.same(a.roster.layer.preview_chunk(chunk, 1), preview) and Acceptance.same(ids_in(a, [chunk]), in_chunk), "Revision-1 region keeps its exact encounters after revision 2")
	var fresh := find_walkable(a, start + Vector2i(0, 256))
	check(a.relocate(fresh) and a.roster.layer.ledger.established(Terrain.chunk_of(fresh)) == 2, "A newly entered region receives revision 2")
	var dense := true
	for c in a.roster.chunks:
		var homes: Array = a.roster.layer.preview_chunk(c, a.roster.layer.ledger.established(c))
		dense = dense and homes.size() <= Encounters.MAX_TOTAL and homes.filter(func(p: Dictionary) -> bool: return str(p.instance_id).begins_with("enc:")).size() <= Encounters.BUDGET
	check(dense, "Adding encounter rules never exceeds the per-chunk creature budget")
	check(a.save(), "Save Run A in the revision-2 region")

	# Run B shares World encounters, never Run A's creature state.
	var b := Session.new(store)
	check(b.start_new(world.world_id, 404, "meadow"), "Start Run B: " + b.last_error)
	b.autosave_interval = 0
	check(b.relocate(start) and b.roster.creatures.has(id) and not b.roster.creatures[id].dead and b.roster.creatures[id].hp == b.roster.creatures[id].max_hp and not b.run.state.inventory.has(trophy_id), "Run B meets the same established encounter alive, with independent state")
	check(b.save() and store.load_run(run_a).state.entity_mutations[id].dead, "Run A's kill survives Run B")

	# Invariants and old saves.
	var legacy_session := Session.new(store)
	check(legacy_session.resume(legacy.run_id) and legacy_session.roster.creatures.keys().all(func(k: String) -> bool: return not k.begins_with("enc:") or legacy_session.roster.layer.ledger.established(Terrain.chunk_of(legacy_session.roster.creatures[k].home)) > 0), "Legacy save resumes; its explored region has no new AI creatures")
	var covered := true
	for run_id in [run_a, b.run.run_id, legacy.run_id]:
		for seen in FogMask.chunks(store.load_run(run_id).state.explored): # Tiles or chunk masks.
			covered = covered and a.roster.layer.ledger.established(seen) >= 0
	check(covered, "Every explored tile of every Run lies in an established region")
	var keys := {}
	var unique := true
	for header in store.content.list_definitions(world.world_id):
		unique = unique and not keys.has("%s@%d" % [header.content_id, int(header.version)])
		keys["%s@%d" % [header.content_id, int(header.version)]] = true
	check(unique and Acceptance.same(store.load_world(world.world_id), world) and store.content.load_definition(world.world_id, "ai:fixture/void_haunt", 1).is_empty(), "Registry has no duplicate IDs, Blueprint unchanged, pending content absent")
	var context := Context.retrieve(store, world.world_id, "beast", [], "chunk:%d,%d" % [chunk.x, chunk.y])
	var described: Dictionary = context.get("region_context", {})
	check(described.get("established") == true and described.get("encounter_revision") == 1 and "%s@1" % creature_def.content_id in described.get("present_creatures", []) and described.has("danger") and context.capabilities.has("encounters"), "Region context reports biome, danger, revision and present AI species")
	finish()

func finish() -> void:
	store.close()
	print("M02 CHECKPOINT H AI WORLD: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func tool_for() -> RefCounted:
	return Pipeline.new(store)

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

func find_encounter(session: RefCounted, origin: Vector2i, content_id: String) -> Dictionary:
	for radius in range(3, 30):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius: continue
				var chunk := origin + Vector2i(dx, dy)
				var neighbors_free := true
				for y in range(-1, 2):
					for x in range(-1, 2): neighbors_free = neighbors_free and session.roster.layer.ledger.established(chunk + Vector2i(x, y)) == -1
				if not neighbors_free: continue
				for placement in session.roster.layer.preview_chunk(chunk, 1):
					if placement.content_id == content_id: return {"chunk": chunk, "placement": placement}
	return {}

func approach_tile(session: RefCounted, placement: Dictionary, homes: Array) -> Vector2i:
	var home := Vector2i(int(placement.position.x), int(placement.position.y))
	var taken := homes.map(func(p: Dictionary) -> Vector2i: return Vector2i(int(p.position.x), int(p.position.y)))
	for distance in range(4, 9):
		for dx in range(-distance, distance + 1):
			for sign in [1, -1]:
				var tile := home + Vector2i(dx, sign * (distance - absi(dx)))
				if Terrain.chunk_of(tile) == Terrain.chunk_of(home) and session.terrain.walkable(tile) and tile not in taken and session.line_clear(tile, home):
					return tile
	return home + Vector2i(4, 0)

func find_walkable(session: RefCounted, near: Vector2i) -> Vector2i:
	for radius in 40:
		for dx in range(-radius, radius + 1):
			for dy in [-radius, radius]:
				var tile := near + Vector2i(dx, dy)
				if session.terrain.walkable(tile): return tile
	return near

func rules_hold(session: RefCounted, chunk: Vector2i, homes: Array, encounter: Dictionary) -> bool:
	var bytes: PackedByteArray = session.terrain.generate_chunk(chunk)
	var tiles := {}
	var ai := 0
	for placement in homes:
		var tile := Vector2i(int(placement.position.x), int(placement.position.y))
		if tiles.has(tile) or not session.terrain.walkable(tile): return false
		tiles[tile] = true
		if str(placement.instance_id).begins_with("enc:"):
			ai += 1
			if session.terrain.biome_at(tile) not in encounter.payload.biomes or Region.biome_shares(bytes)[encounter.payload.biomes[0]] < 10: return false
			if placement.metadata.encounter.content_id != encounter.content_id or int(placement.metadata.established_revision) != 1: return false
	return ai >= 1 and ai <= int(encounter.payload.max_per_chunk) and homes.size() <= Encounters.MAX_TOTAL
