extends SceneTree
const Session = preload("res://src/run/exploration_session.gd")
## Milestone 02 Checkpoint A through the real main scene, keyboard events and renderer.
const Data = preload("res://src/data/json_data.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const KEYS := {Vector2i.UP: KEY_W, Vector2i.RIGHT: KEY_D, Vector2i.DOWN: KEY_S, Vector2i.LEFT: KEY_A}
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
	app.database_path = ProjectSettings.globalize_path("user://m02a_tests/ui-" + Data.uuid() + ".sqlite")
	root.add_child(app)
	app.use_legacy_defaults() # Pre-M03 baseline: legacy World layout, turn model (see main.gd).
	await process_frame
	app._name_entry.text = "Wild frontier"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	app._biome.select(1) # forest
	app._mode.select(0) # normal
	app._run_seed.text = "101"
	app._new_run.pressed.emit()
	await process_frame
	if not check(app.session != null, "Menu starts a normal forest run"):
		return _finish()
	check(app._hp_label.text.begins_with("Lv 1   ATK 7   DEF 1") and app._hud.hp_text.text == "HP 30 / 30" and app._hp_bar.max_value == 30 and app._hp_bar.value == 30, "HUD shows level, HP 30/30 and effective ATK (5 base + 2 starting club)")
	var shortcuts: Control = app._hud.menu_bar
	var last_button: Control = shortcuts.get_child(shortcuts.get_child_count() - 1)
	check(app.get_viewport_rect().encloses(app._hud.hotbar.get_global_rect()) and last_button.get_global_rect().end.x <= app.get_viewport_rect().size.x + 0.5 and last_button.get_global_rect().end.y <= app.get_viewport_rect().size.y + 0.5, "HUD hotbar and panel shortcuts (Menu last) fit on screen")
	var turn := int(app.session.run.state.turn)
	await _key(KEY_SPACE)
	check(int(app.session.run.state.turn) == turn + 1, "Space waits exactly one turn")
	turn = int(app.session.run.state.turn)
	await _key(KEY_F)
	check(int(app.session.run.state.turn) == turn and app._notice.text.contains("Nothing to attack"), "F without a target explains and spends no turn")
	var prey := Acceptance.nearest_creature(app.session, ["neutral"])
	if not check(not prey.is_empty() and await _approach(prey.instance_id), "Walk next to a creature with movement keys"):
		return _finish()
	var id: String = prey.instance_id
	check(app._target_hint.text.contains(prey.definition.name) and app._target_hint.text.contains("neutral") and app.map_view.target_id == id, "Target panel names creature, disposition and HP; map highlights it")
	await _capture("m02a-target.png")
	var hp: int = app.session.roster.creatures[id].hp
	await _key(KEY_F)
	check(app.session.roster.creatures[id].hp < hp and app._notice.text.contains("You hit"), "F attacks the target and reports damage")
	await _capture("m02a-combat.png")
	for _round in 40:
		if app.session.roster.creatures[id].dead or app.session.is_dead():
			break
		if Acceptance.step_toward_creature(app.session, app.session.roster.creatures[id]) != Vector2i.ZERO:
			await _approach(id, 20)
		else:
			await _key(KEY_F)
	check(app.session.roster.creatures[id].dead and app._notice.text.contains("dies. Loot:"), "Killing the creature reports death and loot")
	check(not app.session.run.state.inventory.is_empty(), "Creature loot is in the inventory")
	await _save_shortcut()
	check(not app.session.dirty, "Ctrl+S saves after combat")
	var inventory: Dictionary = app.session.run.state.inventory.duplicate(true)
	await _key(KEY_ESCAPE)
	app._resume.pressed.emit()
	await process_frame
	check(app.session.roster.creatures[id].dead and Acceptance.same(app.session.run.state.inventory, inventory), "Continue keeps the creature dead and the loot once")
	await _die()
	check(app._death_panel.visible and app._death_reload.visible and app._death_text.text.contains("Normal mode"), "Normal death shows the death screen with Load last save")
	turn = int(app.session.run.state.turn)
	await _key(KEY_SPACE)
	check(int(app.session.run.state.turn) == turn, "Keys do nothing while dead")
	app._death_reload.pressed.emit()
	await process_frame
	check(not app._death_panel.visible and not app.session.is_dead() and Acceptance.same(app.session.run.state.inventory, inventory), "Load last save resumes the living save")
	await _key(KEY_ESCAPE)
	app._mode.select(1) # permadeath
	app._run_seed.text = "404"
	app._new_run.pressed.emit()
	await process_frame
	check(app.session != null and app.session.run.mode == "permadeath", "Menu starts a permadeath run")
	var ended_id: String = app.session.run.run_id
	await _die()
	check(app._death_panel.visible and not app._death_reload.visible and app._death_text.text.contains("Permadeath"), "Permadeath death screen offers no reload")
	await _capture("m02a-death.png")
	await _key(KEY_ESCAPE)
	check(app._menu.visible, "Esc on the death screen returns to menu")
	var listed := false
	for index in app._runs.item_count:
		if app._runs.get_item_metadata(index) == ended_id:
			listed = app._runs.get_item_text(index).contains("ENDED")
			app._runs.select(index)
	check(listed, "Run list marks the permadeath run as ENDED")
	app._resume.pressed.emit()
	await process_frame
	check(app.session == null and app._status.text.contains("ended"), "Ended permadeath run cannot be continued from the menu")
	_finish()

func _die() -> void:
	## Low-health setup, then provoke/fight a creature until its real attack lands.
	app.session.stats().hp = 1
	var foe := Acceptance.nearest_creature(app.session, ["neutral", "hostile"])
	if foe.is_empty():
		return
	for _round in 60:
		if app.session.is_dead():
			return
		if Acceptance.step_toward_creature(app.session, app.session.roster.creatures[foe.instance_id]) != Vector2i.ZERO:
			await _approach(foe.instance_id, 10)
		else:
			app._target_id = foe.instance_id
			await _key(KEY_F)
		if app.session.roster.creatures[foe.instance_id].dead:
			foe = Acceptance.nearest_creature(app.session, ["neutral", "hostile"])

func _approach(id: String, limit: int = 200) -> bool:
	for _step in limit:
		var creature: Dictionary = app.session.roster.creatures[id]
		if creature.dead or app.session.is_dead():
			return false
		var direction := Acceptance.step_toward_creature(app.session, creature)
		if direction == Vector2i.ZERO:
			if absi(creature.position.x - app.session.position.x) + absi(creature.position.y - app.session.position.y) == 1:
				app._target_id = id
				app._update_info()
				return true
			await _key(KEY_SPACE)
			continue
		var turn := int(app.session.run.state.turn)
		await _key(KEYS[direction])
		if int(app.session.run.state.turn) == turn:
			await _key(KEY_SPACE) # Blocked by a creature this turn.
	return false

func _finish() -> void:
	if app.session != null:
		app._return_to_menu()
	app.free()
	print("M02 CHECKPOINT A GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
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
