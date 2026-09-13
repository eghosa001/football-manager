extends "res://game/polish/ui2_runtime.gd"

# The production scene uses registry_career_app.gd, which subclasses career_app.gd.
# Resolve the live app by capabilities rather than by an exact script filename.
func _career_app(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current.has_method("_show_career") and current.has_method("_advance_day"):
			return current
		current = current.get_parent()
	return null

# NavigationRuntime now places the desktop sidebar inside a ScrollContainer.
# Keep the visual enhancement logic while locating the sidebar recursively.
func _enhance_shell(tabs: TabContainer, session) -> void:
	var shell := tabs.get_parent()
	if shell == null or shell.has_meta("ui2_shell_enhanced"):
		return
	var sidebar := shell.find_child("CareerSidebar", true, false)
	if sidebar == null:
		return
	shell.set_meta("ui2_shell_enhanced", true)
	if sidebar is Control:
		(sidebar as Control).custom_minimum_size.x = 184
	var identity := sidebar.get_node_or_null("DynastyIdentity")
	if identity != null:
		var club := _club(session.world, session.managed_club_id)
		var crest := Label.new()
		crest.text = "◆"
		crest.add_theme_font_size_override("font_size", 32)
		crest.add_theme_color_override("font_color", UI.CYAN)
		identity.add_child(crest)
		identity.move_child(crest, 0)
		var club_label := Label.new()
		club_label.text = String(club.get("name", "Club"))
		club_label.add_theme_font_size_override("font_size", 12)
		club_label.add_theme_color_override("font_color", UI.MUTED)
		identity.add_child(club_label)
	for child in sidebar.get_children():
		if child is Button:
			var button := child as Button
			button.custom_minimum_size.y = 38
			button.add_theme_font_size_override("font_size", 13)
