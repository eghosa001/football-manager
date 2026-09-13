extends Node

const CareerCommand = preload("res://application/career/career_command_service.gd")

var _next_scan: int = 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 600
	_scan()

func _scan() -> void:
	var app: Node = _find_app(get_tree().root)
	if app == null:
		return
	var tabs: TabContainer = _find_career_tabs(app)
	if tabs == null:
		return
	var page: Control = _page(tabs, "Dynamics")
	if page == null:
		return
	for node in page.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button == null or button.has_meta("dynamics_responsive"):
			continue
		var tone: String = button.text.strip_edges().to_lower()
		if tone not in ["praise", "encourage", "criticize"]:
			continue
		button.set_meta("dynamics_responsive", true)
		for connection in button.pressed.get_connections():
			var callback: Callable = connection.get("callable")
			if callback.is_valid() and button.pressed.is_connected(callback):
				button.pressed.disconnect(callback)
		button.pressed.connect(_meeting.bind(app, tone, button))

func _meeting(app: Node, tone: String, button: Button) -> void:
	var session = app.get("session")
	if session == null:
		return
	var world: Dictionary = session.get("world")
	var club_id: String = String(session.get("managed_club_id"))
	var result: Dictionary = CareerCommand.new().hold_team_meeting(world, club_id, tone)
	if result.has("error"):
		button.text = "%s — unavailable" % tone.capitalize()
		return
	button.text = "%s ✓" % tone.capitalize()
	button.tooltip_text = "Meeting completed. Dressing-room atmosphere is now %.1f/100." % float(result.get("atmosphere", 50.0))
	var status = app.get("status")
	if status is Label:
		(status as Label).text = "%s team meeting completed — atmosphere %.1f/100." % [tone.capitalize(), float(result.get("atmosphere", 50.0))]

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
