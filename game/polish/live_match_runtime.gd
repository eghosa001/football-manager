extends Node

const MatchViewer = preload("res://game/match_viewer.gd")
const Tactics = preload("res://simulation/tactics/tactics_manager.gd")

const CALENDAR_PATH = "res://core/calendar/calendar_service.gd"
const SEASON_RUNNER_PATH = "res://application/season/season_runner.gd"
const MATCHDAY_SERVICE_PATH = "res://application/career/career_matchday_service.gd"
const MATCH_SESSION_PATH = "res://simulation/match/managed_match_session.gd"
const COMMITTER_PATH = "res://application/career/managed_matchday_committer.gd"

var _next_scan := 0
var _active_window: Window

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 650
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is Button:
		_hook_continue(node as Button)
	for child in node.get_children():
		_scan_node(child)

func _hook_continue(button: Button) -> void:
	if not button.visible:
		return
	if not button.text.strip_edges().to_upper().begins_with("CONTINUE"):
		return
	var app := _career_app(button)
	if app == null:
		return
	var live_callable := _continue.bind(app)
	# UI polish runtimes can rebuild/rebind Continue after this runtime first sees it.
	# Remove stale advance-day handlers on every scan while preserving the UI click cue.
	for connection in button.pressed.get_connections():
		var callable: Callable = connection.callable
		if callable == live_callable or String(callable.get_method()) == "_play_ui_click":
			continue
		button.pressed.disconnect(callable)
	if not button.pressed.is_connected(live_callable):
		button.pressed.connect(live_callable)
	button.set_meta("live_match_continue", true)

func _continue(app: Node) -> void:
	if _active_window != null and is_instance_valid(_active_window):
		_active_window.grab_focus()
		return
	var session = app.get("session")
	if session == null or session.world.is_empty():
		app.call("_advance_day")
		return
	var fixture := _next_fixture(session.world, String(session.managed_club_id))
	if fixture.is_empty():
		app.call("_advance_day")
		return
	var seed := int(session.seed) + int(session.world.get("day_index", 0)) * 17 + int(session.world.get("season_year", 2026)) * 101
	var state := _start_live_state(session.world, String(session.managed_club_id), fixture, seed)
	if state.has("error"):
		app.call("_advance_day")
		return
	_open_match_window(app, state)

func _next_fixture(world: Dictionary, club_id: String) -> Dictionary:
	var runner = _instance(SEASON_RUNNER_PATH)
	if runner == null:
		return {}
	runner.call("assign_fixture_dates", world)
	var date := _next_date(String(world.get("date", "2026-07-01")))
	if date == "":
		return {}
	for row in world.get("fixtures", []):
		if bool(row.get("played", false)) or String(row.get("date", "")) != date:
			continue
		if String(row.get("home_club_id", "")) == club_id or String(row.get("away_club_id", "")) == club_id:
			return row
	return {}

func _start_live_state(world: Dictionary, club_id: String, fixture: Dictionary, seed: int) -> Dictionary:
	var service = _instance(MATCHDAY_SERVICE_PATH)
	var match = _instance(MATCH_SESSION_PATH)
	if service == null or match == null:
		return {"error": ERR_CANT_CREATE}
	service.call("_build_indexes", world)
	var home = service.call("_club", world, String(fixture.get("home_club_id", "")))
	var away = service.call("_club", world, String(fixture.get("away_club_id", "")))
	if not home is Dictionary or not away is Dictionary or home.is_empty() or away.is_empty():
		return {"error": ERR_INVALID_DATA}
	var players = service.call("_eligible_match_players", world, String(home.get("id", "")), String(away.get("id", "")), String(fixture.get("competition_id", "")))
	var context = service.call("_match_context", world, fixture, home, away)
	var fixture_seed := int(service.call("_fixture_seed", seed, String(fixture.get("id", ""))))
	var started = match.call("start_match", home, away, players, fixture_seed, context)
	if not started is Dictionary or started.has("error"):
		return {"error": int(started.get("error", ERR_CANT_CREATE)) if started is Dictionary else ERR_CANT_CREATE}
	return {
		"fixture": fixture,
		"target_date": String(fixture.get("date", "")),
		"managed_club_id": club_id,
		"managed_side": "home" if String(home.get("id", "")) == club_id else "away",
		"season_seed": seed,
		"fixture_seed": fixture_seed,
		"home": home,
		"away": away,
		"match": match
	}

