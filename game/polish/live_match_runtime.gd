extends Node

const Coordinator = preload("res://application/career/managed_matchday_coordinator.gd")
const MatchViewer = preload("res://game/match_viewer.gd")
const Tactics = preload("res://simulation/tactics/tactics_manager.gd")

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
	if button.has_meta("live_match_continue") or not button.visible:
		return
	var text := button.text.strip_edges().to_upper()
	if not text.begins_with("CONTINUE"):
		return
	var app := _career_app(button)
	if app == null:
		return
	button.set_meta("live_match_continue", true)
	for connection in button.pressed.get_connections():
		button.pressed.disconnect(connection.callable)
	button.pressed.connect(_continue.bind(app))

func _continue(app: Node) -> void:
	if _active_window != null and is_instance_valid(_active_window):
		_active_window.grab_focus()
		return
	var session = app.get("session")
	if session == null or session.world.is_empty():
		app.call("_advance_day")
		return
	var coordinator = Coordinator.new()
	if not coordinator.has_live_match_tomorrow(session.world, String(session.managed_club_id)):
		app.call("_advance_day")
		return
	var seed := int(session.seed) + int(session.world.get("day_index", 0)) * 17 + int(session.world.get("season_year", 2026)) * 101
	var started: Dictionary = coordinator.start(session.world, String(session.managed_club_id), seed)
	if started.has("error"):
		app.call("_advance_day")
		return
	_open_match_window(app, coordinator)

func _open_match_window(app: Node, coordinator) -> void:
	var window := Window.new()
	_active_window = window
	window.title = "Live Match"
	window.min_size = Vector2i(1120, 700)
	window.size = Vector2i(1180, 740)
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
	viewer.custom_minimum_size = Vector2(760, 520)
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
	var plus5 := Button.new()
	plus5.text = "+5 min"
	time_row.add_child(plus5)
	var plus10 := Button.new()
	plus10.text = "+10 min"
	time_row.add_child(plus10)
	var interval := Button.new()
	interval.text = "Next break"
	time_row.add_child(interval)

	var sub_title := Label.new()
	sub_title.text = "Substitution"
	sub_title.add_theme_font_size_override("font_size", 18)
	controls.add_child(sub_title)
	var off := OptionButton.new()
	off.custom_minimum_size.x = 310
	controls.add_child(off)
	var on := OptionButton.new()
	on.custom_minimum_size.x = 310
	controls.add_child(on)
	var make_sub := Button.new()
	make_sub.text = "Make substitution"
	controls.add_child(make_sub)

	var tactics_title := Label.new()
	tactics_title.text = "Tactical change"
	tactics_title.add_theme_font_size_override("font_size", 18)
	controls.add_child(tactics_title)
	var formation := OptionButton.new()
	var formations: Array = Tactics.FORMATIONS.keys()
	formations.sort()
	for value in formations:
		formation.add_item(String(value))
	controls.add_child(formation)
	var mentality := OptionButton.new()
	for value in Tactics.VALID_MENTALITIES:
		mentality.add_item(String(value).capitalize())
		mentality.set_item_metadata(mentality.item_count - 1, String(value))
	controls.add_child(mentality)
	var apply_tactic := Button.new()
	apply_tactic.text = "Apply tactic now"
	controls.add_child(apply_tactic)

	var events_label := Label.new()
	events_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	events_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_child(events_label)

	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	var cancel := Button.new()
	cancel.text = "Leave without playing"
	bottom.add_child(cancel)
	var full_time := Button.new()
	full_time.text = "Play to full time"
	full_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(full_time)
	var commit := Button.new()
	commit.text = "Confirm result & continue"
	commit.disabled = true
	bottom.add_child(commit)

	var refresh := func(message: String = ""):
		var snap: Dictionary = coordinator.snapshot()
		scoreboard.text = "%s  %d - %d  %s    %d'" % [String(snap.get("home_name", "HOME")), int(snap.get("home_goals", 0)), int(snap.get("away_goals", 0)), String(snap.get("away_name", "AWAY")), int(snap.get("minute", 0))]
		status.text = message if message != "" else ("Full time. Confirm the result to complete the matchday." if bool(snap.get("finished", false)) else "Match is live. Advance time, make a change, or adjust tactics.")
		var partial: Dictionary = coordinator.match.result()
		partial["player_names"] = _player_names(app.get("session").world)
		viewer.set_match(partial)
		if viewer.timeline_size() > 0:
			viewer.set_frame(viewer.timeline_size() - 1)
		off.clear()
		on.clear()
		var side := String(snap.get("managed_side", "home"))
		var lineup: Array = snap.get("home_lineup", []) if side == "home" else snap.get("away_lineup", [])
		var bench: Array = snap.get("home_bench", []) if side == "home" else snap.get("away_bench", [])
		for id in lineup:
			off.add_item(_player_label(app.get("session").world, String(id)))
			off.set_item_metadata(off.item_count - 1, String(id))
		for id in bench:
			on.add_item(_player_label(app.get("session").world, String(id)))
			on.set_item_metadata(on.item_count - 1, String(id))
		var is_finished := bool(snap.get("finished", false))
		make_sub.disabled = is_finished or off.item_count == 0 or on.item_count == 0
		plus5.disabled = is_finished
		plus10.disabled = is_finished
		interval.disabled = is_finished
		full_time.disabled = is_finished
		apply_tactic.disabled = is_finished
		commit.disabled = not is_finished
		var recent: Array = snap.get("events", [])
		var lines: Array[String] = []
		for event in recent.slice(maxi(0, recent.size() - 6)):
			lines.append(_event_text(event, app.get("session").world))
		events_label.text = "\n".join(lines)

	refresh.call()
	plus5.pressed.connect(func():
		coordinator.advance(int(coordinator.snapshot().get("minute", 0)) + 5)
		refresh.call()
	)
	plus10.pressed.connect(func():
		coordinator.advance(int(coordinator.snapshot().get("minute", 0)) + 10)
		refresh.call()
	)
	interval.pressed.connect(func():
		var minute := int(coordinator.snapshot().get("minute", 0))
		var target := 45 if minute < 45 else mini(90, minute + 15)
		coordinator.advance(target)
		refresh.call()
	)
	make_sub.pressed.connect(func():
		if off.selected < 0 or on.selected < 0:
			return
		var err := coordinator.substitute(String(off.get_item_metadata(off.selected)), String(on.get_item_metadata(on.selected)))
		refresh.call("Substitution applied." if err == OK else "Substitution could not be made (%d)." % err)
	)
	apply_tactic.pressed.connect(func():
		var snap: Dictionary = coordinator.snapshot()
		var side := String(snap.get("managed_side", "home"))
		var current: Dictionary = snap.get("tactics", {}).get(side, {})
		var tactic := Tactics.new().create_tactic(formation.get_item_text(formation.selected), String(mentality.get_item_metadata(mentality.selected)), String(current.get("tempo", "standard")), String(current.get("pressing", "standard")))
		var err := coordinator.change_tactic(tactic)
		refresh.call("Tactical change applied." if err == OK else "Tactical change failed (%d)." % err)
	)
	full_time.pressed.connect(func():
		coordinator.advance(90)
		refresh.call()
	)
	cancel.pressed.connect(func():
		window.queue_free()
		_active_window = null
	)
	commit.pressed.connect(_commit_live_match.bind(app, window, coordinator, status))
	window.popup_centered()

