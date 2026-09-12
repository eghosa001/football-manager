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
	_next_scan = now + 600
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if _is_player_profile(node):
		_enhance(node as Control)
	for child in node.get_children():
		_scan_node(child)

func _is_player_profile(node: Node) -> bool:
	var script = node.get_script()
	return script != null and String(script.resource_path).ends_with("game/presentation/player_profile_dialog.gd")

func _enhance(dialog: Control) -> void:
	if dialog.has_meta("ui2_profile_enhanced"):
		return
	var tabs: TabContainer = _find_tabs(dialog)
	if tabs == null:
		return
	var world_value = dialog.get("world")
	var player_id_value = dialog.get("player_id")
	if typeof(world_value) != TYPE_DICTIONARY:
		return
	var world: Dictionary = world_value
	var player_id: String = String(player_id_value)
	var player: Dictionary = _player(world, player_id)
	if player.is_empty():
		return
	dialog.set_meta("ui2_profile_enhanced", true)
	if dialog is Window:
		(dialog as Window).min_size = Vector2i(1040, 720)
	_style_tabs(tabs)
	_enhance_overview(_page(tabs, "Overview"), world, player)
	_enhance_attributes(_page(tabs, "Attributes"), player)
	_enhance_performance(_page(tabs, "Performance"), world, player_id)
	_enhance_contract(_page(tabs, "Contract"), world, player_id)
	_enhance_medical(_page(tabs, "Medical"), player)

func _style_tabs(tabs: TabContainer) -> void:
	tabs.add_theme_constant_override("side_margin", 8)
	tabs.add_theme_font_size_override("font_size", 13)
	for i in range(tabs.get_tab_count()):
		var page: Control = tabs.get_tab_control(i)
		page.set_meta("ui2_profile_page", true)

func _enhance_overview(page: Control, world: Dictionary, player: Dictionary) -> void:
	if page == null:
		return
	var box: VBoxContainer = _first_vbox(page)
	if box == null or box.has_meta("ui2_profile_overview"):
		return
	box.set_meta("ui2_profile_overview", true)
	var hero: HBoxContainer = HBoxContainer.new()
	hero.add_theme_constant_override("separation", 12)
	hero.custom_minimum_size.y = 205
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
	UI.body(identity, "%s foot • Weak foot %d" % [String(player.get("preferred_foot", "—")).capitalize(), int(player.get("weak_foot", 0))], true)
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

	var traits: Array = player.get("traits", [])
	if not traits.is_empty():
		var traits_panel: VBoxContainer = UI.panel(box, Vector2(0, 92), UI.CYAN)
		box.move_child(traits_panel.get_parent(), mini(1, box.get_child_count() - 1))
		UI.section(traits_panel, "PLAYER TRAITS")
		var flow: HFlowContainer = HFlowContainer.new()
		traits_panel.add_child(flow)
		for trait in traits.slice(0, mini(8, traits.size())):
			flow.add_child(UI.chip(String(trait).replace("_", " ").capitalize(), UI.CYAN))

func _ready_row(parent: Control, title: String, value: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label: Label = UI.body(row, title)
	label.custom_minimum_size.x = 82
	UI.progress(row, float(value), UI.score_color(float(value)), 105)
	var score: Label = UI.body(row, str(value))
	score.add_theme_color_override("font_color", UI.score_color(float(value)))

func _enhance_attributes(page: Control, player: Dictionary) -> void:
	if page == null:
		return
	var box: VBoxContainer = _first_vbox(page)
	if box == null or box.has_meta("ui2_profile_attributes"):
		return
	box.set_meta("ui2_profile_attributes", true)
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
		var start: int = chunk * column_index
		var finish: int = mini(keys.size(), chunk * (column_index + 1))
		for i in range(start, finish):
			var key: String = String(keys[i])
			var value: int = int(attrs.get(key, 0))
			var row: HBoxContainer = HBoxContainer.new()
			pane.add_child(row)
			var name_label: Label = UI.body(row, key.replace("_", " ").capitalize())
			name_label.custom_minimum_size.x = 145
			UI.progress(row, float(value) * 5.0, UI.score_color(float(value) * 5.0), 78)
			var value_label: Label = UI.body(row, str(value))
			value_label.add_theme_color_override("font_color", UI.score_color(float(value) * 5.0))

func _enhance_performance(page: Control, world: Dictionary, player_id: String) -> void:
	if page == null:
		return
	var box: VBoxContainer = _first_vbox(page)
	if box == null or box.has_meta("ui2_profile_performance"):
		return
	box.set_meta("ui2_profile_performance", true)
	var goals: int = 0
	var shots: int = 0
	var xg: float = 0.0
	var appearances: int = 0
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
	_add_metric_card(row, "APPEARANCES", str(appearances), UI.CYAN)
	_add_metric_card(row, "GOALS", str(goals), UI.GREEN)
	_add_metric_card(row, "SHOTS", str(shots), UI.PURPLE)
	_add_metric_card(row, "xG", "%.2f" % xg, UI.AMBER)

func _add_metric_card(parent: Control, title: String, value: String, color: Color) -> void:
	var card: VBoxContainer = UI.panel(parent, Vector2(190, 100), color)
	UI.metric(card, title, value, "this season", color)

func _enhance_contract(page: Control, world: Dictionary, player_id: String) -> void:
	if page == null:
		return
	var box: VBoxContainer = _first_vbox(page)
	if box == null or box.has_meta("ui2_profile_contract"):
		return
	box.set_meta("ui2_profile_contract", true)
	var contract: Dictionary = _contract(world, player_id)
	if contract.is_empty():
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	box.move_child(row, 0)
	_add_metric_card(row, "WEEKLY WAGE", UI.money(int(contract.get("weekly_wage", 0))), UI.GREEN)
	_add_metric_card(row, "CONTRACT END", str(contract.get("end_year", "—")), UI.PURPLE)
	_add_metric_card(row, "RELEASE CLAUSE", UI.money(int(contract.get("release_clause", 0))) if contract.has("release_clause") else "—", UI.AMBER)

func _enhance_medical(page: Control, player: Dictionary) -> void:
	if page == null:
		return
	var box: VBoxContainer = _first_vbox(page)
	if box == null or box.has_meta("ui2_profile_medical"):
		return
	box.set_meta("ui2_profile_medical", true)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	box.move_child(row, 0)
	_add_metric_card(row, "CONDITION", "%d%%" % int(player.get("fitness", 0)), UI.score_color(float(player.get("fitness", 0))))
	_add_metric_card(row, "FATIGUE", str(player.get("fatigue", 0)), UI.AMBER)
	_add_metric_card(row, "INJURED", "%d days" % int(player.get("injured_days", 0)) if int(player.get("injured_days", 0)) > 0 else "No", UI.RED if int(player.get("injured_days", 0)) > 0 else UI.GREEN)

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
