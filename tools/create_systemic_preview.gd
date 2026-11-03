extends SceneTree
## Explicit, new disposable DB only. Never opens the personal database.
const Store = preload("res://src/data/game_store.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const Session = preload("res://src/run/exploration_session.gd")

func _initialize() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview-database="): path = arg.trim_prefix("--preview-database=")
	if path.is_empty() or FileAccess.file_exists(path):
		printerr("Supply --preview-database=<new disposable path>; existing files are refused")
		quit(1)
		return
	var store := Store.new()
	if not store.open(path): return _finish(store, store.last_error)
	var world := Atlas.create_world(store, "Systemic Snow preview", 4242)
	var atlas := Atlas.new()
	if world.is_empty() or not atlas.open(store.content, world): return _finish(store, store.last_error + atlas.last_error)
	var proposal := atlas.propose_layout_land("landpkg:snow_mountain/layout")
	if proposal.is_empty() or not atlas.activate(proposal, {"by": "director-authorized disposable development preview"}): return _finish(store, atlas.last_error)
	var session := Session.new(store)
	if not session.start_new(world.world_id, 919, proposal.land.land_id, "normal", "realtime-v1") or not session.save(): return _finish(store, session.last_error)
	print("PREVIEW READY: ", JSON.stringify({"database": path, "world_id": world.world_id, "run_id": session.run.run_id, "seed": 919, "layout_version": proposal.land.layout.version}))
	_finish(store, "")

func _finish(store: RefCounted, error: String) -> void:
	store.close()
	if not error.is_empty(): printerr(error)
	quit(0 if error.is_empty() else 1)
