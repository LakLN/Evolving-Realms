extends SceneTree
## Dev-only visual probe (not part of the regression): plays short runs in a temporary
## database and saves screenshots to .tools/visual-*.png for art review. It relocates the
## hero next to creatures, a chest and places (throwaway save only).
##   .\scripts\godot.ps1 --script res://tests/visual_probe.gd
const Data = preload("res://src/data/json_data.gd")
var app: Control
var shown_species := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = ProjectSettings.globalize_path("user://visual_probe/" + Data.uuid() + ".sqlite")
	root.add_child(app)
	await process_frame
	await _shot("visual-menu.png")
	app._name_entry.text = "Visual probe"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	for biome in [1, 3, 2]: # forest, meadow, beach
		app._run_seed.text = str(400 + biome)
		app._biome.select(biome)
		app._new_run.pressed.emit()
		await _frames(3)
		app._close_talent()
		var s: RefCounted = app.session
		s.autosave_interval = 0
		await _frames(4)
		await _shot("visual-biome-%d.png" % biome)
		if biome == 1:
			await _chest_and_gather(s)
		for species in ["wolf", "boar", "rabbit", "deer", "crab"]:
			if shown_species.has(species):
				continue
			var creature := _nearest_creature(s, species)
			if creature.is_empty() or not await _beside(s, {"x": creature.position.x, "y": creature.position.y}):
				continue
			shown_species[species] = true
			await _shot("visual-%s.png" % species)
			app._attack()
			await _frames(7)
			await _shot("visual-%s-hit.png" % species)
			await _frames(30)
		if biome == 1:
			var shown := 0
			for place in s.locations.loaded():
				if shown >= 2:
					break
				if await _beside(s, place.position):
					app._wait()
					await _frames(25)
					await _shot("visual-place-%d.png" % shown)
					shown += 1
			app._toggle_inventory()
			await _frames(3)
			await _shot("visual-inventory.png")
			app._toggle_inventory()
			app._toggle_character()
			await _frames(3)
			await _shot("visual-gear.png")
			app._toggle_character()
		app._return_to_menu()
		await _frames(2)
	print("species shown: ", shown_species.keys())
	app.free()
	quit(0)

func _chest_and_gather(s: RefCounted) -> void:
	var chest := _nearest(s, func(i: Dictionary) -> bool: return s.objects.definition_for(i).kind == "chest" and not s.is_consumed(i.instance_id))
	if not chest.is_empty() and await _beside(s, chest.position):
		app._interact()
		await _frames(12)
		await _shot("visual-chest-open.png")
	var herb := _nearest(s, func(i: Dictionary) -> bool: return s.objects.definition_for(i).kind == "resource" and not s.is_consumed(i.instance_id))
	if not herb.is_empty() and await _beside(s, herb.position):
		app._interact()
		await _frames(10)
		await _shot("visual-gather.png")

func _nearest_creature(s: RefCounted, visual: String) -> Dictionary:
	var found := {}
	var best := 1 << 30
	for creature in s.roster.creatures.values():
		var d: int = absi(creature.position.x - s.position.x) + absi(creature.position.y - s.position.y)
		if not creature.dead and creature.definition.payload.get("visual") == visual and d < best:
			best = d
			found = creature
	return found

func _nearest(s: RefCounted, accept: Callable) -> Dictionary:
	var found := {}
	var best := 1 << 30
	for objects in s.objects.chunks.values():
		for instance in objects:
			var d: int = absi(int(instance.position.x) - s.position.x) + absi(int(instance.position.y) - s.position.y)
			if d < best and accept.call(instance):
				best = d
				found = instance
	return found

func _beside(s: RefCounted, where: Dictionary) -> bool:
	var tile := Vector2i(int(where.x), int(where.y))
	for offset in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		if s.terrain.walkable(tile + offset) and s.relocate(tile + offset):
			app.map_view.attach(s)
			app._update_info()
			await _frames(4)
			return true
	return false

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.tools/" + name))
	print("saved ", name)
