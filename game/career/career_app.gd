extends Control

const CareerSessionClass = preload("res://application/career/career_session.gd")
const SaveSlotsClass = preload("res://application/career/save_slots.gd")
const DayRunnerClass = preload("res://application/career/day_runner.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")
const CareerQueryClass = preload("res://application/career/career_query.gd")
const CareerViewsClass = preload("res://game/career/career_views.gd")
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
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	return content

func _show_main_menu() -> void:
	var root := _clear()
	_add_heading(root, "FOOTBALL DYNASTY", 36)
	var subtitle := Label.new(); subtitle.text = "Build a dynasty. Shape a football world."; root.add_child(subtitle)
	_add_button(root, "New Career", _show_new_career)
	_add_button(root, "Load Career", _show_load_menu)
	_add_button(root, "Quit", func(): get_tree().quit())

func _show_new_career() -> void:
	var root := _clear()
	_add_heading(root, "New Career", 28)
	var name_label := Label.new(); name_label.text = "Manager name"; root.add_child(name_label)
	_manager_name_input = LineEdit.new(); _manager_name_input.text = "Manager"; _manager_name_input.placeholder_text = "Enter manager name"; root.add_child(_manager_name_input)
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
	InboxServiceClass.new().add_message(session.world, "board", "Welcome to the club", "Your first season is ready. Review the squad, tactics, training and recruitment before the opening fixture.")
	_show_career()

func _show_load_menu() -> void:
	var root := _clear()
	_add_heading(root, "Load Career", 28)
	var any := false
	for meta in slots.list_slots(10):
		if not bool(meta.get("exists", false)): continue
		any = true
		var line := HBoxContainer.new(); root.add_child(line)
		var label := "Slot %d — %s / %s / %s" % [int(meta.slot), String(meta.manager), String(meta.club), String(meta.date)]
		_add_button(line, label, _load_slot.bind(int(meta.slot)))
		_add_button(line, "Delete", _delete_slot.bind(int(meta.slot)))
	if not any:
		var empty := Label.new(); empty.text = "No saved careers yet."; root.add_child(empty)
	_add_button(root, "Back", _show_main_menu)

func _delete_slot(slot: int) -> void:
	slots.delete_slot(slot)
	_show_load_menu()

func _load_slot(slot: int) -> void:
	var path := slots.slot_path(slot)
	if session.load_career(path) != OK:
		_show_main_menu(); return
	active_slot = slot
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
	_add_button(buttons, "Save As", _show_save_as)
	_add_button(buttons, "Main Menu", _show_main_menu)
	status = Label.new(); status.text = "Manager: %s  •  Season %d  •  Inbox %d" % [String(session.manager.get("name", "Manager")), int(snap.season_year), int(dashboard.get("unread_messages",0))]; root.add_child(status)
	var tabs := TabContainer.new(); tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(tabs)
	var views = CareerViewsClass.new(self, session)
	views.add_dashboard(tabs)
	views.add_squad(tabs)
	views.add_training(tabs)
	views.add_tactics(tabs)
	views.add_medical(tabs)
	views.add_scouting(tabs)
	views.add_transfers(tabs)
	views.add_schedule(tabs)
	_add_inbox_tab(tabs)
	views.add_staff(tabs)
	views.add_finances(tabs)
	views.add_search(tabs)
	views.add_match_analysis(tabs)

func _show_save_as() -> void:
	var root := _clear()
	_add_heading(root, "Save Career As", 28)
	for slot in range(1, 11):
		var meta: Dictionary = slots.metadata(slot)
		var label := "Slot %d" % slot
		if bool(meta.get("exists",false)): label += " — overwrite %s / %s" % [String(meta.get("manager","")),String(meta.get("date",""))]
		_add_button(root, label, _save_to_slot.bind(slot))
	_add_button(root, "Back", _show_career)

func _save_to_slot(slot: int) -> void:
	active_slot = slot
	var err := slots.save_slot(slot, session.world, session.history, session.manager)
	_show_career()
	if status != null: status.text = "Saved to slot %d" % slot if err == OK else "Save failed (%d)" % err

func _add_inbox_tab(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new(); scroll.name = "Inbox"
	var box := VBoxContainer.new(); box.custom_minimum_size = Vector2(920, 480); scroll.add_child(box)
	var messages: Array = InboxServiceClass.new().unread(session.world)
	if messages.is_empty():
		var empty := Label.new(); empty.text = "Inbox clear."; box.add_child(empty)
	for message in messages:
		var title := Label.new(); title.text = "%s — %s" % [String(message.get("category", "info")).to_upper(), String(message.get("title", "Message"))]; box.add_child(title)
		var body := Label.new(); body.text = String(message.get("body", "")); body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(body)
		var row := HBoxContainer.new(); box.add_child(row)
		if not bool(message.get("read",false)): _add_button(row, "Mark read", _mark_message_read.bind(int(message.id)))
		if bool(message.get("requires_action", false)) and not bool(message.get("resolved", false)):
			for action in message.get("actions", []):
				var action_id := String(action.get("id", "action"))
				_add_button(row, String(action.get("label", action_id.capitalize())), _resolve_message.bind(int(message.id), action_id))
	tabs.add_child(scroll)

func _mark_message_read(message_id: int) -> void:
	InboxServiceClass.new().mark_read(session.world, message_id)
	_show_career()

func _resolve_message(message_id: int, action_id: String) -> void:
	InboxServiceClass.new().resolve(session.world, message_id, action_id)
	_show_career()

func _advance_day() -> void:
	var result: Dictionary = DayRunnerClass.new().advance_day(session.world, session.history, session.seed + int(session.world.get("day_index",0))*17 + int(session.world.get("season_year",2026))*101)
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
