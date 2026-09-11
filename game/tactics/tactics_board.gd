class_name TacticsBoard
extends VBoxContainer

const Actions = preload("res://application/career/tactics_actions.gd")
const LineupService = preload("res://application/career/lineup_assignment_service.gd")
const TacticsManager = preload("res://simulation/tactics/tactics_manager.gd")

var world: Dictionary
var club_id: String
var _issues: Label
var _pitch: Control

func setup(career_world: Dictionary, managed_club_id: String) -> void:
	world = career_world
	club_id = managed_club_id
	custom_minimum_size = Vector2(980, 560)
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()
	var title := Label.new()
	title.text = tr("TACTICAL BOARD — LINEUP, ROLES & DUTIES")
	title.add_theme_font_size_override("font_size",20)
	add_child(title)
	var club := _club()
	if club.is_empty():
		return
	var tactic: Dictionary = club.get("tactic", TacticsManager.new().create_tactic("4-3-3"))
	LineupService.new().ensure_tactic(tactic)
	club["tactic"] = tactic
	_pitch = PitchDiagram.new()
	_pitch.custom_minimum_size = Vector2(900,300)
	_pitch.set("tactic", tactic)
	add_child(_pitch)
	var grid := GridContainer.new()
	grid.columns = 6
	add_child(grid)
	for text in [tr("Slot"),tr("Starter"),tr("Position"),tr("Role"),tr("Duty"),tr("Individual")]:
		var h := Label.new()
		h.text = text
		grid.add_child(h)
	var actions = Actions.new()
	var lineup_service = LineupService.new()
	var squad := _eligible_squad()
	for slot_key in actions.slot_keys(tactic):
		var position := actions.position_for_slot(tactic,slot_key)
		var slot := Label.new()
		slot.text = slot_key
		grid.add_child(slot)

		var starter := OptionButton.new()
		starter.add_item(tr("Automatic"))
		starter.set_item_metadata(0, "")
		var selected_index := 0
		var assigned_id := lineup_service.assigned_player_id(tactic, slot_key)
		for player in squad:
			var index := starter.item_count
			starter.add_item("%s — %s" % [_player_name(player), String(player.get("position", ""))])
			starter.set_item_metadata(index, String(player.get("id", "")))
			if String(player.get("id", "")) == assigned_id:
				selected_index = index
		starter.select(selected_index)
		starter.item_selected.connect(func(index: int):
			var player_id := String(starter.get_item_metadata(index))
			if player_id == "":
				lineup_service.clear_assignment(world, club_id, slot_key)
			else:
				lineup_service.assign_player(world, club_id, slot_key, player_id)
			_refresh_feedback()
		)
		grid.add_child(starter)

		var pos := Label.new()
		pos.text = position
		grid.add_child(pos)
		var role := OptionButton.new()
		var role_values: Array = TacticsManager.ROLES.get(position,[])
		for value in role_values:
			role.add_item(String(value).replace("_"," ").capitalize())
		var current_role := String(tactic.get("roles",{}).get(slot_key,role_values[0] if not role_values.is_empty() else ""))
		role.select(maxi(0,role_values.find(current_role)))
		role.item_selected.connect(func(index: int):
			if index>=0 and index<role_values.size():
				actions.set_role(world,club_id,slot_key,String(role_values[index]))
				_refresh_feedback()
		)
		grid.add_child(role)
		var duty := OptionButton.new()
		var duties := Actions.VALID_DUTIES.duplicate()
		if position == "GK":
			duties.erase("attack")
		for value in duties:
			duty.add_item(String(value).capitalize())
		var current_duty := String(tactic.get("duties",{}).get(slot_key,"support"))
		duty.select(maxi(0,duties.find(current_duty)))
		duty.item_selected.connect(func(index: int):
			if index>=0 and index<duties.size():
				actions.set_duty(world,club_id,slot_key,String(duties[index]))
				_refresh_feedback()
		)
		grid.add_child(duty)
		var individual := Button.new()
		individual.text = tr("Instructions")
		individual.pressed.connect(_show_individual_instructions.bind(slot_key))
		grid.add_child(individual)
	_issues = Label.new()
	_issues.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_issues)
	_refresh_feedback()

func _show_individual_instructions(slot_key: String) -> void:
	var service = LineupService.new()
	var tactic: Dictionary = _club().get("tactic", {})
	var current := service.instructions(tactic, slot_key)
	var dialog := ConfirmationDialog.new()
	dialog.title = tr("Individual instructions — %s") % slot_key
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(480, 280)
	var controls := {}
	for key in LineupService.INDIVIDUAL_OPTIONS.keys():
		var row := HBoxContainer.new()
		box.add_child(row)
		var label := Label.new()
		label.text = tr(String(key).capitalize())
		label.custom_minimum_size.x = 150
		row.add_child(label)
		var choice := OptionButton.new()
		var values: Array = LineupService.INDIVIDUAL_OPTIONS[key]
		for value in values:
			choice.add_item(tr(String(value).replace("_", " ").capitalize()))
		choice.select(maxi(0, values.find(String(current.get(key, "normal")))))
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(choice)
		controls[key] = choice
	dialog.add_child(box)
	add_child(dialog)
	dialog.confirmed.connect(func():
		for key in controls.keys():
			var values: Array = LineupService.INDIVIDUAL_OPTIONS[key]
			var choice: OptionButton = controls[key]
			service.set_instruction(world, club_id, slot_key, String(key), String(values[choice.selected]))
		_refresh_feedback()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(560, 390))