func _commit_live_match(app: Node, window: Window, coordinator, status: Label) -> void:
	status.text = "Finalising matchday…"
	var session = app.get("session")
	var result: Dictionary = await app.call("_run_job", coordinator.commit.bind(session.world), "Finalising matchday")
	if result.has("error"):
		if is_instance_valid(window):
			window.queue_free()
		_active_window = null
		app.call("_show_career")
		app.call("_show_error", String(result.get("message", "The live match could not be committed.")))
		return
	_autosave_if_due(app)
	if is_instance_valid(window):
		window.queue_free()
	_active_window = null
	app.call("_show_career")

func _autosave_if_due(app: Node) -> void:
	var session = app.get("session")
	var settings: Dictionary = app.get("settings")
	var slot := int(app.get("active_slot"))
	if slot <= 0 or not bool(settings.get("autosave", true)):
		return
	if int(session.world.get("day_index", 0)) % maxi(1, int(settings.get("autosave_interval_days", 7))) != 0:
		return
	var slots = app.get("slots")
	if slots != null:
		slots.save_slot(slot, session.world, session.history, session.manager)

func _event_text(event: Dictionary, world: Dictionary) -> String:
	var minute := int(event.get("minute", 0))
	var event_type := String(event.get("type", "event"))
	if event_type == "substitution":
		return "%d' SUB: %s → %s" % [minute, _player_label(world, String(event.get("player_out", ""))), _player_label(world, String(event.get("player_in", "")))]
	if event_type == "tactical_change":
		return "%d' Tactics: %s %s" % [minute, String(event.get("formation", "")), String(event.get("mentality", ""))]
	if event_type == "shot" and String(event.get("outcome", "")) == "goal":
		return "%d' GOAL — %s" % [minute, _player_label(world, String(event.get("player_id", "")))]
	if event_type == "card":
		return "%d' %s card — %s" % [minute, String(event.get("card", "")).capitalize(), _player_label(world, String(event.get("player_id", "")))]
	return "%d' %s" % [minute, event_type.replace("_", " ").capitalize()]

func _player_names(world: Dictionary) -> Dictionary:
	var result := {}
	for player in world.get("players", []):
		var id := String(player.get("id", ""))
		result[id] = _player_label(world, id)
	return result

func _player_label(world: Dictionary, id: String) -> String:
	for player in world.get("players", []):
		if String(player.get("id", "")) != id:
			continue
		var name := String(player.get("name", "")).strip_edges()
		if name == "":
			name = (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()
		return "%s (%s)" % [name, String(player.get("position", ""))]
	return id

func _career_app(node: Node) -> Node:
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
			return current
		current = current.get_parent()
	return null
