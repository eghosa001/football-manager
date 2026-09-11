extends Node

const UniversalSearch = preload("res://application/career/universal_search.gd")
var _next_scan := 0
var _search = UniversalSearch.new()

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 1000
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer:
		_wire_tabs(node)
	for child in node.get_children():
		_scan_node(child)

func _wire_tabs(tabs: TabContainer) -> void:
	if tabs.has_meta("universal_search_added"):
		return
	var search_tab: Control = null
	for child in tabs.get_children():
		if String(child.name) == "Search":
			search_tab = child
			break
	if search_tab == null:
		return
	var session = _career_session(tabs)
	if session == null:
		return
	var box := _first_vbox(search_tab)
	if box == null:
		return
	tabs.set_meta("universal_search_added", true)
	session.world["saved_search_views"] = session.world.get("saved_search_views", [])

	var title := Label.new()
	title.text = tr("Indexed universal search")
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	var help := Label.new()
	help.text = tr("Search players, clubs, competitions, countries and staff. Saved views remain with this career.")
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	var input := LineEdit.new()
	input.placeholder_text = tr("Name, ID, position, country code or competition")
	box.add_child(input)
	var results := VBoxContainer.new()
	box.add_child(results)

	var run := func():
		for child in results.get_children():
			child.queue_free()
		for row in _search.search(session.world, input.text, 40):
			var button := Button.new()
			button.text = "%s — %s%s" % [String(row.type).capitalize(), String(row.name), " — " + String(row.extra) if String(row.extra) != "" else ""]
			button.pressed.connect(_show_result.bind(session.world, row, tabs))
			results.add_child(button)

	var search_row := HBoxContainer.new()
	box.add_child(search_row)
	var button := Button.new()
	button.text = tr("Search all")
	button.pressed.connect(run)
	search_row.add_child(button)
	var save := Button.new()
	save.text = tr("Save view")
	save.pressed.connect(func():
		var query := input.text.strip_edges()
		if query.is_empty():
			_notice(tabs, tr("Enter a search before saving a view."))
			return
		for view in session.world.saved_search_views:
			if String(view.get("query", "")) == query:
				_notice(tabs, tr("That search view is already saved."))
				return
		session.world.saved_search_views.append({"name":query,"query":query,"created_date":String(session.world.get("date", ""))})
		_refresh_app(tabs)
	)
	search_row.add_child(save)
	input.text_submitted.connect(func(_text): run.call())

	var saved_heading := Label.new()
	saved_heading.text = tr("Saved views")
	saved_heading.add_theme_font_size_override("font_size", 18)
	box.add_child(saved_heading)
	if session.world.saved_search_views.is_empty():
		var empty := Label.new()
		empty.text = tr("No saved search views yet.")
		box.add_child(empty)
	else:
		for view in session.world.saved_search_views.duplicate(true):
			var row := HBoxContainer.new()
			box.add_child(row)
			var load_button := Button.new()
			load_button.text = String(view.get("name", view.get("query", "Search")))
			load_button.pressed.connect(func():
				input.text = String(view.get("query", ""))
				run.call()
			)
			row.add_child(load_button)
			var delete := Button.new()
			delete.text = tr("Delete")
			delete.pressed.connect(func():
				for i in range(session.world.saved_search_views.size() - 1, -1, -1):
					if String(session.world.saved_search_views[i].get("query", "")) == String(view.get("query", "")):
						session.world.saved_search_views.remove_at(i)
				_refresh_app(tabs)
			)
			row.add_child(delete)

func _show_result(world: Dictionary, row: Dictionary, owner: Control) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "%s — %s" % [String(row.type).capitalize(), String(row.name)]
	var detail := "ID: %s" % String(row.id)
	var value := _entity(world, String(row.type), String(row.id))
	if not value.is_empty():
		detail += "\n" + _summary(String(row.type), value)
	dialog.dialog_text = detail
	owner.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(620, 300))

func _entity(world: Dictionary, kind: String, id: String) -> Dictionary:
	var collection: String = String({"club":"clubs", "player":"players", "staff":"staff", "competition":"competitions", "country":"countries"}.get(kind, ""))
	for value in world.get(collection, []):
		if String(value.get("id", "")) == id:
			return value
	return {}

func _summary(kind: String, value: Dictionary) -> String:
	match kind:
		"player":
			return "Position: %s\nAge: %s\nClub: %s\nAbility: %s\nPotential: %s" % [value.get("position", ""), value.get("age", ""), value.get("club_id", ""), value.get("current_ability", ""), value.get("potential", "")]
		"club":
			return "Country: %s\nTier: %s\nReputation: %s\nCash: %s" % [value.get("country_id", ""), value.get("tier", ""), value.get("reputation", ""), value.get("cash", "")]
		"staff":
			return "Role: %s\nClub: %s\nAbility: %s\nReputation: %s" % [value.get("role", ""), value.get("club_id", ""), value.get("ability", ""), value.get("reputation", "")]
		"competition":
			return "Type: %s\nCountry: %s\nTier: %s\nClubs: %d" % [value.get("competition_type", ""), value.get("country_id", ""), value.get("tier", ""), value.get("club_ids", []).size()]
		"country":
			return "Code: %s\nYouth rating: %s" % [value.get("code", ""), value.get("youth_rating", "")]
		_:
			return str(value)

func _notice(owner: Control, text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = text
	owner.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(520, 180))

func _refresh_app(node: Node) -> void:
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
			current.call("_show_career")
			return
		current = current.get_parent()

func _first_vbox(node: Node) -> VBoxContainer:
	if node is VBoxContainer:
		return node
	for child in node.get_children():
		var found := _first_vbox(child)
		if found != null:
			return found
	return null

func _career_session(node: Node):
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
			return current.get("session")
		current = current.get_parent()
	return null
