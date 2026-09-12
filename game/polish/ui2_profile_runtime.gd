extends Node

const UI = preload("res://game/presentation/fd_ui2.gd")

var _next_scan: int = 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 700
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if _is_profile(node) and node is Window:
		_enhance(node as Window)
	for child in node.get_children():
		_scan_node(child)

func _is_profile(node: Node) -> bool:
	var script = node.get_script()
	return script != null and String(script.resource_path).ends_with("game/presentation/player_profile_dialog.gd")

func _enhance(dialog: Window) -> void:
	if dialog.has_meta("ui2_profile_enhanced"):
		return
	var tabs: TabContainer = _find_tabs(dialog)
	if tabs == null:
		return
	var world_value = dialog.get("world")
	if typeof(world_value) != TYPE_DICTIONARY:
		return
	var world: Dictionary = world_value
	var player_id: String = String(dialog.get("player_id"))
	var player: Dictionary = _player(world, player_id)
	if player.is_empty():
		return
	dialog.set_meta("ui2_profile_enhanced", true)
	dialog.min_size = Vector2i(1040, 720)
	var overview: Control = _page(tabs, "Overview")
	var attributes: Control = _page(tabs, "Attributes")
	var performance: Control = _page(tabs, "Performance")
	var contract_page: Control = _page(tabs, "Contract")
	var medical: Control = _page(tabs, "Medical")
	_add_overview_hero(overview, world, player)
	_rebuild_attributes(attributes, player)
	_add_performance_metrics(performance, world, player_id)
	_add_contract_metrics(contract_page, world, player_id)
	_add_medical_metrics(medical, player)

func _add_overview_hero(page: Control, world: Dictionary, player: Dictionary) -> void:
	if page == null:
		return
	var box: VBoxContainer = _first_vbox(page)
	if box == null:
		return
	var hero: HBoxContainer = HBoxContainer.new()
	hero.add_theme_constant_override("separation", 12)
	hero.custom_minimum_size.y = 200
	box.add_child(hero)
	box.move_child(hero, 0)
	var identity: VBoxContainer = UI.panel(hero, Vector2(360, 190), UI.CYAN)
	var name_label: Label = Label.new()
	name_label.text = _player_name(player)
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", UI.TEXT)
	identity.add_child(name_label)
	var chips: HFlowContainer = HFlowContainer.new()
	identity.add_child(chips)
	chips.add_child(UI.chip(String(player.get("position", "—")), UI.CYAN))
	chips.add_child(UI.chip("AGE %d" % int(player.get("age", 0)), UI.PURPLE))
	chips.add_child(UI.chip(String(player.get("country_id", player.get("nationality_id", "—"))).to_upper(), UI.GREEN))
	UI.metric(identity, "Estimated value", UI.money(_estimated_value(player)), "Market valuation", UI.GREEN)
	var level: VBoxContainer = UI.panel(hero, Vector2(280, 190), UI.PURPLE)
	UI.section(level, "PLAYER LEVEL", UI.PURPLE)
	UI.metric(level, "Current ability", UI.stars(int(player.get("current_ability", 0))), "%d / 100" % int(player.get("current_ability", 0)), UI.AMBER)
	UI.metric(level, "Potential", UI.stars(int(player.get("potential", 0))), "%d / 100" % int(player.get("potential", 0)), UI.AMBER)
	var readiness: VBoxContainer = UI.panel(hero, Vector2(280, 190), UI.GREEN)
	UI.section(readiness, "READINESS", UI.GREEN)
	_ready_row(readiness, "Condition", int(player.get("fitness", 0)))
	_ready_row(readiness, "Sharpness", int(player.get("match_sharpness", 0)))
	_ready_row(readiness, "Morale", int(player.get("morale", 0)))
	var contract: Dictionary = _contract(world, String(player.get("id", "")))
	if not contract.is_empty():
		UI.body(readiness, "Contract to %s • %s/w" % [str(contract.get("end_year", "—")), UI.money(int(contract.get("weekly_wage", 0)))], true)

