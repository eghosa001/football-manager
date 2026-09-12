extends Node

## Lightweight procedural presentation layer for Football Dynasty.
## This intentionally complements UIReadabilityRuntime: readability owns minimum
## sizes and contrast, while this runtime owns atmosphere, depth and motion.

const COLOR_TEXT := Color(0.95, 0.97, 1.0, 1.0)
const COLOR_MUTED := Color(0.62, 0.70, 0.82, 1.0)
const COLOR_SURFACE := Color(0.045, 0.070, 0.115, 0.94)
const COLOR_SURFACE_RAISED := Color(0.065, 0.105, 0.170, 0.97)
const COLOR_SURFACE_HOVER := Color(0.095, 0.155, 0.245, 1.0)
const COLOR_BORDER := Color(0.20, 0.30, 0.46, 0.75)
const COLOR_ACCENT := Color(0.47, 0.46, 1.0, 1.0)
const COLOR_SIGNAL := Color(0.20, 0.88, 0.76, 1.0)

var _scan_due := 0

class PremiumBackdrop:
	extends Control
	var context := "Dashboard"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		queue_redraw()

	func set_context(value: String) -> void:
		if context == value:
			return
		context = value
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 1.0 or h <= 1.0:
			return
		# Deep layered base. Multiple translucent bands approximate a premium
		# gradient without shaders or texture assets, keeping mobile cost tiny.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.030, 0.058, 1.0))
		var bands := 14
		for i in range(bands):
			var t := float(i) / float(bands - 1)
			var band_color := Color(0.025 + t * 0.020, 0.045 + t * 0.025, 0.085 + t * 0.055, 0.16)
			draw_rect(Rect2(0.0, h * t, w, h / float(bands) + 2.0), band_color)

		var accent := _context_accent()
		draw_circle(Vector2(w * 0.84, h * 0.18), minf(w, h) * 0.34, Color(accent.r, accent.g, accent.b, 0.075))
		draw_circle(Vector2(w * 0.12, h * 0.88), minf(w, h) * 0.28, Color(0.10, 0.80, 0.68, 0.035))

		# Subtle football pitch / tactics-board motif.
		var line := Color(accent.r, accent.g, accent.b, 0.055)
		var pitch := Rect2(w * 0.08, h * 0.12, w * 0.84, h * 0.76)
		draw_rect(pitch, line, false, 1.0)
		draw_line(Vector2(w * 0.50, pitch.position.y), Vector2(w * 0.50, pitch.end.y), line, 1.0)
		draw_circle(Vector2(w * 0.50, h * 0.50), minf(w, h) * 0.085, line, false, 1.0)
		var box_h := pitch.size.y * 0.36
		draw_rect(Rect2(pitch.position.x, h * 0.50 - box_h * 0.50, pitch.size.x * 0.13, box_h), line, false, 1.0)
		draw_rect(Rect2(pitch.end.x - pitch.size.x * 0.13, h * 0.50 - box_h * 0.50, pitch.size.x * 0.13, box_h), line, false, 1.0)

		# Fine diagonal texture adds identity while remaining almost invisible.
		var texture_line := Color(1.0, 1.0, 1.0, 0.018)
		var step := 72.0
		var x := -h
		while x < w:
			draw_line(Vector2(x, h), Vector2(x + h, 0.0), texture_line, 1.0)
			x += step

	func _context_accent() -> Color:
		var key := context.to_lower()
		if "match" in key:
			return Color(0.20, 0.88, 0.76, 1.0)
		if "transfer" in key or "scout" in key:
			return Color(0.98, 0.72, 0.28, 1.0)
		if "medical" in key:
			return Color(0.96, 0.38, 0.44, 1.0)
		if "tactic" in key or "squad" in key:
			return Color(0.38, 0.62, 1.0, 1.0)
		if "finance" in key or "board" in key:
			return Color(0.64, 0.50, 1.0, 1.0)
		return Color(0.47, 0.46, 1.0, 1.0)


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _scan_due:
		return
	_scan_due = now + 900
	_scan()

