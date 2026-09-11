extends Node

const DressingRoom = preload("res://simulation/players/dressing_room.gd")
const DynamicsActions = preload("res://application/career/dynamics_actions.gd")
const CareerCommand = preload("res://application/career/career_command_service.gd")
const StadiumService = preload("res://simulation/finance/stadium_service.gd")
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
	if tabs.has_meta("management_tabs_added"):
		return
	var session = _career_session(tabs)
	if session == null or session.world.is_empty():
		return
	var names: Array[String] = []
	for child in tabs.get_children():
		names.append(String(child.name))
	if "Dashboard" not in names or "Squad" not in names:
		return
	tabs.set_meta("management_tabs_added", true)
	if "Club" not in names:
		_add_club_tab(tabs, session)
	if "Dynamics" not in names:
		_add_dynamics_tab(tabs, session)

func _add_club_tab(tabs: TabContainer, session) -> void:
	var box := _tab(tabs, "Club")
	var club := _club(session.world, session.managed_club_id)
	if club.is_empty():
		return
	StadiumService.new().ensure_club(club)
	_heading(box, String(club.get("name", "Club")))
	_label(box, "Reputation %d   Cash %d   Transfer budget %d   Wage budget %d" % [int(club.get("reputation",0)), int(club.get("cash",0)), int(club.get("transfer_budget",0)), int(club.get("wage_budget",0))])

	_heading(box, "Stadium")
	var stadium: Dictionary = club.get("stadium", {})
	_label(box, "%s — Capacity %d   Seated %d   Corporate %d" % [String(stadium.get("name", "Stadium")), int(stadium.get("capacity",0)), int(stadium.get("seated_capacity",0)), int(stadium.get("corporate_capacity",0))])
	_label(box, "Condition %d   Pitch quality %d   Ownership %s   Location %s" % [int(stadium.get("condition",0)), int(stadium.get("pitch_quality",0)), String(stadium.get("ownership","owned")).capitalize(), String(stadium.get("location",""))])
	_label(box, "Expansion capacity %d   Roof: %s" % [int(stadium.get("expansion_capacity", stadium.get("capacity",0))), "Yes" if bool(stadium.get("roof",false)) else "No"])
	var project: Dictionary = club.get("stadium_project", {})
	if project.is_empty():
		_label(box, "No stadium project is currently active.")
		var actions := HBoxContainer.new()
		box.add_child(actions)
		for action in ["expand", "renovate", "relocate", "build_new"]:
			var button := Button.new()
			button.text = tr(String(action).replace("_", " ").capitalize())
			button.pressed.connect(func():
				var result := StadiumService.new().start_project(session.world, session.managed_club_id, String(action), int(session.world.get("season_year", 2026)))
				if int(result.get("error", FAILED)) == OK:
					var started: Dictionary = result.get("project", {})
					_notice(box, "Stadium project started. Cost: %d. Completion season: %d." % [int(started.get("cost",0)), int(started.get("completion_year",0))])
					_refresh_app(tabs)
				else:
					_notice(box, "Stadium project unavailable: %s" % String(result.get("reason", result.get("error", "error"))))
			)
			actions.add_child(button)
	else:
		_label(box, "Active project: %s   Cost %d   Completion season %d" % [String(project.get("type","project")).replace("_", " ").capitalize(), int(project.get("cost",0)), int(project.get("completion_year",0))])

	_heading(box, "Facilities")
	var facilities: Dictionary = club.get("facilities", {})
	_label(box, "Training %d   Youth training %d   Youth recruitment %d" % [int(facilities.get("training",0)), int(facilities.get("youth_training", facilities.get("youth",0))), int(facilities.get("youth_recruitment",0))])
	_label(box, "Sports science %d   Medical %d   Scouting %d" % [int(facilities.get("sports_science",0)), int(facilities.get("medical",0)), int(facilities.get("scouting",0))])

	var board: Dictionary = club.get("board", {})
	_label(box, "Board — Ambition %d   Patience %d   Financial prudence %d   Confidence %d" % [int(board.get("ambition",50)), int(board.get("patience",50)), int(board.get("financial_prudence",50)), int(board.get("confidence",50))])
	var supporters: Dictionary = club.get("supporters", {})
	_label(box, "Supporters — Size %d   Loyalty %d   Passion %d   Expectation %d   Wealth %d" % [int(supporters.get("size", supporters.get("core",0))), int(supporters.get("loyalty",50)), int(supporters.get("passion",50)), int(supporters.get("expectation",50)), int(supporters.get("wealth",50))])

	_heading(box, "Honours & recent history")
	var count := 0
	for row in session.world.get("club_honours", []):
		if String(row.get("club_id", "")) != session.managed_club_id:
			continue
		_label(box, "%s — %s" % [String(row.get("season_year", row.get("year", ""))), String(row.get("competition_name", row.get("competition_id", "Honour")))])
		count += 1
	if count == 0:
		_label(box, "No recorded honours yet.")
	_heading(box, "Institutional identity")
	_label(box, "Country: %s   Tier: %d   Ticket price: %d" % [String(club.get("country_id","")), int(club.get("tier",1)), int(club.get("ticket_price",0))])

