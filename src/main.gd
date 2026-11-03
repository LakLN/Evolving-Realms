extends Control
## World/Run menu and exploration shell. Persistence stays in Checkpoint B Store.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const MapView = preload("res://src/world/map_view.gd")
const Data = preload("res://src/data/json_data.gd")
const StarterPack = preload("res://src/content/starter_pack.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const TalentText = preload("res://src/core/talent_text.gd")
const FantasyTheme = preload("res://src/ui/fantasy_theme.gd")
const Art = preload("res://src/world/art.gd")
const WorldMap = preload("res://src/ui/world_map.gd")
const Realtime = preload("res://src/run/realtime_controller.gd")
const Structured = preload("res://src/world/structured_world.gd")
const Atlas = preload("res://src/world/world_atlas.gd")
const DEFAULT_DATABASE := "user://realms.sqlite"
const CONTROLS_TURN := "WASD: move (bump = attack) | E: interact | X: search | F: attack | Tab: target | Space: wait | R: rest | I: items | C: gear | T: talent | K: skills | M: map | N: minimap"
const CONTROLS_REALTIME := "Hold WASD: move | F: attack | \"!\": step away to dodge | E | X | R: rest | 1-9 | I C T K | M: map | N: minimap"
const MOVE_KEYS := {"explore_up": [KEY_W, KEY_UP], "explore_right": [KEY_D, KEY_RIGHT], "explore_down": [KEY_S, KEY_DOWN], "explore_left": [KEY_A, KEY_LEFT]}
const MOVE_DIRECTIONS := {"explore_up": Vector2i.UP, "explore_right": Vector2i.RIGHT, "explore_down": Vector2i.DOWN, "explore_left": Vector2i.LEFT}
var database_path := DEFAULT_DATABASE
var store := Store.new()
var session: RefCounted
var map_view: Node2D
var _world_map: WorldMap
var _menu: Control
var _hud: Control
var _discovery_panel: PanelContainer
var _discovery_column: VBoxContainer
var _discovery_mode := ""
var _worlds: OptionButton
var _runs: ItemList
var _name_entry: LineEdit
var _world_seed: LineEdit
var _run_seed: LineEdit
var _biome: OptionButton
var _mode: OptionButton
var _time_model: OptionButton
var _world_layout: OptionButton
var _region_hint: Label
## Known structured-World leads/bearings, refreshed on discoveries and resolutions only
## (each read loads discovered site records); distances are recomputed from this cache.
var _leads: Array = []
var _frontiers: Array = []
var _controls_hint: Label
## M03 B prototype: gameplay clock of a real-time Run (null for turn Runs).
var _realtime: RefCounted
var _create_world: Button
var _new_run: Button
var _resume: Button
## Milestone 04: the persistent World (atlas) entry points on the main menu.
var _adventure: Button
var _chart: Button
## M05 development: chart the Snow Mountain layout land (land package, not published).
var _chart_snow: Button
const SNOW_LAYOUT := "landpkg:snow_mountain/layout"
const CHART_SNOW := "Chart Snow Mountain (dev)"
const SNOW_RUN := "New Run in Snow Mountain (dev)"
## Real-time notices that may not replace a fresh place message (see _hold_notice).
const ROUTINE_EVENTS := ["autosave", "survival", "status_tick", "skill_resource", "regen"]
const NOTICE_HOLD_MS := 9000
var _notice_hold_until := 0
var _atlas_line: Label
var _pending_land: Dictionary = {}
var _status: Label
var _info: Label
var _notice: Label
var _interaction_hint: Label
var _target_hint: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _survival_label: Label
var _use_button: Button
var _character_panel: PanelContainer
var _character_summary: Label
var _slot_list: ItemList
var _slot_detail: Label
var _unequip_button: Button
var _slot_ids: Array = []
var _rainbow: Array = [] # [ItemList, index, tier] rows animated for rainbow-style tiers
var _talent_panel: PanelContainer
var _talent_style: StyleBoxFlat
var _talent_title: Label
var _talent_rank: Label
var _talent_name: Label
var _talent_text: Label
var _talent_line: Label
var _energy_bar: ProgressBar
var _energy_label: Label
var _skills_panel: PanelContainer
var _skills_summary: Label
var _skill_list: ItemList
var _skill_detail: Label
var _skill_use_button: Button
## Active skill targeting: {skill, kind, options, index}; empty when not targeting.
var _targeting: Dictionary = {}
var _death_panel: PanelContainer
var _death_text: Label
var _death_reload: Button
var _target_id := ""
var _inventory_panel: PanelContainer
var _inventory_list: ItemList
var _inventory_detail: Label
var _inventory_rows: Array = []
var _hold_delay := 0.0
var _data_ready := false
var _discard_on_exit := false
var _acceptance: RefCounted

func _ready() -> void:
	get_tree().auto_accept_quit = false
	for action in MOVE_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in MOVE_KEYS[action]:
				var event := InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action, event)
	map_view = MapView.new()
	add_child(map_view)
	map_view.hide()
	var ui := CanvasLayer.new()
	add_child(ui)
	var frame := Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(frame)
	frame.theme = FantasyTheme.build()
	_build_menu(frame)
	_build_hud(frame)
	_build_inventory(frame)
	_build_character(frame)
	_build_talent_panel(frame)
	_build_skills(frame)
	_build_discovery_panel(frame)
	_build_death_screen(frame)
	_world_map = WorldMap.new()
	_world_map.waypoint_changed.connect(_on_waypoint_changed)
	frame.add_child(_world_map)
	var options := launch_options()
	database_path = options.get("database", database_path)
	if options.has("acceptance") and ProjectSettings.globalize_path(database_path) == ProjectSettings.globalize_path(DEFAULT_DATABASE):
		printerr("Acceptance checks require --database=<separate path>; personal saves are never opened")
		get_tree().quit(2)
		return
	_data_ready = store.open(database_path)
	_create_world.disabled = not _data_ready
	_refresh_worlds()
	_message("Choose a world or create one. Each run keeps its own progress." if _data_ready else store.last_error, not _data_ready)
	if options.has("acceptance"):
		_acceptance = Acceptance.new()
		_acceptance.run(self, options.acceptance)

static func launch_options() -> Dictionary:
	## User arguments after `--`, e.g. `-- --database=D:/saves/test.sqlite`.
	var options := {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			options[argument.get_slice("=", 0).trim_prefix("--")] = argument.substr(argument.find("=") + 1)
	return options

func _build_menu(parent: Control) -> void:
	_menu = Panel.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(_menu)
	var art: RefCounted = Art.shared()
	if art.ready():
		var tile := AtlasTexture.new()
		tile.atlas = art.texture(art.index.ground.atlas)
		tile.region = Rect2(0, art.px, art.px, art.px) # Forest floor (row 1).
		FantasyTheme.backdrop(_menu, tile)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 960
	center.add_child(card)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(920, 0)
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var title := _label(column, "EVOLVING REALMS", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", FantasyTheme.GOLD)
	title.add_theme_constant_override("outline_size", 6)
	_label(column, "A persistent world. A new path with every run.", 18).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(HSeparator.new())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 30)
	column.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 440
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	_label(left, "WORLD BLUEPRINT", 20)
	_worlds = OptionButton.new()
	_worlds.custom_minimum_size.y = 40
	_worlds.item_selected.connect(func(_index: int) -> void: _refresh_runs())
	left.add_child(_worlds)
	_name_entry = _entry(left, "New world name", "")
	_world_seed = _entry(left, "World seed (blank = random)", "")
	_world_layout = OptionButton.new()
	for layout in [["structured", "Layout: structured regions (M03)"], ["legacy", "Layout: legacy (Run 01 style)"], ["atlas", "Layout: persistent atlas lands (M04)"]]:
		_world_layout.add_item(layout[1])
		_world_layout.set_item_metadata(_world_layout.item_count - 1, layout[0])
	# M03 integration: structured Worlds are the default; `-- --layout=legacy` preselects legacy.
	_world_layout.select(1 if launch_options().get("layout", "") == "legacy" else 0)
	left.add_child(_world_layout)
	_create_world = _button(left, "Create world", _on_create_world)
	left.add_child(HSeparator.new())
	_label(left, "NEW RUN", 20)
	_biome = OptionButton.new()
	for biome in ["any", "forest", "beach", "meadow"]:
		_biome.add_item("Starting biome: " + biome)
		_biome.set_item_metadata(_biome.item_count - 1, biome)
	left.add_child(_biome)
	_mode = OptionButton.new()
	for mode in ["normal", "permadeath"]:
		_mode.add_item("Mode: " + mode + (" (death reloads last save)" if mode == "normal" else " (death ends the run)"))
		_mode.set_item_metadata(_mode.item_count - 1, mode)
	left.add_child(_mode)
	_time_model = OptionButton.new()
	for model in [["turn", "Time: turn-based (one action = one turn)"], ["realtime-v1", "Time: real-time (M03 prototype)"]]:
		_time_model.add_item(model[1])
		_time_model.set_item_metadata(_time_model.item_count - 1, model[0])
	# M03 integration: real time is the default for new Runs; `-- --time=turn` preselects turns.
	# Existing Runs keep the model stored in their spawn.
	_time_model.select(0 if launch_options().get("time", "") == "turn" else 1)
	left.add_child(_time_model)
	_run_seed = _entry(left, "Run seed (blank = random)", "")
	_new_run = _button(left, "Begin a new run", _on_new_run)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 450
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	_label(right, "SAVED RUNS", 20)
	_runs = ItemList.new()
	_runs.custom_minimum_size = Vector2(450, 190)
	_runs.item_selected.connect(func(_index: int) -> void: _resume.disabled = false)
	_runs.item_activated.connect(func(_index: int) -> void: _on_resume())
	right.add_child(_runs)
	_resume = _button(right, "Continue selected run", _on_resume)
	_button(right, "Exit", _request_exit)
	right.add_child(HSeparator.new())
	_label(right, "THE EVOLVING REALM", 20)
	_atlas_line = _label(right, "", 14)
	_atlas_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	right.add_child(actions)
	_adventure = _button(actions, "New Adventure", _on_new_adventure)
	_chart = _button(actions, "Chart a new land (dev)", _on_chart_land)
	_chart_snow = _button(actions, CHART_SNOW, func() -> void: _on_chart_land(SNOW_LAYOUT))
	for button in [_adventure, _chart, _chart_snow]: button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status = _label(column, "", 16)
	_status.custom_minimum_size.y = 52
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(column, "WASD/Arrows: move  E: interact  X: search  F: attack  Tab: target  Space: wait  R: rest  I: inventory (U: use/equip)  C: gear  T: talent  K: skills (1-9 use)  Ctrl+S: save  Esc: menu", 14).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_hud(parent: Control) -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_hud)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 86
	_hud.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top.add_child(row)
	_info = _label(row, "", 17)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Long coordinates/counters are trimmed instead of pushing the buttons off-screen.
	_info.clip_text = true
	_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var health := VBoxContainer.new()
	health.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(health)
	_hp_label = _label(health, "HP", 15)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(130, 14)
	_hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("c9483f")
	_hp_bar.add_theme_stylebox_override("fill", fill)
	health.add_child(_hp_bar)
	_energy_bar = ProgressBar.new()
	_energy_bar.custom_minimum_size = Vector2(130, 12)
	_energy_bar.show_percentage = false
	var energy_fill := StyleBoxFlat.new()
	energy_fill.bg_color = Color("3b7fc4")
	_energy_bar.add_theme_stylebox_override("fill", energy_fill)
	health.add_child(_energy_bar)
	_energy_label = Label.new()
	_energy_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_energy_label.add_theme_font_size_override("font_size", 10)
	_energy_bar.add_child(_energy_label)
	_survival_label = _label(health, "", 13)
	_button(row, "Inventory [I]", _toggle_inventory).focus_mode = Control.FOCUS_NONE
	_button(row, "Save [Ctrl+S]", _save_game).focus_mode = Control.FOCUS_NONE
	var menu_button := _button(row, "Menu [Esc]", _return_to_menu)
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.tooltip_text = "Save and return to the menu"
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -100
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN # Taller hint text grows upward, never off-screen.
	_hud.add_child(bottom)
	var column := VBoxContainer.new()
	bottom.add_child(column)
	_notice = _label(column, "", 17)
	_notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Place messages carry clues (M05 chains): wrap up to three lines instead of cutting.
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.max_lines_visible = 3
	_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice.mouse_filter = Control.MOUSE_FILTER_PASS
	_notice.mouse_entered.connect(func() -> void: _notice.tooltip_text = _notice.text)
	_interaction_hint = _label(column, "", 17)
	_target_hint = _label(column, "", 17)
	_region_hint = _label(column, "", 16) # Structured World: region and leads (empty otherwise).
	_region_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_region_hint.mouse_filter = Control.MOUSE_FILTER_PASS
	_region_hint.add_theme_color_override("font_color", Color("cfe3b0"))
	_controls_hint = _label(column, CONTROLS_TURN, 15)
	_label(column, "Red ring: hostile  /  Amber: neutral (fights back)  /  Green: passive.  Black: unexplored, dim: remembered.", 15)
	_hud.hide()

