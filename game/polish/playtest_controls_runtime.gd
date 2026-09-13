extends Node

const LineupAssignment = preload("res://application/career/lineup_assignment_service.gd")
const TacticsActions = preload("res://application/career/tactics_actions.gd")
const CareerCommand = preload("res://application/career/career_command_service.gd")

var _next_scan: int = 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 500
	_scan()

func _scan() -> void:
	var app: Node = _find_app(get_tree().root)
	if app == null:
		return
	var tabs: TabContainer = _find_career_tabs(app)
	if tabs == null:
		return
	_dedupe_continue(app)
	_wire_dashboard(tabs)
	_wire_quick_pick(tabs, app)
	_wire_tactics(tabs, app)

func _dedupe_continue(app: Node) -> void:
	var found: bool = false
	for button in _buttons(app):
		var b: Button = button as Button
		if b.text.strip_edges().to_lower() != "continue" or not b.visible:
			continue
		if not found:
			found = true
		else:
			b.hide()
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _wire_dashboard(tabs: TabContainer) -> void:
	var page: Control = _page(tabs, "Dashboard")
	if page == null:
		return
	for node in page.find_children("*", "PanelContainer", true, false):
		var panel: PanelContainer = node as PanelContainer
		if panel == null or panel.has_meta("playtest_nav"):
			continue
		var text: String = _text(panel).to_lower()
		var target: String = ""
		if "next match" in text or "fixture" in text:
			target = "Schedule"
		elif "squad" in text or "injur" in text:
			target = "Squad"
		elif "finance" in text or "cash" in text:
			target = "Finances"
		elif "inbox" in text or "attention" in text:
			target = "Inbox"
		elif "league" in text or "position" in text:
			target = "Competitions"
		elif "board" in text:
			target = "Club"
		if target == "" or _tab_index(tabs, target) < 0:
			continue
		panel.set_meta("playtest_nav", target)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(_dashboard_input.bind(tabs, panel))

func _dashboard_input(event: InputEvent, tabs: TabContainer, panel: PanelContainer) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var target: String = String(panel.get_meta("playtest_nav", ""))
	var index: int = _tab_index(tabs, target)
	if index >= 0:
		tabs.current_tab = index

func _wire_quick_pick(tabs: TabContainer, app: Node) -> void:
	var page: Control = _page(tabs, "Squad")
	if page == null:
		return
	for button in _buttons(page):
		var b: Button = button as Button
		if b.text.strip_edges().to_lower() != "quick pick" or b.has_meta("playtest_quick_pick"):
			continue
		b.set_meta("playtest_quick_pick", true)
		b.pressed.connect(_quick_pick.bind(app, b))

func _quick_pick(app: Node, button: Button) -> void:
	var session = app.get("session")
	if session == null:
		return
	var world: Dictionary = session.get("world")
	var club_id: String = String(session.get("managed_club_id"))
	var club: Dictionary = _club(world, club_id)
	if club.is_empty():
		return
	var tactic: Dictionary = club.get("tactic", {})
	var service = LineupAssignment.new()
	service.ensure_tactic(tactic)
	var selected: Array = service.resolve(world.get("players", []), club_id, tactic)
	var slots: Array = TacticsActions.new().slot_keys(tactic)
	tactic["lineup_assignments"] = {}
	for i in range(mini(slots.size(), selected.size())):
		service.assign_player(world, club_id, String(slots[i]), String(selected[i].get("id", "")))
	button.text = "Quick Pick ✓ (%d)" % selected.size()
	button.tooltip_text = "Picked the strongest available fit XI and excluded injured players."

func _wire_tactics(tabs: TabContainer, app: Node) -> void:
	var page: Control = _page(tabs, "Tactics")
	if page == null:
		return
	var formation: OptionButton = _option(page, "Formation")
	if formation != null and not formation.has_meta("playtest_live_formation"):
		formation.set_meta("playtest_live_formation", true)
		formation.tooltip_text = "Changing this updates the active formation immediately."
		formation.item_selected.connect(_formation_changed.bind(page, app))
	for button in _buttons(page):
		var b: Button = button as Button
		if b.text.strip_edges().to_lower() != "apply tactical plan" or b.has_meta("playtest_apply"):
			continue
		b.set_meta("playtest_apply", true)
		b.pressed.connect(_apply_plan.bind(page, app, b))

func _formation_changed(_index: int, page: Control, app: Node) -> void:
	_apply_tactic(page, app)

func _apply_plan(page: Control, app: Node, button: Button) -> void:
	_apply_tactic(page, app)
	button.text = "Applied ✓"
	button.tooltip_text = "The tactical plan is active."

func _apply_tactic(page: Control, app: Node) -> void:
	var formation: OptionButton = _option(page, "Formation")
	if formation == null:
		return
	var mentality: OptionButton = _option(page, "Mentality")
	var tempo: OptionButton = _option(page, "Tempo")
	var pressing: OptionButton = _option(page, "Pressing")
	var session = app.get("session")
	var world: Dictionary = session.get("world")
	var club_id: String = String(session.get("managed_club_id"))
	var club: Dictionary = _club(world, club_id)
	var tactic: Dictionary = club.get("tactic", {})
	var mentality_value: String = String(tactic.get("mentality", "balanced"))
	var tempo_value: String = String(tactic.get("tempo", "standard"))
	var pressing_value: String = String(tactic.get("pressing", "standard"))
	if mentality != null:
		mentality_value = mentality.get_item_text(mentality.selected)
	if tempo != null:
		tempo_value = tempo.get_item_text(tempo.selected)
	if pressing != null:
		pressing_value = pressing.get_item_text(pressing.selected)
	CareerCommand.new().set_tactic(world, club_id, formation.get_item_text(formation.selected), mentality_value, tempo_value, pressing_value)

func _find_app(node: Node) -> Node:
	var script = node.get_script()
	if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
		return node
	for child in node.get_children():
		var found: Node = _find_app(child)
		if found != null:
			return found
	return null

func _find_career_tabs(app: Node) -> TabContainer:
	for node in app.find_children("*", "TabContainer", true, false):
		var tabs: TabContainer = node as TabContainer
		if tabs != null and _tab_index(tabs, "Dashboard") >= 0 and _tab_index(tabs, "Squad") >= 0:
			return tabs
	return null

func _page(tabs: TabContainer, title: String) -> Control:
	var index: int = _tab_index(tabs, title)
	if index < 0:
		return null
	return tabs.get_tab_control(index)

func _tab_index(tabs: TabContainer, title: String) -> int:
	for i in range(tabs.get_tab_count()):
		if tabs.get_tab_title(i).strip_edges().to_lower() == title.to_lower():
			return i
		if String(tabs.get_tab_control(i).name).to_lower() == title.to_lower():
			return i
	return -1

func _option(node: Node, control_name: String) -> OptionButton:
	for item in node.find_children("*", "OptionButton", true, false):
		var option: OptionButton = item as OptionButton
		if option != null and String(option.name).to_lower() == control_name.to_lower():
			return option
	return null

func _buttons(node: Node) -> Array:
	var result: Array = []
	if node is Button:
		result.append(node)
	for child in node.get_children():
		result.append_array(_buttons(child))
	return result

func _text(node: Node) -> String:
	var result: String = ""
	if node is Label:
		result += (node as Label).text + " "
	elif node is Button:
		result += (node as Button).text + " "
	for child in node.get_children():
		result += _text(child)
	return result

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return club
	return {}
