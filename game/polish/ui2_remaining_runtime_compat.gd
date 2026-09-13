extends "res://game/polish/ui2_remaining_runtime.gd"

const StaffMarket = preload("res://simulation/staff/staff_market.gd")

func _build_staff(page: Control, tabs: TabContainer, session: Object) -> void:
	super._build_staff(page, tabs, session)
	if page == null:
		return
	var root := page.find_child("StaffUI2", true, false) as VBoxContainer
	if root == null or root.has_meta("staff_market_added"):
		return
	root.set_meta("staff_market_added", true)
	var world: Dictionary = session.get("world")
	var club_id := String(session.get("managed_club_id"))
	var market := StaffMarket.new()
	market.ensure_world(world)
	var panel := UI.panel(root, Vector2(0, 300), UI.PURPLE)
	UI.section(panel, "STAFF RECRUITMENT", UI.PURPLE)
	UI.body(panel, "Shortlisted candidates from the staff market. Hiring uses the same simulation rules as AI clubs.", true)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(grid)
	UI.table_header(grid, ["NAME", "ROLE", "ABILITY", "CURRENT CLUB", "ACTION"])
	var added := 0
	for role in ["coach", "scout", "physio"]:
		var candidates: Array = market.staff_candidates(world, club_id, role, 2)
		for candidate in candidates:
			var staff_id := String(candidate.get("staff_id", ""))
			var member := _staff_member(world, staff_id)
			if member.is_empty():
				continue
			UI.cell(grid, _person_name(member), 190)
			UI.cell(grid, role.capitalize(), 100, UI.CYAN)
			UI.cell(grid, str(member.get("ability", 0)), 70, UI.score_color(float(member.get("ability", 0))))
			var current_club := _club_name(world, String(member.get("club_id", "")))
			UI.cell(grid, current_club if current_club != "" else "Free agent", 160, UI.MUTED)
			var hire := Button.new()
			hire.name = "HireStaff_%s" % staff_id
			hire.text = "HIRE"
			hire.custom_minimum_size.x = 76
			hire.pressed.connect(func() -> void:
				var err := market.hire_staff(world, club_id, staff_id, int(world.get("season_year", 2026)))
				if err != OK:
					hire.text = "FAILED"
					return
				var app := _career_app(tabs)
				if app != null:
					app.call("_show_career")
			)
			grid.add_child(hire)
			added += 1
	if added == 0:
		UI.body(panel, "No suitable staff candidates are available right now.", true)

func _staff_member(world: Dictionary, staff_id: String) -> Dictionary:
	for member in world.get("staff", []):
		if String(member.get("id", "")) == staff_id:
			return member
	return {}

func _club_name(world: Dictionary, club_id: String) -> String:
	if club_id == "":
		return ""
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return String(club.get("name", club_id))
	return club_id
