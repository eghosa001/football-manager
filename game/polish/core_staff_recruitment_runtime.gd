extends Node

const StaffRecruitment = preload("res://simulation/staff/staff_recruitment.gd")
const StaffContracts = preload("res://simulation/staff/staff_contracts.gd")

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
		_upgrade(node as TabContainer)
	for child in node.get_children():
		_scan_node(child)

func _upgrade(tabs: TabContainer) -> void:
	var session = _career_session(tabs)
	if session == null or session.world.is_empty():
		return
	var index := _tab_index(tabs, "Staff")
	if index < 0:
		return
	var page := tabs.get_tab_control(index)
	if page == null or page.has_meta("core_staff_recruitment"):
		return
	var box := _first_vbox(page)
	if box == null:
		return
	page.set_meta("core_staff_recruitment", true)
	StaffContracts.new().ensure_world(session.world)
	var divider := HSeparator.new()
	box.add_child(divider)
	var title := Label.new()
	title.text = "Staff recruitment"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	var help := Label.new()
	help.text = "Hire specialists to run delegated areas. Employed staff require compensation; wages must fit your club budget."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	box.add_child(controls)
	var role := OptionButton.new()
	for value in ["assistant", "coach", "scout", "physio"]:
		role.add_item(String(value).capitalize())
		role.set_item_metadata(role.item_count - 1, value)
	controls.add_child(role)
	var candidate := OptionButton.new()
	candidate.custom_minimum_size.x = 370
	controls.add_child(candidate)
	var wage := SpinBox.new()
	wage.min_value = 100
	wage.max_value = 500000
	wage.step = 100
	wage.custom_minimum_size.x = 140
	controls.add_child(wage)
	var years := SpinBox.new()
	years.min_value = 1
	years.max_value = 5
	years.step = 1
	years.value = 3
	years.custom_minimum_size.x = 70
	controls.add_child(years)
	var hire := Button.new()
	hire.text = "Hire"
	controls.add_child(hire)
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	var rows: Array = []
	var refresh := func():
		candidate.clear()
		rows = StaffRecruitment.new().candidates(session.world, String(session.managed_club_id), String(role.get_item_metadata(role.selected)), 12)
		for row in rows:
			var member := _staff(session.world, String(row.get("staff_id", "")))
			candidate.add_item("%s • Ability %d%s" % [_staff_name(member), int(row.get("ability", 0)), " • Free" if String(row.get("current_club_id", "")) == "" else " • Employed"])
			candidate.set_item_metadata(candidate.item_count - 1, String(row.get("staff_id", "")))
		if rows.is_empty():
			candidate.add_item("No candidates available")
			candidate.disabled = true
			hire.disabled = true
			return
		candidate.disabled = false
		hire.disabled = false
		candidate.select(0)
		wage.value = int(rows[0].get("weekly_wage", 1000))
		_show_candidate_cost(status, rows[0])
	refresh.call()
	role.item_selected.connect(func(_index): refresh.call())
	candidate.item_selected.connect(func(index: int):
		if index >= 0 and index < rows.size():
			wage.value = int(rows[index].get("weekly_wage", 1000))
			_show_candidate_cost(status, rows[index])
	)
	hire.pressed.connect(func():
		if candidate.disabled or candidate.selected < 0 or candidate.selected >= rows.size():
			return
		var selected: Dictionary = rows[candidate.selected]
		var err := StaffRecruitment.new().hire(session.world, String(session.managed_club_id), String(selected.get("staff_id", "")), int(wage.value), int(years.value))
		if err == OK:
			status.text = "%s hired successfully." % _staff_name(_staff(session.world, String(selected.get("staff_id", ""))))
			refresh.call()
		else:
			status.text = _hire_error(err)
	)
	_add_current_staff(box, session, status)

func _add_current_staff(box: VBoxContainer, session, status: Label) -> void:
	var heading := Label.new()
	heading.text = "Current specialists"
	heading.add_theme_font_size_override("font_size", 16)
	box.add_child(heading)
	for member in session.world.get("staff", []):
		if String(member.get("club_id", "")) != String(session.managed_club_id):
			continue
		if String(member.get("role", "")) not in ["assistant", "coach", "scout", "physio"]:
			continue
		var row := HBoxContainer.new()
		box.add_child(row)
		var label := Label.new()
		label.text = "%s — %s — Ability %d" % [_staff_name(member), String(member.get("role", "")).capitalize(), int(member.get("ability", 0))]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var fire := Button.new()
		fire.text = "Release"
		fire.pressed.connect(func():
			var err := StaffRecruitment.new().fire(session.world, String(session.managed_club_id), String(member.get("id", "")))
			status.text = "%s released." % _staff_name(member) if err == OK else "Could not release staff member (%d)." % err
			if err == OK:
				row.visible = false
		)
		row.add_child(fire)

func _show_candidate_cost(label: Label, row: Dictionary) -> void:
	label.text = "Recommended wage: %s/week • Compensation: %s" % [_money(int(row.get("weekly_wage", 0))), _money(int(row.get("compensation", 0)))]

func _hire_error(err: int) -> String:
	match err:
		ERR_UNAUTHORIZED: return "Offer rejected: increase the weekly wage."
		ERR_UNAVAILABLE: return "The club cannot afford this wage or compensation."
		ERR_ALREADY_EXISTS: return "This staff member already works for the club."
		_: return "Staff hire failed (%d)." % err

func _money(value: int) -> String:
	if abs(value) >= 1000000: return "£%.1fm" % (float(value) / 1000000.0)
	if abs(value) >= 1000: return "£%.0fk" % (float(value) / 1000.0)
	return "£%d" % value

func _staff_name(member: Dictionary) -> String:
	var name := String(member.get("name", "")).strip_edges()
	if name != "": return name
	return (String(member.get("first_name", "")) + " " + String(member.get("last_name", ""))).strip_edges()

func _staff(world: Dictionary, staff_id: String) -> Dictionary:
	for member in world.get("staff", []):
		if String(member.get("id", "")) == staff_id: return member
	return {}

func _tab_index(tabs: TabContainer, title: String) -> int:
	for i in range(tabs.get_tab_count()):
		if tabs.get_tab_title(i) == title or String(tabs.get_tab_control(i).name) == title: return i
	return -1

func _first_vbox(node: Node) -> VBoxContainer:
	if node is VBoxContainer: return node
	for child in node.get_children():
		var found := _first_vbox(child)
		if found != null: return found
	return null

func _career_session(node: Node):
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
			return current.get("session")
		current = current.get_parent()
	return null