func _snapshot(state: Dictionary) -> Dictionary:
	var match = state.get("match")
	if match == null:
		return {"error": ERR_UNCONFIGURED}
	var data = match.call("snapshot")
	if not data is Dictionary:
		return {"error": ERR_INVALID_DATA}
	data["fixture"] = state.get("fixture", {}).duplicate(true)
	data["home_name"] = String(state.get("home", {}).get("name", "Home"))
	data["away_name"] = String(state.get("away", {}).get("name", "Away"))
	data["managed_side"] = String(state.get("managed_side", "home"))
	return data

func _open_match_window(app: Node, state: Dictionary) -> void:
	var window := Window.new()
	_active_window = window
	window.title = "Live Match"
	var viewport_size: Vector2 = app.get_viewport_rect().size
	var window_width := mini(1180, maxi(960, int(viewport_size.x) - 80))
	var window_height := mini(680, maxi(560, int(viewport_size.y) - 40))
	window.min_size = Vector2i(mini(1040, window_width), mini(620, window_height))
	window.size = Vector2i(window_width, window_height)
	window.transient = true
	window.exclusive = true
	window.close_requested.connect(func():
		window.queue_free()
		_active_window = null
	)
	app.add_child(window)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	window.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var scoreboard := Label.new()
	scoreboard.add_theme_font_size_override("font_size", 24)
	scoreboard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(scoreboard)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var viewer := MatchViewer.new()
	viewer.custom_minimum_size = Vector2(maxi(620, window_width - 420), maxi(400, window_height - 220))
	viewer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(viewer)
	var controls := VBoxContainer.new()
	controls.custom_minimum_size.x = 330
	controls.add_theme_constant_override("separation", 7)
	body.add_child(controls)

	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(status)
	var time_row := HBoxContainer.new()
	controls.add_child(time_row)
	var plus5 := Button.new(); plus5.text = "+5 min"; time_row.add_child(plus5)
	var plus10 := Button.new(); plus10.text = "+10 min"; time_row.add_child(plus10)
	var interval := Button.new(); interval.text = "Next break"; time_row.add_child(interval)

	var sub_title := Label.new(); sub_title.text = "Substitution"; sub_title.add_theme_font_size_override("font_size", 18); controls.add_child(sub_title)
	var off := OptionButton.new(); off.custom_minimum_size.x = 310; controls.add_child(off)
	var on := OptionButton.new(); on.custom_minimum_size.x = 310; controls.add_child(on)
	var make_sub := Button.new(); make_sub.text = "Make substitution"; controls.add_child(make_sub)

	var tactics_title := Label.new(); tactics_title.text = "Tactical change"; tactics_title.add_theme_font_size_override("font_size", 18); controls.add_child(tactics_title)
	var formation := OptionButton.new()
	var formations: Array = Tactics.FORMATIONS.keys(); formations.sort()
	for value in formations: formation.add_item(String(value))
	controls.add_child(formation)
	var mentality := OptionButton.new()
	for value in Tactics.VALID_MENTALITIES:
		mentality.add_item(String(value).capitalize())
		mentality.set_item_metadata(mentality.item_count - 1, String(value))
	controls.add_child(mentality)
	var apply_tactic := Button.new(); apply_tactic.text = "Apply tactic now"; controls.add_child(apply_tactic)

	var events_scroll := ScrollContainer.new()
	events_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	events_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	events_scroll.custom_minimum_size = Vector2(0, 96)
	events_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_child(events_scroll)
	var events_label := Label.new()
	events_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	events_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	events_scroll.add_child(events_label)

	var bottom := HBoxContainer.new(); root.add_child(bottom)
	var cancel := Button.new(); cancel.text = "Leave without playing"; bottom.add_child(cancel)
	var full_time := Button.new(); full_time.text = "Play to full time"; full_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bottom.add_child(full_time)
	var commit := Button.new(); commit.text = "Confirm result & continue"; commit.disabled = true; bottom.add_child(commit)

	var refresh := func(message: String = ""):
		var snap := _snapshot(state)
		scoreboard.text = "%s  %d - %d  %s    %d'" % [String(snap.get("home_name", "HOME")), int(snap.get("home_goals", 0)), int(snap.get("away_goals", 0)), String(snap.get("away_name", "AWAY")), int(snap.get("minute", 0))]
		status.text = message if message != "" else ("Full time. Confirm the result to complete the matchday." if bool(snap.get("finished", false)) else "Match is live. Advance time, make a change, or adjust tactics.")
		var partial = state.match.call("result")
		if partial is Dictionary:
			partial["player_names"] = _player_names(app.get("session").world)
			viewer.set_match(partial)
			if viewer.timeline_size() > 0: viewer.set_frame(viewer.timeline_size() - 1)
		off.clear(); on.clear()
		var side := String(snap.get("managed_side", "home"))
		var lineup: Array = snap.get("home_lineup", []) if side == "home" else snap.get("away_lineup", [])
		var bench: Array = snap.get("home_bench", []) if side == "home" else snap.get("away_bench", [])
		for id in lineup:
			off.add_item(_player_label(app.get("session").world, String(id)))
			off.set_item_metadata(off.item_count - 1, String(id))
		for id in bench:
			on.add_item(_player_label(app.get("session").world, String(id)))
			on.set_item_metadata(on.item_count - 1, String(id))
		var finished := bool(snap.get("finished", false))
		make_sub.disabled = finished or off.item_count == 0 or on.item_count == 0
		plus5.disabled = finished; plus10.disabled = finished; interval.disabled = finished
		full_time.disabled = finished; apply_tactic.disabled = finished; commit.disabled = not finished
		var lines: Array[String] = []
		var recent: Array = snap.get("events", [])
		for event in recent.slice(maxi(0, recent.size() - 6)):
			lines.append(_event_text(event, app.get("session").world))
		events_label.text = "\n".join(lines)

	refresh.call()
	plus5.pressed.connect(func(): state.match.call("advance_to_minute", int(_snapshot(state).get("minute", 0)) + 5); refresh.call())
	plus10.pressed.connect(func(): state.match.call("advance_to_minute", int(_snapshot(state).get("minute", 0)) + 10); refresh.call())
	interval.pressed.connect(func():
		var minute := int(_snapshot(state).get("minute", 0))
		state.match.call("advance_to_minute", 45 if minute < 45 else mini(90, minute + 15))
		refresh.call()
	)
	make_sub.pressed.connect(func():
		if off.selected < 0 or on.selected < 0: return
		var err := int(state.match.call("make_substitution", String(state.managed_side), String(off.get_item_metadata(off.selected)), String(on.get_item_metadata(on.selected))))
		refresh.call("Substitution applied." if err == OK else "Substitution could not be made (%d)." % err)
	)
	apply_tactic.pressed.connect(func():
		var snap := _snapshot(state)
		var side := String(state.managed_side)
		var current: Dictionary = snap.get("tactics", {}).get(side, {})
		var tactic := Tactics.new().create_tactic(formation.get_item_text(formation.selected), String(mentality.get_item_metadata(mentality.selected)), String(current.get("tempo", "standard")), String(current.get("pressing", "standard")))
		var err := int(state.match.call("change_tactic", side, tactic))
		refresh.call("Tactical change applied." if err == OK else "Tactical change failed (%d)." % err)
	)
	full_time.pressed.connect(func(): state.match.call("advance_to_minute", 90); refresh.call())
	cancel.pressed.connect(func(): window.queue_free(); _active_window = null)
	commit.pressed.connect(_commit_live_match.bind(app, window, state, status))
	window.popup_centered()

