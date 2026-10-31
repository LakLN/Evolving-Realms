extends RefCounted
## RPG-fantasy skin for the existing Control UI: dark leather panels, gold trim, cream
## text. Pure styling (Theme resource); layouts and behaviour stay in main.gd.
const INK := Color("f1e6cc")
const MUTED := Color("b9aa8a")
const GOLD := Color("d6b06a")
const GOLD_DIM := Color("8a6c3c")
const PANEL := Color(0.075, 0.06, 0.05, 0.9)
const WELL := Color(0.045, 0.036, 0.03, 0.92)

static func box(bg: Color, border: Color, width: int = 2, radius: int = 6, margin: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.anti_aliasing = false
	return style

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 17
	var panel := box(PANEL, GOLD_DIM, 2, 6, 8)
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 6
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", box(Color(0.04, 0.035, 0.03, 1.0), Color(0, 0, 0, 0), 0, 0, 0))
	for type in ["Label"]:
		theme.set_color("font_color", type, INK)
		theme.set_color("font_outline_color", type, Color(0.02, 0.015, 0.01))
		theme.set_constant("outline_size", type, 3)
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, box(Color("33261a"), GOLD_DIM, 2, 5, 8))
		theme.set_stylebox("hover", type, box(Color("47331f"), GOLD, 2, 5, 8))
		theme.set_stylebox("pressed", type, box(Color("221810"), GOLD, 2, 5, 8))
		theme.set_stylebox("focus", type, box(Color(0, 0, 0, 0), Color("f4d590"), 2, 5, 8))
		theme.set_stylebox("disabled", type, box(Color("221d18"), Color("4a4136"), 2, 5, 8))
		theme.set_color("font_color", type, INK)
		theme.set_color("font_hover_color", type, Color("fff3d6"))
		theme.set_color("font_pressed_color", type, GOLD)
		theme.set_color("font_focus_color", type, Color("fff3d6"))
		theme.set_color("font_disabled_color", type, Color("6f6656"))
	theme.set_stylebox("normal", "LineEdit", box(WELL, GOLD_DIM, 2, 5, 8))
	theme.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), GOLD, 2, 5, 8))
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", Color("7d7160"))
	theme.set_color("caret_color", "LineEdit", GOLD)
	theme.set_stylebox("panel", "ItemList", box(WELL, Color("4d3c24"), 2, 5, 6))
	theme.set_stylebox("focus", "ItemList", box(Color(0, 0, 0, 0), GOLD_DIM, 2, 5, 6))
	theme.set_stylebox("selected", "ItemList", box(Color("5a4224"), Color(0, 0, 0, 0), 0, 3, 4))
	theme.set_stylebox("selected_focus", "ItemList", box(Color("6e5029"), GOLD, 1, 3, 4))
	theme.set_stylebox("hovered", "ItemList", box(Color("2e2316"), Color(0, 0, 0, 0), 0, 3, 4))
	theme.set_stylebox("cursor", "ItemList", box(Color(0, 0, 0, 0), GOLD, 1, 3, 4))
	theme.set_stylebox("cursor_unfocused", "ItemList", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 3, 4))
	theme.set_color("font_color", "ItemList", INK)
	theme.set_color("font_selected_color", "ItemList", Color("fff3d6"))
	theme.set_color("font_hovered_color", "ItemList", Color("fff3d6"))
	theme.set_constant("v_separation", "ItemList", 6)
	theme.set_stylebox("background", "ProgressBar", box(Color(0.03, 0.025, 0.02, 0.95), Color("4d3c24"), 1, 3, 0))
	theme.set_stylebox("separator", "HSeparator", box(GOLD_DIM, Color(0, 0, 0, 0), 0, 0, 0))
	theme.set_constant("separation", "HSeparator", 6)
	var grabber := box(Color("6b5434"), Color(0, 0, 0, 0), 0, 4, 0)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", box(GOLD_DIM, Color(0, 0, 0, 0), 0, 4, 0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", box(GOLD, Color(0, 0, 0, 0), 0, 4, 0))
	theme.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 0, 4, 2))
	theme.set_stylebox("panel", "TooltipPanel", box(Color(0.06, 0.05, 0.04, 0.97), GOLD_DIM, 1, 4, 8))
	theme.set_color("font_color", "TooltipLabel", INK)
	theme.set_stylebox("panel", "PopupMenu", box(Color(0.07, 0.055, 0.045, 0.98), GOLD_DIM, 2, 5, 6))
	theme.set_stylebox("hover", "PopupMenu", box(Color("5a4224"), Color(0, 0, 0, 0), 0, 3, 4))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", Color("fff3d6"))
	return theme

static func backdrop(parent: Control, texture: Texture2D) -> void:
	## Menu background: dimmed tiled forest floor with a soft vignette.
	if texture == null:
		return
	var ground := TextureRect.new()
	ground.texture = texture
	ground.stretch_mode = TextureRect.STRETCH_TILE
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.modulate = Color(0.42, 0.4, 0.36)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ground)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.01, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)