func _build_character(parent: Control) -> void:
	_character_panel = PanelContainer.new()
	_character_panel.anchor_top = 0.5
	_character_panel.anchor_bottom = 0.5
	_character_panel.offset_left = 20
	_character_panel.offset_right = 395
	_character_panel.offset_top = -268 # Starts right under the top HUD.
	_character_panel.offset_bottom = 175 # Ends above the bottom notice lines.
	parent.add_child(_character_panel)
	var column := _scroll_column(_character_panel, 8)
	_label(column, "CHARACTER & GEAR", 22)
	_character_summary = _label(column, "", 15)
	_character_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_talent_line = _label(column, "", 14)
	_talent_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slot_list = ItemList.new()
	_slot_list.custom_minimum_size = Vector2(355, 140)
	_slot_list.fixed_icon_size = Vector2i(22, 22)
	_slot_list.item_selected.connect(_show_slot)
	_slot_list.item_activated.connect(func(_index: int) -> void: _unequip_selected())
	column.add_child(_slot_list)
	_slot_detail = _label(column, "", 14)
	_slot_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slot_detail.custom_minimum_size.y = 24
	_unequip_button = _button(column, "Unequip selected [U / Enter]", _unequip_selected)
	_unequip_button.focus_mode = Control.FOCUS_NONE
	_button(column, "Close [C / Esc]", _toggle_character)
	_character_panel.hide()

func _panel_open() -> bool:
	if _discovery_panel != null and _discovery_panel.visible: return true
	return (_inventory_panel != null and _inventory_panel.visible) or (_character_panel != null and _character_panel.visible) or (_talent_panel != null and _talent_panel.visible) or (_skills_panel != null and _skills_panel.visible) or (_world_map != null and _world_map.map_open) or not _targeting.is_empty()

func _build_discovery_panel(parent: Control) -> void:
	_discovery_panel = PanelContainer.new()
	_discovery_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_discovery_panel.offset_left = -340
	_discovery_panel.offset_right = 340
	_discovery_panel.offset_top = -240
	_discovery_panel.offset_bottom = 240
	parent.add_child(_discovery_panel)
	_discovery_column = _scroll_column(_discovery_panel, 10)
	_discovery_panel.hide()

func _clear_discovery_panel(mode: String) -> void:
	for child in _discovery_column.get_children():
		_discovery_column.remove_child(child)
		child.queue_free()
	_discovery_mode = mode
	_discovery_panel.show()

func _close_discovery_panel() -> void:
	_discovery_panel.hide()
	get_viewport().gui_release_focus()
	_hold_delay = 0.2

func _show_knowledge() -> void:
	_clear_discovery_panel("knowledge")
	_label(_discovery_column, "KNOWLEDGE — confirmed this Run", 22)
	var entries: Array = preload("res://src/run/player_knowledge.gd").entries(session)
	if entries.is_empty(): _label(_discovery_column, "No confirmed entries yet. Learn through experience.", 16)
	for entry in entries:
		_label(_discovery_column, "%s / %s" % [entry.category, entry.title], 19)
		var body := _label(_discovery_column, entry.text, 17)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(_discovery_column, "Close [J / Esc]", _close_discovery_panel).grab_focus()

func _show_interactions() -> bool:
	var rows: Array = []
	for instance in session.places.targets(session):
		for choice in session.places.available(session, instance, "interact"):
			rows.append({"instance": instance, "choice": choice})
	# Preserve quick E for a single ordinary gather/open or place interaction.
	if rows.is_empty() or (rows.size() == 1 and session.interaction_target().is_empty() and not rows[0].choice.has("world_method")): return false
	_clear_discovery_panel("interactions")
	_label(_discovery_column, "INTERACT — choose an approach", 22)
	var first: Button
	var object: Dictionary = session.interaction_target()
	if not object.is_empty():
		first = _button(_discovery_column, "Gather / open nearby supplies", func() -> void:
			_close_discovery_panel()
			_after_action(session.interact(object.instance_id)))
	for row in rows:
		var instance: Dictionary = row.instance
		var choice: Dictionary = row.choice
		var definition: Dictionary = session.locations.definition_for(instance)
		var event: Dictionary = session.locations.event(choice.event)
		var details: Array = session.places.unmet(session, event.payload.get("conditions", []))
		if choice.has("world_method"):
			var threshold := int(definition.payload.world_properties.fracture_attack)
			if choice.world_method == "force":
				details.append("Attack %d+ (current %d); 2 HP; two thirds of fragile contents lost" % [threshold, int(session.combat_stats().attack)])
			else:
				details.append("Contents preserved")
				for fuel in definition.payload.world_properties.thaw_fuel:
					details.append("%s x%d" % [session._definition(fuel.content_id, int(fuel.version)).get("name", fuel.content_id), int(fuel.quantity)])
		for item in event.payload.get("cost", {}).get("items", []):
			details.append("%s x%d" % [session._definition(item.content_id, int(item.version)).get("name", item.content_id), int(item.get("quantity", 1))])
		var button := _button(_discovery_column, "%s: %s" % [definition.name, choice.get("verb", "Explore")], func() -> void:
			_close_discovery_panel()
			_after_action(session.perform_action({"type": "interact", "instance_id": instance.instance_id, "interaction": choice.id})))
		if first == null: first = button
		if not details.is_empty():
			var label := _label(_discovery_column, "; ".join(details), 16)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(_discovery_column, "Cancel [Esc] — no action spent", _close_discovery_panel)
	if first != null: first.grab_focus()
	return true

func _toggle_character() -> void:
	if session == null or _menu.visible or session.is_dead():
		return
	_inventory_panel.hide()
	_skills_panel.hide()
	_character_panel.visible = not _character_panel.visible
	_hold_delay = 0.2
	if _character_panel.visible:
		_refresh_character()
		_slot_list.grab_focus()
	else:
		get_viewport().gui_release_focus()

func item_label(definition: Dictionary, metadata: Dictionary) -> String:
	var tier: String = session.quality.of(definition, metadata)
	return ("[%s] %s" % [session.quality.tier(tier).name, definition.get("name", "?")]) if not tier.is_empty() else str(definition.get("name", "?"))

func _color_row(list: ItemList, index: int, definition: Dictionary, metadata: Dictionary) -> void:
	var tier: String = session.quality.of(definition, metadata)
	if tier.is_empty():
		return
	list.set_item_custom_fg_color(index, session.quality.color(tier))
	match session.quality.tier(tier).get("style", "plain"):
		"black_gold":
			list.set_item_custom_bg_color(index, Color("17130c"))
		"platinum":
			list.set_item_custom_bg_color(index, Color("1d2a33"))
		"rainbow":
			_rainbow.append([list, index, tier])

func _refresh_character(selected_slot: String = "") -> void:
	var effective: Dictionary = session.effective_stats()
	var character: Dictionary = session.run.state.character
	var lines := PackedStringArray()
	for track_id in session.character_rules.rules.tracks:
		var track: Dictionary = character.progression[track_id]
		lines.append("%s  Level %d   XP %d / %d" % [session.character_rules.rules.tracks[track_id].get("name", track_id), int(track.level), int(track.xp), session.character_rules.xp_to_next(track_id, int(track.level))])
	for stat in session.character_rules.rules.stats:
		var part: Dictionary = effective.breakdown[stat]
		var talent := " %s %d talent" % ["+" if int(part.talent) >= 0 else "-", absi(int(part.talent))] if int(part.talent) != 0 else ""
		lines.append("%s %d  = %d base + %d level + %d gear%s%s" % [session.character_rules.rules.stats[stat].name, effective.stats[stat], part.base, part.growth, part.gear, talent, " (incl. %+d%%)" % part.percent if part.percent != 0 else ""])
	_character_summary.text = "\n".join(lines)
	_talent_line.text = talent_summary()
	var held: Array = character.talents
	_talent_line.modulate = session.talent_rules.color(held[0].rank) if not held.is_empty() else Color("b8b8b8")
	_rainbow = _rainbow.filter(func(entry: Array) -> bool: return entry[0] != _slot_list)
	_slot_list.clear()
	_slot_ids = session.character_rules.slot_ids()
	var index := 0
	for slot in _slot_ids:
		var record: Dictionary = character.equipment.get(slot, {})
		var definition: Dictionary = {} if record.is_empty() else session._definition(record.content_id, int(record.version))
		_slot_list.add_item("%s:  %s" % [session.character_rules.slot_name(slot), "—" if record.is_empty() else item_label(definition, record.get("metadata", {}))])
		var slot_icon: Texture2D = Art.shared().icon(str(Art.shared().index.get("mapping", {}).get("slot_icons", {}).get(slot, ""))) if Art.shared().ready() else null
		if slot_icon != null:
			_slot_list.set_item_icon(_slot_list.item_count - 1, slot_icon)
			_slot_list.set_item_icon_modulate(_slot_list.item_count - 1, Color.WHITE if not record.is_empty() else Color(1, 1, 1, 0.3))
		if not record.is_empty():
			_color_row(_slot_list, _slot_list.item_count - 1, definition, record.get("metadata", {}))
		if slot == selected_slot:
			index = _slot_list.item_count - 1
	_slot_list.select(index)
	_show_slot(index)

func _show_slot(index: int) -> void:
	var slot: String = _slot_ids[index]
	var record: Dictionary = session.run.state.character.equipment.get(slot, {})
	_unequip_button.disabled = record.is_empty()
	_slot_detail.text = "Empty slot. Equip items from the inventory (I, then U)." if record.is_empty() else gear_text(session._definition(record.content_id, int(record.version)), record.get("metadata", {}))