func _commit_live_match(app: Node, window: Window, state: Dictionary, status: Label) -> void:
	status.text = "Finalising matchday…"
	var result = state.match.call("finish_match")
	if not result is Dictionary or result.has("error"):
		status.text = "Unable to finish this match."
		return
	var committer = _instance(COMMITTER_PATH)
	if committer == null:
		status.text = "Unable to finalise matchday."
		return
	var session = app.get("session")
	var commit_result: Dictionary = await app.call("_run_job", committer.commit.bind(session.world, state.fixture, result, state.home, state.away, state.managed_club_id, state.target_date, state.season_seed, state.fixture_seed), "Finalising matchday")
	if commit_result.has("error"):
		status.text = String(commit_result.get("message", "The live match could not be committed."))
		return
	_autosave_if_due(app)
	if is_instance_valid(window): window.queue_free()
	_active_window = null
	app.call("_show_career")

func _next_date(date_string: String) -> String:
	var parts := date_string.split("-")
	if parts.size() != 3: return ""
	var calendar = _instance(CALENDAR_PATH)
	if calendar == null: return ""
	calendar.call("set_date", int(parts[0]), int(parts[1]), int(parts[2]))
	calendar.call("advance_days", 1)
	return String(calendar.call("get_date_string"))

func _autosave_if_due(app: Node) -> void:
	var session = app.get("session")
	var settings: Dictionary = app.get("settings")
	var slot := int(app.get("active_slot"))
	if slot <= 0 or not bool(settings.get("autosave", true)): return
	if int(session.world.get("day_index", 0)) % maxi(1, int(settings.get("autosave_interval_days", 7))) != 0: return
	var slots = app.get("slots")
	if slots != null: slots.save_slot(slot, session.world, session.history, session.manager)

