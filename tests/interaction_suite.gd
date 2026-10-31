extends SceneTree
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Data = preload("res://src/data/json_data.gd")
const Pack = preload("res://src/content/starter_pack.gd")
const Inventory = preload("res://src/core/inventory.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Helpers = preload("res://tests/interaction_helpers.gd")
const Mock = preload("res://src/content/mock_provider.gd")
const Spawn = preload("res://src/world/spawn_selector.gd")
var checks := 0
var failures := 0
var directory := ""

func _initialize() -> void:
	directory = ProjectSettings.globalize_path("user://checkpoint_d_tests/" + Data.uuid())
	DirAccess.make_dir_recursive_absolute(directory)
	print("Interaction artifacts: ", directory)
	_test_objects_and_actions()
	_test_inventory()
	_test_legacy()
	_test_restart()
	print("CHECKPOINT D INTERACTIONS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func _test_objects_and_actions() -> void:
	var store := Store.new()
	check(store.open(directory + "/objects.sqlite"), "Open real SQLite for interactions")
	var world := store.create_world("Object world", 1847, 1, Pack.blueprint(1847))
	var session := Session.new(store)
	check(session.start_new(world.world_id, 101, "meadow"), "Activate data-driven starter objects: " + session.last_error)
	if session.run.is_empty():
		store.close()
		return
	var fixed: Dictionary = store.content.load_instance(world.world_id, "landmark:wayfarer_cache")
	check(not fixed.is_empty() and fixed.origin == "authored" and Helpers.same(fixed.position, world.blueprint.fixed_locations[0].position), "Blueprint landmark becomes one fixed world instance")
	check(store.content.list_instances(world.world_id).size() == 1, "Unchanged procedural objects are not copied to SQLite")
	var snapshots := {}
	var origins: Array = session.objects.chunks.keys()
	for chunk in origins:
		snapshots[chunk] = session.objects.generate_chunk(chunk)
	origins.reverse()
	var consistent := true
	var valid := true
	var unique := {}
	for chunk in origins:
		var again: Array = session.objects.generate_chunk(chunk)
		consistent = consistent and Helpers.same(again, snapshots[chunk])
		for instance in again:
			var point := Vector2i(instance.position.x, instance.position.y)
			valid = valid and session.terrain.walkable(point) and Terrain.chunk_of(point) == chunk and not unique.has(instance.instance_id)
			unique[instance.instance_id] = true
			var definition: Dictionary = session.objects.definition_for(instance)
			if instance.origin == "procedural":
				valid = valid and session.terrain.biome_at(point) in definition.payload.spawn.biomes
	check(consistent and unique.size() > 20, "Object seeds and reverse chunk order preserve identical placements")
	check(valid, "All generated positions match biome, walkability, chunk and unique IDs")
	var fixed_chunk := Terrain.chunk_of(Vector2i(fixed.position.x, fixed.position.y))
	var fixed_seen := false
	for instance in session.objects.generate_chunk(fixed_chunk):
		fixed_seen = fixed_seen or instance.instance_id == fixed.instance_id
	check(fixed_seen, "Fixed and procedural instances merge into their chunk")
	var bad := fixed.duplicate(true)
	bad.instance_id = "test:blocked"
	bad.position = {"x": Terrain.LIMIT + 1, "y": 0}
	check(not session.objects.materialize(bad), "Invalid object placement is rejected before storage")
	bad = fixed.duplicate(true)
	bad.content_id = {"invalid": true}
	check(not session.objects.materialize(bad), "Malformed object reference is rejected without runtime execution")
	var turn := int(session.run.state.turn)
	check(not session.interact("missing:object") and int(session.run.state.turn) == turn, "Missing object interaction spends no turn")
	check(not session.perform_action({"type": "attack"}) and int(session.run.state.turn) == turn, "Unsupported action is rejected without executing code")
	var gathering := Helpers.route_to_object(session, "gather")
	check(not gathering.is_empty(), "Find reachable sample resource")
	if gathering.is_empty():
		store.close()
		return
	var resource_id: String = gathering.instance.instance_id
	if gathering.route.size() > 1:
		check(not session.interact(resource_id) and int(session.run.state.turn) == turn, "Remote resource cannot be harvested")
	check(Helpers.walk(session, gathering.route), "Walk to resource without object collision")
	var loot_before := session.preview_loot(resource_id)
	turn = int(session.run.state.turn)
	check(session.interact(resource_id), "Gather resource using stable object ID: " + session.last_error)
	check(int(session.run.state.turn) == turn + 1 and session.is_consumed(resource_id), "Successful gather consumes exactly one turn and depletes object")
	check(not session.run.state.inventory.is_empty() and Helpers.same(session.run.state.entity_mutations[resource_id].loot, loot_before), "Resource receipt matches deterministic loot")
	var inventory_after: Dictionary = session.run.state.inventory.duplicate(true)
	check(not session.interact(resource_id) and int(session.run.state.turn) == turn + 1 and Helpers.same(session.run.state.inventory, inventory_after), "Repeated gather cannot duplicate items or turns")
	check(not store.content.load_instance(world.world_id, resource_id).is_empty(), "Only interacted procedural instance is materialized for mutation FK")
	var chests := Helpers.route_to_object(session, "open")
	check(not chests.is_empty(), "Find reachable procedural chest")
	if not chests.is_empty():
		check(Helpers.walk(session, chests.route), "Walk to chest")
		var chest_id: String = chests.instance.instance_id
		var preview := session.preview_loot(chest_id)
		check(session.save(), "Save before opening chest")
		var resumed := Session.new(store)
		check(resumed.resume(session.run.run_id) and Helpers.same(resumed.preview_loot(chest_id), preview), "Reloading unopened chest cannot reroll reward")
		turn = int(resumed.run.state.turn)
		check(resumed.interact(chest_id) and int(resumed.run.state.turn) == turn + 1, "Chest grants loot and spends one turn")
		inventory_after = resumed.run.state.inventory.duplicate(true)
		check(not resumed.interact(chest_id) and Helpers.same(resumed.run.state.inventory, inventory_after) and int(resumed.run.state.turn) == turn + 1, "Chest cannot pay twice in the same run")
		session = resumed
	var pickup := Helpers.route_to_object(session, "pickup")
	check(not pickup.is_empty(), "Loose item pickups are generated from data")
	if not pickup.is_empty():
		check(Helpers.walk(session, pickup.route) and session.interact(pickup.instance.instance_id), "Pick up loose item using shared action pipeline")
	check(session.save(), "Atomic save of inventory and consumed object deltas")
	var run_a_id: String = session.run.run_id
	var snapshot: Dictionary = store.load_run(run_a_id)
	var footprint: Dictionary = session.run.state.entity_mutations.duplicate(true)
	var other := Session.new(store)
	check(other.start_new(world.world_id, 202, "beach"), "New independent Run B")
	check(other.run.state.inventory.is_empty() and other.run.state.entity_mutations.is_empty() and not other.is_consumed(resource_id), "Run B resets inventory/resources/chests")
	for biome in Terrain.BIOMES:
		var biome_run := Session.new(store)
		var ready := biome_run.start_new(world.world_id, 303, biome)
		var native_resource := false
		if ready:
			for objects in biome_run.objects.chunks.values():
				for instance in objects:
					var definition: Dictionary = biome_run.objects.definition_for(instance)
					if definition.kind == "resource" and biome_run.terrain.biome_at(Vector2i(instance.position.x, instance.position.y)) == biome:
						native_resource = true
		check(ready and native_resource, "Biome-specific resources are present in " + biome)
	check(Helpers.same(store.load_run(run_a_id), snapshot) and Helpers.same(store.load_world(world.world_id), world), "Run B and interactions leave Run A and World Blueprint unchanged")
	store.close()
	store.open(directory + "/objects.sqlite")
	var loaded := Session.new(store)
	check(loaded.resume(run_a_id) and Helpers.same(loaded.run.state.inventory, snapshot.state.inventory) and Helpers.same(loaded.run.state.entity_mutations, footprint), "Reopen restores exact inventory and object state")
	var resource_point := Vector2i(gathering.instance.position.x, gathering.instance.position.y)
	loaded.objects.follow(resource_point + Vector2i(500, 500))
	loaded.objects.follow(resource_point)
	var reloaded: Dictionary = loaded.objects.find(resource_id)
	check(not reloaded.is_empty() and loaded.is_consumed(resource_id), "Eviction/regeneration does not respawn a depleted resource")
	var seen := {}
	var no_duplicates := true
	for objects in loaded.objects.chunks.values():
		for instance in objects:
			no_duplicates = no_duplicates and not seen.has(instance.instance_id)
			seen[instance.instance_id] = true
	check(no_duplicates and loaded.objects.chunks.size() == 9, "Reloaded object chunks remain bounded without duplicate boundary instances")
	var fixed_run := store.create_run(world.world_id, 909, {"position":fixed.position,"biome":loaded.terrain.biome_at(Vector2i(fixed.position.x, fixed.position.y))})
	var at_landmark := Session.new(store)
	check(at_landmark.resume(fixed_run.run_id) and at_landmark.interact(fixed.instance_id), "Open fixed Blueprint chest from its walkable tile")
	var keepsake: Dictionary = at_landmark.run.state.inventory["core:keepsake"]
	check(keepsake.quantity == 1 and keepsake.instances.size() == 1, "Fixed cache grants guaranteed individual item")
	check(at_landmark.save(), "Persist individual item instance together with fixed chest state")
	var landmark_reload := Session.new(store)
	check(landmark_reload.resume(fixed_run.run_id) and Helpers.same(landmark_reload.run.state.inventory["core:keepsake"], keepsake) and not landmark_reload.interact(fixed.instance_id), "Unique item ID and opened landmark survive save/load without payout twice")
	var fixed_run_b := store.create_run(world.world_id, 909, {"position":fixed.position,"biome":fixed_run.spawn.biome})
	var landmark_b := Session.new(store)
	check(landmark_b.resume(fixed_run_b.run_id) and landmark_b.interact(fixed.instance_id), "Same fixed chest can be opened in an independent run")
	check(landmark_b.run.state.inventory["core:keepsake"].instances[0].instance_id != keepsake.instances[0].instance_id, "Individual item IDs are independent across runs")
	# A new type registered through data becomes a rule with no gameplay code edits.
	var custom := {"content_id": "test:custom_reeds", "version": 1, "schema_version": 1, "kind": "resource", "name": "Blue reeds", "payload": {"interaction": "gather", "visual": "unknown_custom_visual", "spawn": {"biomes": ["meadow"], "per_10000":10000, "priority":-10}, "loot": {"rolls":1,"entries":[{"content_id":"core:fiber","version":1,"min":1,"max":1,"weight":1}]}}, "dependencies":[{"content_id":"core:fiber","version":1}]}
	check(not store.content.register_definition(world.world_id, custom).is_empty(), "Register new resource type through structured data")
	var extended := Session.new(store)
	check(extended.resume(run_a_id), "Reload session to activate newly registered data rules")
	var custom_found := false
	for objects in extended.objects.chunks.values():
		for instance in objects:
			custom_found = custom_found or instance.content_id == "test:custom_reeds"
	check(custom_found, "New resource type spawns through existing generic generator")
	extended.objects.follow(resource_point)
	check(extended.objects.find(resource_id).content_id == gathering.instance.content_id and extended.is_consumed(resource_id), "New rules cannot replace a materialized depleted object")
	check(store._db.rows("PRAGMA foreign_key_check").is_empty() and store._db.rows("PRAGMA user_version")[0].user_version == 2, "No FK violations and no SQLite migration required")
	store.close()

func _test_inventory() -> void:
	var store := Store.new()
	store.open(directory + "/inventory.sqlite")
	var world := store.create_world("Inventory", 7)
	Pack.new().install(store.content, world.world_id)
	var inventory := Inventory.new()
	var result := inventory.award(store.content, world.world_id, {}, [{"content_id":"core:wood","version":1,"quantity":53}], "run:test/source/a")
	check(not result.is_empty() and result.inventory["core:wood"].quantity == 53 and result.inventory["core:wood"].stacks == [50, 3], "Stack limit splits 53 wood into 50+3")
	result = inventory.award(store.content, world.world_id, result.inventory, [{"content_id":"core:wood","version":1,"quantity":49}], "run:test/source/b")
	check(result.inventory["core:wood"].quantity == 102 and result.inventory["core:wood"].stacks == [50, 50, 2], "Awards merge partial stacks before creating another")
	var legacy := {"core:wood": {"version": 1, "quantity": 4, "legacy_note": "keep"}}
	result = inventory.award(store.content, world.world_id, legacy, [{"content_id":"core:wood","version":1,"quantity":3}], "run:test/source/c")
	check(result.inventory["core:wood"].quantity == 7 and result.inventory["core:wood"].legacy_note == "keep" and not legacy["core:wood"].has("stacks"), "Legacy B stack entries extend without loss or input mutation")
	var unique_loot := [{"content_id":"core:keepsake","version":1,"quantity":2}]
	result = inventory.award(store.content, world.world_id, {}, unique_loot, "run:test/source/chest")
	var unique: Dictionary = result.inventory["core:keepsake"]
	check(unique.quantity == 2 and unique.instances.size() == 2 and unique.instances[0].instance_id != unique.instances[1].instance_id, "Non-stackable items have separate stable IDs")
	check(inventory.award(store.content, world.world_id, result.inventory, unique_loot, "run:test/source/chest").is_empty(), "Duplicate individual item award is rejected")
	var rows := inventory.rows(store.content, world.world_id, result.inventory)
	check(rows.size() == 1 and rows[0].name == "Traveler's keepsake" and not rows[0].description.is_empty() and rows[0].type == "keepsake", "Inventory exposes name, description, quantity and item type")
	check(inventory.award(store.content, world.world_id, {}, [{"content_id":"missing:item","version":1,"quantity":1}], "bad").is_empty(), "Missing loot item rejected before inventory changes")
	check(inventory.award(store.content, world.world_id, {"core:wood":{"version":1,"quantity":2,"stacks":[1]}}, [{"content_id":"core:wood","version":1,"quantity":1}], "bad").is_empty(), "Corrupt stack totals rejected instead of silently repaired")
	var table := {"rolls":1,"entries":[{"content_id":"core:wood","version":1,"min":1,"max":1,"weight":1},{"content_id":"core:coin","version":1,"min":1,"max":1,"weight":9}]}
	var loot := Loot.new()
	check(loot.validate(table, store.content, world.world_id), "Weighted loot table validates active pinned item references")
	var coins := 0
	for index in 1000:
		if loot.roll(table, "weighted-test-" + str(index))[0].content_id == "core:coin":
			coins += 1
	check(coins > 830 and coins < 960, "9:1 weight materially changes selection frequencies")
	check(Helpers.same(loot.roll(table, "repeat"), loot.roll(table, "repeat")), "Loot draw is repeatable without shared RNG")
	table.entries[0].weight = 0
	check(not loot.validate(table, store.content, world.world_id), "Invalid zero weight rejected clearly")
	var malformed := {"content_id":"test:invalid_visual","version":1,"schema_version":1,"kind":"resource","name":"Invalid visual","payload":{"visual":42,"interaction":"gather","loot":{"rolls":1,"entries":[{"content_id":"core:wood","version":1,"min":1,"max":1,"weight":1}]}},"dependencies":[{"content_id":"core:wood","version":1}]}
	store.content.register_definition(world.world_id, malformed)
	var rejected := Session.new(store)
	check(not rejected.start_new(world.world_id, 3) and rejected.last_error.contains("visual"), "Malformed visual data cannot reach the renderer")
	store.close()

func _test_restart() -> void:
	for phase in ["write", "read"]:
		var output: Array = []
		var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/interaction_restart_probe.gd", "--", phase, directory + "/restart.json"]
		var code := OS.execute(OS.get_executable_path(), args, output, true)
		print("Interaction restart ", phase, ": ", output)
		check(code == 0 and str(output).contains("INTERACTION RESTART PASS"), "Separate-process inventory/consumption persistence " + phase)

func _test_legacy() -> void:
	var store := Store.new()
	store.open(directory + "/legacy-c.sqlite")
	var world := store.create_world("Legacy C", -77)
	store.content.register_definition(world.world_id, Mock.herb())
	var terrain := Terrain.new()
	terrain.configure(-77, 1)
	var run := store.create_run(world.world_id, 44, Spawn.select(terrain, 44, "meadow"), "normal", {"hp":12, "custom_stat":3})
	run.state.inventory = {"mock:moonleaf":{"version":1,"quantity":4,"legacy_note":"preserve"}}
	run.state.character["legacy_character_note"] = "keep"
	run.state.explored = [run.state.character.position.duplicate(true)]
	check(store.save_run(run.run_id, 0, run.state) and store.content.list_definitions(world.world_id).size() == 1, "Prepare populated pre-D schema-2 Run without starter pack")
	store.close()
	store.open(directory + "/legacy-c.sqlite")
	var session := Session.new(store)
	check(session.resume(run.run_id), "Existing C Run upgrades through additive content installation")
	var found := Helpers.route_to_object(session, "gather")
	var worked := not found.is_empty() and Helpers.walk(session, found.route) and session.interact(found.instance.instance_id) and session.save()
	var loaded: Dictionary = store.load_run(run.run_id)
	check(worked and Helpers.same(loaded.state.inventory["mock:moonleaf"], run.state.inventory["mock:moonleaf"]) and Helpers.same(loaded.state.character.stats, run.state.character.stats) and loaded.state.character.legacy_character_note == "keep" and Helpers.same(store.load_world(world.world_id), world), "New interaction/save preserves legacy inventory, stats, extra data and Blueprint")
	store.close()
