extends Node

const UniversalSearch = preload("res://application/career/universal_search.gd")
var _next_scan := 0
var _search = UniversalSearch.new()

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan: return
	_next_scan = now + 1000
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer: _wire_tabs(node)
	for child in node.get_children(): _scan_node(child)

func _wire_tabs(tabs: TabContainer) -> void:
	if tabs.has_meta("universal_search_added"): return
	var search_tab: Control = null
	for child in tabs.get_children():
		if String(child.name) == "Search": search_tab = child; break
	if search_tab == null: return
	var session = _career_session(tabs)
	if session == null: return
	var box := _first_vbox(search_tab)
	if box == null: return
	tabs.set_meta("universal_search_added",true)
	var title := Label.new(); title.text=tr("Indexed universal search"); title.add_theme_font_size_override("font_size",18); box.add_child(title)
	var help := Label.new(); help.text=tr("Search players, clubs, competitions, countries and staff."); help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(help)
	var input := LineEdit.new(); input.placeholder_text=tr("Name, ID, position, country code or competition"); box.add_child(input)
	var results := VBoxContainer.new(); box.add_child(results)
	var run := func():
		for child in results.get_children(): child.queue_free()
		for row in _search.search(session.world,input.text,40):
			var button := Button.new(); button.text="%s — %s%s" % [String(row.type).capitalize(),String(row.name)," — "+String(row.extra) if String(row.extra)!="" else ""]
			button.pressed.connect(_show_result.bind(session.world,row,tabs)); results.add_child(button)
	var button := Button.new(); button.text=tr("Search all"); button.pressed.connect(run); box.add_child(button)
	input.text_submitted.connect(func(_text): run.call())

func _show_result(world: Dictionary, row: Dictionary, owner: Control) -> void:
	var dialog := AcceptDialog.new(); dialog.title="%s — %s" % [String(row.type).capitalize(),String(row.name)]
	var detail := "ID: %s" % String(row.id)
	var value := _entity(world,String(row.type),String(row.id))
	if not value.is_empty(): detail += "\n"+_summary(String(row.type),value)
	dialog.dialog_text=detail; owner.add_child(dialog); dialog.confirmed.connect(dialog.queue_free); dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(620,300))

func _entity(world: Dictionary, kind: String, id: String) -> Dictionary:
	var collection := {"club":"clubs","player":"players","staff":"staff","competition":"competitions","country":"countries"}.get(kind,"")
	for value in world.get(collection,[]):
		if String(value.get("id",""))==id: return value
	return {}

func _summary(kind: String, value: Dictionary) -> String:
	match kind:
		"player": return "Position: %s\nAge: %s\nClub: %s\nAbility: %s\nPotential: %s" % [value.get("position",""),value.get("age",""),value.get("club_id",""),value.get("current_ability",""),value.get("potential","")]
		"club": return "Country: %s\nTier: %s\nReputation: %s\nCash: %s" % [value.get("country_id",""),value.get("tier",""),value.get("reputation",""),value.get("cash","")]
		"staff": return "Role: %s\nClub: %s\nAbility: %s\nReputation: %s" % [value.get("role",""),value.get("club_id",""),value.get("ability",""),value.get("reputation","")]
		"competition": return "Type: %s\nCountry: %s\nTier: %s\nClubs: %d" % [value.get("competition_type",""),value.get("country_id",""),value.get("tier",""),value.get("club_ids",[]).size()]
		"country": return "Code: %s\nYouth rating: %s" % [value.get("code",""),value.get("youth_rating","")]
		_: return str(value)

func _first_vbox(node: Node) -> VBoxContainer:
	if node is VBoxContainer: return node
	for child in node.get_children():
		var found:=_first_vbox(child); if found!=null: return found
	return null

func _career_session(node: Node):
	var current: Node=node
	while current!=null:
		var script=current.get_script()
		if script!=null and String(script.resource_path).ends_with("game/career/career_app.gd"): return current.get("session")
		current=current.get_parent()
	return null
