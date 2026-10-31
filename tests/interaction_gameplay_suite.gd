extends SceneTree
const Data = preload("res://src/data/json_data.gd")
const Helpers = preload("res://tests/interaction_helpers.gd")
var app: Control
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func _run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = ProjectSettings.globalize_path("user://checkpoint_d_tests/ui-" + Data.uuid() + ".sqlite")
	root.add_child(app)
	await process_frame
	app._name_entry.text = "Living coast"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	app._run_seed.text = "101"
	app._biome.select(3)
	app._new_run.pressed.emit()
	await process_frame
	check(app.session != null, "Start real menu Run with objects")
	if app.session == null:
		app.free()
		quit(1)
		return
	var run_id: String = app.session.run.run_id
	var resource := Helpers.route_to_object(app.session, "gather")
	check(not resource.is_empty(), "Find resource through actual generated map")
	if resource.is_empty():
		app.free()
		quit(1)
		return
	for tile in resource.route:
		app.move_player(tile - app.session.position)
		await process_frame
	check(app._interaction_hint.text.begins_with("E: Gather") or app._interaction_hint.text.begins_with("E: Pick"), "HUD indicates an available interaction")
	var target: Dictionary = app.session.interaction_target()
	var turn := int(app.session.run.state.turn)
	await _capture("checkpoint-d-resources.png")
	await _key(KEY_E)
	check(app.session.is_consumed(target.instance_id) and int(app.session.run.state.turn) == turn + 1, "Real E key harvests and consumes one turn")
	check(app._notice.text.begins_with("Received:") and not app.session.run.state.inventory.is_empty(), "Receiving items is reported in UI")
	await _key(KEY_I)
	check(app._inventory_panel.visible and app._inventory_list.item_count > 0, "Real I key opens populated inventory")
	check(not app._inventory_detail.text.is_empty() and app._inventory_detail.text.contains("Quantity"), "Inventory displays quantity/type/description")
	var position: Vector2i = app.session.position
	turn = int(app.session.run.state.turn)
	await _key(KEY_RIGHT)
	check(app.session.position == position and int(app.session.run.state.turn) == turn, "Inventory navigation does not move player or spend turns")
	await _capture("checkpoint-d-inventory.png")
	await _key(KEY_ESCAPE)
	check(not app._inventory_panel.visible and not app._menu.visible, "Esc closes inventory while staying on map")
	var chest := Helpers.route_to_object(app.session, "open")
	check(not chest.is_empty(), "Find chest in streamed map")
	if not chest.is_empty():
		for tile in chest.route:
			app.move_player(tile - app.session.position)
			await process_frame
		# E chooses a deterministic nearest target; consume any nearer resource first.
		for _attempt in 5:
			if app.session.is_consumed(chest.instance.instance_id):
				break
			await _key(KEY_E)
		check(app.session.is_consumed(chest.instance.instance_id) and app.session.run.state.entity_mutations[chest.instance.instance_id].opened, "Real E flow opens chest and receives its loot")
		await _capture("checkpoint-d-opened-chest.png")
	var inventory: Dictionary = app.session.run.state.inventory.duplicate(true)
	var mutations: Dictionary = app.session.run.state.entity_mutations.duplicate(true)
	await _key(KEY_F5)
	check(not app.session.dirty and app._notice.text.contains("Saved"), "F5 persists gathered items and opened chest")
	await _key(KEY_ESCAPE)
	app._resume.pressed.emit()
	await process_frame
	check(Helpers.same(app.session.run.state.inventory, inventory) and Helpers.same(app.session.run.state.entity_mutations, mutations), "Continue restores inventory and all consumed object states")
	await _key(KEY_I)
	check(app._inventory_panel.visible and app._inventory_list.item_count == inventory.size(), "Restored items are visible in inventory UI")
	await _key(KEY_I)
	app._return_to_menu()
	app._run_seed.text = "202"
	app._new_run.pressed.emit()
	await process_frame
	check(app.session.run.run_id != run_id and app.session.run.state.inventory.is_empty() and app.session.run.state.entity_mutations.is_empty(), "New UI run starts with reset object states and empty inventory")
	check(Helpers.same(app.store.load_run(run_id).state.inventory, inventory), "New run leaves previous inventory intact")
	app._return_to_menu()
	app.free()
	print("CHECKPOINT D GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)

func _key(key: int) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.tools/" + filename)) == OK, "Capture native renderer " + filename)
