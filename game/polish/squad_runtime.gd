extends Node

const PlayerProfileDialog = preload("res://game/presentation/player_profile_dialog.gd")
var _next_scan := 0

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
		_wire(node)
	for child in node.get_children():
		_scan_node(child)

func _wire(tabs: TabContainer) -> void:
	if tabs.has_meta("advanced_squad_tools"):
		return
	var squad_tab := _named_tab(tabs, "Squad")
	if squad_tab == null:
		return
	var session = _career_session(tabs)
	if session == null:
		return
	var box := _first_vbox(squad_tab)
	if box == null:
		return
	tabs.set_meta("advanced_squad_tools", true)
	session.world["squad_saved_views"] = session.world.get("squad_saved_views", [])

	var heading := Label.new()
	heading.text = tr("Squad table tools")
	heading.add_theme_font_size_override("font_size", 18)
	box.add_child(heading)
	box.move_child(heading, 0)

	var controls := HBoxContainer.new()
	box.add_child(controls)
	box.move_child(controls, 1)
	var search := LineEdit.new()
	search.placeholder_text = tr("Search squad")
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(search)
	var position := OptionButton.new()
	for value in ["All", "GK", "DL", "DC", "DR", "WBL", "WBR", "DM", "ML", "MC", "MR", "AML", "AMC", "AMR", "ST"]:
		position.add_item(value)
	controls.add_child(position)
	var sort_by := OptionButton.new()
	var sort_fields := ["Name", "Position", "Age", "Condition", "Sharpness", "Morale", "Appearances", "Goals", "Rating", "Value", "Contract"]
	for field in sort_fields:
		sort_by.add_item(field)
	controls.add_child(sort_by)
	var descending := CheckBox.new()
	descending.text = tr("Descending")
	controls.add_child(descending)

	var table := VBoxContainer.new()
	box.add_child(table)
	box.move_child(table, 2)

	var render := func():
		for child in table.get_children():
			child.queue_free()
		var rows := _squad_rows(session.world, session.managed_club_id)
		var query := search.text.strip_edges().to_lower()
		var filter_position := position.get_item_text(position.selected)
		var filtered: Array = []
		for row in rows:
			if filter_position != "All" and String(row.position) != filter_position:
				continue
			if query != "" and not String(row.name).to_lower().contains(query):
				continue
			filtered.append(row)
		var field := sort_by.get_item_text(sort_by.selected)
		filtered.sort_custom(func(a: Dictionary, b: Dictionary):
			var av = _sort_value(a, field)
			var bv = _sort_value(b, field)
			if av == bv:
				return String(a.name) < String(b.name)
			return av > bv if descending.button_pressed else av < bv
		)
		var header := Label.new()
		header.text = tr("Name | Pos | Age | Cond | Sharp | Morale | Form | Apps | Goals | Ast | Rating | Value | Contract")
		table.add_child(header)
		for row in filtered:
			var line := HBoxContainer.new()
			table.add_child(line)
			var text := "%s | %s | %d | %d | %d | %d | %s | %d | %d | %d | %.1f | %s | %s" % [String(row.name),String(row.position),int(row.age),int(row.condition),int(row.sharpness),int(row.morale),String(row.form),int(row.appearances),int(row.goals),int(row.assists),float(row.rating),_money(int(row.value)),String(row.contract)]
			var open := Button.new()
			open.text = text
			open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			open.pressed.connect(_open_profile.bind(session.world, String(row.id), session.managed_club_id, tabs))
			line.add_child(open)

	var actions := HBoxContainer.new()
	box.add_child(actions)
	box.move_child(actions, 3)
	var apply := Button.new()
	apply.text = tr("Apply view")
	apply.pressed.connect(render)
	actions.add_child(apply)
	var save := Button.new()
	save.text = tr("Save squad view")
	save.pressed.connect(func():
		var name := "%s / %s / %s" % [position.get_item_text(position.selected), sort_by.get_item_text(sort_by.selected), "desc" if descending.button_pressed else "asc"]
		session.world.squad_saved_views.append({"name":name,"query":search.text,"position":position.get_item_text(position.selected),"sort":sort_by.get_item_text(sort_by.selected),"descending":descending.button_pressed})
		_refresh_app(tabs)
	)
	actions.add_child(save)
	var saved := OptionButton.new()
	saved.add_item(tr("Saved views"))
	for view in session.world.squad_saved_views:
		saved.add_item(String(view.get("name","View")))
	actions.add_child(saved)
	var load := Button.new()
	load.text = tr("Load")
	load.pressed.connect(func():
		var index := saved.selected - 1
		if index < 0 or index >= session.world.squad_saved_views.size():
			return
		var view: Dictionary = session.world.squad_saved_views[index]
		search.text = String(view.get("query",""))
		_select_text(position, String(view.get("position","All")))
		_select_text(sort_by, String(view.get("sort","Name")))
		descending.button_pressed = bool(view.get("descending",false))
		render.call()
	)
	actions.add_child(load)
	var delete := Button.new()
	delete.text = tr("Delete view")
	delete.pressed.connect(func():
		var index := saved.selected - 1
		if index >= 0 and index < session.world.squad_saved_views.size():
			session.world.squad_saved_views.remove_at(index)
			_refresh_app(tabs)
	)
	actions.add_child(delete)
	search.text_submitted.connect(func(_text): render.call())
	position.item_selected.connect(func(_index): render.call())
	sort_by.item_selected.connect(func(_index): render.call())
	descending.toggled.connect(func(_value): render.call())
	render.call()