func gear_text(definition: Dictionary, metadata: Dictionary) -> String:
	var bonus: Dictionary = session.character_rules.gear_bonus(definition, metadata)
	var parts := PackedStringArray()
	for stat in bonus.flat:
		parts.append("%s %+d" % [session.character_rules.rules.stats.get(stat, {}).get("name", stat), int(bonus.flat[stat])])
	for stat in bonus.percent:
		parts.append("%s %+d%%" % [session.character_rules.rules.stats.get(stat, {}).get("name", stat), int(bonus.percent[stat])])
	var tier: String = bonus.quality
	var grade := "" if tier.is_empty() else "%s (%d/10, gear stats %+d%%)  " % [session.quality.tier(tier).name, session.quality.rank(tier), session.quality.bonus_percent(tier)]
	var requirement: String = session.character_rules.requirement_error(definition, session.run.state.character)
	return "%s%s: %s%s" % [grade, session.character_rules.slot_name(definition.payload.equipment.slot), ", ".join(parts), "\n" + requirement if not requirement.is_empty() else ""]

func _unequip_selected() -> void:
	var picked := _slot_list.get_selected_items()
	if session == null or session.is_dead() or picked.is_empty():
		return
	var slot: String = _slot_ids[picked[0]]
	_after_action(session.unequip_slot(slot))
	if _character_panel.visible:
		_refresh_character(slot)

func _build_inventory(parent: Control) -> void:
	_inventory_panel = PanelContainer.new()
	_inventory_panel.anchor_left = 1.0
	_inventory_panel.anchor_right = 1.0
	_inventory_panel.anchor_top = 0.5
	_inventory_panel.anchor_bottom = 0.5
	_inventory_panel.offset_left = -395
	_inventory_panel.offset_right = -20
	_inventory_panel.offset_top = -268 # Starts right under the top HUD.
	_inventory_panel.offset_bottom = 175 # Ends above the bottom notice lines.
	parent.add_child(_inventory_panel)
	var column := _scroll_column(_inventory_panel, 10)
	_label(column, "INVENTORY", 24)
	_inventory_list = ItemList.new()
	_inventory_list.custom_minimum_size = Vector2(365, 150)
	_inventory_list.fixed_icon_size = Vector2i(24, 24)
	_inventory_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_list.item_selected.connect(_show_inventory_item)
	column.add_child(_inventory_list)
	_inventory_detail = _label(column, "", 16)
	_inventory_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inventory_detail.custom_minimum_size.y = 130
	_inventory_list.item_activated.connect(func(_index: int) -> void: _use_selected())
	_use_button = _button(column, "Use selected [U / Enter]", _use_selected)
	_use_button.focus_mode = Control.FOCUS_NONE
	_button(column, "Close [I / Esc]", _toggle_inventory)
	_inventory_panel.hide()