func _on_node_added(node: Node) -> void:
	if node is Control:
		call_deferred("_apply_control", node as Control)
	call_deferred("_ensure_career_backdrop")

func _scan() -> void:
	if get_tree().current_scene == null:
		return
	_apply_recursive(get_tree().current_scene)
	_ensure_career_backdrop()

func _apply_recursive(node: Node) -> void:
	if node is Control:
		_apply_control(node as Control)
	for child in node.get_children():
		_apply_recursive(child)

func _apply_control(control: Control) -> void:
	if control == null:
		return
	if control is Button and not control is CheckBox and not control is CheckButton:
		_style_button(control as Button)
	elif control is PanelContainer:
		_style_panel(control as PanelContainer)
	elif control is LineEdit:
		_style_line_edit(control as LineEdit)
	elif control is OptionButton:
		_style_option(control as OptionButton)
	elif control is Label:
		_style_label(control as Label)
	elif control is TabContainer:
		_wire_tabs(control as TabContainer)

	if control is PanelContainer and not control.has_meta("presentation_reveal"):
		control.set_meta("presentation_reveal", true)
		_reveal(control)

func _ensure_career_backdrop() -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene is Control:
		return
	var script = scene.get_script()
	if script == null or not String(script.resource_path).ends_with("game/career/career_app.gd"):
		return
	var root := scene as Control
	var backdrop := root.get_node_or_null("PremiumBackdrop") as PremiumBackdrop
	if backdrop == null:
		backdrop = PremiumBackdrop.new()
		backdrop.name = "PremiumBackdrop"
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.z_index = -20
		root.add_child(backdrop)
		root.move_child(backdrop, 0)
	# The career app rebuilds an opaque ColorRect on every screen. Make it a
	# translucent tint so the procedural artwork remains visible behind content.
	for child in root.get_children():
		if child is ColorRect and child != backdrop:
			var background := child as ColorRect
			if bool(_career_setting(root, "high_contrast", false)):
				background.color = Color(0.0, 0.0, 0.0, 0.90)
			else:
				background.color = Color(0.018, 0.030, 0.058, 0.56)
			background.z_index = -10

func _wire_tabs(tabs: TabContainer) -> void:
	if tabs.has_meta("presentation_tabs"):
		return
	tabs.set_meta("presentation_tabs", true)
	tabs.tab_changed.connect(_on_tab_changed.bind(tabs))
	var bar := tabs.get_tab_bar()
	if bar != null:
		bar.add_theme_constant_override("h_separation", 4)
		bar.add_theme_stylebox_override("panel", _box(Color(0.025, 0.045, 0.080, 0.80), Color.TRANSPARENT, 0, 12, 5, false))
	_on_tab_changed(tabs.current_tab, tabs)

func _on_tab_changed(index: int, tabs: TabContainer) -> void:
	if index < 0 or index >= tabs.get_tab_count():
		return
	var page := tabs.get_tab_control(index)
	if page != null and not _reduce_motion(tabs):
		page.modulate.a = 0.35
		var tween := page.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(page, "modulate:a", 1.0, 0.20)
	var scene := get_tree().current_scene
	if scene != null:
		var backdrop := scene.get_node_or_null("PremiumBackdrop") as PremiumBackdrop
		if backdrop != null:
			backdrop.set_context(tabs.get_tab_title(index))

func _style_button(button: Button) -> void:
	var nav := button.has_meta("target_tab")
	var primary := _looks_primary(button.text)
	var normal := Color(0.035, 0.060, 0.100, 0.78) if nav else COLOR_SURFACE_RAISED
	var border := Color.TRANSPARENT if nav else COLOR_BORDER
	if primary:
		normal = Color(0.28, 0.25, 0.76, 0.98)
		border = Color(0.56, 0.55, 1.0, 0.95)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _box(normal, border, 1 if not nav else 0, 10, 12, not nav))
	button.add_theme_stylebox_override("hover", _box(COLOR_SURFACE_HOVER if not primary else Color(0.36, 0.32, 0.88, 1.0), COLOR_ACCENT, 1, 10, 12, true))
	button.add_theme_stylebox_override("pressed", _box(Color(0.20, 0.20, 0.52, 1.0), COLOR_ACCENT, 1, 10, 12, false))
	if not button.has_meta("presentation_motion"):
		button.set_meta("presentation_motion", true)
		button.mouse_entered.connect(_button_hover.bind(button, true))
		button.mouse_exited.connect(_button_hover.bind(button, false))
		button.button_down.connect(_button_press.bind(button, true))
		button.button_up.connect(_button_press.bind(button, false))

