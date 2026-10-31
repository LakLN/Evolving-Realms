extends SceneTree
const Data = preload("res://src/data/json_data.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const Inventory = preload("res://src/core/inventory.gd")
var app: Control
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_test")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func run_test() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.database_path = ProjectSettings.globalize_path("user://m02f-ui-" + Data.uuid() + ".sqlite")
	root.add_child(app)
	await process_frame
	app._name_entry.text = "Elemental field test"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	app._run_seed.text = "101"
	app._new_run.pressed.emit()
	await process_frame
	await key(KEY_ENTER)
	var session: RefCounted = app.session
	session.autosave_interval = 0
	session.run.state.character.talents = []
	session.reload_talents()
	var award := Inventory.new().award(app.store.content, session.world.world_id, session.run.state.inventory, [{"content_id": "core:book/renewal", "version": 1, "quantity": 1}, {"content_id": "core:book/purify", "version": 1, "quantity": 1}, {"content_id": "core:cinder_ring", "version": 1, "quantity": 1}, {"content_id": "core:cinder_draught", "version": 1, "quantity": 2}], "test:effect-ui-books")
	session.run.state.inventory = award.inventory
	await key(KEY_I)
	for book in ["core:book/renewal", "core:book/purify"]:
		for i in app._inventory_rows.size():
			if app._inventory_rows[i].content_id == book:
				app._inventory_list.select(i)
				app._show_inventory_item(i)
				break
		await key(KEY_U)
	check(session.run.state.character.skills.size() == 2, "Learn new skills using inventory U")
	await key(KEY_I)
	session.stats().hp = 8
	await key(KEY_1)
	check(session.last_events.any(func(e: Dictionary) -> bool: return e.type == "status_tick" and e.status == "Regeneration"), "Quick key casts Renewal and reports a HoT tick")
	await key(KEY_K)
	check(app._skill_detail.text.contains("Elements: wood") and app._skill_detail.text.contains("Regeneration"), "Skill detail explains element and status")
	check(app._target_hint.text.contains("Regeneration") and app._target_hint.text.contains("x1"), "HUD displays active player duration and stacks")
	await key(KEY_K)
	session.statuses.apply(session, {"type": "apply_status", "content_id": "core:status/burn", "version": 1}, {"content_id": "core:skill/ember", "version": 1, "actor": "player"}, "player")
	await key(KEY_2)
	check(session.last_events.any(func(e: Dictionary) -> bool: return e.type == "status_dispel" and e.status == "Burn") and not session.last_events.any(func(e: Dictionary) -> bool: return e.type == "status_tick" and e.status == "Burn"), "Purify key removes burn before it can tick")
	await key(KEY_K)
	await save_key()
	check(not session.dirty, "Save shortcut works with skills panel open")
	var statuses: Array = session.run.state.character.statuses.duplicate(true)
	var run_id: String = session.run.run_id
	await key(KEY_K)
	app._return_to_menu()
	for i in app._runs.item_count:
		if app._runs.get_item_metadata(i) == run_id:
			app._runs.select(i)
			break
	app._on_resume()
	await process_frame
	check(app.session != null and Acceptance.same(app.session.run.state.character.statuses, statuses), "Menu continue restores active status without another tick")
	await key(KEY_I)
	for item in ["core:cinder_ring", "core:cinder_draught"]:
		for i in app._inventory_rows.size():
			if app._inventory_rows[i].content_id == item:
				app._inventory_list.select(i)
				app._show_inventory_item(i)
				break
		await key(KEY_U)
	check(app.session.last_events.any(func(e: Dictionary) -> bool: return e.type == "status_tick" and e.status == "Burn" and e.amount == -1) and app.session.combat_stats().defense == 4, "Inventory equips ring and drinks draught: real fire resistance and stat buff")
	await key(KEY_I)
	var foe: Dictionary = Acceptance.nearest_creature(app.session, ["neutral", "passive", "hostile"])
	if not foe.is_empty():
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var tile: Vector2i = app.session.position + direction
			if app.session.terrain.walkable(tile) and app.session.roster.living_at(tile).is_empty():
				foe.position = tile
				app._target_id = foe.instance_id
				app.session.statuses.apply(app.session, {"type": "apply_status", "content_id": "core:status/burn", "version": 1}, {"content_id": "core:skill/ember", "version": 1, "actor": "player"}, foe.instance_id)
				app.session.dirty = true
				break
	app._update_info()
	check(app._target_hint.text.contains("Burn [fire] x1"), "Selected creature HUD shows status element, stack and remaining turns")
	await key(KEY_K)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.tools/effects-gameplay.png")) == OK, "Capture rendered status and skill UI")
	app._return_to_menu()
	app.free()
	print("M02 CHECKPOINT F GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)

func key(code: int, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.ctrl_pressed = ctrl
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func save_key() -> void:
	await key(KEY_S, true)