func _build_talent_panel(parent: Control) -> void:
	## Awakening reveal at the start of a Run; T reopens it as the talent sheet.
	_talent_panel = PanelContainer.new()
	_talent_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_talent_panel.custom_minimum_size = Vector2(660, 0)
	_talent_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_talent_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_talent_style = StyleBoxFlat.new()
	_talent_style.bg_color = Color(0.06, 0.06, 0.09, 0.97)
	_talent_style.set_border_width_all(2)
	_talent_style.set_content_margin_all(22)
	_talent_panel.add_theme_stylebox_override("panel", _talent_style)
	parent.add_child(_talent_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_talent_panel.add_child(column)
	_talent_title = _label(column, "", 18)
	_talent_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_talent_title.modulate = Color("c9c0a0")
	_talent_rank = _label(column, "", 30)
	_talent_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_talent_name = _label(column, "", 26)
	_talent_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_talent_text = _label(column, "", 15)
	_talent_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_talent_text.custom_minimum_size.x = 616
	var close := _button(column, "Continue [Enter]", _close_talent)
	close.focus_mode = Control.FOCUS_NONE
	_talent_panel.hide()

func show_talent(awakening: bool) -> void:
	_inventory_panel.hide()
	_character_panel.hide()
	var held: Array = session.run.state.character.talents
	_talent_title.text = "TALENT AWAKENED" if awakening else "TALENT"
	_rainbow = _rainbow.filter(func(entry: Array) -> bool: return entry[0] != _talent_rank)
	if held.is_empty():
		_talent_rank.text = "—"
		_talent_rank.modulate = Color("b8b8b8")
		_talent_name.text = "No talent"
		_talent_text.text = "This run holds no awakened talent."
		_talent_style.border_color = Color("6f6f6f")
	else:
		var first: Dictionary = session.talent_definition(held[0].content_id, int(held[0].version))
		_talent_rank.text = TalentText.rank_title(session.talent_rules, held[0].rank)
		_talent_rank.modulate = session.talent_rules.color(held[0].rank)
		_talent_name.text = first.name if held.size() == 1 else "%d talents" % held.size()
		_talent_style.border_color = session.talent_rules.color(held[0].rank)
		if session.talent_rules.rank(held[0].rank).get("style") == "rainbow":
			_rainbow.append([_talent_rank, -1, held[0].rank])
		var lines := PackedStringArray()
		for record in held:
			var definition: Dictionary = session.talent_definition(record.content_id, int(record.version))
			if held.size() > 1:
				lines.append(TalentText.label(session.talent_rules, definition))
			lines.append(str(definition.get("description", "")))
			lines.append_array(talent_lines(record))
		lines.append("" if not awakening else "\nAwakened for this run only. It is saved with the run and never rerolled.")
		_talent_text.text = "\n".join(lines).strip_edges()
	_talent_panel.show()
	_hold_delay = 0.2

func talent_lines(record: Dictionary) -> PackedStringArray:
	var stat_names := {}
	for stat in session.character_rules.rules.stats:
		stat_names[stat] = session.character_rules.rules.stats[stat].name
	return TalentText.details(session.talent_rules, session.talent_definition(record.content_id, int(record.version)), record, int(session.run.state.turn), stat_names, func(content_id: String, version: int) -> String: return str(session._definition(content_id, version).get("name", content_id)), session.talent_supported(record))

func talent_summary() -> String:
	## Compact talent line for the character panel.
	var held: Array = session.run.state.character.talents
	if held.is_empty():
		return "Talent: none awakened in this run."
	var parts := PackedStringArray()
	for record in held:
		var definition: Dictionary = session.talent_definition(record.content_id, int(record.version))
		var state := ""
		for ability in definition.payload.get("abilities", []):
			state += TalentText.status(ability, record, int(session.run.state.turn))
		parts.append("Talent: %s%s" % [TalentText.label(session.talent_rules, definition), state])
	return "\n".join(parts) + "  (T: details)"

func _toggle_talent() -> void:
	if session == null or _menu.visible or session.is_dead():
		return
	if _talent_panel.visible:
		_close_talent()
	else:
		show_talent(false)

func _close_talent() -> void:
	_talent_panel.hide()
	_hold_delay = 0.2
	get_viewport().gui_release_focus()

func _scroll_column(panel: PanelContainer, separation: int) -> VBoxContainer:
	## Side panels keep a fixed frame and scroll long content instead of growing over
	## the bottom notice lines.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	return column

func _build_skills(parent: Control) -> void:
	## K: learned skills with costs, cooldowns, conditions; U / Enter / 1-9 use one.
	_skills_panel = PanelContainer.new()
	_skills_panel.anchor_top = 0.5
	_skills_panel.anchor_bottom = 0.5
	_skills_panel.offset_left = 20
	_skills_panel.offset_right = 415
	_skills_panel.offset_top = -268
	_skills_panel.offset_bottom = 175 # Ends above the bottom notice lines.
	parent.add_child(_skills_panel)
	var column := _scroll_column(_skills_panel, 8)
	_label(column, "SKILLS", 22)
	_skills_summary = _label(column, "", 15)
	_skills_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_list = ItemList.new()
	_skill_list.custom_minimum_size = Vector2(375, 120)
	_skill_list.item_selected.connect(_show_skill)
	_skill_list.item_activated.connect(func(index: int) -> void: begin_skill(index))
	column.add_child(_skill_list)
	_skill_detail = _label(column, "", 13)
	_skill_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_detail.custom_minimum_size = Vector2(375, 110)
	_skill_use_button = _button(column, "Use selected [U / Enter]", func() -> void: _use_selected_skill())
	_skill_use_button.focus_mode = Control.FOCUS_NONE
	_button(column, "Close [K / Esc]", _toggle_skills)
	_skills_panel.hide()

func _toggle_skills() -> void:
	if session == null or _menu.visible or session.is_dead():
		return
	_inventory_panel.hide()
	_character_panel.hide()
	_cancel_targeting()
	_skills_panel.visible = not _skills_panel.visible
	_hold_delay = 0.2
	if _skills_panel.visible:
		_refresh_skills()
		_skill_list.grab_focus()
	else:
		get_viewport().gui_release_focus()

func skill_rows() -> Array:
	## Learned skills in learning order; 1-9 use the same order.
	return session.run.state.character.skills

func _refresh_skills(selected: int = 0) -> void:
	var lines := PackedStringArray()
	for id in session.skill_rules.resource_ids():
		lines.append("%s %d / %d" % [session.skill_rules.rules.resources[id].name, session.skills.resource(session, id), session.skills.resource_max(session, id)])
	var active := PackedStringArray()
	for status in session.run.state.character.statuses:
		if status.has("remaining"):
			active.append(session.statuses.describe(session, [status]))
		else:
			active.append("%s %s (%d turns left)" % [str(status.id).capitalize(), _status_text(status), int(status.until_turn) - int(session.run.state.turn)])
	if not active.is_empty():
		lines.append("Active: " + "; ".join(active)) # One wrapped line, not one per status.
	_skills_summary.text = "\n".join(lines)
	_skill_list.clear()
	var turn := int(session.run.state.turn)
	for index in skill_rows().size():
		var record: Dictionary = skill_rows()[index]
		var definition: Dictionary = session.skill_definition(record.content_id, int(record.version))
		var kind: String = definition.payload.get("type", "?")
		var state := kind
		if kind == "active":
			var cost: Dictionary = session.skills.costs(session, definition)
			state = "%s%s" % [_cost_text(cost), "  ready" if int(record.cooldown_until) <= turn else "  %dt" % (int(record.cooldown_until) - turn)]
		_skill_list.add_item("%s%s  [%s]" % ["%d. " % (index + 1) if index < 9 else "", definition.name, state])
		if kind == "active" and not session.skills.use_check(session, definition).is_empty():
			_skill_list.set_item_custom_fg_color(_skill_list.item_count - 1, Color("9a9a9a"))
	if skill_rows().is_empty():
		_skill_detail.text = "No skills yet. Find manuals and scrolls in chests and caches, then learn them from the inventory (I, U)."
		_skill_use_button.disabled = true
		return
	selected = clampi(selected, 0, skill_rows().size() - 1)
	_skill_list.select(selected)
	_show_skill(selected)

func _show_skill(index: int) -> void:
	var record: Dictionary = skill_rows()[index]
	var definition: Dictionary = session.skill_definition(record.content_id, int(record.version))
	_skill_detail.text = "\n".join(skill_lines(definition, record))
	_skill_use_button.disabled = definition.payload.get("type") != "active"

func skill_lines(definition: Dictionary, record: Dictionary = {}) -> PackedStringArray:
	## Rules text generated from the same data the handlers execute.
	var payload: Dictionary = definition.payload
	var lines := PackedStringArray([str(definition.description)])
	lines.append("Elements: " + ", ".join(payload.get("elements", ["neutral"])))
	lines.append("Type: %s%s" % [payload.type, "  Tags: " + ", ".join(payload.get("tags", [])) if not payload.get("tags", []).is_empty() else ""])
	if payload.type == "active":
		var use: Dictionary = payload.use
		var reach: int = session.skills.reach(session, definition)
		lines.append("Target: %s%s  Cost: %s  Cooldown: %d turns" % [use.target.kind, "" if use.target.kind == "self" else " within %d%s" % [reach, " (line of sight)" if use.target.get("line_of_sight", true) and reach > 1 else ""], _cost_text(session.skills.costs(session, definition)), int(use.get("cooldown_turns", 0))])
		var effects := PackedStringArray()
		for effect in payload.effects:
			effects.append(_skill_effect_text(effect))
		lines.append("Effect: " + ", ".join(effects))
		if not use.get("conditions", []).is_empty():
			lines.append("Use needs: " + ", ".join(use.conditions.map(func(condition: Dictionary) -> String: return session.skill_rules.describe(condition))))
		var modifiers: Dictionary = session.skills.modifiers(session, definition)
		if modifiers.power_percent != 0 or modifiers.cost_percent != 0 or modifiers.range_add != 0:
			lines.append("Talents/gear: power %+d%%, cost %+d%%, range %+d" % [modifiers.power_percent, modifiers.cost_percent, modifiers.range_add])
	else:
		var stat_names := {}
		for stat in session.character_rules.rules.stats:
			stat_names[stat] = session.character_rules.rules.stats[stat].name
		for effect in payload.get("passive", []):
			lines.append("Always: " + TalentText.effect_text(effect, stat_names, func(id: String, _v: int) -> String: return id))
		for ability in payload.get("abilities", []):
			lines.append(TalentText.ability_text(ability, stat_names, func(id: String, _v: int) -> String: return id) + (TalentText.status(ability, record, int(session.run.state.turn)) if not record.is_empty() else ""))
	for relation in payload.get("relations", []):
		lines.append("%s: %s" % [str(relation.type).capitalize(), str(session.skill_definition(relation.skill, 1).get("name", relation.skill))])
	if not record.is_empty() and payload.type == "active":
		var problem: String = session.skills.use_check(session, definition)
		lines.append("Ready." if problem.is_empty() else problem + ".")
	return lines

func _skill_effect_text(effect: Dictionary) -> String:
	match effect.type:
		"strike":
			return "strike for %d%% ATK%s" % [int(effect.get("attack_percent", 100)), " +%d" % int(effect.flat) if int(effect.get("flat", 0)) > 0 else ""]
		"apply_status":
			var def: Dictionary = session._definition(effect.content_id, int(effect.version))
			return "%s [%s], %dt, max %d stacks" % [def.name, def.payload.element, int(def.payload.duration), int(def.payload.max_stacks)]
		"cleanse":
			return "remove harmful statuses"
		"stun":
			return "bind for %d turns" % int(effect.turns)
		"heal":
			return "+%d HP" % int(effect.amount) if effect.has("amount") else "heal %d%% of max HP" % int(effect.percent_of_max)
		"status":
			return "%s for %d turns" % [_status_text(effect), int(effect.duration)]
		"restore":
			return "%s +%d" % [session.skill_rules.rules.resources[effect.resource].short, int(effect.amount)]
		"blink":
			return "move to the chosen tile"
		"need":
			return "%s %+d" % [effect.need, int(effect.amount)]
	return str(effect.type)

func _status_text(status: Dictionary) -> String:
	var name: String = session.character_rules.rules.stats.get(status.stat, {}).get("name", status.stat)
	return ("%s %+d" % [name, int(status.add)]) if int(status.get("add", 0)) != 0 else ("%s %+d%%" % [name, int(status.percent)])

func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in cost:
		if key == "items":
			for item in cost.items:
				parts.append("%s x%d" % [session._definition(item.content_id, int(item.version)).get("name", item.content_id), int(item.quantity)])
		elif int(cost[key]) > 0:
			parts.append("%s %d" % ["HP" if key == "hp" else session.skill_rules.rules.resources[key].short, int(cost[key])])
	return "free" if parts.is_empty() else ", ".join(parts)

func _use_selected_skill() -> void:
	var picked := _skill_list.get_selected_items()
	if not picked.is_empty():
		begin_skill(picked[0])

func begin_skill(index: int) -> void:
	## Self skills act at once; creature/tile skills open targeting (Tab / WASD, Enter).
	if session == null or session.is_dead() or index < 0 or index >= skill_rows().size():
		return
	var record: Dictionary = skill_rows()[index]
	var definition: Dictionary = session.skill_definition(record.content_id, int(record.version))
	var problem: String = session.skills.use_check(session, definition)
	if not problem.is_empty():
		_notice.text = problem + " (no turn spent)."
		return
	var kind: String = definition.payload.use.target.kind
	_skills_panel.hide()
	get_viewport().gui_release_focus()
	if kind == "self":
		_after_action(session.perform_action({"type": "skill", "skill_id": definition.content_id}))
		return
	var options: Array = session.skills.targets(session, definition)
	if options.is_empty():
		_notice.text = "%s: no valid %s within %d tiles in sight (no turn spent)." % [definition.name, "target" if kind == "creature" else "free tile in a straight line", session.skills.reach(session, definition)]
		return
	var start := 0
	for i in options.size():
		if kind == "creature" and options[i].instance_id == _target_id:
			start = i
	_targeting = {"skill": definition, "kind": kind, "options": options, "index": start}
	_hold_delay = 0.2
	_show_targeting()

func _show_targeting() -> void:
	var definition: Dictionary = _targeting.skill
	var option: Dictionary = _targeting.options[_targeting.index]
	var tiles: Array = _targeting.options.map(func(entry: Dictionary) -> Vector2i: return entry.position if _targeting.kind == "creature" else entry.tile)
	map_view.skill_marks = {"tiles": tiles, "selected": tiles[_targeting.index]}
	map_view.refresh()
	if _targeting.kind == "creature":
		_notice.text = "%s → %s (HP %d/%d). Tab: next target (%d valid) | Enter / F: use | Esc: cancel" % [definition.name, option.definition.name, option.hp, option.max_hp, _targeting.options.size()]
	else:
		_notice.text = "%s → tile (%d, %d). WASD: direction | Enter: go | Esc: cancel" % [definition.name, option.tile.x, option.tile.y]

func _confirm_targeting() -> void:
	var definition: Dictionary = _targeting.skill
	var option: Dictionary = _targeting.options[_targeting.index]
	var action := {"type": "skill", "skill_id": definition.content_id}
	if _targeting.kind == "creature":
		action.target_id = option.instance_id
		_target_id = option.instance_id
	else:
		action.target = {"x": option.tile.x, "y": option.tile.y}
	_cancel_targeting()
	_after_action(session.perform_action(action))

func _cancel_targeting() -> void:
	_targeting = {}
	if map_view != null:
		map_view.skill_marks = {}
		if session != null:
			map_view.refresh()

func _targeting_input(event: InputEventKey) -> void:
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_ESCAPE:
		_cancel_targeting()
		_notice.text = "Skill cancelled (no turn spent)."
	elif key in [KEY_ENTER, KEY_KP_ENTER] or (key == KEY_F and _targeting.kind == "creature"):
		_confirm_targeting()
	elif key == KEY_TAB and _targeting.kind == "creature":
		_targeting.index = (int(_targeting.index) + 1) % _targeting.options.size()
		_show_targeting()
	elif _targeting.kind == "tile":
		for action in MOVE_KEYS:
			if key in MOVE_KEYS[action]:
				for i in _targeting.options.size():
					if _targeting.options[i].direction == MOVE_DIRECTIONS[action]:
						_targeting.index = i
				_show_targeting()

func book_text(item: Dictionary) -> String:
	## Compact inventory detail for a skill book; K shows the full rules once learned.
	var book: Dictionary = session.skills.book_for(session, item.content_id)
	var definition: Dictionary = session.skill_definition(book.skill.content_id, int(book.skill.version))
	var payload: Dictionary = definition.get("payload", {})
	var summary := ""
	if payload.get("type") == "active":
		var effects := PackedStringArray()
		for effect in payload.effects:
			effects.append(_skill_effect_text(effect))
		summary = "%s; %s, CD %d" % [", ".join(effects), _cost_text(session.skills.costs(session, definition)), int(payload.use.get("cooldown_turns", 0))]
		if payload.use.target.kind != "self":
			summary += ", range %d" % session.skills.reach(session, definition)
	else:
		summary = str(definition.get("description", ""))
	var needs: Array = payload.get("learn", {}).get("conditions", []).map(func(condition: Dictionary) -> String: return session.skill_rules.describe(condition))
	for relation in payload.get("relations", []):
		if relation.type == "prerequisite":
			needs.append("knows " + str(session.skill_definition(relation.skill, 1).get("name", relation.skill)))
	var unmet: Array = session.skills.learn_check(session, definition)
	var lines := PackedStringArray(["Teaches: %s (%s)" % [definition.get("name", "?"), payload.get("type", "?")], summary, "Learn needs: " + ("nothing" if needs.is_empty() else ", ".join(needs))])
	lines.append(("Can learn now. The book is %s." % ("used up" if book.get("consume_on_learn", true) else "kept")) if unmet.is_empty() else "Cannot learn yet: " + "; ".join(unmet))
	return "\n".join(lines)

func _build_death_screen(parent: Control) -> void:
	_death_panel = PanelContainer.new()
	_death_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death_panel.custom_minimum_size = Vector2(520, 0)
	_death_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color(0.07, 0.06, 0.07, 0.96)
	backdrop.border_color = Color("8d3b33")
	backdrop.set_border_width_all(2)
	backdrop.set_content_margin_all(22)
	_death_panel.add_theme_stylebox_override("panel", backdrop)
	parent.add_child(_death_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_death_panel.add_child(column)
	var title := _label(column, "YOU DIED", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color("f09283")
	_death_text = _label(column, "", 17)
	_death_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_death_reload = _button(column, "Load last save", _reload_after_death)
	_button(column, "Return to menu", _return_to_menu)
	_death_panel.hide()

func _show_death() -> void:
	_discovery_panel.hide()
	_inventory_panel.hide()
	_character_panel.hide()
	_talent_panel.hide()
	_skills_panel.hide()
	_cancel_targeting()
	var permadeath: bool = session.run.mode == "permadeath"
	_death_text.text = ("Permadeath: this run has ended and cannot be continued. The world remains; begin a new run from the menu." if permadeath else "Normal mode: the death was not saved. Load your last save to continue from it.") + "\nTurn %d." % int(session.run.state.turn)
	_death_reload.visible = not permadeath
	_death_panel.show()

func _reload_after_death() -> void:
	if session == null:
		return
	var next := Session.new(store)
	if not next.resume(session.run.run_id):
		_notice.text = next.last_error
		return
	_death_panel.hide()
	_enter_map(next)
	_notice.text = "Loaded your last save."

func _toggle_inventory() -> void:
	if session == null or _menu.visible or session.is_dead():
		return
	_discovery_panel.hide()
	_character_panel.hide()
	_skills_panel.hide()
	_inventory_panel.visible = not _inventory_panel.visible
	_hold_delay = 0.2
	if _inventory_panel.visible:
		_refresh_inventory()
		_inventory_list.grab_focus()
	else:
		get_viewport().gui_release_focus()

func _refresh_inventory(selected: String = "") -> void:
	_inventory_rows = session.inventory_rows()
	_inventory_list.clear()
	_rainbow = _rainbow.filter(func(entry: Array) -> bool: return entry[0] != _inventory_list)
	var index := 0
	for item in _inventory_rows:
		var usable: bool = not session.use_for(item.content_id).is_empty()
		var gear: bool = item.definition.payload.has("equipment")
		var book: bool = item.definition.payload.has("skill_book")
		var tag := "   [gear]" if gear else ("   [book]" if book else ("   [usable]" if usable else ""))
		_inventory_list.add_item("%s%s%s" % [item_label(item.definition, item.metadata), "" if gear else "  x%d" % item.quantity, tag])
		_inventory_list.set_item_tooltip(_inventory_list.item_count - 1, "%s / %s" % [item.name, item.type])
		var icon: Texture2D = Art.shared().item_icon(item.content_id, item.name, item.definition) if Art.shared().ready() else null
		if icon != null:
			_inventory_list.set_item_icon(_inventory_list.item_count - 1, icon)
		_color_row(_inventory_list, _inventory_list.item_count - 1, item.definition, item.metadata)
		if item.content_id == selected or (not item.instance_id.is_empty() and item.instance_id == selected):
			index = _inventory_list.item_count - 1
	_use_button.disabled = _inventory_rows.is_empty()
	if _inventory_rows.is_empty():
		_inventory_detail.text = "Empty. Explore and gather resources or open chests."
	else:
		_inventory_list.select(index)
		_show_inventory_item(index)

func selected_item_id() -> String:
	var picked := _inventory_list.get_selected_items()
	return "" if picked.is_empty() or picked[0] >= _inventory_rows.size() else _inventory_rows[picked[0]].content_id

func _use_selected() -> void:
	var content_id := selected_item_id()
	if session == null or session.is_dead() or content_id.is_empty():
		return
	var row: Dictionary = _inventory_rows[_inventory_list.get_selected_items()[0]]
	var accepted: bool
	if row.definition.payload.has("equipment"):
		accepted = session.equip_item(content_id, row.instance_id)
	elif row.definition.payload.has("skill_book"):
		accepted = session.perform_action({"type": "learn", "content_id": content_id})
	else:
		accepted = session.use_item(content_id)
	_after_action(accepted)
	if _inventory_panel.visible:
		_refresh_inventory(content_id)

func _show_inventory_item(index: int) -> void:
	var item: Dictionary = _inventory_rows[index]
	var stacking := "Stackable / limit %d per stack" % item.stack_limit if item.stackable else "Non-stackable / %d individual items" % item.quantity
	_inventory_detail.text = "%s\n%s / v%d / Quantity: %d\n%s\n%s" % [item.name, item.type, item.version, item.quantity, stacking, item.description]
	if not item.stackable and not item.slots.is_empty():
		_inventory_detail.text += "\nItem ID: " + str(item.slots[0].instance_id).left(22) + "..."
	if item.definition.payload.has("equipment"):
		_inventory_detail.text = "%s\n%s\n%s" % [item_label(item.definition, item.metadata), gear_text(item.definition, item.metadata), item.description]
		var comparison: Dictionary = session.compare_equipment(item.content_id, item.instance_id)
		var changes := PackedStringArray()
		for stat in comparison.get("after", {}):
			if int(comparison.after[stat]) != int(comparison.before[stat]):
				changes.append("%s %d→%d (%+d)" % [session.character_rules.rules.stats[stat].name, comparison.before[stat], comparison.after[stat], int(comparison.after[stat]) - int(comparison.before[stat])])
		var current: Dictionary = comparison.get("replaces", {})
		_inventory_detail.text += "\nIf equipped%s: %s" % ["" if current.is_empty() else " (replaces " + item_label(session._definition(current.content_id, int(current.version)), current.get("metadata", {})) + ")", "no stat change" if changes.is_empty() else ", ".join(changes)]
		_use_button.text = "Equip selected [U / Enter]"
		_use_button.disabled = false
		return
	if item.definition.payload.has("skill_book"):
		_inventory_detail.text = book_text(item)
		_use_button.text = "Learn [U / Enter]"
		_use_button.disabled = false
		return
	_use_button.text = "Use selected [U / Enter]"
	var use: Dictionary = session.use_for(item.content_id)
	var effects := PackedStringArray()
	for effect in use.get("payload", {}).get("effects", []):
		if effect.type in ["apply_status", "cleanse"]:
			effects.append(_skill_effect_text(effect))
			continue
		var amount: int = effect.amount if effect.type == "heal" else effect.amount * 100 / int(session.survival.rules.scale)
		effects.append({"heal": "+%d HP", "sate": "-%d%% hunger", "quench": "-%d%% thirst"}[effect.type] % amount)
	_inventory_detail.text += "\n" + ("Use (%s): %s. Spends 1 turn." % [use.payload.get("verb", "Use"), ", ".join(effects)] if not use.is_empty() else "No use yet.")
	_use_button.disabled = use.is_empty()

func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	if size >= 20 and not text.is_empty() and text == text.to_upper():
		label.add_theme_color_override("font_color", FantasyTheme.GOLD) # Section headers.
	parent.add_child(label)
	return label

func _entry(parent: Node, placeholder: String, text: String) -> LineEdit:
	var entry := LineEdit.new()
	entry.placeholder_text = placeholder
	entry.tooltip_text = placeholder
	entry.max_length = 64
	entry.text = text
	entry.custom_minimum_size.y = 38
	parent.add_child(entry)
	return entry

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _selected_world() -> String:
	return "" if _worlds.selected < 0 else str(_worlds.get_item_metadata(_worlds.selected))

func _refresh_worlds(selected: String = "") -> void:
	_worlds.clear()
	if _data_ready:
		for world in store.list_worlds():
			var loaded: Dictionary = store.load_world(world.world_id)
			var tag := "  [atlas]" if Atlas.enabled(loaded) else ("  [structured]" if Structured.enabled(loaded) else "")
			_worlds.add_item("%s  /  seed %d%s" % [str(world.name).left(32), world.seed, tag])
			var index := _worlds.item_count - 1
			_worlds.set_item_metadata(index, world.world_id)
			if world.world_id == selected:
				_worlds.select(index)
	_refresh_atlas_line()
	_refresh_runs()

func _persistent_world() -> Dictionary:
	## The persistent World is the first atlas World of this save (created on demand).
	if not _data_ready:
		return {}
	for header in store.list_worlds():
		var loaded: Dictionary = store.load_world(header.world_id)
		if Atlas.enabled(loaded):
			return loaded
	return {}

func _refresh_atlas_line() -> void:
	if _atlas_line == null:
		return
	var world := _persistent_world()
	_chart.disabled = world.is_empty()
	_chart_snow.disabled = world.is_empty()
	if world.is_empty():
		_atlas_line.text = "No persistent world yet: New Adventure charts one (a few seconds, once)."
		return
	var atlas := Atlas.new()
	if not atlas.open(store.content, world):
		_atlas_line.text = atlas.last_error
		return
	var names: Array = atlas.lands.values().map(func(plan: Dictionary) -> String: return str(plan.name))
	if _pending_land.is_empty():
		_chart_snow.text = SNOW_RUN if atlas.lands.values().any(func(p: Dictionary) -> bool: return p.get("layout", {}).get("id", "") == SNOW_LAYOUT) else CHART_SNOW
	_atlas_line.text = "%s: %d lands, revision %d. Each adventure starts in a random land." % [world.name, atlas.lands.size(), atlas.revision()]
	_atlas_line.tooltip_text = ", ".join(names)

func _on_new_adventure() -> void:
	## Normal play: the persistent World, a random eligible land, a fresh character.
	var world := _persistent_world()
	if world.is_empty():
		_message("Charting the persistent world for the first time...")
		_adventure.disabled = true
		await get_tree().process_frame
		await get_tree().process_frame
		world = Atlas.create_world(store, "The Evolving Realm", int(randi() & 0x7fffffff))
		_adventure.disabled = false
		if world.is_empty():
			_message(store.last_error, true)
			return
	_start_adventure(world, "any")

func _start_adventure(world: Dictionary, land_id: String) -> void:
	var next := Session.new(store)
	if not next.start_new(world.world_id, int(randi() & 0x7fffffff), land_id, _mode.get_item_metadata(_mode.selected), _time_model.get_item_metadata(_time_model.selected)):
		_message(next.last_error, true)
		_refresh_worlds(world.world_id)
		return
	_refresh_worlds(world.world_id)
	var arrival := describe_events(next.last_events)
	_enter_map(next)
	_notice.text = (arrival + " " + _notice.text).strip_edges()

func _on_chart_land(layout_id: String = "") -> void:
	## Development: propose -> validate -> (click again to approve) -> activate.
	var world := _persistent_world()
	if world.is_empty():
		return
	var atlas := Atlas.new()
	if not atlas.open(store.content, world):
		_message(atlas.last_error, true)
		return
	var button: Button = _chart_snow if not layout_id.is_empty() else _chart
	if not layout_id.is_empty():
		for plan in atlas.lands.values():
			if plan.get("layout", {}).get("id", "") == layout_id:
				_start_adventure(world, plan.land_id) # Charted already: a new Run there.
				return
	if _pending_land.get("world_id", "") != world.world_id or int(_pending_land.get("revision", -1)) != atlas.revision() or _pending_land.get("layout", "") != layout_id:
		_chart.text = "Chart a new land (dev)"
		_chart_snow.text = CHART_SNOW
		_message("Designing a land beyond a frontier gate%s..." % (" (validating the whole land on foot, a few seconds)" if not layout_id.is_empty() else ""))
		await get_tree().process_frame
		await get_tree().process_frame
		var proposal: Dictionary = atlas.propose_layout_land(layout_id) if not layout_id.is_empty() else atlas.propose_expansion()
		if proposal.is_empty():
			_message(atlas.last_error, true)
			return
		var problem: String = atlas.validate(proposal)
		if not problem.is_empty():
			_message("Proposal rejected by validation: " + problem, true)
			return
		_pending_land = {"world_id": world.world_id, "revision": atlas.revision(), "proposal": proposal, "layout": layout_id}
		button.text = "Approve: %s" % proposal.land.name
		_message("PROPOSED (validated, not active): %s. %s. Click Approve to add it to the World." % [proposal.summary, str(proposal.land.history)])
		return
	if not atlas.activate(_pending_land.proposal, {"by": "developer (main menu)"}):
		_message(atlas.last_error, true)
		return
	_message("Revision %d: %s joins the World. Established lands are unchanged; new adventures may begin there." % [atlas.revision(), _pending_land.proposal.land.name])
	_pending_land = {}
	_chart.text = "Chart a new land (dev)"
	_chart_snow.text = CHART_SNOW
	_refresh_worlds(world.world_id)

func _refresh_runs() -> void:
	_runs.clear()
	_resume.disabled = true
	_new_run.disabled = not _data_ready or _selected_world().is_empty()
	if _new_run.disabled:
		return
	for run in store.list_runs(_selected_world()):
		_runs.add_item("%s  |  seed %d  |  %s%s" % [str(run.run_id).left(8), run.seed, run.mode, "  |  ENDED" if run.status == "dead" else ""])
		_runs.set_item_metadata(_runs.item_count - 1, run.run_id)
		_runs.set_item_tooltip(_runs.item_count - 1, "%s\nCreated: %s" % [run.run_id, run.created_at])
	if _runs.item_count > 0:
		_runs.select(0)
		_resume.disabled = false

func _parse_seed(entry: LineEdit) -> Variant:
	var text := entry.text.strip_edges()
	if text.is_empty():
		return int(randi() & 0x7fffffff)
	if not text.is_valid_int() or not Data.seed_value(text.to_int()):
		_message("Seed must be an integer between -2147483648 and 2147483647.", true)
		return null
	return text.to_int()

func use_legacy_defaults() -> void:
	## Baseline suites and release acceptance select the pre-M03 layout and turn model
	## explicitly (like Session.auto_awaken = false); players get the M03 defaults.
	_world_layout.select(1)
	_time_model.select(0)

func _on_create_world() -> void:
	var seed_value: Variant = _parse_seed(_world_seed)
	if seed_value == null:
		return
	if _world_layout.get_item_metadata(_world_layout.selected) == "atlas":
		_message("Charting the atlas World...")
		await get_tree().process_frame
		await get_tree().process_frame
		var atlas_world := Atlas.create_world(store, _name_entry.text, seed_value)
		if atlas_world.is_empty():
			_message(store.last_error, true)
			return
		_refresh_worlds(atlas_world.world_id)
		_message("Atlas World created with its first lands. Begin a run (a random land) or New Adventure.")
		return
	if _world_layout.get_item_metadata(_world_layout.selected) == "structured":
		var structured := Structured.create(store, _name_entry.text, seed_value)
		if structured.is_empty():
			_message(store.last_error, true)
			return
		_refresh_worlds(structured.world_id)
		_message("Structured World created: named regions with a waystone, supplies and a relic site each. Begin a run.")
		return
	var blueprint := StarterPack.blueprint(seed_value)
	if blueprint.is_empty():
		_message("Could not establish a valid landmark for this seed.", true)
		return
	var world := store.create_world(_name_entry.text, seed_value, 1, blueprint)
	if world.is_empty():
		_message(store.last_error, true)
		return
	_refresh_worlds(world.world_id)
	_message("World created. Choose a starting biome, then begin a run.")

func _on_new_run() -> void:
	var seed_value: Variant = _parse_seed(_run_seed)
	if seed_value == null or _selected_world().is_empty():
		return
	var next := Session.new(store)
	if not next.start_new(_selected_world(), seed_value, _biome.get_item_metadata(_biome.selected), _mode.get_item_metadata(_mode.selected), _time_model.get_item_metadata(_time_model.selected)):
		_message(next.last_error, true)
		_refresh_runs()
		return
	_enter_map(next)

func _on_resume() -> void:
	var selected := _runs.get_selected_items()
	if selected.is_empty():
		return
	var next := Session.new(store)
	if not next.resume(_runs.get_item_metadata(selected[0])):
		_message(next.last_error, true)
		return
	_enter_map(next)

func _enter_map(active_session: RefCounted) -> void:
	_discovery_panel.hide()
	_realtime = null
	if active_session.realtime:
		var clock := Realtime.new()
		if not clock.configure(active_session):
			_message(clock.last_error, true)
			_refresh_runs()
			return
		_realtime = clock
		active_session.action_completed.connect(func(action: Dictionary, _result: Dictionary) -> void:
			if _realtime != null: _realtime.note_action(str(action.get("type", ""))))
	map_view.smooth_steps = _realtime != null
	_controls_hint.text = CONTROLS_REALTIME if _realtime != null else CONTROLS_TURN
	session = active_session
	_target_id = ""
	_death_panel.hide()
	_menu.hide()
	_hud.show()
	map_view.show()
	map_view.attach(session)
	_world_map.attach(session)
	_refresh_exploration()
	_hold_delay = 0.2
	_discard_on_exit = false
	_update_info()
	_notice.text = "Explore freely. Save with Ctrl+S; Esc saves and returns to the menu."
	if _realtime != null:
		_notice.text = "REAL TIME: hold WASD to move, F to attack. \"!\" = a blow is coming: step away. Panels and the map pause."
	get_viewport().gui_release_focus()
	_talent_panel.hide()
	_skills_panel.hide()
	_targeting = {}
	map_view.skill_marks = {}
	if not session.awakened_now.is_empty():
		show_talent(true) # Reveal once; the record is already part of the Run state.
		session.awakened_now = []

const ROUTE_NAMES := {"pass": "mountain pass", "causeway": "causeway", "harbor": "harbour"}
const DIRECTIONS_8 := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

func _refresh_exploration() -> void:
	## Structured Worlds: known leads, places and region bearings -> map markers, journal
	## and the HUD region line. Only acquired knowledge (Task A contract) is shown.
	_leads = session.exploration_leads()
	_frontiers = session.exploration_frontiers()
	var markers: Array = []
	var journal: Array = []
	var routes: Array = [] # Atlas lands and routes lead the journal; clues follow.
	for land in session.known_lands():
		routes.append({"state": "discovered", "title": "◆ %s (%s)" % [land.name, land.title], "detail": "%s — %d/%d regions walked" % [land.epithet, land.regions.size(), int(land.region_count)]})
	# What resolved places said in this Run, newest first: words only, never a marker.
	var notes: Array = []
	for note in session.places.notes(session):
		notes.append({"state": "note", "title": "» " + str(note.place),"detail": note.message, "wrap": true})
	for lead in _leads:
		var title := str(lead.metadata.get("title", lead.role))
		if lead.knowledge == "lead": # Not seen yet: discovered ones are already map landmarks.
			markers.append({"id": "lead:" + str(lead.instance_id), "position": lead.position.duplicate(), "label": "? " + title, "kind": "lead"})
		var state := "resolved" if lead.resolved else ("discovered" if lead.knowledge == "discovered" else "lead")
		journal.append({"state": state, "title": "%s %s" % [{"lead": "?", "discovered": "•", "resolved": "✓"}[state], _short_title(title)], "detail": "%s — %s" % [{"lead": "lead, not seen yet", "discovered": "found", "resolved": "done"}[state], str(lead.reason)]})
	for frontier in _frontiers:
		if frontier.has("gate_id"): # Atlas route/gate (M04): only what this Run has seen or read.
			var state: String = {"open": "open", "locked": "locked", "veil": "into the Veil"}.get(frontier.state, frontier.state)
			markers.append({"id": "frontier:" + str(frontier.gate_id), "position": frontier.position.duplicate(), "label": "→ %s (%s)" % [frontier.name, state], "kind": "frontier"})
			routes.append({"state": "frontier", "title": "→ %s, %s" % [frontier.name, frontier.direction], "detail": str(frontier.opportunity)})
			continue
		var bounds: Dictionary = frontier.bounds
		var center := {"x": int(bounds.x) + int(bounds.size) / 2, "y": int(bounds.y) + int(bounds.size) / 2}
		markers.append({"id": "frontier:" + str(frontier.region_id), "position": center, "label": "→ %s (%s, unsurveyed)" % [frontier.name, frontier.direction], "kind": "frontier"})
		journal.append({"state": "frontier", "title": "→ %s (%s)" % [frontier.name, frontier.direction], "detail": "unsurveyed — %s" % frontier.opportunity})
	_world_map.set_markers(markers)
	_world_map.set_journal(routes + notes + journal)

func _after_exploration_events(events: Array) -> void:
	if events.any(func(e: Dictionary) -> bool: return e.get("type") in ["discovery", "location", "land_entered", "region_entered", "route_sighted", "route_learned"]):
		_refresh_exploration()

func _bearing(target: Dictionary) -> String:
	var delta := Vector2(int(target.x) - session.position.x, int(target.y) - session.position.y)
	if delta.length() < 1.0:
		return "here"
	return DIRECTIONS_8[posmod(roundi(delta.angle() / (PI / 4.0)), 8)]

func _hold_notice(events: Array) -> void:
	## Keep a place/discovery message readable: routine real-time notices wait for it.
	if events.any(func(e: Dictionary) -> bool: return str(e.get("type", "")) in ["location", "discovery", "land_entered"]):
		_notice_hold_until = Time.get_ticks_msec() + NOTICE_HOLD_MS

func weather_text(status: Dictionary) -> String:
	## "Blizzard: EXPOSED −1 HP in 3s (wind-scoured)" / "Blizzard: sheltered (roof)".
	var unit := "s" if session.realtime else " turns"
	var text := str(status.weather)
	if status.exposed:
		text += ": EXPOSED −1 HP in %d%s" % [int(status.next_damage_in), unit]
		text += {"lee": " (lee slope: slower)", "exposed": " (wind-scoured: faster)"}.get(str(status.get("area", "")), "")
	elif status.sheltered:
		text += ": sheltered (%s)" % ("under a roof" if status.shelter == "roof" else "beside cover")
	return text + " · %d%s left" % [int(status.remaining), unit]

func region_text() -> String:
	## HUD line: current region, then the nearest unfinished lead or a region bearing.
	var region: Dictionary = session.world_region()
	if region.is_empty():
		return ""
	var text := "Region: %s (danger %d, %s)" % [region.name, int(region.danger), region.opportunity]
	if region.has("land_name"): # Atlas World: weather where you stand first, then land > region.
		text = "%s › %s (danger %d, %s)" % [region.land_name, region.name, int(region.danger), region.opportunity]
		var status: Dictionary = session.environment_status()
		if not str(status.get("weather", "")).is_empty():
			text = weather_text(status) + "  |  " + text # First: it must never be cut off.
		elif not str(status.get("incoming", "")).is_empty():
			text = "⚠ %s coming in %d%s — find cover  |  %s" % [status.incoming, int(status.incoming_in), "s" if session.realtime else " turns", text]
		if not str(status.get("hazard", "")).is_empty():
			text = "⚠ " + status.hazard + "  |  " + text
	var best: Dictionary = {}
	var best_distance := 2147483647
	for lead in _leads:
		var distance := absi(int(lead.position.x) - session.position.x) + absi(int(lead.position.y) - session.position.y)
		if not lead.resolved and distance < best_distance:
			best = lead
			best_distance = distance
	if not best.is_empty():
		text += "  |  Lead: %s, %d tiles %s%s" % [_short_title(str(best.metadata.get("title", best.role))), best_distance, _bearing(best.position), "" if best.knowledge == "lead" else " (found)"]
	elif not _frontiers.is_empty():
		text += "  |  Onward: %s to the %s" % [_frontiers[0].name, _frontiers[0].direction]
	return text

static func _short_title(title: String) -> String:
	## "Silver Hunting wood - Healing grove" -> "Healing grove" (the region is shown already).
	return title.get_slice(" - ", 1) if title.contains(" - ") else title

func _update_info() -> void:
	_info.text = "  %s  /  Run %s%s\n  Tile (%d, %d) | %s | Turn %d | Explored %d | Chunks %d" % [session.world.name, str(session.run.run_id).left(8), " * unsaved" if session.dirty else "", session.position.x, session.position.y, session.terrain.biome_at(session.position), session.run.state.turn, session.explored.size(), session.cache.chunks.size()]
	_region_hint.text = region_text()
	_region_hint.tooltip_text = _region_hint.text
	if _realtime != null: # Real time: `turn` counts world seconds.
		_info.text = _info.text.replace("Turn %d" % session.run.state.turn, "Time %d s%s" % [session.run.state.turn, " | resting" if session.resting else ""])
	var stats: Dictionary = session.combat_stats() # Effective: base + level + gear.
	_hp_label.text = "Lv %d  HP %d/%d  ATK %d DEF %d" % [session.character_rules.level(session.run.state.character), stats.hp, stats.max_hp, stats.attack, stats.defense]
	_hp_bar.max_value = int(stats.max_hp)
	_hp_bar.value = int(stats.hp)
	var worst: int = session.survival.worst_level(session.stats())
	var recovery := "regen" if worst == 0 and int(stats.hp) < int(stats.max_hp) else ("no regen" if worst > 0 and int(stats.hp) < int(stats.max_hp) else "")
	_survival_label.text = "Hunger %d%%  Thirst %d%%%s" % [session.survival.percent(session.stats(), "hunger"), session.survival.percent(session.stats(), "thirst"), "" if recovery.is_empty() else "  " + recovery]
	# Skill resource as a slim bar with its numbers inside (keeps the HUD width).
	var resource_id: String = session.skill_rules.resource_ids()[0]
	_energy_bar.max_value = session.skills.resource_max(session, resource_id)
	_energy_bar.value = session.skills.resource(session, resource_id)
	_energy_label.text = "%s %d/%d" % [session.skill_rules.rules.resources[resource_id].short, int(_energy_bar.value), int(_energy_bar.max_value)]
	_survival_label.modulate = [Color("c8c8c8"), Color("f0c060"), Color("ff7a6b"), Color("ff4b3e")][worst]
	var foe := current_target()
	map_view.target_id = "" if foe.is_empty() else foe.instance_id
	if foe.is_empty():
		_target_hint.text = "No creature next to you."
	else:
		var count: int = session.roster.targets(session).size()
		var foe_stats: Dictionary = session.roster.creature_stats(session, foe)
		_target_hint.text = "Target: %s (%s, %s)  HP %d/%d  ATK %d DEF %d  |  F: attack%s" % [foe.definition.name, foe.definition.payload.disposition, foe.state, foe.hp, foe.max_hp, foe_stats.attack, foe_stats.defense, "  Tab: next (%d)" % count if count > 1 else ""]
	var active_statuses: String = session.statuses.describe(session, session.run.state.character.statuses)
	_energy_label.tooltip_text = active_statuses
	if not active_statuses.is_empty(): _target_hint.text += "\nYou: " + active_statuses
	if not foe.is_empty():
		_target_hint.text += "\n" + session.statuses.describe(session, foe.get("statuses", []))
	var target: Dictionary = session.interaction_target()
	_interaction_hint.text = "E: interact / choose an approach.  I: inventory.  J: Knowledge."
	if not target.is_empty():
		var definition: Dictionary = session.objects.definition_for(target)
		_interaction_hint.text = "E: %s %s  /  (%d, %d)" % [str(definition.payload.interaction).capitalize(), definition.name, target.position.x, target.position.y]
	elif not session.places.targets(session).is_empty():
		_interaction_hint.text = place_hint(session.places.targets(session)[0])
	elif session.places.search_cue(session):
		_interaction_hint.text = "The ground nearby looks disturbed... X: search the surroundings."

func place_hint(place: Dictionary) -> String:
	## Name, state and the next interaction (with unmet requirements) of a known place.
	var definition: Dictionary = session.locations.definition_for(place)
	var state: String = session.places.state(session, place)
	var next: Dictionary = session.places.next_interaction(session, place)
	if next.is_empty():
		return "%s [%s] — nothing more to do here." % [definition.name, state]
	var needs: Array = session.places.unmet(session, session.locations.event(next.event).payload.get("conditions", []))
	return "E: %s — %s [%s]%s" % [next.get("verb", "Explore"), definition.name, state, "  (needs %s)" % ", ".join(needs) if not needs.is_empty() else ""]

func current_target() -> Dictionary:
	## Selected adjacent creature; falls back to the first valid one (ID order).
	if session == null:
		return {}
	var nearby: Array = session.roster.targets(session)
	for creature in nearby:
		if creature.instance_id == _target_id:
			return creature
	return {} if nearby.is_empty() else nearby[0]

func _cycle_target() -> void:
	var nearby: Array = session.roster.targets(session)
	if nearby.is_empty():
		_notice.text = "No creature next to you to target."
		return
	var index := 0
	for i in nearby.size():
		if nearby[i].instance_id == current_target().instance_id:
			index = (i + 1) % nearby.size()
	_target_id = nearby[index].instance_id
	_update_info()

func _attack() -> void:
	var foe := current_target()
	if foe.is_empty():
		_notice.text = "Nothing to attack — stand next to a creature (no turn spent)."
		_update_info()
		return
	_target_id = foe.instance_id
	if _realtime != null:
		if not _realtime.attack(foe.instance_id):
			_notice.text = _realtime.last_error # Cooldown: nothing happens, nothing is spent.
			return
		_after_action(true)
		return
	_after_action(session.attack_target(foe.instance_id))

func _wait() -> void:
	_after_action(session.wait_turn(), "You wait a turn.")

func _rest() -> void:
	if _realtime != null:
		if session.rest():
			_notice.text = "Resting… needs and energy recover faster. Move, attack or press R to stop." if session.resting else "You stop resting."
			_update_info()
		else:
			_notice.text = session.last_error
		return
	if not session.rest():
		_after_action(false)
		return
	var summary: Dictionary = session.last_result
	_after_action(true)
	var why: String = {"rested": "", "healed": " Fully healed.", "danger": " Interrupted: danger in sight!", "attacked": " Interrupted: you were attacked!", "needs": "", "died": ""}[summary.reason]
	_notice.text = ("Rested %d turn%s (%+d HP).%s %s" % [summary.turns, "" if summary.turns == 1 else "s", summary.hp_gained, why, _notice.text]).strip_edges()

func _after_action(accepted: bool, quiet: String = "") -> void:
	## Shared feedback for every turn-spending action.
	if not accepted:
		_notice.text = session.last_error
		_update_info()
		return
	map_view.refresh()
	_world_map.refresh(session.last_events)
	_after_exploration_events(session.last_events)
	map_view.show_events(session.last_events)
	var text := describe_events(session.last_events)
	_notice.text = text if not text.is_empty() else quiet
	_hold_notice(session.last_events)
	_update_info()
	if session.is_dead():
		_show_death()

func _receipt_text(item: Dictionary) -> String:
	var tier: String = item.get("quality", "")
	return ("[%s] %s" % [session.quality.tier(tier).name, item.name] if session != null and session.quality.has(tier) else str(item.name)) + " x%d" % item.quantity

static func _stat_delta(before: Dictionary, after: Dictionary) -> String:
	var parts := PackedStringArray()
	for stat in after:
		if int(after[stat]) != int(before.get(stat, 0)):
			parts.append("%s %d→%d" % [{"max_hp": "Max HP", "attack": "ATK", "defense": "DEF"}.get(stat, stat), int(before.get(stat, 0)), int(after[stat])])
	return "No stat change." if parts.is_empty() else ", ".join(parts) + "."

func describe_events(events: Array) -> String:
	var parts := PackedStringArray()
	for event in events:
		match event.type:
			"hit":
				if event.attacker == "player":
					parts.append("You hit %s for %d (%d/%d)." % [event.name, event.damage, event.hp, event.max_hp])
				elif int(event.damage) == 0:
					parts.append("%s attacks, but deals no damage." % event.name)
				else:
					parts.append("%s hits you for %d!" % [event.name, event.damage])
			"creature_death":
				var received := PackedStringArray()
				for item in event.get("display_received", event.received):
					received.append(_receipt_text(item))
				parts.append("%s dies. Loot: %s." % [event.name, ", ".join(received)])
			"player_death":
				parts.append("You have died.")
			"death_save_failed":
				parts.append("Could not record the death: " + event.error)
			"equip":
				parts.append("Equipped %s%s. %s" % [event.name, "" if event.replaced.is_empty() else " (replacing %s)" % event.replaced, _stat_delta(event.before, event.after)])
			"unequip":
				parts.append("Unequipped %s. %s" % [event.name, _stat_delta(event.before, event.after)])
			"xp":
				parts.append("+%d XP." % event.amount)
			"skill":
				parts.append("%s%s%s." % [event.name, " → " + event.target if not str(event.target).is_empty() else "", ": " + event.summary if not str(event.summary).is_empty() else ""])
			"learn":
				parts.append("Learned %s!%s" % [event.name, " The book is used up." if event.consumed else " The book remains."])
			"stunned":
				parts.append("%s is bound and cannot act." % event.name)
			"status_apply":
				parts.append("%s: %s x%d (%dt)." % [event.target, event.status, int(event.stacks), int(event.remaining)])
			"status_dispel":
				parts.append("%s: %s removed." % [event.target, event.status])
			"status_tick":
				var by := str(event.get("source", ""))
				parts.append("%s: %s %+d HP%s." % [event.target, event.status, int(event.amount), "" if by.is_empty() or by == "you" else " (from %s)" % by])
			"dodge":
				parts.append("You dodge %s's attack." % event.name)
			"rest_start":
				pass # The R handler explains resting.
			"rest_end":
				if event.reason != "manual":
					parts.append({"danger": "Rest interrupted: danger in sight!", "attacked": "Rest interrupted: you were attacked!", "healed": "Fully rested.", "needs": "Rest interrupted: you need food, water or care."}.get(event.reason, "You stop resting."))
			"status_error":
				parts.append("Status could not resolve: " + str(event.error))
			"status_blocked":
				parts.append("Status prevents action; a turn passes.")
			"status_end":
				parts.append("%s wears off." % str(event.status).capitalize())
			"talent":
				if not event.get("quiet", false):
					parts.append("[%s] %s: %s." % [event.rank, event.name, event.summary if not str(event.summary).is_empty() else "activated"])
			"level_up":
				parts.append("LEVEL UP! %s level %d." % [event.name, event.level])
			"use":
				var effects := PackedStringArray()
				for change in event.changes:
					if change.type == "status": continue
					effects.append("%s %d -> %d" % [{"hp": "HP", "hunger": "hunger", "thirst": "thirst"}[change.stat], change.before, change.after])
				parts.append(("%s: %s." % [event.verb, event.name]) if effects.is_empty() else ("%s: %s (%s)." % [event.verb, event.name, ", ".join(effects)]))
			"survival":
				parts.append({"warning": "You are getting %s.", "danger": "You are badly %s — find food and water!", "depleted": "You are starving and dehydrating: %s now costs HP!"}[event.level] % {"hunger": "hungry", "thirst": "thirsty"}.get(event.need, event.need))
			"starvation":
				parts.append("Starvation hurts you (-%d HP)." % event.damage)
			"discovery":
				parts.append("DISCOVERED: %s — %s" % [event.name, event.description])
			"location":
				var outcome := PackedStringArray()
				for item in event.get("display_received", event.received):
					outcome.append(_receipt_text(item))
				for change in event.changes:
					outcome.append("%s %d -> %d" % [{"hp": "HP", "hunger": "hunger", "thirst": "thirst"}.get(change.stat, change.stat), change.before, change.after])
				if int(event.damage) > 0:
					outcome.append("-%d HP" % int(event.damage))
				parts.append("%s%s: %s%s" % ["⚠ " if event.tone == "bane" else "", event.verb, event.message, (" (" + ", ".join(outcome) + ")") if not outcome.is_empty() else ""])
			"search":
				if event.found.is_empty(): parts.append("You search the area but find nothing new.")
			"location_error":
				parts.append("Place could not be recorded: " + str(event.error))
			"land_entered":
				parts.append("LAND: %s, %s (%s, %s)." % [event.name, event.epithet, event.title, event.climate])
			"region_entered":
				parts.append("Region: %s (danger %d)." % [event.name, int(event.danger)])
			"route_sighted":
				parts.append("You sight a %s to the %s." % [ROUTE_NAMES.get(event.kind, "route"), event.side])
			"route_learned":
				parts.append("Road-marks tell of a %s to the %s." % [ROUTE_NAMES.get(event.kind, "route"), event.side])
			"weather":
				match str(event.state):
					"start": parts.append("%s! Sight drops to %d." % [event.name, int(event.sight)])
					"warning": parts.append("⚠ The wind rises: %s in %d%s. Head for pines, rocks or a roof." % [str(event.name).to_lower(), int(event.get("in", 0)), "s" if session != null and session.realtime else " turns"])
					_: parts.append("The %s passes." % str(event.name).to_lower())
			"environment":
				parts.append("%s: %d HP%s" % [event.name, int(event.amount), " — shelter beside pines or rocks, or under a roof!" if event.kind == "exposure" else " — get off the scorching ground!"])
			"knowledge":
				parts.append("Knowledge learned: %s. Press J to read." % event.name)
			"autosave":
				parts.append("Autosaved.")
			"autosave_failed":
				parts.append("Autosave failed: " + event.error)
	return " ".join(parts)

func _interact() -> void:
	if session == null or _panel_open():
		return
	if _show_interactions(): return
	var target: Dictionary = session.interaction_target()
	if session.interact():
		if not target.is_empty() and not session.last_result.get("place", false):
			map_view.show_received(session.last_result.received, Vector2i(int(target.position.x), int(target.position.y)))
		if session.last_result.get("place", false):
			_after_action(true) # The place's own notice lists its rewards.
			return
		var received := PackedStringArray()
		for item in session.last_result.received:
			received.append(_receipt_text(item))
		_after_action(true)
		_notice.text = ("Received: " + ", ".join(received) + " " + _notice.text).strip_edges()
	else:
		_after_action(false)

func _search() -> void:
	## Declared rule: searching the surroundings always takes one turn.
	if session == null or _panel_open():
		return
	_after_action(session.search(), "You search the area but find nothing.")

func move_player(direction: Vector2i) -> bool:
	if session == null or _menu.visible or _panel_open() or session.is_dead():
		return false
	map_view.face(direction)
	var moved: bool = session.try_move(direction)
	_after_action(moved)
	return moved

func _on_waypoint_changed(waypoint: Dictionary) -> void:
	if session == null:
		return
	_update_info()
	_notice.text = "Waypoint cleared." if waypoint.is_empty() else "Waypoint set to (%d, %d)." % [int(waypoint.x), int(waypoint.y)]

func _unhandled_key_input(event: InputEvent) -> void:
	if session == null or _menu.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if _panel_open():
		return
	if session.is_dead():
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_return_to_menu()
		get_viewport().set_input_as_handled()
		return
	var acting: bool = event.physical_keycode in [KEY_E, KEY_X] or event.keycode in [KEY_E, KEY_X] or (event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9) or (event.keycode >= KEY_1 and event.keycode <= KEY_9)
	if _realtime != null and acting and not event.ctrl_pressed and not event.alt_pressed and not _realtime.ready_for_action():
		_notice.text = _realtime.last_error # Real time: short shared recovery between actions.
		get_viewport().set_input_as_handled()
		return
	if _is_save_shortcut(event):
		_save_game()
	elif event.ctrl_pressed or event.alt_pressed:
		return # Modified keys are not movement/interaction commands.
	elif event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		_return_to_menu()
	elif event.keycode == KEY_E or event.physical_keycode == KEY_E:
		_interact()
	elif event.keycode == KEY_X or event.physical_keycode == KEY_X:
		_search()
	elif event.keycode == KEY_I or event.physical_keycode == KEY_I:
		_toggle_inventory()
	elif event.keycode == KEY_F or event.physical_keycode == KEY_F:
		_attack()
	elif event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB:
		_cycle_target()
	elif event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE:
		_wait()
	elif event.keycode == KEY_R or event.physical_keycode == KEY_R:
		_rest()
	elif event.keycode == KEY_C or event.physical_keycode == KEY_C:
		_toggle_character()
	elif event.keycode == KEY_T or event.physical_keycode == KEY_T:
		_toggle_talent()
	elif event.keycode == KEY_K or event.physical_keycode == KEY_K:
		_toggle_skills()
	elif event.keycode == KEY_J or event.physical_keycode == KEY_J:
		_show_knowledge()
	elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
		begin_skill(event.physical_keycode - KEY_1)
	elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
		begin_skill(event.keycode - KEY_1)
	elif _realtime == null: # Real time reads held movement keys every frame in _process.
		for action in MOVE_KEYS:
			if event.is_action_pressed(action):
				move_player(MOVE_DIRECTIONS[action])
				_hold_delay = 0.2
				break
	get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if _discovery_panel != null and _discovery_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or (_discovery_mode == "knowledge" and event.keycode == KEY_J):
			_close_discovery_panel()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and _world_map != null:
		if _world_map.map_open:
			if event.keycode in [KEY_M, KEY_ESCAPE] or event.physical_keycode in [KEY_M, KEY_ESCAPE]:
				_world_map.close_map()
			get_viewport().set_input_as_handled()
			return
		if session != null and not _menu.visible and not session.is_dead() and not _panel_open():
			if event.keycode == KEY_M or event.physical_keycode == KEY_M:
				_world_map.open_map()
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_N or event.physical_keycode == KEY_N:
				_world_map.toggle_minimap()
				get_viewport().set_input_as_handled()
				return
	if not _targeting.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		_targeting_input(event)
		get_viewport().set_input_as_handled() # Modal while choosing a target.
		return
	if _skills_panel != null and _skills_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_K, KEY_ESCAPE] or event.physical_keycode in [KEY_K, KEY_ESCAPE]:
			_toggle_skills()
			get_viewport().set_input_as_handled()
		elif _is_save_shortcut(event):
			_save_game()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_U or event.physical_keycode == KEY_U:
			_use_selected_skill()
			get_viewport().set_input_as_handled()
		return
	if _talent_panel != null and _talent_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if _is_save_shortcut(event):
			_save_game()
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_T] or event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_T]:
			_close_talent()
		get_viewport().set_input_as_handled() # Modal: no movement or other commands.
		return
	if _character_panel != null and _character_panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_C, KEY_ESCAPE] or event.physical_keycode in [KEY_C, KEY_ESCAPE]:
			_toggle_character()
			get_viewport().set_input_as_handled()
		elif _is_save_shortcut(event):
			_save_game()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_U or event.physical_keycode == KEY_U:
			_unequip_selected()
			get_viewport().set_input_as_handled()
		return
	if _inventory_panel == null or not _inventory_panel.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_I, KEY_ESCAPE] or event.physical_keycode in [KEY_I, KEY_ESCAPE]:
		_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif _is_save_shortcut(event):
		_save_game()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_U or event.physical_keycode == KEY_U:
		_use_selected()
		get_viewport().set_input_as_handled()

