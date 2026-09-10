extends Control

const CareerSessionClass = preload("res://application/career/career_session.gd")
const SaveSlotsClass = preload("res://application/career/save_slots.gd")
const DayRunnerClass = preload("res://application/career/day_runner.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")
const CareerQueryClass = preload("res://application/career/career_query.gd")
const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")

var session = CareerSessionClass.new()
var slots = SaveSlotsClass.new()
var query = CareerQueryClass.new()
var active_slot := 1
var content: VBoxContainer
var status: Label
var _manager_name_input: LineEdit
var _club_selector: OptionButton
var _wizard_clubs: Array = []

func _ready() -> void:
	_show_main_menu()

func _clear() -> VBoxContainer:
	for child in get_children(): child.queue_free()
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
	_add_heading(root, "FOOTBALL DYNASTY", 34)
	var subtitle := Label.new()
	subtitle.text = "Career Management"
	root.add_child(subtitle)
	_add_button(root, "New Career", _show_new_career)
	_add_button(root, "Load Career", _show_load_menu)
	_add_button(root, "Quit", func(): get_tree().quit())

func _show_new_career() -> void:
	var root := _clear()
	_add_heading(root, "New Career", 28)
	var name_label := Label.new(); name_label.text = "Manager name"; root.add_child(name_label)
	_manager_name_input = LineEdit.new()
	_manager_name_input.text = "Manager"
	_manager_name_input.placeholder_text = "Enter manager name"
	root.add_child(_manager_name_input)
	var club_label := Label.new(); club_label.text = "Choose club"; root.add_child(club_label)
	_club_selector = OptionButton.new()
	_wizard_clubs = WorldGeneratorClass.new().create_world(12345).clubs
	for club in _wizard_clubs: _club_selector.add_item(String(club.name))
	root.add_child(_club_selector)
	var buttons := HBoxContainer.new(); root.add_child(buttons)
	_add_button(buttons, "Create Career", _create_career_from_wizard)
	_add_button(buttons, "Back", _show_main_menu)

func _create_career_from_wizard() -> void:
	var manager_name := _manager_name_input.text.strip_edges()
	if manager_name == "": manager_name = "Manager"
	var selected := clampi(_club_selector.selected, 0, maxi(0, _wizard_clubs.size()-1))
	var club_id := String(_wizard_clubs[selected].id) if not _wizard_clubs.is_empty() else ""
	session.new_career(manager_name, club_id, 12345)
	InboxServiceClass.new().add_message(session.world, "board", "Welcome to the club", "Your first season is ready. Review the squad, tactics and upcoming fixtures.")
	_show_career()

func _show_load_menu() -> void:
	var root := _clear()
	_add_heading(root, "Load Career", 28)
	var any := false
	for meta in slots.list_slots(10):
		if not bool(meta.get("exists", false)): continue
		any = true
		var label := "Slot %d — %s / %s / %s" % [int(meta.slot), String(meta.manager), String(meta.club), String(meta.date)]
		_add_button(root, label, _load_slot.bind(int(meta.slot)))
	if not any:
		var empty := Label.new(); empty.text = "No saved careers yet."; root.add_child(empty)
	_add_button(root, "Back", _show_main_menu)

func _load_slot(slot: int) -> void:
	var payload: Dictionary = slots.load_slot(slot)
	if payload.is_empty():
		_show_main_menu(); return
	active_slot = slot
	session.world = payload.world
	session.history = payload.get("history", [])
	session.manager = session.world.get("human_manager", {})
	session.managed_club_id = String(session.manager.get("club_id", ""))
	_show_career()

func _show_career() -> void:
	var root := _clear()
	var snap: Dictionary = session.snapshot()
	var dashboard: Dictionary = query.dashboard(session.world, session.managed_club_id)
	var club: Dictionary = dashboard.get("club", {})
	_add_heading(root, "%s — %s" % [String(club.get("name", "Club")), String(snap.date)], 26)
	var buttons := HBoxContainer.new(); root.add_child(buttons)
	_add_button(buttons, "Continue", _advance_day)
	_add_button(buttons, "Save Slot %d" % active_slot, _save)
	_add_button(buttons, "Main Menu", _show_main_menu)
	status = Label.new(); status.text = "Manager: %s  •  Season %d" % [String(session.manager.get("name", "Manager")), int(snap.season_year)]; root.add_child(status)
	var tabs := TabContainer.new(); tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(tabs)
	_add_text_tab(tabs, "Dashboard", str(dashboard))
	_add_text_tab(tabs, "Squad", _rows(query.squad(session.world, session.managed_club_id)))
	_add_text_tab(tabs, "Schedule", _rows(query.schedule(session.world, session.managed_club_id, 20)))
	_add_inbox_tab(tabs)
	_add_text_tab(tabs, "Tactics", str(query.tactics(session.world, session.managed_club_id)))
	_add_text_tab(tabs, "Finances", str(query.finances(session.world, session.managed_club_id)))
	_add_text_tab(tabs, "Staff", _rows(query.staff(session.world, session.managed_club_id)))

func _add_inbox_tab(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new(); scroll.name = "Inbox"
	var box := VBoxContainer.new(); box.custom_minimum_size = Vector2(780, 430); scroll.add_child(box)
	var messages: Array = InboxServiceClass.new().unread(session.world)
	if messages.is_empty():
		var empty := Label.new(); empty.text = "Inbox clear."; box.add_child(empty)
	for message in messages:
		var title := Label.new(); title.text = "%s — %s" % [String(message.get("category", "info")).to_upper(), String(message.get("title", "Message"))]; box.add_child(title)
		var body := Label.new(); body.text = String(message.get("body", "")); body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(body)
		if bool(message.get("requires_action", false)) and not bool(message.get("resolved", false)):
			var action_row := HBoxContainer.new(); box.add_child(action_row)
			for action in message.get("actions", []):
				var action_id := String(action.get("id", "action"))
				_add_button(action_row, String(action.get("label", action_id.capitalize())), _resolve_message.bind(int(message.id), action_id))
	tabs.add_child(scroll)

func _resolve_message(message_id: int, action_id: String) -> void:
	InboxServiceClass.new().resolve(session.world, message_id, action_id)
	_show_career()

func _advance_day() -> void:
	var result: Dictionary = DayRunnerClass.new().advance_day(session.world, session.history, session.seed + int(session.world.get("season_year", 2026)))
	if result.has("error"):
		status.text = "Unable to advance day"; return
	_show_career()

func _save() -> void:
	var err := slots.save_slot(active_slot, session.world, session.history, session.manager)
	status.text = "Saved to slot %d" % active_slot if err == OK else "Save failed (%d)" % err

func _add_heading(parent: Control, text: String, size: int) -> void:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); parent.add_child(label)

func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new(); button.text = text; button.pressed.connect(callback); parent.add_child(button)

func _add_text_tab(tabs: TabContainer, title: String, text: String) -> void:
	var scroll := ScrollContainer.new(); scroll.name = title
	var label := RichTextLabel.new(); label.fit_content = true; label.custom_minimum_size = Vector2(780, 430); label.text = text; scroll.add_child(label)
	tabs.add_child(scroll)

func _rows(rows: Array) -> String:
	var out: Array[String] = []
	for row in rows: out.append(str(row))
	return "\n".join(out)
