extends Control

const CareerSessionClass = preload("res://application/career/career_session.gd")
const SaveSlotsClass = preload("res://application/career/save_slots.gd")
const DayRunnerClass = preload("res://application/career/day_runner.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")
const CareerQueryClass = preload("res://application/career/career_query.gd")

var session = CareerSessionClass.new()
var slots = SaveSlotsClass.new()
var query = CareerQueryClass.new()
var active_slot := 1
var content: VBoxContainer
var status: Label

func _ready() -> void:
	_show_main_menu()

func _clear() -> VBoxContainer:
	for child in get_children():
		child.queue_free()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	return content

func _show_main_menu() -> void:
	var root := _clear()
	var title := Label.new()
	title.text = "FOOTBALL DYNASTY"
	title.add_theme_font_size_override("font_size", 34)
	root.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Career Management"
	root.add_child(subtitle)
	var new_button := Button.new()
	new_button.text = "New Career"
	new_button.pressed.connect(_new_career)
	root.add_child(new_button)
	var load_button := Button.new()
	load_button.text = "Load Slot 1"
	load_button.disabled = not bool(slots.metadata(1).get("exists", false))
	load_button.pressed.connect(_load_slot.bind(1))
	root.add_child(load_button)
	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(func(): get_tree().quit())
	root.add_child(quit_button)

func _new_career() -> void:
	session.new_career("Manager", "", 12345)
	InboxServiceClass.new().add_message(session.world, "board", "Welcome to the club", "Your first season is ready. Review the squad, tactics and upcoming fixtures.")
	_show_career()

func _load_slot(slot: int) -> void:
	var payload: Dictionary = slots.load_slot(slot)
	if payload.is_empty():
		_show_main_menu()
		return
	active_slot = slot
	session.world = payload.world
	session.history = payload.get("history", [])
	session.manager = session.world.get("human_manager", {})
	session.managed_club_id = String(session.manager.get("club_id", ""))
	_show_career()

func _show_career() -> void:
	var root := _clear()
	var snap: Dictionary = session.snapshot()
	var club: Dictionary = query.dashboard(session.world, session.managed_club_id).get("club", {})
	var title := Label.new()
	title.text = "%s — %s" % [String(club.get("name", "Club")), String(snap.date)]
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)
	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	_add_button(buttons, "Continue", _advance_day)
	_add_button(buttons, "Save", _save)
	_add_button(buttons, "Main Menu", _show_main_menu)
	status = Label.new()
	status.text = "Season %d" % int(snap.season_year)
	root.add_child(status)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	_add_text_tab(tabs, "Dashboard", str(query.dashboard(session.world, session.managed_club_id)))
	_add_text_tab(tabs, "Squad", _rows(query.squad(session.world, session.managed_club_id)))
	_add_text_tab(tabs, "Schedule", _rows(query.schedule(session.world, session.managed_club_id, 20)))
	_add_text_tab(tabs, "Inbox", _rows(InboxServiceClass.new().unread(session.world)))
	_add_text_tab(tabs, "Tactics", str(query.tactics(session.world, session.managed_club_id)))
	_add_text_tab(tabs, "Finances", str(query.finances(session.world, session.managed_club_id)))

func _advance_day() -> void:
	var result: Dictionary = DayRunnerClass.new().advance_day(session.world, session.history, session.seed + int(session.world.get("season_year", 2026)))
	if result.has("error"):
		status.text = "Unable to advance day"
		return
	_show_career()

func _save() -> void:
	var err := slots.save_slot(active_slot, session.world, session.history, session.manager)
	status.text = "Saved to slot %d" % active_slot if err == OK else "Save failed (%d)" % err

func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)

func _add_text_tab(tabs: TabContainer, title: String, text: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	var label := RichTextLabel.new()
	label.fit_content = true
	label.custom_minimum_size = Vector2(780, 430)
	label.text = text
	scroll.add_child(label)
	tabs.add_child(scroll)

func _rows(rows: Array) -> String:
	var out: Array[String] = []
	for row in rows:
		out.append(str(row))
	return "\n".join(out)
