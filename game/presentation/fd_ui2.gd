class_name FDUI2
extends RefCounted

const BG := Color(0.035, 0.043, 0.075, 1.0)
const SURFACE := Color(0.055, 0.065, 0.105, 0.98)
const SURFACE_2 := Color(0.075, 0.086, 0.132, 0.98)
const BORDER := Color(0.20, 0.23, 0.32, 0.9)
const TEXT := Color(0.94, 0.95, 0.98, 1.0)
const MUTED := Color(0.61, 0.66, 0.76, 1.0)
const CYAN := Color(0.08, 0.86, 0.91, 1.0)
const GREEN := Color(0.20, 0.85, 0.48, 1.0)
const AMBER := Color(0.96, 0.72, 0.25, 1.0)
const RED := Color(0.95, 0.31, 0.37, 1.0)
const PURPLE := Color(0.53, 0.45, 0.96, 1.0)

static func panel(parent: Control, min_size := Vector2.ZERO, accent := Color.TRANSPARENT) -> VBoxContainer:
	var container := PanelContainer.new()
	container.custom_minimum_size = min_size
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE
	style.border_color = BORDER if accent == Color.TRANSPARENT else Color(accent.r, accent.g, accent.b, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	container.add_theme_stylebox_override("panel", style)
	parent.add_child(container)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(box)
	return box

static func section(parent: Control, title: String, accent := CYAN) -> Label:
	var label := Label.new()
	label.text = title.to_upper()
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", accent)
	parent.add_child(label)
	return label

static func title(parent: Control, text: String, subtitle := "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	parent.add_child(box)
	var heading := Label.new()
	heading.text = text.to_upper()
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", TEXT)
	box.add_child(heading)
	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.add_theme_font_size_override("font_size", 12)
		sub.add_theme_color_override("font_color", MUTED)
		box.add_child(sub)
	return box

static func body(parent: Control, text: String, muted := false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", MUTED if muted else TEXT)
	parent.add_child(label)
	return label

static func metric(parent: Control, label_text: String, value: String, detail := "", accent := CYAN) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	var label := Label.new()
	label.text = label_text.to_upper()
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", MUTED)
	box.add_child(label)
	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 20)
	value_label.add_theme_color_override("font_color", accent)
	box.add_child(value_label)
	if detail != "":
		var d := Label.new()
		d.text = detail
		d.add_theme_font_size_override("font_size", 11)
		d.add_theme_color_override("font_color", MUTED)
		box.add_child(d)
	return box

static func chip(text: String, accent := CYAN) -> Label:
	var label := Label.new()
	label.text = "  %s  " % text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", TEXT)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(accent.r, accent.g, accent.b, 0.28)
	box.border_color = Color(accent.r, accent.g, accent.b, 0.72)
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	label.add_theme_stylebox_override("normal", box)
	return label

static func action(text: String, accent := CYAN) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.focus_mode = Control.FOCUS_ALL
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent.r, accent.g, accent.b, 0.20)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.62)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.34)
	button.add_theme_stylebox_override("hover", hover)
	return button

# Supports both progress(parent, value, accent) and a detached progress(value, accent)
# for compact composition code. Fractions in the 0..1 range are promoted to %.
static func progress(parent_or_value: Variant, value_or_accent: Variant = 0.0, accent := GREEN, width := 120.0) -> ProgressBar:
	var parent: Control = null
	var value := 0.0
	var fill_color := accent
	if parent_or_value is Control:
		parent = parent_or_value as Control
		value = float(value_or_accent)
	else:
		value = float(parent_or_value)
		if value_or_accent is Color:
			fill_color = value_or_accent
	if value >= 0.0 and value <= 1.0:
		value *= 100.0
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = clampf(value, 0, 100)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, 8)
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0.02,0.025,0.045,1); bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new(); fill.bg_color = fill_color; fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	if parent != null:
		parent.add_child(bar)
	return bar

static func table_header(parent: GridContainer, columns: Array[String]) -> void:
	for text in columns:
		var label := Label.new()
		label.text = text.to_upper()
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", MUTED)
		label.custom_minimum_size.y = 28
		parent.add_child(label)

static func cell(parent: GridContainer, text: String, width := 0.0, accent := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", accent)
	label.custom_minimum_size = Vector2(width, 32)
	parent.add_child(label)
	return label

static func divider(parent: Control) -> HSeparator:
	var line := HSeparator.new()
	line.modulate = Color(1,1,1,0.12)
	parent.add_child(line)
	return line

static func score_color(value: float) -> Color:
	if value >= 75.0: return GREEN
	if value >= 55.0: return AMBER
	return RED

static func stars(value: int) -> String:
	var count := clampi(int(round(float(value) / 20.0)), 0, 5)
	return "★".repeat(count) + "☆".repeat(5 - count)

static func money(value: int) -> String:
	if abs(value) >= 1000000000: return "£%.2fb" % (float(value) / 1000000000.0)
	if abs(value) >= 1000000: return "£%.1fm" % (float(value) / 1000000.0)
	if abs(value) >= 1000: return "£%.0fk" % (float(value) / 1000.0)
	return "£%d" % value
