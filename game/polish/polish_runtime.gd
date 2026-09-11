extends Node

const HistoryService = preload("res://application/career/world_history_service.gd")
const AUDIO_PATH := "user://audio_settings.json"
const TUTORIAL_CONTEXTS := {
	"Tactics": ["First tactic", "Set a shape and mentality that fit your squad. Tactical familiarity improves with use, so avoid changing everything every match."],
	"Scouting": ["First scouting visit", "Use scouting before committing money. Compare ability, potential, position fit, age and contract situation rather than judging one number."],
	"Transfers": ["First transfer", "Check transfer and wage budgets before negotiating. Structure affordable offers and leave room for renewals and squad depth."],
	"Competitions": ["Registration", "Review registration rules before the deadline. Keep enough eligible players in every position and register key youngsters when rules allow."],
	"Finances": ["Finances", "Watch cash, wage commitments and projected costs together. A transfer you can afford today can still damage the season budget."],
	"Match Analysis": ["Matchday review", "Use the match viewer and analysis after games. Look for repeated spatial problems, tired players and tactical patterns before changing instructions."],
}

var audio_settings := {"mute": false, "master": 0.8, "ui": 0.65, "match": 0.75}
var _ui_player: AudioStreamPlayer
var _match_player: AudioStreamPlayer
var _crowd_player: AudioStreamPlayer
var _last_scan_msec := 0
var _last_goal_key := ""

func _ready() -> void:
	audio_settings = _load_audio_settings()
	_ui_player = AudioStreamPlayer.new()
	_match_player = AudioStreamPlayer.new()
	_crowd_player = AudioStreamPlayer.new()
	add_child(_ui_player)
	add_child(_match_player)
	add_child(_crowd_player)
	_ui_player.stream = _tone(720.0, 0.035, 0.14)
	_match_player.stream = _tone(1080.0, 0.18, 0.25)
	_crowd_player.stream = _crowd_burst()
	set_process(true)
	call_deferred("_scan_tree")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_scan_msec < 700: return
	_last_scan_msec = now
	_scan_tree()

func _scan_tree() -> void:
	var root := get_tree().root
	_scan_node(root)

func _scan_node(node: Node) -> void:
	if node is Button:
		_wire_button(node)
	if node is TabContainer:
		_wire_tabs(node)
	if _is_match_viewer(node):
		_wire_match_viewer(node)
	for child in node.get_children():
		_scan_node(child)

func _wire_button(button: Button) -> void:
	if button.has_meta("polish_audio"): return
	button.set_meta("polish_audio", true)
	button.pressed.connect(_play_ui_click)

func _wire_tabs(tabs: TabContainer) -> void:
	if not _looks_like_career_tabs(tabs): return
	if not tabs.has_meta("polish_tutorial"):
		tabs.set_meta("polish_tutorial", true)
		tabs.tab_changed.connect(_on_career_tab_changed.bind(tabs))
	if not _has_tab(tabs, "World History"):
		_add_history_tab(tabs)
	if not _has_tab(tabs, "Audio"):
		_add_audio_tab(tabs)

func _looks_like_career_tabs(tabs: TabContainer) -> bool:
	var names: Array[String] = []
	for child in tabs.get_children(): names.append(String(child.name))
	return "Dashboard" in names and "Squad" in names and "Tactics" in names

func _has_tab(tabs: TabContainer, name: String) -> bool:
	for child in tabs.get_children():
		if String(child.name) == name: return true
	return false