func _style_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", _box(COLOR_SURFACE, Color(0.16, 0.25, 0.40, 0.72), 1, 14, 14, true))

func _style_line_edit(edit: LineEdit) -> void:
	edit.add_theme_color_override("font_color", COLOR_TEXT)
	edit.add_theme_color_override("font_placeholder_color", COLOR_MUTED)
	edit.add_theme_color_override("caret_color", COLOR_SIGNAL)
	edit.add_theme_stylebox_override("normal", _box(COLOR_SURFACE_RAISED, COLOR_BORDER, 1, 10, 12, false))
	edit.add_theme_stylebox_override("focus", _box(COLOR_SURFACE_RAISED, COLOR_SIGNAL, 2, 10, 12, true))

func _style_option(option: OptionButton) -> void:
	option.add_theme_color_override("font_color", COLOR_TEXT)
	option.add_theme_stylebox_override("normal", _box(COLOR_SURFACE_RAISED, COLOR_BORDER, 1, 10, 12, false))
	option.add_theme_stylebox_override("hover", _box(COLOR_SURFACE_HOVER, COLOR_ACCENT, 1, 10, 12, true))
	option.add_theme_stylebox_override("pressed", _box(Color(0.20, 0.20, 0.52, 1.0), COLOR_ACCENT, 1, 10, 12, false))

func _style_label(label: Label) -> void:
	var font_size := label.get_theme_font_size("font_size")
	if font_size >= 28:
		label.add_theme_color_override("font_color", Color(0.985, 0.99, 1.0, 1.0))
		label.add_theme_color_override("font_shadow_color", Color(0.10, 0.08, 0.30, 0.72))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 3)
		label.add_theme_constant_override("shadow_outline_size", 5)
	elif font_size >= 20:
		label.add_theme_color_override("font_color", Color(0.86, 0.90, 1.0, 1.0))

func _reveal(control: Control) -> void:
	if _reduce_motion(control) or not control.is_inside_tree():
		return
	control.modulate.a = 0.0
	var tween := control.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.03)
	tween.tween_property(control, "modulate:a", 1.0, 0.24)

func _button_hover(button: Button, entered: bool) -> void:
	if not is_instance_valid(button) or _reduce_motion(button):
		return
	var target := Color(1.08, 1.08, 1.08, 1.0) if entered else Color.WHITE
	var tween := button.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", target, 0.11)

func _button_press(button: Button, pressed: bool) -> void:
	if not is_instance_valid(button) or _reduce_motion(button):
		return
	var target := Color(0.86, 0.88, 0.96, 1.0) if pressed else Color.WHITE
	var tween := button.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", target, 0.07)

func _looks_primary(text: String) -> bool:
	var key := text.to_lower()
	for token in ["continue", "resume", "create career", "confirm", "save", "start match", "play match", "submit offer"]:
		if token in key:
			return true
	return false

func _reduce_motion(node: Node) -> bool:
	var current: Node = node
	while current != null:
		if current.has_method("get"):
			var script = current.get_script()
			if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
				return bool(_career_setting(current, "reduce_motion", false))
		current = current.get_parent()
	return false

func _career_setting(career: Node, key: String, fallback: Variant) -> Variant:
	var settings = career.get("settings")
	if typeof(settings) == TYPE_DICTIONARY:
		return settings.get(key, fallback)
	return fallback

func _box(background: Color, border: Color, border_width: int, radius: int, padding: int, shadow: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = padding
	style.content_margin_top = max(7, padding - 2)
	style.content_margin_right = padding
	style.content_margin_bottom = max(7, padding - 2)
	if shadow:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 3)
	return style