static func _is_save_shortcut(event: InputEventKey) -> bool:
	# Not F5: in the Godot editor F5 restarts the project and would drop unsaved play.
	return event.ctrl_pressed and (event.keycode == KEY_S or event.physical_keycode == KEY_S)

func _process(delta: float) -> void:
	for entry in _rainbow:
		if not is_instance_valid(entry[0]) or session == null:
			continue
		if entry[0] is Label:
			entry[0].modulate = session.talent_rules.color(entry[2], Time.get_ticks_msec() / 1000.0) # Rainbow talent rank.
		elif entry[1] < entry[0].item_count:
			entry[0].set_item_custom_fg_color(entry[1], session.quality.color(entry[2], Time.get_ticks_msec() / 1000.0))
	if session == null or _menu.visible or _panel_open() or session.is_dead():
		return # Real time: this is also the pause rule (menus, panels, targeting, death).
	if _realtime != null:
		_realtime_frame(delta)
		return
	_hold_delay -= delta
	if _hold_delay > 0 or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT):
		return
	for action in MOVE_KEYS:
		if Input.is_action_pressed(action):
			move_player(MOVE_DIRECTIONS[action])
			_hold_delay = 0.14
			return

func _realtime_frame(delta: float) -> void:
	## One frame of a real-time Run: held keys -> controller -> render and messages.
	if DisplayServer.get_name() != "headless" and not get_window().has_focus():
		return # Alt-tab pauses the world.
	var direction := Vector2i.ZERO
	if not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_ALT):
		for action in MOVE_KEYS:
			if Input.is_action_pressed(action):
				direction += MOVE_DIRECTIONS[action]
	direction = direction.clamp(-Vector2i.ONE, Vector2i.ONE)
	var events: Array = _realtime.update(int(round(delta * 1000.0)), direction)
	if _realtime.moved:
		map_view.player_step_time = _realtime.last_step_ms / 1000.0
		map_view.refresh() # Fog, chunks, objects: only when the hero changed tile.
	elif direction != Vector2i.ZERO:
		map_view.face(direction) # Blocked: still turn toward the attempted direction.
	if not _realtime.moved and (_realtime.creatures.moved or not events.is_empty()):
		map_view.sync_actors()
	if events.is_empty() and not _realtime.moved:
		return
	_world_map.refresh(events) # Minimap/fog/landmarks follow real-time steps too.
	_after_exploration_events(events)
	map_view.show_events(events)
	var text := describe_events(events)
	if not text.is_empty() and (Time.get_ticks_msec() >= _notice_hold_until or not events.all(func(e: Dictionary) -> bool: return str(e.get("type", "")) in ROUTINE_EVENTS)):
		_notice.text = text
		_hold_notice(events)
	_update_info()
	if session.is_dead():
		_show_death()