func _ready_row(parent: Control, title: String, value: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label: Label = UI.body(row, title)
	label.custom_minimum_size.x = 82
	UI.progress(row, float(value), UI.score_color(float(value)), 105)
	var score: Label = UI.body(row, str(value))
	score.add_theme_color_override("font_color", UI.score_color(float(value)))

func _rebuild_attributes(page: Control, player: Dictionary) -> void:
	if page == null:
		return
	var box: VBoxContainer = _first_vbox(page)
	if box == null:
		return
	for child in box.get_children():
		child.visible = false
	var attrs: Dictionary = player.get("attributes", {})
	var keys: Array = attrs.keys()
	keys.sort()
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	box.add_child(columns)
	var headings: Array[String] = ["TECHNICAL", "MENTAL", "PHYSICAL"]
	var colors: Array[Color] = [UI.CYAN, UI.GREEN, UI.PURPLE]
	var chunk: int = maxi(1, int(ceil(float(keys.size()) / 3.0)))
	for column_index in range(3):
		var pane: VBoxContainer = UI.panel(columns, Vector2(285, 490), colors[column_index])
		UI.section(pane, headings[column_index], colors[column_index])
		var start_index: int = chunk * column_index
		var end_index: int = mini(keys.size(), chunk * (column_index + 1))
		for key_index in range(start_index, end_index):
			var key: String = String(keys[key_index])
			var value: int = int(attrs.get(key, 0))
			var row: HBoxContainer = HBoxContainer.new()
			pane.add_child(row)
			var name_label: Label = UI.body(row, key.replace("_", " ").capitalize())
			name_label.custom_minimum_size.x = 145
			UI.progress(row, float(value) * 5.0, UI.score_color(float(value) * 5.0), 78)
			var value_label: Label = UI.body(row, str(value))
			value_label.add_theme_color_override("font_color", UI.score_color(float(value) * 5.0))

func _add_performance_metrics(page: Control, world: Dictionary, player_id: String) -> void:
	if page == null:
		return
	var box: VBoxContainer = _first_vbox(page)
	if box == null:
		return
	var appearances: int = 0
	var goals: int = 0
	var shots: int = 0
	var xg: float = 0.0
	for stat in world.get("player_match_stats", []):
		if String(stat.get("player_id", "")) != player_id:
			continue
		appearances += 1
		goals += int(stat.get("goals", 0))
		shots += int(stat.get("shots", 0))
		xg += float(stat.get("xg", 0.0))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	box.move_child(row, 0)
	_metric_card(row, "APPEARANCES", str(appearances), UI.CYAN)
	_metric_card(row, "GOALS", str(goals), UI.GREEN)
	_metric_card(row, "SHOTS", str(shots), UI.PURPLE)
	_metric_card(row, "xG", "%.2f" % xg, UI.AMBER)

func _add_contract_metrics(page: Control, world: Dictionary, player_id: String) -> void:
	if page == null:
		return
	var contract: Dictionary = _contract(world, player_id)
	if contract.is_empty():
		return
	var box: VBoxContainer = _first_vbox(page)
	if box == null:
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	box.move_child(row, 0)
	_metric_card(row, "WEEKLY WAGE", UI.money(int(contract.get("weekly_wage", 0))), UI.GREEN)
	_metric_card(row, "CONTRACT END", str(contract.get("end_year", "—")), UI.PURPLE)
	var clause_text: String = UI.money(int(contract.get("release_clause", 0))) if contract.has("release_clause") else "—"
	_metric_card(row, "RELEASE CLAUSE", clause_text, UI.AMBER)

func _add_medical_metrics(page: Control, player: Dictionary) -> void:
	if page == null:
		return
	var box: VBoxContainer = _first_vbox(page)
	if box == null:
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	box.move_child(row, 0)
	_metric_card(row, "CONDITION", "%d%%" % int(player.get("fitness", 0)), UI.score_color(float(player.get("fitness", 0))))
	_metric_card(row, "FATIGUE", str(player.get("fatigue", 0)), UI.AMBER)
	var injured_days: int = int(player.get("injured_days", 0))
	_metric_card(row, "INJURED", "%d days" % injured_days if injured_days > 0 else "No", UI.RED if injured_days > 0 else UI.GREEN)

func _metric_card(parent: Control, title: String, value: String, color: Color) -> void:
	var card: VBoxContainer = UI.panel(parent, Vector2(190, 100), color)
	UI.metric(card, title, value, "", color)

func _find_tabs(node: Node) -> TabContainer:
	if node is TabContainer:
		return node as TabContainer
	for child in node.get_children():
		var found: TabContainer = _find_tabs(child)
		if found != null:
			return found
	return null

func _page(tabs: TabContainer, name: String) -> Control:
	for i in range(tabs.get_tab_count()):
		var page: Control = tabs.get_tab_control(i)
		if String(page.name) == name or tabs.get_tab_title(i) == name:
			return page
	return null

func _first_vbox(node: Node) -> VBoxContainer:
	if node is VBoxContainer:
		return node as VBoxContainer
	for child in node.get_children():
		var found: VBoxContainer = _first_vbox(child)
		if found != null:
			return found
	return null

func _player(world: Dictionary, id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == id:
			return player
	return {}

func _contract(world: Dictionary, id: String) -> Dictionary:
	for contract in world.get("contracts", []):
		if String(contract.get("player_id", "")) == id and not bool(contract.get("expired", false)):
			return contract
	return {}

func _player_name(player: Dictionary) -> String:
	var name: String = String(player.get("name", "")).strip_edges()
	if name != "":
		return name
	return (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()

func _estimated_value(player: Dictionary) -> int:
	var ability: int = int(player.get("current_ability", 50))
	var potential: int = int(player.get("potential", ability))
	var age: int = int(player.get("age", 25))
	var factor: float = 1.25 if age <= 23 else (1.0 if age <= 28 else maxf(0.35, 1.0 - float(age - 28) * 0.09))
	return int((ability * ability * 900 + maxi(0, potential - ability) * ability * 450) * factor)
