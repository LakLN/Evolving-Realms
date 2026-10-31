extends SceneTree
## Milestone 02 Checkpoint D through the real main scene: awakening screen, talent
## sheet (T), character panel line, activation feedback, save/continue.
const Data = preload("res://src/data/json_data.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
var app: Control
var checks := 0
var failures := 0

func _initialize() -> void:
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
	app.database_path = ProjectSettings.globalize_path("user://m02d_tests/ui-" + Data.uuid() + ".sqlite")
	root.add_child(app)
	await process_frame
	app._name_entry.text = "Talent UI"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	app._biome.select(3)
	app._run_seed.text = "101"
	app._new_run.pressed.emit()
	await process_frame
	if not check(app.session != null, "Start a run from the menu"):
		return _finish()
	app.session.autosave_interval = 0
	var record: Dictionary = app.session.run.state.character.talents[0]
	var definition: Dictionary = app.session.talent_definition(record.content_id, int(record.version))
	var rank: Dictionary = app.session.talent_rules.rank(record.rank)
	check(app._talent_panel.visible and app._talent_title.text == "TALENT AWAKENED", "A new run opens the awakening screen")
	check(app._talent_rank.text == "%s · %s" % [record.rank, rank.name] and app._talent_name.text == definition.name, "Screen shows rank, Vietnamese title and talent name (%s)" % app._talent_rank.text)
	check(rank.style == "rainbow" or app._talent_rank.modulate == app.session.talent_rules.color(record.rank), "Rank is drawn in its rank color")
	check(app._talent_text.text.contains(definition.description) and app._talent_text.text.contains("never rerolled") and (definition.payload.get("abilities", []).is_empty() or app._talent_text.text.contains("• ")), "Screen lists description, effects/conditions and the no-reroll rule")
	await _capture("m02d-awakening.png")
	var turn := int(app.session.run.state.turn)
	await _key(KEY_D)
	check(int(app.session.run.state.turn) == turn and app._talent_panel.visible, "Movement waits while the awakening screen is open")
	await _key(KEY_ENTER)
	check(not app._talent_panel.visible, "Enter closes the awakening screen")
	await _key(KEY_T)
	check(app._talent_panel.visible and app._talent_title.text == "TALENT" and not app._talent_text.text.contains("never rerolled"), "T opens the talent sheet")
	await _key(KEY_ESCAPE)
	check(not app._talent_panel.visible and not app._menu.visible, "Esc closes the talent sheet without leaving the run")
	await _key(KEY_C)
	check(app._character_panel.visible and app._talent_line.text.contains("Talent: [%s · %s] %s" % [record.rank, rank.name, definition.name]) and app._talent_line.text.contains("(T: details)"), "Character panel shows the talent with rank and title")
	var panel_rect: Rect2 = app._character_panel.get_global_rect()
	check(panel_rect.position.y >= 86 and panel_rect.end.y <= app.get_viewport_rect().size.y - 100, "Character panel with the talent line still fits between the HUD bars")
	await _key(KEY_ESCAPE)
	# A stateful talent: walking into unknown land reports its finds.
	_force("core:talent/wayfarer")
	var start: Vector2i = app.session.position
	var far: Array = Acceptance.route(app.session, func(tile: Vector2i) -> bool: return absi(tile.x - start.x) + absi(tile.y - start.y) >= 45)
	var reported := false
	for tile in far:
		if not app.move_player(tile - app.session.position):
			break
		await process_frame
		if app._notice.text.contains("Lữ Khách: found Wild berries x2"):
			reported = true
			break
	check(reported and int(app.session.run.state.inventory.get("core:berries", {}).get("quantity", 0)) >= 2, "Activation feedback: \"[E] Lữ Khách: found Wild berries x2\" and the berries arrive")
	await _key(KEY_C)
	check(app._talent_line.text.contains("tiles]"), "Character panel shows the stored exploration progress (%s)" % app._talent_line.text.get_slice("\n", 0))
	await _capture("m02d-character.png")
	await _key(KEY_ESCAPE)
	var talents: Array = app.session.run.state.character.talents.duplicate(true)
	await _save_shortcut()
	await _key(KEY_ESCAPE)
	app._resume.pressed.emit()
	await process_frame
	check(app.session != null and not app._talent_panel.visible and Acceptance.same(app.session.run.state.character.talents, talents), "Continue keeps the talent and its counters; no second reveal")
	# The highest rank uses the animated rainbow style.
	_force("core:talent/fate_reversal")
	await _key(KEY_T)
	check(app._talent_rank.text == "SSS · Nghịch Thiên" and app._rainbow.any(func(entry: Array) -> bool: return entry[0] == app._talent_rank) and app._talent_text.text.contains("Limitations:"), "SSS sheet: Nghịch Thiên in rainbow with its abilities and limitations")
	await _capture("m02d-sss.png")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	app._run_seed.text = "202"
	app._new_run.pressed.emit()
	await process_frame
	check(app.session != null and app._talent_panel.visible and app.session.run.state.character.talents.size() == 1, "A second run awakens its own talent and reveals it")
	_finish()

func _force(content_id: String) -> void:
	app.session.run.state.character.talents = [app.session.talent_rules.record(app.session.talent_definition(content_id, 1), 0, int(app.session.run.state.turn))]
	app.session.reload_talents()
	app.session.dirty = true

func _finish() -> void:
	if app.session != null:
		app._return_to_menu()
	app.free()
	print("M02 CHECKPOINT D GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)

func _save_shortcut() -> void:
	var ctrl := InputEventKey.new()
	ctrl.keycode = KEY_CTRL
	ctrl.physical_keycode = KEY_CTRL
	ctrl.ctrl_pressed = true
	ctrl.pressed = true
	Input.parse_input_event(ctrl)
	await _key(KEY_S, true)
	ctrl = ctrl.duplicate()
	ctrl.ctrl_pressed = false
	ctrl.pressed = false
	Input.parse_input_event(ctrl)
	await process_frame

func _key(key: int, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.ctrl_pressed = ctrl
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