func _refresh_feedback() -> void:
	var issues := Actions.new().issues(world,club_id)
	var tactic: Dictionary = _club().get("tactic", {})
	var assignments: Dictionary = tactic.get("lineup_assignments", {})
	_issues.text = tr("Tactical feedback:\n• ") + "\n• ".join(issues) + tr("\nAssigned starters: %d/11") % assignments.size()
	if _pitch != null:
		_pitch.set("tactic",tactic)
		_pitch.set("world",world)
		_pitch.queue_redraw()

func _eligible_squad() -> Array:
	var values: Array = []
	for player in world.get("players", []):
		if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)) and int(player.get("injured_days", 0)) <= 0:
			values.append(player)
	values.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a.get("current_ability", 0)) == int(b.get("current_ability", 0)):
			return _player_name(a) < _player_name(b)
		return int(a.get("current_ability", 0)) > int(b.get("current_ability", 0))
	)
	return values

func _player_name(player: Dictionary) -> String:
	if player.has("name"):
		return String(player.name)
	return (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()

func _club() -> Dictionary:
	for club in world.get("clubs",[]):
		if String(club.get("id","")) == club_id:
			return club
	return {}

class PitchDiagram:
	extends Control
	var tactic: Dictionary = {}
	var world: Dictionary = {}
	func _draw() -> void:
		var pitch := Rect2(Vector2(20,10),Vector2(maxf(200.0,size.x-40.0),maxf(160.0,size.y-20.0)))
		draw_rect(pitch,Color(0.06,0.30,0.13),true)
		draw_rect(pitch,Color.WHITE,false,2.0)
		draw_line(Vector2(pitch.get_center().x,pitch.position.y),Vector2(pitch.get_center().x,pitch.end.y),Color.WHITE,1.0)
		var formation := String(tactic.get("formation","4-3-3"))
		var positions: Array = TacticsManager.FORMATIONS.get(formation,TacticsManager.FORMATIONS["4-3-3"])
		var coords := _formation_coords(positions)
		var counts := {}
		for i in range(positions.size()):
			var p := String(positions[i])
			counts[p]=int(counts.get(p,0))+1
			var key := p if int(counts[p])==1 else "%s_%d" % [p,int(counts[p])]
			var point := Vector2(pitch.position.x+coords[i].x*pitch.size.x,pitch.position.y+coords[i].y*pitch.size.y)
			draw_circle(point,15.0,Color(0.2,0.55,1.0))
			draw_circle(point,15.0,Color.WHITE,false,1.0)
			draw_string(ThemeDB.fallback_font,point+Vector2(-11,4),p,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)
			var role := String(tactic.get("roles",{}).get(key,""))
			var duty := String(tactic.get("duties",{}).get(key,""))
			draw_string(ThemeDB.fallback_font,point+Vector2(18,-2),role.replace("_"," "),HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color.WHITE)
			draw_string(ThemeDB.fallback_font,point+Vector2(18,10),duty,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(0.85,0.9,1.0))
			var player_id := String(tactic.get("lineup_assignments", {}).get(key, ""))
			if player_id != "":
				draw_string(ThemeDB.fallback_font,point+Vector2(-24,30),_short_name(player_id),HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color.WHITE)
	func _short_name(player_id: String) -> String:
		for player in world.get("players", []):
			if String(player.get("id", "")) == player_id:
				var name := String(player.get("name", (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()))
				return name.left(14)
		return player_id.left(12)
	func _formation_coords(positions: Array) -> Array:
		var groups := {"GK":[],"DEF":[],"MID":[],"AM":[],"ST":[]}
		for i in range(positions.size()):
			var p := String(positions[i])
			var group := "MID"
			if p=="GK": group="GK"
			elif p in ["DL","DC","DR","WBL","WBR"]: group="DEF"
			elif p in ["AML","AMC","AMR"]: group="AM"
			elif p=="ST": group="ST"
			groups[group].append(i)
		var coords: Array = []
		coords.resize(positions.size())
		var xs := {"GK":0.07,"DEF":0.25,"MID":0.50,"AM":0.70,"ST":0.88}
		for group in groups.keys():
			var ids: Array = groups[group]
			for j in range(ids.size()):
				coords[int(ids[j])] = Vector2(float(xs[group]),float(j+1)/float(ids.size()+1))
		return coords
