extends "res://game/career/career_views.gd"

func add_dynamics(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Dynamics")
	var world: Dictionary = session.world
	var club_id := String(session.managed_club_id)
	var dynamics = preload("res://application/career/dynamics_actions.gd").new()
	var squad: Array = []
	for player in world.get("players", []):
		if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)):
			squad.append(player)
	var morale_total := 0.0
	for player in squad:
		morale_total += float(player.get("morale", 50))
	var average_morale := morale_total / maxf(1.0, float(squad.size()))
	_heading(box, tr("Dressing room"), 20)
	_label(box, tr("Squad morale: %.0f/100 • Players: %d") % [average_morale, squad.size()])
	var club := _managed_club()
	if not club.is_empty():
		_label(box, tr("Captain: %s") % _player_name(_player(String(club.get("captain_id", "")))) if String(club.get("captain_id", "")) != "" else tr("Captain: Not appointed"))
	_heading(box, tr("Team meeting"), 18)
	var meeting_row := HBoxContainer.new()
	box.add_child(meeting_row)
	for tone in ["praise", "encourage", "criticize"]:
		_button(meeting_row, String(tone).capitalize(), func():
			var result: Dictionary = command.hold_team_meeting(world, club_id, tone)
			app.call("_show_career")
			app.call("_show_error", tr("Team meeting completed.") if not result.has("error") else tr("Team meeting is unavailable right now."))
		)
	_heading(box, tr("Captaincy"), 18)
	var candidates: Array = dynamics.captain_candidates(world, club_id)
	if candidates.is_empty():
		_label(box, tr("No eligible captain candidates."))
		return
	var captain_row := HBoxContainer.new()
	box.add_child(captain_row)
	var selector := OptionButton.new()
	selector.custom_minimum_size.x = 440
	for candidate in candidates.slice(0, mini(15, candidates.size())):
		selector.add_item("%s • Leadership %d • Influence %.0f" % [String(candidate.get("name", "Player")), int(candidate.get("leadership", 0)), float(candidate.get("influence", 0.0))])
		selector.set_item_metadata(selector.item_count - 1, String(candidate.get("id", "")))
	captain_row.add_child(selector)
	_button(captain_row, tr("Appoint captain"), func():
		if selector.item_count == 0:
			return
		var err: Error = dynamics.set_captain(world, club_id, String(selector.get_item_metadata(selector.selected)))
		app.call("_show_career")
		app.call("_show_error", tr("Captain updated.") if err == OK else tr("Captain appointment failed."))
	)
	_heading(box, tr("Leadership group"), 18)
	for candidate in candidates.slice(0, mini(8, candidates.size())):
		_label(box, "%s — Leadership %d • Influence %.0f" % [String(candidate.get("name", "Player")), int(candidate.get("leadership", 0)), float(candidate.get("influence", 0.0))])

func add_club(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Club")
	var club := _managed_club()
	if club.is_empty():
		_label(box, tr("Club information is unavailable."))
		return
	_heading(box, String(club.get("name", "Club")), 22)
	_label(box, tr("Reputation: %d • Cash: %d • Debt: %d") % [int(club.get("reputation", 0)), int(club.get("cash", 0)), int(club.get("debt", 0))])
	var stadium: Dictionary = club.get("stadium", {})
	if not stadium.is_empty():
		_label(box, tr("Stadium: %s • Capacity %d") % [String(stadium.get("name", "Club stadium")), int(stadium.get("capacity", 0))])
	var facilities: Dictionary = club.get("facilities", {})
	if not facilities.is_empty():
		_label(box, tr("Facilities — Training %d • Youth %d • Medical %d") % [int(facilities.get("training", 0)), int(facilities.get("youth", 0)), int(facilities.get("medical", 0))])
	var board: Dictionary = club.get("board", {})
	_heading(box, tr("Board"), 18)
	_label(box, tr("Board confidence: %d/100") % int(board.get("confidence", 60)))
	var objectives: Array = board.get("objectives", [])
	if objectives.is_empty():
		_label(box, tr("No active board objectives."))
	else:
		for objective in objectives:
			_label(box, "• %s — %s" % [String(objective.get("type", "Objective")).replace("_", " ").capitalize(), str(objective.get("target", ""))])
	var supporters: Dictionary = club.get("supporters", {})
	if not supporters.is_empty():
		_heading(box, tr("Supporters"), 18)
		_label(box, tr("Supporter confidence: %d/100 • Loyalty: %d/100") % [int(supporters.get("confidence", supporters.get("happiness", 60))), int(supporters.get("loyalty", 60))])
	_button(box, tr("Open finances & boardroom"), func(): _focus_tab(tabs, "Finances"))

func _managed_club() -> Dictionary:
	for club in session.world.get("clubs", []):
		if String(club.get("id", "")) == String(session.managed_club_id):
			return club
	return {}

func add_match_analysis(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Match Analysis")
	var data: Dictionary = query.last_match_analysis(session.world)
	if data.is_empty():
		_label(box, tr("No managed match has been played yet."))
		return
	var analysis: Dictionary = data.analysis
	_heading(box, tr("%s — %d:%d") % [String(data.date), int(analysis.score[0]), int(analysis.score[1])], 20)
	_label(box, tr("Stats: %s") % str(analysis.stats))
	var replay_result: Dictionary = session.world.last_managed_match.result.duplicate(true)
	replay_result["player_names"] = _player_name_map()
	var viewer = MatchViewerClass.new()
	viewer.custom_minimum_size = Vector2(900, 480)
	viewer.set_match(replay_result)
	box.add_child(viewer)
	var controls := HBoxContainer.new()
	box.add_child(controls)
	_button(controls, tr("◀"), viewer.previous_frame)
	_button(controls, tr("Play/Pause"), viewer.toggle_playback)
	_button(controls, tr("▶"), viewer.next_frame)
	for speed in [1.0, 2.0, 4.0]:
		_button(controls, tr("%dx") % int(speed), viewer.set_speed.bind(speed))

func _player_name_map() -> Dictionary:
	var names: Dictionary = {}
	for player in session.world.get("players", []):
		var id := String(player.get("id", ""))
		if id == "":
			continue
		var display := String(player.get("name", "")).strip_edges()
		if display == "":
			display = (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()
		if display != "":
			names[id] = display
	return names
