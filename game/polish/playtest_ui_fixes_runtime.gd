extends Node

const TacticsManager = preload("res://simulation/tactics/tactics_manager.gd")

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
	_fix_squad_filter(tabs)
	_fix_ui2_tactics(tabs, app)

func _fix_squad_filter(tabs: TabContainer) -> void:
	var page: Control = _page(tabs, "Squad")
	if page == null:
		return
	for node in page.find_children("*", "OptionButton", true, false):
		var option: OptionButton = node as OptionButton
		if option == null or option.item_count == 0:
			continue
		if option.get_item_text(0).strip_edges().to_upper() != "ALL":
			continue
		if option.has_meta("playtest_filter_fixed"):
			return
		option.set_meta("playtest_filter_fixed", true)
		option.fit_to_longest_item = false
		option.custom_minimum_size = Vector2(120, 38)
		option.tooltip_text = "Filter squad by playing position. ALL shows the complete first-team squad."
		var popup: PopupMenu = option.get_popup()
		popup.min_size = Vector2i(180, 0)
		popup.max_size = Vector2i(240, 360)
		return

func _fix_ui2_tactics(tabs: TabContainer, app: Node) -> void:
	var page: Control = _page(tabs, "Tactics")
	if page == null or page.has_meta("playtest_ui2_tactics_fixed"):
		return
	var options: Array = page.find_children("*", "OptionButton", true, false)
	if options.size() < 4:
		return
	var apply: Button = null
	for node in page.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button != null and button.text.strip_edges().to_upper() == "APPLY PLAN":
			apply = button
			break
	if apply == null:
		return
	page.set_meta("playtest_ui2_tactics_fixed", true)
	var formation: OptionButton = options[0] as OptionButton
	var mentality: OptionButton = options[1] as OptionButton
	var tempo: OptionButton = options[2] as OptionButton
	var pressing: OptionButton = options[3] as OptionButton
	formation.tooltip_text = "Formation — changes the shape shown on the pitch immediately."
	mentality.tooltip_text = "Mentality — controls overall attacking and defensive risk."
	tempo.tooltip_text = "Tempo — controls how quickly the team moves and circulates the ball."
	pressing.tooltip_text = "Pressing intensity — higher settings increase pressure, workload and fatigue."
	# Replace UI2's old Apply handler, which rebuilt the entire career screen and caused a visible stall.
	for connection in apply.pressed.get_connections():
		var callback: Callable = connection.get("callable")
		if callback.is_valid() and apply.pressed.is_connected(callback):
			apply.pressed.disconnect(callback)
	apply.pressed.connect(_apply_plan.bind(app, page, formation, mentality, tempo, pressing, apply))
	formation.item_selected.connect(_formation_preview.bind(app, page, formation))

func _formation_preview(_index: int, app: Node, page: Control, formation: OptionButton) -> void:
	var session = app.get("session")
	if session == null:
		return
	var world: Dictionary = session.get("world")
	var club_id: String = String(session.get("managed_club_id"))
	var club: Dictionary = _club(world, club_id)
	if club.is_empty():
		return
	var tactic: Dictionary = club.get("tactic", {})
	if tactic.is_empty():
		tactic = TacticsManager.new().create_tactic(formation.get_item_text(formation.selected))
		club["tactic"] = tactic
	else:
		tactic["formation"] = formation.get_item_text(formation.selected)
		tactic["familiarity"] = maxf(0.0, float(tactic.get("familiarity", 50.0)) - 1.0)
	_redraw_pitch(page, tactic)

func _apply_plan(app: Node, page: Control, formation: OptionButton, mentality: OptionButton, tempo: OptionButton, pressing: OptionButton, apply: Button) -> void:
	var session = app.get("session")
	if session == null:
		return
	var world: Dictionary = session.get("world")
	var club_id: String = String(session.get("managed_club_id"))
	var club: Dictionary = _club(world, club_id)
	if club.is_empty():
		return
	var tactic: Dictionary = club.get("tactic", {})
	if tactic.is_empty():
		tactic = TacticsManager.new().create_tactic(formation.get_item_text(formation.selected))
		club["tactic"] = tactic
	# Mutate the existing tactic dictionary so the pitch keeps the same reference and redraws instantly.
	tactic["formation"] = formation.get_item_text(formation.selected)
	tactic["mentality"] = TacticsManager.VALID_MENTALITIES[mentality.selected]
	tactic["tempo"] = TacticsManager.VALID_TEMPOS[tempo.selected]
	tactic["pressing"] = TacticsManager.VALID_PRESSING[pressing.selected]
	tactic["familiarity"] = maxf(0.0, float(tactic.get("familiarity", 50.0)) - 2.0)
	_redraw_pitch(page, tactic)
	apply.text = "APPLIED ✓"
	apply.tooltip_text = "Plan applied without rebuilding the whole career interface."
	var status = app.get("status")
	if status is Label:
		(status as Label).text = "Tactical plan applied."

func _redraw_pitch(page: Control, tactic: Dictionary) -> void:
	for node in page.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control == null:
			continue
		var script = control.get_script()
		if script != null and String(script.resource_path).ends_with("game/polish/ui2_runtime.gd"):
			if control.get("tactic") is Dictionary:
				control.set("tactic", tactic)
				control.queue_redraw()

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
	return tabs.get_tab_control(index) if index >= 0 else null

func _tab_index(tabs: TabContainer, title: String) -> int:
	for i in range(tabs.get_tab_count()):
		if tabs.get_tab_title(i).strip_edges().to_lower() == title.to_lower() or String(tabs.get_tab_control(i).name).to_lower() == title.to_lower():
			return i
	return -1

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return club
	return {}
