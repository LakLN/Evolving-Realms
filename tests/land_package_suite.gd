extends SceneTree
const Package = preload("res://src/content/land_package.gd")
const Store = preload("res://src/data/game_store.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const Data = preload("res://src/data/json_data.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	var manifest := Package.read_manifest("res://content/land_packages/snow_mountain/manifest.json")
	var result := Package.inspect(manifest)
	check(result.valid and not result.ready and result.blockers.size() > 15, "Real draft resumes with explicit unfinished work")
	var bad := manifest.duplicate(true)
	bad.schema_version = 9
	check(not Package.inspect(bad).valid, "Unknown schema refused")
	bad = manifest.duplicate(true)
	bad.workflow_version = 9
	check(not Package.inspect(bad).valid, "Unknown workflow refused")
	bad = manifest.duplicate(true)
	bad.entries[0].depends_on = ["snow:absent"]
	check(not Package.inspect(bad).valid, "Missing references refused")
	bad.entries[0].depends_on = [bad.entries[1].id]
	bad.entries[1].depends_on = [bad.entries[0].id]
	check(not Package.inspect(bad).valid, "Cyclic dependencies refused")
	bad = manifest.duplicate(true)
	bad.entries.append(bad.entries[0])
	check(not Package.inspect(bad).valid, "Duplicate IDs refused")
	bad = manifest.duplicate(true)
	bad.stage = "published"
	check(not Package.inspect(bad).valid and not Package.inspect(bad).ready, "Cannot publish unfinished package")
	var store := Store.new()
	var database := ProjectSettings.globalize_path("user://m05-package-tests/" + Data.uuid() + ".sqlite")
	check(store.open(database), "Disposable DB")
	var world := Atlas.create_world(store, "Package fixture", 4242)
	var atlas := Atlas.new()
	if world.is_empty() or not atlas.open(store.content, world):
		check(false, "Open fixture atlas")
		return _finish()
	var land: Dictionary = {}
	for plan in atlas.lands.values():
		if plan.archetype == "frost_highlands": land = plan
	var before := JSON.stringify(atlas.lands, "", true)
	var complete := manifest.duplicate(true)
	complete.binding = {"world_id": world.world_id, "land_id": land.land_id, "plan_sha256": JSON.stringify(land, "", true).sha256_text()}
	complete.entries = [{"id": "snow:fixture", "version": 1, "kind": "asset", "source": "test", "status": "complete", "depends_on": [], "evidence": "fixture only", "path": "res://assets/game/icons/water.png"}]
	for gate in ["design", "assets", "automated_validation", "human_playtest", "publication"]:
		complete.approvals[gate] = {"by": "test-fixture-not-real-review", "evidence": "synthetic"}
	check(Package.inspect(complete, atlas).ready, "Bound synthetic complete package can pass report")
	complete.entries[0].path = "res://assets/game/missing-snow.png"
	check(not Package.inspect(complete, atlas).ready, "Claimed complete missing art blocked")
	complete.entries[0].path = "res://assets/game/icons/water.png"
	complete.entries[0].kind = "content"
	complete.entries[0].content_id = "snow:missing"
	complete.entries[0].content_version = 1
	check(not Package.inspect(complete, atlas).ready, "Nonexistent registry definition blocks")
	complete.entries[0].content_id = "core:atlas/land"
	check(Package.inspect(complete, atlas).ready, "Active pinned registry definition checked")
	complete.entries[0].status = "pending_capability"
	check(not Package.inspect(complete, atlas).ready, "Unsupported mechanics remain incomplete")
	complete.entries[0].status = "complete"
	complete.approvals.human_playtest = {}
	check(not Package.inspect(complete, atlas).ready, "Automated report cannot omit human review")
	complete.approvals.human_playtest = {"by": "synthetic", "evidence": "fixture only"}
	complete.binding.world_id = "other-world"
	check(not Package.inspect(complete, atlas).ready, "Cross World binding refused")
	complete.binding.world_id = world.world_id
	complete.binding.plan_sha256 = "stale"
	check(not Package.inspect(complete, atlas).ready, "Changed plan binding refused")
	check(atlas.reload() and before == JSON.stringify(atlas.lands, "", true), "Readiness never rewrites World plans")
	store.close()
	check(store.open(database) and atlas.open(store.content, world) and before == JSON.stringify(atlas.lands, "", true), "Same World preserved after database reopen")
	store.close()
	_finish()

func _finish() -> void:
	print("M05 LAND PACKAGE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
