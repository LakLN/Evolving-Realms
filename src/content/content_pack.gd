extends RefCounted
## Curated AI content packs (Run 01): an ordered list of generation envelopes that go
## through the normal pipeline (draft -> confirm -> activate) for ONE explicit World.
## Nothing here runs during gameplay and no pack is ever installed automatically.
##
## <pack>/manifest.json: {"pack_id", "version", "title", "modules": [{"id", "file", "summary"}]}
## Each module file is an ordinary generation envelope (schema 1, request, provenance,
## content). Modules are applied in manifest order because later ones pin definitions
## of earlier ones. Applying again is a no-op; a changed module needs a new request ID.
const Pipeline = preload("res://src/content/authoring_pipeline.gd")
const Store = preload("res://src/data/game_store.gd")
const Packs = preload("res://src/content/starter_pack.gd")
const Data = preload("res://src/data/json_data.gd")
var last_error := ""

func load_pack(folder: String) -> Dictionary:
	## {manifest, modules: [{id, summary, envelope, proposal}]} or {} with last_error.
	var manifest: Variant = _json(folder.path_join("manifest.json"))
	if not manifest is Dictionary or not manifest.get("pack_id") is String or not manifest.get("modules") is Array or manifest.modules.is_empty():
		return _fail("Pack manifest needs pack_id and modules: " + folder)
	var modules: Array = []
	for entry in manifest.modules:
		if not entry is Dictionary or not entry.get("id") is String or not entry.get("file") is String:
			return _fail("Pack module needs id and file")
		var envelope: Variant = _json(folder.path_join(entry.file))
		if not envelope is Dictionary or not envelope.get("request") is Dictionary or not envelope.request.get("request_id") is String:
			return _fail("Module %s is not a generation envelope" % entry.id)
		modules.append({"id": entry.id, "summary": str(entry.get("summary", "")), "envelope": envelope,
			"proposal": "proposal:" + str(envelope.request.request_id).sha256_text().substr(0, 32)})
	return {"manifest": manifest, "modules": modules}

func status(store: RefCounted, world_id: String, pack: Dictionary) -> Array:
	## Stage of every module in this World (absent / draft / confirmed / activated / rejected).
	var tool := Pipeline.new(store)
	var result: Array = []
	for module in pack.modules:
		var proposal: Dictionary = tool.latest(world_id, module.proposal)
		result.append({"module": module.id, "proposal": module.proposal, "stage": proposal.get("payload", {}).get("stage", "absent"),
			"definitions": module.envelope.get("content", {}).get("definitions", []).size(), "summary": module.summary})
	return result

func apply(store: RefCounted, world_id: String, pack: Dictionary, only: Array = []) -> Dictionary:
	## Drafts, confirms and activates each selected module in order. Stops at the first
	## module that is invalid, pending a capability or fails to activate; earlier
	## modules stay activated (each activation is atomic on its own).
	var tool := Pipeline.new(store)
	var report: Array = []
	for module in pack.modules:
		if not only.is_empty() and module.id not in only:
			continue
		var step := {"module": module.id, "proposal": module.proposal}
		var drafted: Dictionary = tool.draft(world_id, module.envelope)
		if drafted.is_empty():
			return _halt(report, step, tool.last_error)
		step.validation = drafted.payload.report.status
		if drafted.payload.stage == "draft":
			if drafted.payload.report.status != "valid":
				return _halt(report, step, "Module is %s: %s %s" % [drafted.payload.report.status, JSON.stringify(drafted.payload.report.errors), JSON.stringify(drafted.payload.report.missing_capabilities)])
			if tool.confirm(world_id, module.proposal).is_empty():
				return _halt(report, step, tool.last_error)
		var activated: Dictionary = tool.activate(world_id, module.proposal)
		if activated.is_empty():
			return _halt(report, step, tool.last_error)
		step.stage = activated.payload.stage
		step.revision = int(activated.payload.get("encounter_revision", 0))
		report.append(step)
	last_error = ""
	return {"pack": pack.manifest.pack_id, "world": world_id, "modules": report}

func check(pack: Dictionary) -> Dictionary:
	## Dry run in a throwaway database and World (random seed): applies the whole pack
	## and lists what became playable. Never touches a real save.
	var path := ProjectSettings.globalize_path("user://pack_check/%s.sqlite" % Data.uuid())
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var store := Store.new()
	if not store.open(path):
		return _fail(store.last_error)
	var seed_value := int(randi() & 0x7fffffff)
	var world: Dictionary = store.create_world("Pack check", seed_value, 1, Packs.blueprint(seed_value))
	var result := {}
	if world.is_empty():
		result = _fail(store.last_error)
	else:
		result = apply(store, world.world_id, pack)
		if result.is_empty():
			result = {"error": last_error}
		else:
			result.registered = Pipeline.new(store).registered(world.world_id).map(func(d: Dictionary) -> String: return "%s (%s)" % [d.content_id, d.kind])
	store.close()
	for suffix in ["", "-wal", "-shm"]:
		DirAccess.remove_absolute(path + suffix)
	return result

func _halt(report: Array, step: Dictionary, message: String) -> Dictionary:
	step.error = message
	report.append(step)
	last_error = "Module %s: %s" % [step.module, message]
	return {"error": last_error, "modules": report}

func _json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 350000:
		return null
	return JSON.parse_string(file.get_as_text())

func _fail(message: String) -> Dictionary:
	last_error = message
	return {}