func _add_history_tab(tabs: TabContainer) -> void:
	var session = _career_session(tabs)
	if session == null: return
	var scroll := ScrollContainer.new()
	scroll.name = "World History"
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(900, 500)
	scroll.add_child(box)
	var heading := Label.new(); heading.text = "WORLD HISTORY"; heading.add_theme_font_size_override("font_size", 22); box.add_child(heading)
	var history: Dictionary = HistoryService.new().build(session.world, session.history)
	_add_section(box, "All-time players", history.all_time_players, func(row): return "%s — %d goals, %d appearances%s" % [String(row.name), int(row.goals), int(row.appearances), " • retired" if bool(row.retired) else ""])
	_add_section(box, "Transfer records", history.transfer_records, func(row): return "%s: %s → %s — %s" % [String(row.player), String(row.from), String(row.to), _money(int(row.fee))])
	_add_section(box, "Club honours", history.club_honours, func(row): return "%s — %s × %d" % [String(row.club), String(row.competition), int(row.titles)])
	_add_section(box, "Competition history", history.competition_history, func(row): return "%s — %s: %s" % [String(row.season), String(row.competition), String(row.champion)])
	_add_section(box, "Manager history", history.manager_history, func(row): return "%s — %s (%s → %s) %s" % [String(row.manager), String(row.club), String(row.from), String(row.to), String(row.reason)])
	_add_section(box, "Legends & hall of fame", history.legends, func(row): return "%s — %s • %s" % [String(row.name), String(row.club), String(row.summary)])
	_add_section(box, "Recent world timeline", history.timeline, func(row): return "%s  %s" % [String(row.date), String(row.text)])
	var restart := Button.new(); restart.text = "Restart coach tips"; restart.pressed.connect(_restart_tutorial.bind(tabs)); box.add_child(restart)
	tabs.add_child(scroll)

func _add_section(parent: VBoxContainer, title: String, rows: Array, formatter: Callable) -> void:
	var label := Label.new(); label.text = title; label.add_theme_font_size_override("font_size", 18); parent.add_child(label)
	if rows.is_empty():
		var empty := Label.new(); empty.text = "No historical records yet."; parent.add_child(empty); return
	for row in rows:
		var line := Label.new(); line.text = String(formatter.call(row)); line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; parent.add_child(line)

func _add_audio_tab(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new(); scroll.name = "Audio"
	var box := VBoxContainer.new(); box.custom_minimum_size = Vector2(820, 420); scroll.add_child(box)
	var heading := Label.new(); heading.text = "AUDIO & CUES"; heading.add_theme_font_size_override("font_size", 22); box.add_child(heading)
	var description := Label.new(); description.text = "Generated offline audio cues are used for UI actions, match goals and crowd ambience. No network or external audio pack is required."; description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(description)
	var mute := CheckBox.new(); mute.text = "Mute all audio"; mute.button_pressed = bool(audio_settings.mute); mute.toggled.connect(func(value): audio_settings.mute = value; _save_audio_settings()); box.add_child(mute)
	_add_volume(box, "Master volume", "master")
	_add_volume(box, "UI volume", "ui")
	_add_volume(box, "Match volume", "match")
	var test_ui := Button.new(); test_ui.text = "Test UI cue"; test_ui.pressed.connect(_play_ui_click); box.add_child(test_ui)
	var test_match := Button.new(); test_match.text = "Test match cue"; test_match.pressed.connect(func(): _play_match_cue(true)); box.add_child(test_match)
	tabs.add_child(scroll)

func _add_volume(parent: VBoxContainer, title: String, key: String) -> void:
	var row := HBoxContainer.new(); parent.add_child(row)
	var label := Label.new(); label.text = title; label.custom_minimum_size.x = 180; row.add_child(label)
	var slider := HSlider.new(); slider.min_value = 0.0; slider.max_value = 1.0; slider.step = 0.05; slider.value = float(audio_settings.get(key, 0.8)); slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(slider)
	slider.value_changed.connect(func(value): audio_settings[key] = float(value); _save_audio_settings())

func _on_career_tab_changed(index: int, tabs: TabContainer) -> void:
	if index < 0 or index >= tabs.get_tab_count(): return
	var context := tabs.get_tab_title(index)
	if not TUTORIAL_CONTEXTS.has(context): return
	var session = _career_session(tabs)
	if session == null: return
	var seen: Array = session.world.get("tutorial_seen", [])
	if context in seen: return
	seen.append(context)
	session.world["tutorial_seen"] = seen
	var data: Array = TUTORIAL_CONTEXTS[context]
	var dialog := AcceptDialog.new()
	dialog.title = String(data[0])
	dialog.dialog_text = String(data[1])
	dialog.ok_button_text = "Got it"
	tabs.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(560, 210))

func _restart_tutorial(tabs: TabContainer) -> void:
	var session = _career_session(tabs)
	if session == null: return
	session.world["tutorial_seen"] = []
	var dialog := AcceptDialog.new(); dialog.title = "Coach tips restarted"; dialog.dialog_text = "Contextual first-season guidance will appear again as you visit key screens."; tabs.add_child(dialog); dialog.confirmed.connect(dialog.queue_free); dialog.popup_centered(Vector2i(520, 180))

