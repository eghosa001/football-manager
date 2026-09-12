extends Node

const DESKTOP_TARGET_HEIGHT := 40.0
const MOBILE_TARGET_HEIGHT := 50.0
const DESKTOP_MIN_FONT := 16
const MOBILE_MIN_FONT := 18

const COLOR_TEXT := Color(0.93, 0.95, 0.99, 1.0)
const COLOR_MUTED := Color(0.66, 0.72, 0.82, 1.0)
const COLOR_SURFACE := Color(0.055, 0.085, 0.14, 0.98)
const COLOR_SURFACE_RAISED := Color(0.075, 0.115, 0.185, 0.98)
const COLOR_SURFACE_HOVER := Color(0.095, 0.145, 0.23, 1.0)
const COLOR_BORDER := Color(0.18, 0.24, 0.36, 1.0)
const COLOR_BORDER_SOFT := Color(0.12, 0.17, 0.27, 1.0)
const COLOR_ACCENT := Color(0.43, 0.42, 1.0, 1.0)
const COLOR_ACCENT_SOFT := Color(0.22, 0.22, 0.50, 1.0)
const COLOR_SIGNAL := Color(0.22, 0.84, 0.74, 1.0)

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_polish_existing")

func _polish_existing() -> void:
	if get_tree().current_scene != null:
		_apply_recursive(get_tree().current_scene)

func _on_node_added(node: Node) -> void:
	if node is Control:
		call_deferred("apply_control", node)

func _apply_recursive(node: Node) -> void:
	if node is Control:
		apply_control(node as Control)
	for child in node.get_children():
		_apply_recursive(child)

func apply_control(control: Control, mobile_override: Variant = null) -> void:
	if control == null:
		return
	var mobile := OS.has_feature("mobile") if mobile_override == null else bool(mobile_override)
	var target_height := MOBILE_TARGET_HEIGHT if mobile else DESKTOP_TARGET_HEIGHT
	var min_font := MOBILE_MIN_FONT if mobile else DESKTOP_MIN_FONT

	if control is BaseButton or control is LineEdit or control is OptionButton or control is SpinBox:
		control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, target_height)
		control.focus_mode = Control.FOCUS_ALL

	if control is BaseButton:
		(control as BaseButton).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if control is Label:
		var label := control as Label
		if label.text.length() >= 56 and label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style_label(label)

	if control is Button and not control is CheckBox and not control is CheckButton:
		_style_button(control as Button)
	elif control is LineEdit:
		_style_line_edit(control as LineEdit)
	elif control is OptionButton:
		_style_option_button(control as OptionButton)
	elif control is PanelContainer:
		control.add_theme_stylebox_override("panel", _box(COLOR_SURFACE, COLOR_BORDER_SOFT, 1, 10, 12))
	elif control is HSeparator:
		control.add_theme_constant_override("separation", 12)
	elif control is VBoxContainer:
		control.add_theme_constant_override("separation", maxi(8, control.get_theme_constant("separation")))
	elif control is HBoxContainer:
		control.add_theme_constant_override("separation", maxi(8, control.get_theme_constant("separation")))
	elif control is GridContainer:
		control.add_theme_constant_override("h_separation", 12)
		control.add_theme_constant_override("v_separation", 12)

	if control is TabContainer:
		var tabs := control as TabContainer
		var bar := tabs.get_tab_bar()
		if bar != null:
			bar.scrolling_enabled = true
			bar.focus_mode = Control.FOCUS_ALL
			bar.custom_minimum_size.y = maxf(bar.custom_minimum_size.y, target_height)
			_style_tab_bar(bar)

	# Never force text smaller than the production readability floor. Explicit
	# larger overrides remain untouched.
	if control is Label or control is BaseButton or control is LineEdit or control is OptionButton or control is SpinBox:
		var current := control.get_theme_font_size("font_size")
		if current > 0 and current < min_font:
			control.add_theme_font_size_override("font_size", min_font)

func _style_label(label: Label) -> void:
	label.add_theme_color_override("font_color", COLOR_TEXT)
	var size := label.get_theme_font_size("font_size")
	if size >= 22:
		label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1.0))
	elif size > 0 and size <= 14:
		label.add_theme_color_override("font_color", COLOR_MUTED)

func _style_button(button: Button) -> void:
	var is_nav := button.has_meta("target_tab")
	var normal_color := Color(0.045, 0.07, 0.115, 0.88) if is_nav else COLOR_SURFACE_RAISED
	var border := Color.TRANSPARENT if is_nav else COLOR_BORDER
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _box(normal_color, border, 1 if not is_nav else 0, 8, 10))
	button.add_theme_stylebox_override("hover", _box(COLOR_SURFACE_HOVER, Color(0.28, 0.36, 0.54, 1.0), 1, 8, 10))
	button.add_theme_stylebox_override("pressed", _box(COLOR_ACCENT_SOFT, COLOR_ACCENT, 1, 8, 10))
	button.add_theme_stylebox_override("focus", _focus_box())
	if is_nav:
		button.add_theme_stylebox_override("hover_pressed", _box(COLOR_ACCENT_SOFT, COLOR_ACCENT, 1, 8, 10))

func _style_line_edit(edit: LineEdit) -> void:
	edit.add_theme_color_override("font_color", COLOR_TEXT)
	edit.add_theme_color_override("font_placeholder_color", COLOR_MUTED)
	edit.add_theme_color_override("caret_color", COLOR_SIGNAL)
	edit.add_theme_stylebox_override("normal", _box(COLOR_SURFACE_RAISED, COLOR_BORDER, 1, 8, 10))
	edit.add_theme_stylebox_override("focus", _box(COLOR_SURFACE_RAISED, COLOR_ACCENT, 2, 8, 10))

func _style_option_button(option: OptionButton) -> void:
	option.add_theme_color_override("font_color", COLOR_TEXT)
	option.add_theme_color_override("font_hover_color", Color.WHITE)
	option.add_theme_stylebox_override("normal", _box(COLOR_SURFACE_RAISED, COLOR_BORDER, 1, 8, 10))
	option.add_theme_stylebox_override("hover", _box(COLOR_SURFACE_HOVER, COLOR_ACCENT, 1, 8, 10))
	option.add_theme_stylebox_override("pressed", _box(COLOR_ACCENT_SOFT, COLOR_ACCENT, 1, 8, 10))
	option.add_theme_stylebox_override("focus", _focus_box())

func _style_tab_bar(bar: TabBar) -> void:
	bar.add_theme_color_override("font_selected_color", Color.WHITE)
	bar.add_theme_color_override("font_unselected_color", COLOR_MUTED)
	bar.add_theme_stylebox_override("tab_selected", _box(COLOR_ACCENT_SOFT, COLOR_ACCENT, 1, 8, 10))
	bar.add_theme_stylebox_override("tab_unselected", _box(COLOR_SURFACE, Color.TRANSPARENT, 0, 8, 10))
	bar.add_theme_stylebox_override("tab_hovered", _box(COLOR_SURFACE_HOVER, COLOR_BORDER, 1, 8, 10))
	bar.add_theme_stylebox_override("tab_focus", _focus_box())

func _focus_box() -> StyleBoxFlat:
	return _box(Color(0.0, 0.0, 0.0, 0.0), COLOR_SIGNAL, 2, 8, 8)

func _box(background: Color, border: Color, border_width: int, radius: int, padding: int) -> StyleBoxFlat:
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
	style.content_margin_top = max(6, padding - 2)
	style.content_margin_right = padding
	style.content_margin_bottom = max(6, padding - 2)
	return style
