extends Control
## In-game HUD (docs/UI_UX_FOUNDATION.md): vitals top-left, target frame top-centre,
## region/weather under the minimap (drawn by world_map.gd) top-right, prompt + hotbar
## bottom-centre, fading message feed bottom-left, panel shortcuts bottom-right.
## Presentation only: main.gd owns every action and formats gameplay text; the HUD reads
## session state for bars and slots and never mutates a Run.
const FantasyTheme = preload("res://src/ui/fantasy_theme.gd")
const Art = preload("res://src/world/art.gd")
const SLOT := 40
const SKILL_SLOTS := 10
const ITEM_KEYS := ["q", "z"]
const EDGE := 16
const COLUMN_WIDTH := 200.0 # Matches the minimap width (world_map.gd MINIMAP_SIZE).
const FEED_WIDTH := 280.0
const MAX_FEED := 2
const LOG_SIZE := 80
const DISPOSITION_COLORS := {"hostile": Color("e0564b"), "neutral": Color("e0b34b"), "passive": Color("7fd17a")}
const COMMANDS := [["Bag", "I", "inventory"], ["Gear", "C", "character"], ["Skills", "K", "skills"], ["Craft", "G", "craft"],
	["Lore", "J", "knowledge"], ["Map", "M", "map"], ["Help", "H", "help"], ["Menu", "Esc", "menu"]]

signal skill_pressed(index: int)
signal item_pressed(key: String)
signal command(name: String)

var session: RefCounted
## main.gd's rules text for a learned skill (Callable(definition, record) -> PackedStringArray).
var describe_skill: Callable
var info: Label
var region: Label
var region_panel: PanelContainer
var notice: Label
var interaction: Label
var target: Label
var hp_label: Label
var hp_bar: ProgressBar
var hp_text: Label
var xp_bar: ProgressBar
var energy_bar: ProgressBar
var energy_label: Label
var survival: Label
var menu_bar: GridContainer
var hotbar: PanelContainer
var developer_overlay: PanelContainer
var developer_text: Label
## Messages shown this session, newest last (L opens them).
var messages: Array = []
## While true the newest message never fades (skill targeting instructions).
var pinned := false
var _target_panel: PanelContainer
var _target_bar: ProgressBar
var _target_fill: StyleBoxFlat
var _prompt_panel: PanelContainer
var _statuses: HFlowContainer
var _status_texts: PackedStringArray = []
var _feed: VBoxContainer
var _feed_entries: Array = [] # [{label, until}], oldest first; the last label is `notice`.
var _skill_slots: Array = []
var _item_slots: Dictionary = {}
var _region_style: StyleBoxFlat
var _slot_poll := 0.0
var _vitals_style: StyleBoxFlat
var _last_hp := -1
var _hurt := 0.0

func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_vitals()
	_build_target()
	_build_region()
	_build_feed()
	_build_hotbar()
	_build_menu_bar()
	developer_overlay = PanelContainer.new()
	developer_overlay.position = Vector2(EDGE, 168)
	developer_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(developer_overlay)
	developer_text = _text(developer_overlay, 14)
	developer_overlay.hide()
	hide()

# ------------------------------------------------------------------ layout

func _panel(alpha: float = 0.82, border: Color = Color("52616c"), margin: int = 8) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := FantasyTheme.box(Color(Color("172126"), alpha), border, 1, 6, margin)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