func _career_session(node: Node):
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
			return current.get("session")
		current = current.get_parent()
	return null

func _is_match_viewer(node: Node) -> bool:
	var script = node.get_script()
	return script != null and String(script.resource_path).ends_with("game/match_viewer.gd")

func _wire_match_viewer(viewer: Node) -> void:
	if viewer.has_meta("polish_audio"): return
	viewer.set_meta("polish_audio", true)
	if viewer.has_signal("frame_changed"):
		viewer.frame_changed.connect(_on_match_frame.bind(viewer))
	if viewer.has_signal("playback_finished"):
		viewer.playback_finished.connect(func(): _play_match_cue(false))

func _on_match_frame(_index: int, minute: int, viewer: Node) -> void:
	if minute == 0:
		_play_match_cue(false)
	if minute > 0 and minute % 10 == 0 and not bool(audio_settings.mute):
		_crowd_player.volume_db = _volume_db(float(audio_settings.master) * float(audio_settings.match) * 0.25)
		_crowd_player.play()
	var result: Dictionary = viewer.get("match_result")
	for event in result.get("events", []):
		if String(event.get("type", "")) != "goal": continue
		if int(event.get("minute", -1)) != minute: continue
		var key := "%s:%d:%s" % [String(result.get("fixture_id", "match")), minute, String(event.get("player_id", ""))]
		if key == _last_goal_key: continue
		_last_goal_key = key
		_play_match_cue(true)

func _play_ui_click() -> void:
	if bool(audio_settings.mute): return
	_ui_player.volume_db = _volume_db(float(audio_settings.master) * float(audio_settings.ui))
	_ui_player.play()

func _play_match_cue(goal: bool) -> void:
	if bool(audio_settings.mute): return
	_match_player.stream = _tone(1320.0 if goal else 920.0, 0.28 if goal else 0.12, 0.30)
	_match_player.volume_db = _volume_db(float(audio_settings.master) * float(audio_settings.match))
	_match_player.play()

func _load_audio_settings() -> Dictionary:
	if not FileAccess.file_exists(AUDIO_PATH): return audio_settings.duplicate(true)
	var file := FileAccess.open(AUDIO_PATH, FileAccess.READ)
	if file == null: return audio_settings.duplicate(true)
	var parsed = JSON.parse_string(file.get_as_text()); file.close()
	if typeof(parsed) != TYPE_DICTIONARY: return audio_settings.duplicate(true)
	return {"mute":bool(parsed.get("mute", false)),"master":clampf(float(parsed.get("master",0.8)),0.0,1.0),"ui":clampf(float(parsed.get("ui",0.65)),0.0,1.0),"match":clampf(float(parsed.get("match",0.75)),0.0,1.0)}

func _save_audio_settings() -> void:
	var file := FileAccess.open(AUDIO_PATH, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(audio_settings, "\t")); file.close()

func _volume_db(linear: float) -> float:
	return linear_to_db(clampf(linear, 0.001, 1.0))

func _tone(frequency: float, seconds: float, amplitude: float) -> AudioStreamWAV:
	var rate := 22050
	var samples := maxi(1, int(rate * seconds))
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		var envelope := 1.0 - float(i) / float(samples)
		var value := int(sin(TAU * frequency * float(i) / float(rate)) * amplitude * envelope * 32767.0)
		bytes.encode_s16(i * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _crowd_burst() -> AudioStreamWAV:
	var rate := 11025
	var samples := int(rate * 0.35)
	var bytes := PackedByteArray(); bytes.resize(samples * 2)
	var state := 1779033703
	for i in range(samples):
		state = int((state * 1103515245 + 12345) & 0x7fffffff)
		var noise := (float(state % 20001) / 10000.0) - 1.0
		var envelope := sin(PI * float(i) / float(samples))
		bytes.encode_s16(i * 2, int(noise * envelope * 4800.0))
	var stream := AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = rate; stream.stereo = false; stream.data = bytes
	return stream

func _money(value: int) -> String:
	if value >= 1000000: return "£%.1fm" % (float(value) / 1000000.0)
	if value >= 1000: return "£%.0fk" % (float(value) / 1000.0)
	return "£%d" % value