func _squad_rows(world: Dictionary, club_id: String) -> Array:
	var last_ratings := {}
	if world.has("last_managed_match"):
		for row in preload("res://application/career/match_rating_service.gd").new().ratings(world.last_managed_match.get("result", {})):
			last_ratings[String(row.player_id)] = float(row.rating)
	var contracts := {}
	for contract in world.get("contracts", []):
		if String(contract.get("club_id","")) == club_id and not bool(contract.get("expired",false)):
			contracts[String(contract.get("player_id",""))] = contract
	var rows: Array = []
	for player in world.get("players", []):
		if String(player.get("club_id","")) != club_id or bool(player.get("retired",false)):
			continue
		var history_goals := 0
		for stat in world.get("player_match_stats", []):
			if String(stat.get("player_id","")) == String(player.id) and int(stat.get("season_year",0)) == int(world.get("season_year",0)):
				history_goals += int(stat.get("goals",0))
		var contract: Dictionary = contracts.get(String(player.id), {})
		rows.append({
			"id":String(player.id),"name":_name(player),"position":String(player.get("position","")),"age":int(player.get("age",0)),
			"condition":int(player.get("fitness",0)),"sharpness":int(player.get("match_sharpness",0)),"morale":int(player.get("morale",0)),"form":str(player.get("form","-")),
			"appearances":int(player.get("season_appearances",0)),"goals":history_goals,"assists":int(player.get("season_assists",0)),"rating":float(last_ratings.get(String(player.id),6.0)),
			"value":_estimated_value(player),"contract":String(contract.get("end_year","-"))
		})
	return rows

func _sort_value(row: Dictionary, field: String):
	match field:
		"Name": return String(row.name).to_lower()
		"Position": return String(row.position)
		"Age": return int(row.age)
		"Condition": return int(row.condition)
		"Sharpness": return int(row.sharpness)
		"Morale": return int(row.morale)
		"Appearances": return int(row.appearances)
		"Goals": return int(row.goals)
		"Rating": return float(row.rating)
		"Value": return int(row.value)
		"Contract": return String(row.contract)
		_: return String(row.name).to_lower()

func _open_profile(world: Dictionary, id: String, club_id: String, owner: Control) -> void:
	var dialog = PlayerProfileDialog.new()
	dialog.setup(world, id, club_id)
	owner.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(940, 700))

func _select_text(option: OptionButton, text: String) -> void:
	for i in range(option.item_count):
		if option.get_item_text(i) == text:
			option.select(i)
			return

func _named_tab(tabs: TabContainer, name: String) -> Control:
	for child in tabs.get_children():
		if String(child.name) == name:
			return child
	return null
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
func _refresh_app(node: Node) -> void:
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
			current.call("_show_career")
			return
		current = current.get_parent()
func _name(player: Dictionary) -> String:
	var name := String(player.get("name","")).strip_edges()
	return name if name != "" else (String(player.get("first_name",""))+" "+String(player.get("last_name",""))).strip_edges()
func _estimated_value(player: Dictionary) -> int:
	var ca := int(player.get("current_ability",50)); var pa := int(player.get("potential",ca)); var age := int(player.get("age",25))
	var age_factor := 1.25 if age <= 23 else (1.0 if age <= 28 else maxf(0.35,1.0-float(age-28)*0.09))
	return int((ca*ca*900 + maxi(0,pa-ca)*ca*450)*age_factor)
func _money(value: int) -> String:
	if value >= 1000000:
		return "£%.1fm" % (float(value)/1000000.0)
	if value >= 1000:
		return "£%.0fk" % (float(value)/1000.0)
	return "£%d" % value