func _text(parent: Node, font_size: int, color: Color = FantasyTheme.INK) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _icon(parent: Node, name: String, size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = Art.shared().icon(name) if Art.shared().ready() else null
	parent.add_child(rect)
	return rect

func _bar(parent: Node, color: Color, height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func _bar_text(bar: ProgressBar, font_size: int) -> Label:
	var label := _text(bar, font_size)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 4)
	return label

func _build_vitals() -> void:
	var panel := _panel()
	panel.position = Vector2(EDGE, EDGE)
	panel.custom_minimum_size = Vector2(260, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)
	_vitals_style = panel.get_theme_stylebox("panel")
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	hp_label = _text(header, 15, Color("d3dace"))
	xp_bar = _bar(header, Color("b48a3c"), 6)
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for row in [["HP", Color("ac514b"), 18], ["Energy", Color("50849b"), 16]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		column.add_child(line)
		var label := _text(line, 12, Color("cbd4d8"))
		label.text = row[0]
		label.custom_minimum_size.x = 48
		var bar := _bar(line, row[1], row[2])
		if row[0] == "HP":
			hp_bar = bar
			hp_text = _bar_text(bar, 14)
		else:
			energy_bar = bar
			energy_label = _bar_text(bar, 12)
	var needs := HBoxContainer.new()
	needs.add_theme_constant_override("separation", 6)
	column.add_child(needs)

	survival = _text(needs, 14)
	_statuses = HFlowContainer.new()
	_statuses.add_theme_constant_override("h_separation", 4)
	_statuses.add_theme_constant_override("v_separation", 4)
	_statuses.custom_minimum_size.x = 244
	_statuses.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_statuses)

func _build_target() -> void:
	## Adjacent selected creature: name, disposition-coloured HP and its statuses.
	_target_panel = _panel()
	_target_panel.anchor_left = 0.5
	_target_panel.anchor_right = 0.5
	_target_panel.offset_left = -170
	_target_panel.offset_right = 170
	_target_panel.offset_top = EDGE
	_target_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_target_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_target_panel.add_child(column)
	target = _text(column, 15)
	target.custom_minimum_size.x = 324
	target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_bar = _bar(column, Color("e0564b"), 8)
	_target_fill = _target_bar.get_theme_stylebox("fill")
	_target_panel.hide()

func _build_region() -> void:
	## Under the minimap: weather first (it must never be cut), then land and region.
	region_panel = _panel()
	region_panel.anchor_left = 1.0
	region_panel.anchor_right = 1.0
	region_panel.offset_left = -EDGE - COLUMN_WIDTH
	region_panel.offset_right = -EDGE
	region_panel.offset_top = EDGE + 158
	region_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_region_style = region_panel.get_theme_stylebox("panel")
	add_child(region_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	region_panel.add_child(column)
	region = _text(column, 14)
	region.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	region.custom_minimum_size.x = COLUMN_WIDTH - 16
	region.mouse_filter = Control.MOUSE_FILTER_PASS
	info = _text(column, 13, FantasyTheme.MUTED)
	info.clip_text = true # A long World name never widens the column off screen.
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.custom_minimum_size.x = COLUMN_WIDTH - 16

func _build_feed() -> void:
	_feed = VBoxContainer.new()
	_feed.anchor_top = 1.0
	_feed.anchor_bottom = 1.0
	_feed.offset_left = EDGE
	_feed.offset_right = EDGE + FEED_WIDTH
	_feed.offset_bottom = -EDGE - SLOT - 30
	_feed.grow_vertical = Control.GROW_DIRECTION_BEGIN # New lines push older ones upward.
	_feed.alignment = BoxContainer.ALIGNMENT_END
	_feed.add_theme_constant_override("separation", 4)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)
	notice = _feed_label()
	_feed_entries.append({"label": notice, "panel": notice.get_parent(), "until": 0})

func _feed_label() -> Label:
	var panel := _panel(0.72, Color(0, 0, 0, 0), 6)
	_feed.add_child(panel)
	panel.get_theme_stylebox("panel").set_border_width_all(2)
	var label := _text(panel, 15)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 5
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = FEED_WIDTH - 12
	panel.modulate.a = 0.0
	return label

func _build_hotbar() -> void:
	var stack := VBoxContainer.new()
	stack.anchor_left = 0.5
	stack.anchor_right = 0.5
	stack.anchor_top = 1.0
	stack.anchor_bottom = 1.0
	stack.offset_bottom = -EDGE + 2
	stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stack.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stack.alignment = BoxContainer.ALIGNMENT_END
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack)
	_prompt_panel = _panel(0.86, Color("d3dace"), 6)
	_prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(_prompt_panel)
	interaction = _text(_prompt_panel, 16)
	interaction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	interaction.custom_minimum_size.x = 0
	interaction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel.hide()
	hotbar = _panel(0.8, Color("53666c"), 5)
	hotbar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hotbar.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.add_child(hotbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	hotbar.add_child(row)
	for index in SKILL_SLOTS:
		var slot := _slot(row, str((index + 1) % 10))
		slot.button.pressed.connect(func() -> void: skill_pressed.emit(index))
		_skill_slots.append(slot)
	var divider := ColorRect.new()
	divider.color = Color("53666c")
	divider.custom_minimum_size = Vector2(2, SLOT - 8)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(divider)
	for key in ITEM_KEYS:
		var slot := _slot(row, key.to_upper())
		slot.button.pressed.connect(func() -> void: item_pressed.emit(key))
		_item_slots[key] = slot

func _slot(parent: Node, key: String) -> Dictionary:
	var button := Button.new()
	button.custom_minimum_size = Vector2(SLOT, SLOT)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, FantasyTheme.box(Color("172126") if state != "hover" else Color("30424b"), Color("53666c"), 1, 3, 2))
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	parent.add_child(button)
	var icon := _icon(button, "", 28)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_left = -14
	icon.offset_right = 14
	icon.offset_top = -16
	icon.offset_bottom = 12
	var short := _text(button, 15)
	short.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	short.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	short.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var cool := ColorRect.new()
	cool.color = Color(0, 0, 0, 0.62)
	cool.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cool)
	var cool_text := _text(cool, 16, Color("fff3d6"))
	cool_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cool_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cool_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var keycap := _text(button, 12, Color("d3dace"))
	keycap.position = Vector2(3, 0)
	keycap.text = key
	var corner := _text(button, 11, Color("cfe3ff"))
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.offset_right = -3
	corner.offset_bottom = 1
	return {"button": button, "icon": icon, "short": short, "cool": cool, "cool_text": cool_text, "corner": corner, "key": key}