func _event_text(event: Dictionary, world: Dictionary) -> String:
	var minute := int(event.get("minute", 0))
	var event_type := String(event.get("type", "event"))
	if event_type == "substitution": return "%d' SUB: %s → %s" % [minute, _player_label(world, String(event.get("player_out", ""))), _player_label(world, String(event.get("player_in", "")))]
	if event_type == "tactical_change": return "%d' Tactics: %s %s" % [minute, String(event.get("formation", "")), String(event.get("mentality", ""))]
	if event_type == "shot" and String(event.get("outcome", "")) == "goal": return "%d' GOAL — %s" % [minute, _player_label(world, String(event.get("player_id", "")))]
	if event_type == "card": return "%d' %s card — %s" % [minute, String(event.get("card", "")).capitalize(), _player_label(world, String(event.get("player_id", "")))]
	return "%d' %s" % [minute, event_type.replace("_", " ").capitalize()]

func _player_names(world: Dictionary) -> Dictionary:
	var result := {}
	for player in world.get("players", []):
		var id := String(player.get("id", ""))
		result[id] = _player_label(world, id)
	return result

func _player_label(world: Dictionary, id: String) -> String:
	for player in world.get("players", []):
		if String(player.get("id", "")) != id: continue
		var name := String(player.get("name", "")).strip_edges()
		if name == "": name = (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()
		return "%s (%s)" % [name, String(player.get("position", ""))]
	return id

func _instance(path: String):
	var script = load(path)
	return null if script == null else script.new()

func _career_app(node: Node) -> Node:
	var current: Node = node
	while current != null:
		var script = current.get_script()
		while script != null:
			if String(script.resource_path).ends_with("game/career/career_app.gd"):
				return current
			script = script.get_base_script()
		current = current.get_parent()
	return null
