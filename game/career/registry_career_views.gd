extends "res://game/career/career_views.gd"

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