func _build_menu_bar() -> void:
	var panel := _panel(0.78, Color("53666c"), 5)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_right = -EDGE
	panel.offset_bottom = -EDGE + 2
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(panel)
	menu_bar = GridContainer.new()
	menu_bar.columns = 2
	menu_bar.add_theme_constant_override("h_separation", 4)
	menu_bar.add_theme_constant_override("v_separation", 4)
	panel.add_child(menu_bar)
	for entry in COMMANDS:
		var button := Button.new()
		button.text = "%s %s" % [entry[0], entry[1]]
		button.tooltip_text = {"inventory": "Inventory: items, use, equip, learn, quick slots", "character": "Character: stats, level and equipped gear", "skills": "Skills: learned skills, costs and cooldowns", "talent": "Talent awakened in this Run", "craft": "Crafting: turn materials into gear, remedies and food", "knowledge": "Knowledge confirmed in this Run", "map": "World map and journal", "help": "Controls and how the screen works", "menu": "Save and return to the main menu"}[entry[2]]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(56, 24)
		button.add_theme_font_size_override("font_size", 13)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBoxFlat = FantasyTheme.box(Color("172126") if state != "hover" else Color("2b3b42"), Color("53666c") if state != "hover" else Color("d3dace"), 1, 4, 3)
			button.add_theme_stylebox_override(state, style)
		var name: String = entry[2]
		button.pressed.connect(func() -> void: command.emit(name))
		menu_bar.add_child(button)

# ------------------------------------------------------------------ messages

func say(text: String, replace: bool = false) -> void:
	## Newest message at the bottom of the feed; older ones move up and fade sooner.
	## `replace` rewrites the newest message (a follow-up to the same action).
	if text.strip_edges().is_empty():
		return
	if replace and not messages.is_empty():
		messages[messages.size() - 1] = text
	else:
		messages.append(text)
	if messages.size() > LOG_SIZE:
		messages = messages.slice(messages.size() - LOG_SIZE)
	var newest: Dictionary = _feed_entries[_feed_entries.size() - 1]
	if not replace and not notice.text.is_empty() and newest.panel.modulate.a > 0.05:
		if _feed_entries.size() >= MAX_FEED:
			var oldest: Dictionary = _feed_entries.pop_front()
			oldest.panel.queue_free()
		var older := _feed_label()
		_feed.move_child(older.get_parent(), notice.get_parent().get_index())
		older.text = notice.text
		older.get_parent().modulate.a = 0.8
		older.tooltip_text = notice.text
		older.get_parent().get_theme_stylebox("panel").border_color = _tone(notice.text)
		_feed_entries.insert(_feed_entries.size() - 1, {"label": older, "panel": older.get_parent(), "until": mini(int(newest.until), Time.get_ticks_msec() + 2500)})
	notice.text = text
	notice.tooltip_text = text
	newest.panel.get_theme_stylebox("panel").border_color = _tone(text)
	newest.panel.modulate.a = 1.0
	newest.until = Time.get_ticks_msec() + int(clampf(2.5 + text.length() / 28.0, 3.5, 12.0) * 1000.0)

static func _tone(text: String) -> Color:
	## Message frame: gold for discoveries and learning, amber for refusals and failures.
	if text.begins_with("DISCOVERED") or text.contains("Knowledge learned") or text.begins_with("LAND:") or text.begins_with("LEVEL UP") or text.begins_with("Learned "):
		return Color("d3dace")
	if text.contains("no turn spent") or text.contains("failed") or text.contains("Cannot") or text.contains("Not enough") or text.contains("is empty"):
		return Color("e0904b")
	return Color(0, 0, 0, 0)

