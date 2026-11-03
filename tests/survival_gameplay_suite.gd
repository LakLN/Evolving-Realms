extends SceneTree
const Session = preload("res://src/run/exploration_session.gd")
## Milestone 02 Checkpoint B through the real main scene: HUD needs, inventory use, rest.
const Data = preload("res://src/data/json_data.gd")
const Inventory = preload("res://src/core/inventory.gd")
var app: Control
var checks := 0
var failures := 0

func _initialize() -> void:
	Session.auto_awaken = false # Baseline rules: this suite predates talents (see TALENTS.md).
	call_deferred("_run")

func check(condition: bool, label: String) -> bool:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)
	return condition

func _run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = ProjectSettings.globalize_path("user://m02b_tests/ui-" + Data.uuid() + ".sqlite")
	root.add_child(app)
	app.use_legacy_defaults() # Pre-M03 baseline: legacy World layout, turn model (see main.gd).
	await process_frame
	app._name_entry.text = "Survival UI"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	app._biome.select(3) # meadow: no hostile spawns at the start
	app._run_seed.text = "101"
	app._new_run.pressed.emit()
	await process_frame
	if not check(app.session != null, "Start a run from the menu"):
		return _finish()
	app.session.autosave_interval = 0
	check(app._survival_label.text.begins_with("Hunger 0%  Thirst 0%"), "HUD shows hunger and thirst")
	var top_row: Control = app._info.get_parent()
	var last_button: Control = top_row.get_child(top_row.get_child_count() - 1)
	await process_frame
	check(last_button.get_global_rect().end.x <= app.get_viewport_rect().size.x + 0.5 and top_row.get_global_rect().end.y <= 90, "Top HUD with survival line fits, Menu button fully visible")
	var stats: Dictionary = app.session.stats()
	stats.hunger = 640
	stats.hp = 20
	app._update_info()
	await process_frame
	check(last_button.get_global_rect().end.x <= app.get_viewport_rect().size.x + 0.5, "Widest HUD state (warning + no regen) still fits")
	check(app._survival_label.text.contains("Hunger 64%") and app._survival_label.text.contains("no regen") and app._survival_label.modulate == Color("f0c060"), "Warning state is colored and says recovery stopped")
	var award := Inventory.new().award(app.store.content, app.session.world.world_id, app.session.run.state.inventory, [{"content_id": "core:berries", "version": 1, "quantity": 3}, {"content_id": "core:wood", "version": 1, "quantity": 1}], "test:ui")
	app.session.run.state.inventory = award.inventory
	await _key(KEY_I)
	_select("core:berries")
	check(app._inventory_detail.text.contains("Use (Eat)") and app._inventory_list.get_item_text(_index("core:berries")).contains("[usable]") and not app._use_button.disabled, "Inventory shows the use, its effect and an enabled Use button")
	var turn := int(app.session.run.state.turn)
	await _key(KEY_U)
	check(app.session.run.state.inventory["core:berries"].quantity == 2 and int(app.session.run.state.turn) == turn + 1 and app._notice.text.contains("Eat: Wild berries") and app._inventory_list.get_item_text(_index("core:berries")).contains("x2"), "U eats one berry, spends one turn, reports it and refreshes the list")
	await _capture("m02b-inventory-use.png")
	_select("core:wood")
	check(app._use_button.disabled and app._inventory_detail.text.contains("No use yet"), "Unusable item shows no use and a disabled button")
	turn = int(app.session.run.state.turn)
	await _key(KEY_U)
	check(app.session.run.state.inventory["core:wood"].quantity == 1 and int(app.session.run.state.turn) == turn and app._notice.text.contains("no use"), "U on an unusable item explains and spends nothing")
	await _key(KEY_ESCAPE)
	stats.hunger = 0
	turn = int(app.session.run.state.turn)
	await _key(KEY_R)
	check(int(app.session.run.state.turn) > turn and app._notice.text.begins_with("Rested"), "R rests and reports turns and HP gained")
	await _capture("m02b-rest.png")
	_finish()

func _index(content_id: String) -> int:
	for index in app._inventory_rows.size():
		if app._inventory_rows[index].content_id == content_id:
			return index
	return -1

func _select(content_id: String) -> void:
	var index := _index(content_id)
	app._inventory_list.select(index)
	app._show_inventory_item(index)

func _finish() -> void:
	if app.session != null:
		app._return_to_menu()
	app.free()
	print("M02 CHECKPOINT B GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
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
