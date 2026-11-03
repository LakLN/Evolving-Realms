extends SceneTree
## Development preview (Milestone 05): creates a DISPOSABLE atlas World (seed 4242 unless
## --seed=N) in user://snow-preview/, proposes and validates the Snow Mountain layout land,
## prints the survey and writes .tools/snow-overview.png (2 px per tile). Never opens the
## personal database. Usage:
##   .\scripts\godot.ps1 --headless --script res://tools/snow_mountain_preview.gd '--' --seed=4242 [--activate]
const Store = preload("res://src/data/game_store.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const Survey = preload("res://src/world/land_survey.gd")
const Data = preload("res://src/data/json_data.gd")
const WorldMap = preload("res://src/ui/world_map.gd")
const LAYOUT := "landpkg:snow_mountain/layout"

func _initialize() -> void:
	var seed_value := 4242
	var activate := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_value = int(arg.trim_prefix("--seed="))
		if arg == "--activate": activate = true
	var store := Store.new()
	if not store.open(ProjectSettings.globalize_path("user://snow-preview/" + Data.uuid() + ".sqlite")):
		return _quit("open failed: " + store.last_error)
	var started := Time.get_ticks_msec()
	var world := Atlas.create_world(store, "Snow preview", seed_value)
	var atlas := Atlas.new()
	if world.is_empty() or not atlas.open(store.content, world):
		return _quit("world failed: " + store.last_error + atlas.last_error)
	print("World created in %d ms" % (Time.get_ticks_msec() - started))
	started = Time.get_ticks_msec()
	var proposal := atlas.propose_layout_land(LAYOUT)
	if proposal.is_empty():
		return _quit("proposal failed: " + atlas.last_error)
	var plan: Dictionary = proposal.land
	print("Proposed %s at slot %s rotation %d gate %s (%d ms)" % [plan.name, str(plan.slot), int(plan.layout.rotation), plan.gates[0].side, Time.get_ticks_msec() - started])
	started = Time.get_ticks_msec()
	var problem := atlas.validate(proposal)
	print("Validation: %s (%d ms)" % ["OK" if problem.is_empty() else problem, Time.get_ticks_msec() - started])
	var terrain := Atlas.TerrainAtlas.new()
	terrain.configure_atlas(seed_value, atlas.lands.values() + [plan])
	var first := Vector2i(int(plan.starts[0].position.x), int(plan.starts[0].position.y))
	var report := Survey.survey(terrain, plan, first)
	print("Survey: reached %d of %d walkable, unreached %d" % [report.reached, report.walkable, report.unreached])
	for region in plan.regions:
		print("  area %d %s: %d reachable tiles" % [region.index, region.name, int(report.by_region.get(int(region.index), 0))])
	print("  gates %s\n  starts %s\n  shelters %s" % [str(report.gates), str(report.starts), str(report.shelters)])
	print("  surfaces %s" % str(report.by_value))
	var image := Survey.overview(report.chunks, plan, WorldMap.TERRAIN_COLORS, 2)
	for start in plan.starts:
		image.fill_rect(Rect2i((Vector2i(int(start.position.x), int(start.position.y)) - Atlas.TerrainAtlas.slot_origin(Vector2i(int(plan.slot.x), int(plan.slot.y)))) * 2 - Vector2i(3, 3), Vector2i(7, 7)), Color.RED)
	image.save_png(ProjectSettings.globalize_path("res://.tools/snow-overview.png"))
	print("Wrote .tools/snow-overview.png")
	if activate and problem.is_empty():
		print("Activate: %s" % str(atlas.activate(proposal, {"by": "snow preview tool"})))
	_quit("")

func _quit(error: String) -> void:
	if not error.is_empty(): printerr(error)
	quit(0 if error.is_empty() else 1)