func _fade_feed() -> void:
	var now := Time.get_ticks_msec()
	for index in range(_feed_entries.size() - 1, -1, -1):
		var entry: Dictionary = _feed_entries[index]
		var newest: bool = entry.label == notice
		if newest and pinned:
			entry.panel.modulate.a = 1.0
			continue
		var left := float(int(entry.until) - now) / 600.0
		if left >= 1.0:
			continue
		entry.panel.modulate.a = clampf(left, 0.0, 1.0) * (1.0 if newest else 0.8)
		if left <= 0.0 and not newest:
			entry.panel.queue_free()
			_feed_entries.remove_at(index)

# ------------------------------------------------------------------ state

var _panel_mode := false

func set_panel_mode(open: bool) -> void:
	## A player sheet is open on the right: keep vitals, messages and the hotbar, hide
	## the world-facing pieces it would cover.
	if open == _panel_mode:
		return
	_panel_mode = open
	region_panel.visible = not open
	if open:
		_target_panel.hide()
		_prompt_panel.hide()
	else:
		_prompt_panel.visible = not interaction.text.is_empty()
		_target_panel.visible = not target.text.is_empty()

func show_prompt(text: String) -> void:
	## One line sized to its text; long requirement lists wrap inside a fixed width.
	interaction.text = text
	var long := text.length() > 64
	interaction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if long else TextServer.AUTOWRAP_OFF
	interaction.custom_minimum_size.x = 520 if long else 0
	_prompt_panel.visible = not text.is_empty() and not _panel_mode

func show_target(text: String, disposition: String, hp: int, max_hp: int) -> void:
	target.text = text
	_target_panel.visible = not text.is_empty() and not _panel_mode
	_target_bar.max_value = maxi(1, max_hp)
	_target_bar.value = hp
	_target_fill.bg_color = DISPOSITION_COLORS.get(disposition, Color.WHITE)

func set_weather_alert(level: int) -> void:
	## 0 calm, 1 warning/incoming, 2 exposed or hazardous: tints the region frame.
	_region_style.border_color = [Color("53666c"), Color("e0b34b"), Color("e0564b")][clampi(level, 0, 2)]
	_region_style.set_border_width_all(1 if level == 0 else 2)

func set_statuses(chips: Array) -> void:
	## chips: [{text, icon}] for the player's active statuses.
	_status_texts = PackedStringArray()
	for child in _statuses.get_children():
		_statuses.remove_child(child)
		child.queue_free()
	for chip in chips:
		_status_texts.append(chip.text)
		var panel := _panel(0.9, Color("4d6a8a"), 3)
		panel.tooltip_text = chip.text
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		_statuses.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		panel.add_child(row)
		var texture: Texture2D = Art.shared().status_icon(chip.icon) if Art.shared().ready() else null
		if texture != null:
			_icon(row, "", 16).texture = texture
		_text(row, 13).text = chip.text

func status_text() -> String:
	return "; ".join(_status_texts)

func _process(delta: float) -> void:
	if not visible:
		return
	_fade_feed()
	_vital_feedback(delta)
	_slot_poll -= delta
	if _slot_poll <= 0.0 and session != null and not session.run.is_empty():
		_slot_poll = 0.25 # Real-time cooldowns tick without an event.
		refresh_slots()

func _vital_feedback(delta: float) -> void:
	## A red flash on the vitals frame when HP drops; the HP bar pulses below 30%.
	var hp := int(hp_bar.value)
	if _last_hp >= 0 and hp < _last_hp:
		_hurt = 0.5
	_last_hp = hp
	_hurt = maxf(0.0, _hurt - delta)
	_vitals_style.border_color = Color("53666c").lerp(Color("ff5a4a"), clampf(_hurt * 2.0, 0.0, 1.0))
	_vitals_style.set_border_width_all(2 if _hurt > 0.0 else 1)
	var low := hp_bar.max_value > 0 and hp > 0 and float(hp) / hp_bar.max_value < 0.3
	hp_bar.modulate = Color(1, 1, 1).lerp(Color(1.6, 0.8, 0.8), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)) if low else Color.WHITE

