extends Node

var _next_scan := 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 700
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is ItemList and String(node.name) == "CoreLeagueSelector":
		_configure(node as ItemList)
	for child in node.get_children():
		_scan_node(child)

func _configure(list: ItemList) -> void:
	if list.has_meta("exact_leagues_populated"):
		_ensure_selected_club_league(list)
		return
	var app := _career_app(list)
	if app == null:
		return
	var preview = app.get("_wizard_preview")
	if typeof(preview) != TYPE_DICTIONARY or preview.is_empty():
		return
	var leagues: Array = _league_rows(preview)
	if leagues.is_empty():
		return
	list.clear()
	for row in leagues:
		list.add_item(String(row.get("label", row.get("id", "League"))))
		list.set_item_metadata(list.item_count - 1, String(row.get("id", "")))
	# Fast default: top division from the first three nations shown in the
	# launch database. The user's own division is forced on below.
	var selected_countries := {}
	for i in range(list.item_count):
		var token := String(list.get_item_metadata(i))
		var parts := token.split(":")
		if parts.size() != 2 or int(parts[1]) != 1:
			continue
		var country := String(parts[0])
		if selected_countries.size() < 3 and not selected_countries.has(country):
			list.select(i, false)
			selected_countries[country] = true
	list.set_meta("exact_leagues_populated", true)
	_replace_help_text(list)
	var club_selector = app.get("_club_selector")
	if club_selector is OptionButton:
		var selector: OptionButton = club_selector
		if not selector.item_selected.is_connected(_club_changed.bind(list)):
			selector.item_selected.connect(_club_changed.bind(list))
	_ensure_selected_club_league(list)

func _club_changed(_index: int, list: ItemList) -> void:
	call_deferred("_ensure_selected_club_league", list)

func _ensure_selected_club_league(list: ItemList) -> void:
	if not is_instance_valid(list):
		return
	var app := _career_app(list)
	if app == null:
		return
	var clubs = app.get("_wizard_clubs")
	var selector = app.get("_club_selector")
	if not (clubs is Array) or clubs.is_empty() or not (selector is OptionButton):
		return
	var index := clampi((selector as OptionButton).selected, 0, clubs.size() - 1)
	var club: Dictionary = clubs[index]
	var token := "%s:%d" % [String(club.get("country_id", "")), int(club.get("tier", 1))]
	for item in range(list.item_count):
		if String(list.get_item_metadata(item)) == token:
			list.select(item, false)
			return

func _league_rows(preview: Dictionary) -> Array:
	var countries := {}
	for country in preview.get("countries", []):
		countries[String(country.get("id", ""))] = String(country.get("name", country.get("id", "")))
	var by_id := {}
	for club in preview.get("clubs", []):
		var country_id := String(club.get("country_id", ""))
		var tier := int(club.get("tier", 1))
		var id := "%s:%d" % [country_id, tier]
		if by_id.has(id):
			continue
		by_id[id] = {
			"id": id,
			"country_id": country_id,
			"tier": tier,
			"label": "%s — %s" % [String(countries.get(country_id, country_id)), String(club.get("competition_name", "Division %d" % tier))],
		}
	var rows: Array = by_id.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary):
		var ai := String(a.get("country_id", ""))
		var bi := String(b.get("country_id", ""))
		if ai == bi:
			return int(a.get("tier", 1)) < int(b.get("tier", 1))
		return ai < bi
	)
	return rows

func _replace_help_text(list: ItemList) -> void:
	var parent := list.get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child is Label:
			var label := child as Label
			if "countries you want simulated" in label.text or "Active leagues" == label.text:
				if "countries you want simulated" in label.text:
					label.text = "Select only the divisions you want fully simulated. Fewer active leagues means faster Continue and matchdays. Your chosen club's division is always enabled."

func _career_app(node: Node) -> Node:
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
			return current
		current = current.get_parent()
	return null
