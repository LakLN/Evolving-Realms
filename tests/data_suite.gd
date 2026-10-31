extends SceneTree
const Store = preload("res://src/data/game_store.gd")
const Database = preload("res://src/data/database.gd")
const Data = preload("res://src/data/json_data.gd")
const Mock = preload("res://src/content/mock_provider.gd")
var failures := 0
var checks := 0
var directory := ""

func _initialize() -> void:
	directory = ProjectSettings.globalize_path("user://checkpoint_b_tests/" + Data.uuid())
	DirAccess.make_dir_recursive_absolute(directory)
	print("Test artifacts: ", directory)
	_test_repository()
	_test_migration()
	_test_rejection()
	_test_restart()
	print("CHECKPOINT B: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)
	else:
		print("PASS: ", label)

func same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return a == b
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not same(a[key], b[key]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for index in a.size():
			if not same(a[index], b[index]):
				return false
		return true
	return a == b

func _test_repository() -> void:
	var store := Store.new()
	check(store.open(directory + "/repository.sqlite"), "Open native SQLite: " + store.last_error)
	var blueprint := {"fixed_locations": [{"id": "ruin:old", "position": {"x": -90, "y": 300}}], "metadata": {"history": "An ancient coast"}}
	var world := store.create_world("Test ' world; DROP TABLE worlds; --", -2147483648, 1, blueprint)
	check(not world.is_empty(), "Create seeded world with bound SQL text")
	if world.is_empty():
		printerr(store.last_error)
		store.close()
		return
	var world_id: String = world.world_id
	check(same(world, store.load_world(world_id)), "World round trip exactly")
	check(world.world_id.length() == 36 and world.generation_version == 1, "UUID and generation version")
	check(store.create_world("bad", 0, 99).is_empty(), "Unknown generator rejected")
	check(store.create_world("bad", 2147483648).is_empty(), "Out-of-range seed rejected")
	var other := store.create_world("Other world", 7)
	check(store.list_worlds().size() == 2, "Multiple worlds")
	var herb := store.content.register_definition(world_id, Mock.herb())
	check(not herb.is_empty() and herb.status == "active", "Mock definition validates and registers")
	check(same(herb, store.content.load_definition(world_id, "mock:moonleaf", 1)), "Definition reload includes metadata and provenance")
	check(store.content.register_definition(world_id, Mock.herb()).is_empty(), "Duplicate immutable content version rejected")
	var version2 := Mock.herb()
	version2.version = 2
	version2.name = "Moonleaf II"
	check(not store.content.register_definition(world_id, version2).is_empty(), "New definition version appended")
	check(store.content.load_definition(world_id, "mock:moonleaf", 1).name == "Moonleaf", "Old version remains pinned")
	var missing := Mock.herb()
	missing.content_id = "mock:missing"
	missing.dependencies = [{"content_id": "unknown:item", "version": 1}]
	check(store.content.register_definition(world_id, missing).is_empty() and store.last_error.contains("Missing dependency"), "Dangling dependency rejected clearly")
	check(store.content.load_definition(world_id, "mock:missing", 1).is_empty(), "Rejected registration leaves no partial definition")
	var self_ref := Mock.herb()
	self_ref.dependencies = [{"content_id": "mock:moonleaf", "version": 1}]
	self_ref.version = 3
	check(store.content.register_definition(world_id, self_ref).is_empty(), "Self-dependency rejected")
	var resource := Mock.herb()
	resource.content_id = "mock:moonleaf_patch"
	resource.kind = "resource"
	resource.dependencies = [{"content_id": "mock:moonleaf", "version": 1}]
	check(not store.content.register_definition(world_id, resource).is_empty(), "Valid pinned dependency")
	var egg := store.content.register_definition(world_id, Mock.spirit_egg())
	check(not egg.is_empty() and egg.status == "pending_capability" and egg.missing_capabilities.size() == 2, "Unsupported AI idea persisted as pending")
	var dependent := Mock.herb()
	dependent.content_id = "mock:egg_quest"
	dependent.dependencies = [{"content_id": "mock:spirit_egg", "version": 1}]
	check(store.content.register_definition(world_id, dependent).status == "pending_capability", "Pending dependency cannot become active")
	var instance := {"instance_id": "chunk:-1/0/herb_4", "content_id": "mock:moonleaf_patch", "version": 1, "position": {"x": -28, "y": 7}, "origin": "procedural", "metadata": {"generation_version": 1}}
	check(not store.content.create_instance(world_id, instance).is_empty(), "Persistent procedural instance separate from definition")
	var ai_instance := instance.duplicate(true)
	ai_instance.instance_id = "ai:moonleaf_1"
	ai_instance.origin = "ai"
	check(not store.content.create_instance(world_id, ai_instance).is_empty(), "AI-added fixed instance persists")
	var pending_instance := instance.duplicate(true)
	pending_instance.instance_id = "ai:egg_1"
	pending_instance.content_id = "mock:spirit_egg"
	check(store.content.create_instance(world_id, pending_instance).is_empty(), "Pending content cannot instantiate")
	check(store.content.create_instance(other.world_id, instance).is_empty(), "Cross-world definition reference rejected")
	var unknown_kind := Mock.herb()
	unknown_kind.content_id = "mock:portal"
	unknown_kind.kind = "dimensional_portal"
	check(store.content.register_definition(world_id, unknown_kind).status == "pending_capability", "Unknown mechanic kind is retained pending")
	var bad_definition := Mock.herb()
	bad_definition.content_id = "mock:bad_schema"
	bad_definition.schema_version = 99
	check(store.content.register_definition(world_id, bad_definition).is_empty(), "Future content schema rejected")
	bad_definition = Mock.herb()
	bad_definition.content_id = "mock:bad_data"
	bad_definition.payload = {"position": Vector2i(1, 2)}
	check(store.content.register_definition(world_id, bad_definition).is_empty(), "Engine object in proposed JSON rejected")
	bad_definition = Mock.herb()
	bad_definition.content_id = "mock:bad_number"
	bad_definition.payload = {"value": INF}
	check(store.content.register_definition(world_id, bad_definition).is_empty(), "Nonfinite proposed data rejected")
	bad_definition = Mock.herb()
	bad_definition.content_id = "mock:duplicate_dependency"
	bad_definition.dependencies = [{"content_id": "mock:moonleaf", "version": 1}, {"content_id": "mock:moonleaf", "version": 1}]
	check(store.content.register_definition(world_id, bad_definition).is_empty(), "Duplicate dependency rejected")
	check(store.content.register_definition(other.world_id, resource).is_empty(), "Dependency cannot resolve from another world")
	for status in ["draft", "hidden", "invalid_conflicted"]:
		var inactive := Mock.herb()
		inactive.content_id = "mock:" + status
		inactive.status = status
		check(store.content.register_definition(world_id, inactive).status == status, "Preserve content status " + status)
		var inactive_instance := instance.duplicate(true)
		inactive_instance.instance_id = "status:" + status
		inactive_instance.content_id = inactive.content_id
		check(store.content.create_instance(world_id, inactive_instance).is_empty(), "Inactive content does not instantiate: " + status)
	var spawn := {"position": {"x": -28, "y": 8}, "biome": "forest"}
	var run_a := store.create_run(world_id, 101, spawn, "normal", {"hp": 12})
	var run_b := store.create_run(world_id, 202, {"position": {"x": 60, "y": -8}, "biome": "beach"})
	check(not run_a.is_empty() and not run_b.is_empty() and run_a.run_id != run_b.run_id, "Two independent run UUIDs")
	check(run_a.seed != run_b.seed and not same(run_a.spawn, run_b.spawn), "Separate run seeds and spawn records")
	check(store.list_runs(world_id).size() == 2, "Run listing retains both runs")
	check(store.create_run("unknown", 3, spawn).is_empty(), "Unknown parent world rejected")
	var state: Dictionary = run_a.state.duplicate(true)
	state.turn = 8
	state.character.position = {"x": -28, "y": 7}
	state.inventory = {"mock:moonleaf": {"version": 1, "quantity": 3}}
	state.explored = [{"x": -28, "y": 7}]
	state.entity_mutations = {"chunk:-1/0/herb_4": {"collected": true}}
	check(store.save_run(run_a.run_id, 0, state), "Atomic run save: " + store.last_error)
	check(same(store.load_run(run_a.run_id).state, state), "Run state round trip")
	check(same(store.load_run(run_b.run_id), run_b), "Run A mutation leaves Run B unchanged")
	check(same(store.load_world(world_id), world), "Run mutation leaves World Blueprint unchanged")
	check(same(store.content.load_instance(world_id, instance.instance_id), instance), "Collected state leaves fixed instance unchanged")
	check(not store.save_run(run_a.run_id, 0, run_a.state) and store.last_error.contains("Stale"), "Stale snapshot cannot overwrite newer save")
	var bad_state := state.duplicate(true)
	bad_state.inventory["missing:item"] = {"version": 1, "quantity": 1}
	check(not store.save_run(run_a.run_id, 1, bad_state), "Invalid inventory reference rejected")
	bad_state = state.duplicate(true)
	bad_state.entity_mutations["unknown:entity"] = {"opened": true}
	check(not store.save_run(run_a.run_id, 1, bad_state), "Unknown instance mutation rejected")
	var foreign_definition := store.content.register_definition(other.world_id, Mock.herb())
	check(not foreign_definition.is_empty(), "Same content ID can be scoped to another world")
	var foreign_instance := instance.duplicate(true)
	foreign_instance.instance_id = "other:only"
	foreign_instance.content_id = "mock:moonleaf"
	store.content.create_instance(other.world_id, foreign_instance)
	bad_state = state.duplicate(true)
	bad_state.entity_mutations["other:only"] = {}
	check(not store.save_run(run_a.run_id, 1, bad_state), "Cross-world mutation rejected")
	bad_state = state.duplicate(true)
	bad_state.turn = -1
	check(not store.save_run(run_a.run_id, 1, bad_state), "Negative turn rejected")
	# Force a late SQL failure after UPDATE and DELETE to verify real rollback.
	check(store._db.execute("CREATE TRIGGER fail_mutation BEFORE INSERT ON run_entity_states BEGIN SELECT RAISE(ABORT,'injected failure'); END"), "Install rollback fault injection")
	bad_state = state.duplicate(true)
	bad_state.turn = 999
	check(not store.save_run(run_a.run_id, 1, bad_state) and store.last_error.contains("injected failure"), "Late transaction failure surfaced")
	var after_failure := store.load_run(run_a.run_id)
	check(after_failure.revision == 1 and same(after_failure.state, state), "Rollback restores run and entity mutations together")
	store._db.execute("DROP TRIGGER fail_mutation")
	var dead_run := store.create_run(world_id, 303, spawn, "permadeath")
	dead_run.state.status = "dead"
	check(store.save_run(dead_run.run_id, 0, dead_run.state), "Persist dead status without implementing combat")
	dead_run.state.status = "alive"
	check(not store.save_run(dead_run.run_id, 1, dead_run.state), "Dead permadeath save cannot be resurrected")
	store.close()
	check(store.open(directory + "/repository.sqlite"), "Reopen existing SQLite")
	check(same(store.load_world(world_id), world) and same(store.load_run(run_a.run_id).state, state), "World and run survive connection restart")
	check(same(store.load_run(run_b.run_id), run_b), "Independent run survives connection restart")
	check(store.content.list_instances(world_id).size() == 2 and store.content.load_definition(world_id, "mock:spirit_egg", 1).status == "pending_capability", "Content and pending ideas survive restart")
	check(store._db.rows("PRAGMA foreign_key_check").is_empty(), "No foreign key violations")
	check(store._db.rows("PRAGMA integrity_check")[0].integrity_check == "ok", "SQLite integrity check")
	var peer := Store.new()
	check(peer.open(directory + "/repository.sqlite"), "Second native connection")
	var peer_snapshot := peer.load_run(run_a.run_id)
	check(store.save_run(run_a.run_id, 1, state), "Save with another connection open")
	check(not peer.save_run(run_a.run_id, peer_snapshot.revision, peer_snapshot.state) and peer.last_error.contains("Stale"), "Stale save rejected across two connections")
	peer.close()
	store.close()
	check(store.load_world(world_id).is_empty() and store.last_error.contains("not open"), "Closed-store access reports unavailable database")

func _fixture(path: String, version: int) -> Object:
	var db: Object = ClassDB.instantiate("SQLite")
	db.path = path
	db.verbosity_level = 0
	check(db.open_db(), "Open fixture database")
	check(db.query(FileAccess.get_file_as_string(Database.MIGRATIONS[0])), "Create genuine v1 schema fixture")
	check(db.query("PRAGMA user_version=%d" % version), "Set fixture schema version")
	return db

func _test_migration() -> void:
	var path := directory + "/migration.sqlite"
	var raw := _fixture(path, 1)
	var blueprint := {"fixed_locations": [], "metadata": {"legacy": true}}
	check(raw.query_with_bindings("INSERT INTO worlds VALUES(?,?,?,?,?,?,?)", ["legacy-world", "Legacy", 45, 1, 1, JSON.stringify(blueprint), "2026-01-01T00:00:00Z"]), "Seed v1 world before migration")
	var old_state := {"status": "alive", "turn": 4, "character": {"position": {"x": 2, "y": 3}, "stats": {}}, "inventory": {}, "explored": []}
	check(raw.query_with_bindings("INSERT INTO runs VALUES(?,?,?,?,?,?,?,?)", ["legacy-run", "legacy-world", 99, 1, "normal", JSON.stringify({"position": {"x": 2, "y": 3}, "biome": "forest"}), JSON.stringify(old_state), "2026-01-01T00:00:00Z"]), "Seed v1 run before migration")
	raw.close_db()
	var store := Store.new()
	check(store.open(path), "Migrate populated v1 -> v2: " + store.last_error)
	var legacy := store.load_run("legacy-run")
	check(legacy.revision == 0 and legacy.state.turn == 4 and legacy.state.entity_mutations.is_empty(), "Migration preserves run and adds revision")
	check(same(store.load_world("legacy-world").blueprint, blueprint), "Migration preserves world data")
	check(FileAccess.file_exists(store.last_backup_path), "Pre-migration backup exists")
	var backup_path := store.last_backup_path
	raw = ClassDB.instantiate("SQLite")
	raw.path = backup_path
	check(raw.open_db() and raw.query("PRAGMA user_version"), "Backup is valid SQLite")
	check(raw.query_result[0].user_version == 1, "Backup retains original version")
	raw.query("SELECT state_json FROM runs WHERE run_id='legacy-run'")
	check(same(JSON.parse_string(raw.query_result[0].state_json), old_state), "Backup retains exact original run state")
	raw.close_db()
	var saved := store.save_run("legacy-run", 0, legacy.state)
	check(saved, "Migrated run remains writable: " + store.last_error)
	store.close()
	check(store.open(path) and store.last_backup_path.is_empty(), "Migration is idempotent on next startup")
	store.close()

func _test_rejection() -> void:
	var path := directory + "/future.sqlite"
	var raw := _fixture(path, 99)
	raw.close_db()
	var before := FileAccess.get_sha256(path)
	var store := Store.new()
	check(not store.open(path) and store.last_error.contains("Unsupported database"), "Future database version refused")
	check(FileAccess.get_sha256(path) == before, "Refused future database byte-for-byte unchanged")
	path = directory + "/broken-migration.sqlite"
	raw = _fixture(path, 1)
	raw.query("CREATE TABLE content_definitions(conflict TEXT)")
	raw.close_db()
	check(not store.open(path) and store.last_error.contains("Migration"), "Conflicted migration fails explicitly")
	raw = ClassDB.instantiate("SQLite")
	raw.path = path
	raw.open_db()
	raw.query("PRAGMA user_version")
	check(raw.query_result[0].user_version == 1, "Failed migration leaves old version")
	raw.query("PRAGMA table_info(runs)")
	var columns: Array = raw.query_result
	check(columns.size() == 8, "Failed migration rolls back added revision column")
	raw.close_db()
	path = directory + "/unversioned.sqlite"
	raw = _fixture(path, 0)
	raw.close_db()
	check(not store.open(path) and store.last_error.contains("Unversioned"), "Nonempty unversioned database refused")
	check(not store.open("res://forbidden.sqlite"), "Read-only resource path rejected")

func _test_restart() -> void:
	var manifest := directory + "/restart.json"
	for phase in ["write", "read"]:
		var output: Array = []
		var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/restart_probe.gd", "--", phase, manifest]
		var code := OS.execute(OS.get_executable_path(), args, output, true)
		print("Restart child ", phase, ": ", output)
		check(code == 0 and str(output).contains("RESTART PASS") and not str(output).contains("SCRIPT ERROR"), "Separate application process " + phase)
