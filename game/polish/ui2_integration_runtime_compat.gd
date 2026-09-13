extends "res://game/polish/ui2_integration_runtime.gd"

# Desktop navigation now nests CareerSidebar inside CareerSidebarScroll.
# Preserve the existing utility actions and button styling with recursive lookup.
func _style_desktop_sidebar(shell: Node, app: Node) -> void:
	var sidebar: Node = shell.find_child("CareerSidebar", true, false)
	if not sidebar is VBoxContainer:
		return
	var sidebar_box: VBoxContainer = sidebar as VBoxContainer
	sidebar_box.custom_minimum_size.x = 196
	sidebar_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for child_node: Node in sidebar_box.get_children():
		if child_node is Button:
			_style_navigation_button(child_node as Button)

	var spacer := Control.new()
	spacer.name = "UI2NavigationSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_box.add_child(spacer)

	var divider := HSeparator.new()
	divider.modulate = Color(1.0, 1.0, 1.0, 0.10)
	sidebar_box.add_child(divider)

	var utility_label := Label.new()
	utility_label.text = "CAREER"
	utility_label.add_theme_font_size_override("font_size", 10)
	utility_label.add_theme_color_override("font_color", UI.MUTED)
	sidebar_box.add_child(utility_label)

	_add_utility_button(sidebar_box, "SAVE", func() -> void: _save_current(app))
	_add_utility_button(sidebar_box, "SAVE AS", func() -> void: app.call("_show_save_as"))
	_add_utility_button(sidebar_box, "SETTINGS", func() -> void: app.call("_show_settings"))
	_add_utility_button(sidebar_box, "MAIN MENU", func() -> void: app.call("_show_main_menu"))
