extends Node

const PlayerHappiness = preload("res://simulation/players/player_happiness.gd")

var _next_scan := 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 900
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer:
		_wire(node)
	for child in node.get_children():
		_scan_node(child)

func _wire(tabs: TabContainer) -> void:
	if tabs.has_meta("happiness_categories_added"):
		return
	var dynamics := _named_tab(tabs, "Dynamics")
	if dynamics == null:
		return
	var session = _career_session(tabs)
	if session == null or session.world.is_empty():
		return
	var box := _first_vbox(dynamics)
	if box == null:
		return
	tabs.set_meta("happiness_categories_added", true)
	var service = PlayerHappiness.new()
	var rows: Array = []
	for player in session.world.get("players", []):
		if String(player.get("club_id", "")) != session.managed_club_id or bool(player.get("retired", false)):
			continue
		service.ensure_player(player)
		rows.append({"player":player,"concerns":service.concerns(player,55.0)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.player.get("happiness",65.0)) < float(b.player.get("happiness",65.0)))
	var heading := Label.new()
	heading.text = tr("Player happiness")
	heading.add_theme_font_size_override("font_size",18)
	box.add_child(heading)
	var help := Label.new()
	help.text = tr("Happiness is tracked separately for playing time, contract, training, manager relationship, club performance, squad harmony and transfer status.")
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	for row in rows.slice(0, mini(12, rows.size())):
		var player: Dictionary = row.player
		var concerns: Array = row.concerns
		var text := "%s — %.0f/100" % [_name(player), float(player.get("happiness",65.0))]
		if not concerns.is_empty():
			var parts: Array[String] = []
			for concern in concerns:
				parts.append("%s %.0f" % [String(concern.category).replace("_"," ").capitalize(),float(concern.value)])
			text += " — " + ", ".join(parts)
		var label := Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)

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

func _name(player: Dictionary) -> String:
	var name := String(player.get("name", "")).strip_edges()
	if name != "":
		return name
	return (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()

func _career_session(node: Node):
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
			return current.get("session")
		current = current.get_parent()
	return null
