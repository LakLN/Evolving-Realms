extends SceneTree
## Shared gameplay capabilities through the real main scene: creature trait parts
## (fear of a wielded element, charge, pack call, resistances) on established
## creatures via the trait overlay, and their persistence across Continue.
const Data = preload("res://src/data/json_data.gd")
const Inventory = preload("res://src/core/inventory.gd")
const Traits = preload("res://src/core/creature_traits.gd")
const Effects = preload("res://src/core/effects.gd")
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
	app.database_path = ProjectSettings.globalize_path("user://systems_tests/systems-" + Data.uuid() + ".sqlite")
	root.add_child(app)
	app.use_legacy_defaults()
	await process_frame
	app._name_entry.text = "Systems"
	app._world_seed.text = "1847"
	app._create_world.pressed.emit()
	app._biome.select(1)
	app._run_seed.text = "101"
	app._new_run.pressed.emit()
	await process_frame
	if not check(app.session != null, "Start a forest run"):
		return _finish()
	await _key(KEY_ENTER)
	var s: RefCounted = app.session
	s.autosave_interval = 0
	s.run.state.character.talents = []
	s.reload_talents()
	check(Traits.validate(Traits.rules()).is_empty() and Traits.of(s._definition("core:wolf", 1)).names == ["Fears fire", "Pack caller"] and not Traits.of(s._definition("core:boar", 1)).charge.is_empty(), "Trait overlay gives established wolves fear of fire + pack call, boars a charge")
	# --- Resistances through the shared effect engine --------------------------
	var crab: Dictionary = {"hp": 8, "max_hp": 8, "statuses": [], "modifiers": Traits.of(s._definition("core:shore_crab", 1)).effect_modifiers}
	var hero: Dictionary = {"hp": 30, "max_hp": 30, "statuses": [], "modifiers": []}
	check(Effects.damage(20, ["neutral"], hero, crab) == 15 and Effects.damage(20, ["lightning"], hero, crab) == 30, "Hard shell: blades deal 25% less, lightning 50% more")
	var coat: Dictionary = {"hp": 16, "max_hp": 16, "statuses": [], "modifiers": Traits.of({"content_id": "snow:scree_wolf"}).effect_modifiers}
	check(Effects.damage(20, ["fire"], hero, coat) == 30 and Effects.damage(20, ["ice"], hero, coat) == 10, "Thick coat: fire bites deeper, cold barely touches")
	# --- Fear of a wielded element ---------------------------------------------
	var wolf := _creature(s, "core:wolf")
	if check(not wolf.is_empty() and _place(s, wolf, 3), "A grey wolf three tiles away in the open"):
		var plain: Dictionary = s.roster.decide(s, wolf, "test/fear/0")
		check(plain.type in ["move", "charge"] and plain.state == "chase", "Facing a club, the wolf closes in")
		var kit: Dictionary = Inventory.new().award(app.store.content, s.world.world_id, s.run.state.inventory, [{"content_id": "core:tallow_torch", "version": 1, "quantity": 1}], "test:systems-torch")
		s.run.state.inventory = kit.inventory
		check(s.equip_item("core:tallow_torch", s.run.state.inventory["core:tallow_torch"].instances[0].instance_id), "Equip a tallow torch")
		_place(s, wolf, 3)
		var wary: Dictionary = s.roster.decide(s, wolf, "test/fear/1")
		check(wary.type == "wait" and wary.state == "wary", "Facing fire, the wolf holds its distance and watches")
		_place(s, wolf, 2)
		var back: Dictionary = s.roster.decide(s, wolf, "test/fear/2")
		check(back.type == "move" and absi(back.to.x - s.position.x) + absi(back.to.y - s.position.y) == 3, "Closer than that, it backs away from the flame")
		app._target_id = ""
		_place(s, wolf, 1)
		app._update_info()
		check(app._target_hint.text.contains("Fears fire") and app._target_hint.text.contains("Pack caller"), "Target frame names the wolf's traits")
		await _frames(2)
		await _capture("systems-wary-wolf.png")
		s.unequip_slot("weapon")
		# --- Pack call: one wolf's hunt alerts its kin ---------------------------
		var kin := _creature(s, "core:wolf", wolf.instance_id)
		if check(not kin.is_empty(), "A second grey wolf is loaded"):
			kin.position = wolf.position + Vector2i(4, 4)
			kin.alerted_until = 0
			wolf.state = "idle"
			_place(s, wolf, 3)
			var hunt: Dictionary = s.roster.decide(s, wolf, "test/call/0")
			var events: Array = s.roster.after_decision(s, wolf, hunt)
			check(events.size() == 1 and events[0].type == "call_allies" and int(events[0].answered) >= 1 and int(kin.alerted_until) > int(s.run.state.turn) and app.describe_events(events).contains("howls"), "The hunting wolf howls and its kin are alerted")
			check(s.roster.after_decision(s, wolf, hunt).is_empty(), "It howls once when the hunt starts, not every turn")
	# --- Charge ----------------------------------------------------------------
	s.unequip_slot("weapon")
	var boar := _creature(s, "core:boar")
	if check(not boar.is_empty() and _place(s, boar, 3), "A wild boar three tiles away in a straight line"):
		boar.provoked = true
		boar.charge_ready = 0
		var rush: Dictionary = s.roster.decide(s, boar, "test/charge/0")
		check(rush.type == "charge" and absi(rush.to.x - s.position.x) + absi(rush.to.y - s.position.y) == 1, "A provoked boar charges to the tile beside the hero")
		var hp := int(s.stats().hp)
		s.stats().hp = 30
		var turn := int(s.run.state.turn)
		var dash: Array = s.roster.charge(s, boar, rush.to)
		var hit: Array = s.roster.creature_strike(s, boar, "test/charge/hit")
		check(not dash.is_empty() and int(boar.charge_ready) == turn + 6 and not boar.charged and app.describe_events(dash).contains("charges"), "The charge lands and starts a 6-turn recovery")
		var damage := int(hit.filter(func(e: Dictionary) -> bool: return e.type == "hit")[0].damage)
		var normal: Array = s.roster.creature_strike(s, boar, "test/charge/hit")
		check(damage > int(normal.filter(func(e: Dictionary) -> bool: return e.type == "hit")[0].damage), "The charging blow hits harder than a normal one (same roll)")
		s.stats().hp = hp
		_place(s, boar, 3)
		check(s.roster.decide(s, boar, "test/charge/1").type != "charge", "While recovering, the boar cannot charge again")
		# --- Persistence of trait timers -----------------------------------------
		var boar_id: String = boar.instance_id
		check(s.save(), "Save with trait timers in creature state")
		var ready := int(boar.charge_ready)
		await _key(KEY_ESCAPE)
		app._resume.pressed.emit()
		await process_frame
		check(app.session != null and int(app.session.roster.creatures[boar_id].charge_ready) == ready, "Continue restores the boar's charge recovery")
	_finish()

func _creature(s: RefCounted, content_id: String, except: String = "") -> Dictionary:
	for creature in s.roster.creatures.values():
		if creature.content_id == content_id and not creature.dead and creature.instance_id != except:
			return creature
	return {}

func _place(s: RefCounted, creature: Dictionary, distance: int) -> bool:
	## Put the creature `distance` tiles away on an open straight line in sight.
	for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var clear := true
		for step in range(1, distance + 1):
			var tile: Vector2i = s.position + direction * step
			clear = clear and s.terrain.walkable(tile) and s.visible.has(tile) and (s.roster.living_at(tile).is_empty() or s.roster.living_at(tile).instance_id == creature.instance_id)
		var beyond: Vector2i = s.position + direction * (distance + 1)
		if clear and s.terrain.walkable(beyond) and s.roster.living_at(beyond).is_empty():
			creature.position = s.position + direction * distance
			creature.home = creature.position
			return true
	return false

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _finish() -> void:
	if app.session != null:
		app._return_to_menu()
	app.free()
	print("SYSTEMS GAMEPLAY: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)

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