func refresh_slots() -> void:
	if session == null or session.run.is_empty():
		return
	var turn := int(session.run.state.turn)
	var unit := "s" if session.realtime else "t"
	var learned: Array = session.run.state.character.skills
	for index in SKILL_SLOTS:
		var slot: Dictionary = _skill_slots[index]
		if index >= learned.size():
			_fill_slot(slot, null, "", "", 0.35, "")
			slot.button.tooltip_text = "Slot %d: empty.\nLearn skills from manuals and scrolls (Inventory, then Learn)." % (index + 1)
			continue
		var record: Dictionary = learned[index]
		var definition: Dictionary = session.skill_definition(record.content_id, int(record.version))
		var kind: String = definition.payload.get("type", "?")
		var texture: Texture2D = Art.shared().icon(skill_icon(definition)) if Art.shared().ready() else null
		var lines: PackedStringArray = describe_skill.call(definition, record) if describe_skill.is_valid() else PackedStringArray()
		if kind != "active":
			_fill_slot(slot, texture, _short_name(definition.name), "", 0.55, "")
			slot.corner.text = kind.left(3).to_upper()
			slot.button.tooltip_text = "%s [%s]\n%s cannot be pressed: it works on its own.\n%s" % [definition.name, slot.key, kind.capitalize(), "\n".join(lines)]
			continue
		var cooldown := int(record.cooldown_until) - turn
		var problem: String = session.skills.use_check(session, definition)
		var cost: Dictionary = session.skills.costs(session, definition)
		var energy := ""
		for key in cost:
			if session.skill_rules.rules.resources.has(key) and int(cost[key]) > 0:
				energy = str(int(cost[key]))
		_fill_slot(slot, texture, _short_name(definition.name), "%d%s" % [cooldown, unit] if cooldown > 0 else "", 1.0 if problem.is_empty() else 0.55, energy)
		slot.button.tooltip_text = "%s [%s]\n%s" % [definition.name, slot.key, "\n".join(lines)]
	for key in ITEM_KEYS:
		var slot: Dictionary = _item_slots[key]
		var content_id := str(session.run.state.character.get("quick_items", {}).get(key, ""))
		if content_id.is_empty():
			_fill_slot(slot, null, "", "", 0.35, "")
			slot.button.tooltip_text = "Quick item %s: empty.\nAssign: open Inventory (I), select a usable item, press %s." % [key.to_upper(), key.to_upper()]
			continue
		var entry: Dictionary = session.run.state.inventory.get(content_id, {})
		var count := int(entry.get("quantity", 0))
		var definition: Dictionary = session._definition(content_id, int(entry.get("version", 1))) if not entry.is_empty() else store_definition(content_id)
		var name := str(definition.get("name", content_id))
		var texture: Texture2D = Art.shared().item_icon(content_id, name, definition) if Art.shared().ready() else null
		_fill_slot(slot, texture, _short_name(name), "", 1.0 if count > 0 else 0.4, "x%d" % count)
		var use: Dictionary = session.use_for(content_id) if count > 0 else {}
		slot.button.tooltip_text = "%s [%s]  x%d\n%s" % [name, key.to_upper(), count, ("%s: spends one action." % use.payload.get("verb", "Use")) if not use.is_empty() else "None left. Find more, or reassign in the Inventory."]

func store_definition(content_id: String) -> Dictionary:
	return {"name": content_id.get_slice(":", content_id.get_slice_count(":") - 1).capitalize()}

func _fill_slot(slot: Dictionary, texture: Texture2D, short: String, cooling: String, alpha: float, corner: String) -> void:
	slot.icon.texture = texture
	slot.short.text = "" if texture != null else short
	slot.cool.visible = not cooling.is_empty()
	slot.cool_text.text = cooling
	slot.icon.modulate.a = alpha
	slot.short.modulate.a = alpha
	slot.corner.text = corner

static func _short_name(name: String) -> String:
	var words := name.split(" ", false)
	if words.size() >= 2:
		return (words[0].left(1) + words[1].left(1)).to_upper()
	return name.left(2).capitalize()

static func skill_icon(definition: Dictionary) -> String:
	## Closest existing UI icon for a skill's main effect (no skill-specific art yet).
	var payload: Dictionary = definition.get("payload", {})
	if payload.get("type") != "active":
		return "buff"
	var elements: Array = payload.get("elements", [])
	for element in ["fire", "frost", "ice", "poison"]:
		if element in elements:
			return "frost" if element == "ice" else element
	for effect in payload.get("effects", []):
		match str(effect.get("type", "")):
			"strike": return "sword"
			"heal": return "heart"
			"stun": return "stun"
			"status": return "buff"
			"restore": return "mana"
			"blink": return "boots"
			"cleanse": return "potion"
			"need": return "water"
	return "book"
