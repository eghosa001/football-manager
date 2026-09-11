extends Node

const TrainingDepth = preload("res://simulation/players/training_depth.gd")
const TacticsManager = preload("res://simulation/tactics/tactics_manager.gd")

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
		_wire(node)
	for child in node.get_children():
		_scan_node(child)

func _wire(tabs: TabContainer) -> void:
	if tabs.has_meta("individual_training_added"):
		return
	var training := _named_tab(tabs, "Training")
	if training == null:
		return
	var session = _career_session(tabs)
	if session == null or session.world.is_empty():
		return
	var box := _first_vbox(training)
	if box == null:
		return
	tabs.set_meta("individual_training_added", true)
	_add_controls(box, session)

func _add_controls(box: VBoxContainer, session) -> void:
	var depth = TrainingDepth.new()
	var squad: Array = []
	for player in session.world.get("players", []):
		if String(player.get("club_id", "")) == session.managed_club_id and not bool(player.get("retired", false)):
			depth.ensure_player(player)
			squad.append(player)
	if squad.is_empty():
		return
	var heading := Label.new()
	heading.text = tr("Individual training")
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)
	var help := Label.new()
	help.text = tr("Choose a player, role training, position training, attribute focus and one trait-development target. Progress is applied during weekly training.")
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)

	var player_choice := OptionButton.new()
	for player in squad:
		player_choice.add_item("%s — %s" % [_name(player), String(player.get("position", ""))])
	box.add_child(_labeled(tr("Player"), player_choice))

	var role_choice := OptionButton.new()
	box.add_child(_labeled(tr("Role training"), role_choice))
	var position_choice := OptionButton.new()
	for position in TrainingDepth.POSITIONS:
		position_choice.add_item(String(position))
	box.add_child(_labeled(tr("Position training"), position_choice))
	var focus_choice := OptionButton.new()
	for focus in TrainingDepth.FOCUS_AREAS:
		focus_choice.add_item(tr(String(focus).capitalize()))
	box.add_child(_labeled(tr("Attribute focus"), focus_choice))
	var focus_intensity := HSlider.new()
	focus_intensity.min_value = 0.2
	focus_intensity.max_value = 1.0
	focus_intensity.step = 0.05
	focus_intensity.value = 0.65
	box.add_child(_labeled(tr("Focus intensity"), focus_intensity))
	var trait_choice := OptionButton.new()
	trait_choice.add_item(tr("No trait target"))
	for trait in TrainingDepth.TRAITS:
		trait_choice.add_item(tr(String(trait).replace("_", " ").capitalize()))
	box.add_child(_labeled(tr("Trait development"), trait_choice))

	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)

	var refresh := func(index: int):
		var player: Dictionary = squad[clampi(index, 0, squad.size() - 1)]
		role_choice.clear()
		var roles: Array = TacticsManager.ROLES.get(String(player.get("position", "MC")), ["support"])
		for role in roles:
			role_choice.add_item(tr(String(role).replace("_", " ").capitalize()))
		var current_role := String(player.get("role_training", ""))
		if current_role in roles:
			role_choice.select(roles.find(current_role))
		var current_position := String(player.get("position_training", player.get("position", "MC")))
		position_choice.select(maxi(0, TrainingDepth.POSITIONS.find(current_position)))
		var current_focus := String(player.get("training_focus", "passing"))
		focus_choice.select(maxi(0, TrainingDepth.FOCUS_AREAS.find(current_focus)))
		focus_intensity.value = float(player.get("training_focus_intensity", 0.65))
		var current_trait := String(player.get("trait_training", ""))
		trait_choice.select(TrainingDepth.TRAITS.find(current_trait) + 1 if current_trait in TrainingDepth.TRAITS else 0)
		var risk := depth.injury_risk_feedback(player, float(focus_intensity.value))
		status.text = tr("Current plan: role %s • position %s • focus %s • trait %s • injury risk %s") % [current_role if current_role != "" else tr("none"), current_position, current_focus, current_trait if current_trait != "" else tr("none"), String(risk.band).capitalize()]
	player_choice.item_selected.connect(refresh)
	focus_intensity.value_changed.connect(func(_value): refresh.call(player_choice.selected))
	refresh.call(0)

	var apply := Button.new()
	apply.text = tr("Apply individual plan")
	apply.pressed.connect(func():
		var player: Dictionary = squad[clampi(player_choice.selected, 0, squad.size() - 1)]
		var roles: Array = TacticsManager.ROLES.get(String(player.get("position", "MC")), ["support"])
		if not roles.is_empty():
			depth.set_role_training(player, String(roles[clampi(role_choice.selected, 0, roles.size() - 1)]))
		depth.set_position_training(player, String(TrainingDepth.POSITIONS[position_choice.selected]))
		depth.set_individual_focus(player, String(TrainingDepth.FOCUS_AREAS[focus_choice.selected]), float(focus_intensity.value))
		if trait_choice.selected > 0:
			var selected_trait := String(TrainingDepth.TRAITS[trait_choice.selected - 1])
			if selected_trait not in player.get("traits", []):
				depth.set_trait_development(player, selected_trait)
		refresh.call(player_choice.selected)
	)
	box.add_child(apply)

func _named_tab(tabs: TabContainer, name: String) -> Control:
	for child in tabs.get_children():
		if String(child.name) == name:
			return child
	return null

func _first_vbox(node: Node) -> VBoxContainer:
	if node is VBoxContainer:
		return node
	for child in node.get_children():
		var found := _first_vbox(child)
		if found != null:
			return found
	return null

func _labeled(text: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 180
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _name(player: Dictionary) -> String:
	var name := String(player.get("name", "")).strip_edges()
	if name != "":
		return name
	return (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()

func _career_session(node: Node):
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
			return current.get("session")
		current = current.get_parent()
	return null
