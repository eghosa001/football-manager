extends "res://game/polish/core_management_runtime.gd"

# Production career scenes use registry_career_app.gd, which subclasses the
# base career app. Resolve the live app by capabilities and process it once per
# scan instead of walking every Control and repeating the same management work.
func _scan() -> void:
	var app := _find_career_app(get_tree().root)
	if app == null:
		return
	_focus_main_menu(app)
	_focus_new_career(app)
	_focus_career_tabs(app)
	_apply_staff_delegation(app)

func _focus_career_tabs(app: Node) -> void:
	var session = app.get("session")
	if session == null or session.world.is_empty():
		return
	for tabs in _tab_containers(app):
		if tabs.get_tab_count() < 4:
			continue
		var has_dashboard := false
		var has_squad := false
		for i in range(tabs.get_tab_count()):
			var title: String = tabs.get_tab_title(i)
			if title == "Dashboard" or title == "Home":
				has_dashboard = true
			if title == "Squad":
				has_squad = true
		if not has_dashboard or not has_squad:
			continue
		var keep := ["Dashboard", "Home", "Inbox", "Squad", "Tactics", "Training", "Medical", "Dynamics", "Staff", "Scouting", "Transfers", "Schedule", "Competitions", "Youth Academy", "Finances", "Club", "Search", "Match Analysis"]
		for i in range(tabs.get_tab_count()):
			var title: String = tabs.get_tab_title(i)
			tabs.set_tab_hidden(i, title not in keep)
		_add_staff_responsibilities(tabs, session)
		_add_match_substitution_plan(tabs, session)

func _find_career_app(node: Node) -> Node:
	if node.has_method("_show_career") and node.has_method("_advance_day"):
		return node
	for child in node.get_children():
		var found := _find_career_app(child)
		if found != null:
			return found
	return null

func _career_app(node: Node) -> Node:
	var current := node
	while current != null:
		if current.has_method("_show_career") and current.has_method("_advance_day"):
			return current
		current = current.get_parent()
	return null