func _save_game() -> void:
	if session == null:
		return
	if session.save():
		_discard_on_exit = false
		_notice.text = "Saved to local SQLite."
	else:
		_notice.text = "Save failed: " + session.last_error
	_update_info()

func _return_to_menu() -> void:
	if session == null:
		return
	if session.is_dead():
		# Normal: the death is discarded and the last save stays. Permadeath: retry
		# recording the ending if the immediate death save failed.
		if session.run.mode == "permadeath":
			session.save()
	elif not session.save():
		_notice.text = "Save failed; staying in game: " + session.last_error
		return
	var world_id: String = session.world.world_id
	_discovery_panel.hide()
	session = null
	_realtime = null
	map_view.smooth_steps = false
	_inventory_panel.hide()
	_character_panel.hide()
	_talent_panel.hide()
	_skills_panel.hide()
	_targeting = {}
	_death_panel.hide()
	map_view.skill_marks = {}
	map_view.clear_map()
	map_view.hide()
	_world_map.detach()
	_hud.hide()
	_menu.show()
	_refresh_worlds(world_id)
	_message("Run saved. Continue it, or begin an independent run in the same world.")

func _message(text: String, error: bool = false) -> void:
	_status.text = text
	_status.modulate = Color("f09283") if error else Color("d4c899")

func _request_exit() -> void:
	if session != null and session.is_dead():
		if session.run.mode == "permadeath":
			session.save()
		get_tree().quit()
		return
	if session != null and not _discard_on_exit and not session.save():
		# Never trap the player: a second close request explicitly discards unsaved play.
		_discard_on_exit = true
		_notice.text = "Save failed: %s  Close again to quit WITHOUT saving (changes since the last save are lost)." % session.last_error
		return
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_exit()

func _exit_tree() -> void:
	store.close()
