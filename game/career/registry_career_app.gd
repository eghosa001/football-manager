extends "res://game/career/career_app.gd"

const RegistryClass = preload("res://game/career/career_screen_registry.gd")
const RegistryCareerViewsClass = preload("res://game/career/career_views.gd")

var _screen_registry = RegistryClass.new()

func _show_career() -> void:
	var root := _clear()
	var snap: Dictionary = session.snapshot()
	var dashboard: Dictionary = query.dashboard(session.world, session.managed_club_id)
	var club: Dictionary = dashboard.get("club", {})
	_add_heading(root, tr("%s — %s") % [String(club.get("name", "Club")), String(snap.date)], 26)
	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	_add_button(buttons, tr("Continue"), _advance_day)
	_add_button(buttons, tr("Save Slot %d") % active_slot if active_slot > 0 else "Save Career", _save)
	_add_button(buttons, tr("Save As"), _show_save_as)
	_add_button(buttons, tr("Settings"), _show_settings)
	_add_button(buttons, tr("Main Menu"), _show_main_menu)
	status = Label.new()
	status.text = tr("Manager: %s  •  Season %d  •  Inbox %d") % [String(session.manager.get("name", "Manager")), int(snap.season_year), int(dashboard.get("unread_messages", 0))]
	root.add_child(status)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	var views = RegistryCareerViewsClass.new(self, session)
	for descriptor in _screen_registry.tab_plan():
		var builder := String(descriptor.get("builder", ""))
		var owner := String(descriptor.get("owner", "views"))
		if owner == "app":
			if has_method(builder):
				call(builder, tabs)
			else:
				push_error("Career tab builder missing on app: %s" % builder)
		elif views.has_method(builder):
			views.call(builder, tabs)
		else:
			push_error("Career tab builder missing on views: %s" % builder)