func _add_dynamics_tab(tabs: TabContainer, session) -> void:
	var box := _tab(tabs, "Dynamics")
	var room := DressingRoom.new().rebuild(session.world, session.managed_club_id)
	_heading(box, "Dressing room")
	_label(box, "Atmosphere: %.1f / 100" % float(room.get("atmosphere",50.0)))
	_label(box, "Team leaders: %s" % _names(session.world, room.get("leaders",[])))
	_label(box, "Highly influential: %s" % _names(session.world, room.get("highly_influential",[])))
	_label(box, "Influential: %s" % _names(session.world, room.get("influential",[])))
	for group in room.get("social_groups", []):
		_label(box, "%s group: %s" % [String(group.get("name","Group")).capitalize(), _names(session.world,group.get("members",[]))])
	var club := _club(session.world, session.managed_club_id)
	var captain_id := String(club.get("captain_id", ""))
	_label(box, "Captain: %s" % (_player_name(session.world,captain_id) if captain_id != "" else "Not appointed"))
	_heading(box, "Captaincy")
	for candidate in DynamicsActions.new().captain_candidates(session.world, session.managed_club_id):
		var row := HBoxContainer.new()
		box.add_child(row)
		_label(row, "%s — Influence %.1f, Leadership %d, Age %d" % [String(candidate.name), float(candidate.influence), int(candidate.leadership), int(candidate.age)])
		var button := Button.new()
		button.text = tr("Appoint captain")
		button.pressed.connect(func():
			DynamicsActions.new().set_captain(session.world, session.managed_club_id, String(candidate.id))
			_refresh_app(tabs)
		)
		row.add_child(button)
	_heading(box, "Team meeting")
	var meetings := HBoxContainer.new()
	box.add_child(meetings)
	for tone in ["praise", "encourage", "criticize"]:
		var button := Button.new()
		button.text = tr(String(tone).capitalize())
		button.pressed.connect(func():
			CareerCommand.new().hold_team_meeting(session.world, session.managed_club_id, String(tone))
			_refresh_app(tabs)
		)
		meetings.add_child(button)
	_heading(box, "Active promises")
	var promises := 0
	for promise in session.world.get("player_promises", []):
		if String(promise.get("status", "")) != "active":
			continue
		var player := _player(session.world, String(promise.get("player_id", "")))
		if player.is_empty() or String(player.get("club_id", "")) != session.managed_club_id:
			continue
		_label(box, "%s — %s target %s by day %d" % [_name(player), String(promise.get("type","")), str(promise.get("target_value","")), int(promise.get("deadline_day",0))])
		promises += 1
	if promises == 0:
		_label(box, "No active player promises.")
	_heading(box, "Relationships")
	var relationships := 0
	for rel in session.world.get("relationships", []):
		var a := String(rel.get("source_person_id", rel.get("source_id", "")))
		var b := String(rel.get("target_person_id", rel.get("target_id", "")))
		var pa := _player(session.world, a)
		var pb := _player(session.world, b)
		if pa.is_empty() or pb.is_empty():
			continue
		if String(pa.get("club_id", "")) != session.managed_club_id and String(pb.get("club_id", "")) != session.managed_club_id:
			continue
		_label(box, "%s ↔ %s — %s (%d)" % [_name(pa), _name(pb), String(rel.get("relationship_type",rel.get("type","relationship"))), int(rel.get("strength",0))])
		relationships += 1
		if relationships >= 12:
			break
	if relationships == 0:
		_label(box, "No notable squad relationships recorded yet.")

func _refresh_app(node: Node) -> void:
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
			current.call("_show_career")
			return
		current = current.get_parent()

func _notice(parent: Control, text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = text
	parent.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(560, 190))

func _tab(tabs: TabContainer, name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(900,480)
	box.add_theme_constant_override("separation",8)
	scroll.add_child(box)
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count()-1, tr(name))
	return box

func _heading(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = tr(text)
	label.add_theme_font_size_override("font_size",18)
	parent.add_child(label)

func _label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = tr(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func _club(world: Dictionary, id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == id:
			return club
	return {}

func _player(world: Dictionary, id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == id:
			return player
	return {}

func _name(player: Dictionary) -> String:
	var name := String(player.get("name", "")).strip_edges()
	return name if name != "" else (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()

func _player_name(world: Dictionary, id: String) -> String:
	var player := _player(world, id)
	return _name(player) if not player.is_empty() else id

func _names(world: Dictionary, ids: Array) -> String:
	var rows: Array[String] = []
	for id in ids:
		rows.append(_player_name(world, String(id)))
	return ", ".join(rows)

func _career_session(node: Node):
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
			return current.get("session")
		current = current.get_parent()
	return null
