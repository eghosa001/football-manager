class_name LineupAssignmentService
extends RefCounted

const TacticsManager = preload("res://simulation/tactics/tactics_manager.gd")
const TacticsActions = preload("res://application/career/tactics_actions.gd")

const INDIVIDUAL_OPTIONS := {
	"width": ["normal", "stay_wider", "sit_narrower"],
	"risk": ["normal", "take_more_risks", "take_fewer_risks"],
	"shooting": ["normal", "shoot_more", "shoot_less"],
	"pressing": ["normal", "press_more", "press_less"],
}

func ensure_tactic(tactic: Dictionary) -> void:
	tactic["lineup_assignments"] = tactic.get("lineup_assignments", {})
	tactic["individual_instructions"] = tactic.get("individual_instructions", {})

func assign_player(world: Dictionary, club_id: String, slot_key: String, player_id: String) -> Error:
	var club := _club(world, club_id)
	if club.is_empty():
		return ERR_DOES_NOT_EXIST
	if not club.has("tactic"):
		club["tactic"] = TacticsManager.new().create_tactic("4-3-3")
	ensure_tactic(club.tactic)
	if slot_key not in TacticsActions.new().slot_keys(club.tactic):
		return ERR_INVALID_PARAMETER
	var player := _player(world, player_id)
	if player.is_empty() or String(player.get("club_id", "")) != club_id or bool(player.get("retired", false)):
		return ERR_INVALID_PARAMETER
	for existing_slot in club.tactic.lineup_assignments.keys():
		if String(club.tactic.lineup_assignments[existing_slot]) == player_id:
			club.tactic.lineup_assignments.erase(existing_slot)
	club.tactic.lineup_assignments[slot_key] = player_id
	club.tactic.familiarity = maxf(0.0, float(club.tactic.get("familiarity", 50.0)) - 0.5)
	return OK

func clear_assignment(world: Dictionary, club_id: String, slot_key: String) -> Error:
	var club := _club(world, club_id)
	if club.is_empty() or not club.has("tactic"):
		return ERR_DOES_NOT_EXIST
	ensure_tactic(club.tactic)
	club.tactic.lineup_assignments.erase(slot_key)
	return OK

func set_instruction(world: Dictionary, club_id: String, slot_key: String, instruction: String, value: String) -> Error:
	var club := _club(world, club_id)
	if club.is_empty():
		return ERR_DOES_NOT_EXIST
	if not club.has("tactic"):
		club["tactic"] = TacticsManager.new().create_tactic("4-3-3")
	ensure_tactic(club.tactic)
	if slot_key not in TacticsActions.new().slot_keys(club.tactic):
		return ERR_INVALID_PARAMETER
	if not INDIVIDUAL_OPTIONS.has(instruction) or value not in INDIVIDUAL_OPTIONS[instruction]:
		return ERR_INVALID_PARAMETER
	if not club.tactic.individual_instructions.has(slot_key):
		club.tactic.individual_instructions[slot_key] = {}
	club.tactic.individual_instructions[slot_key][instruction] = value
	club.tactic.familiarity = maxf(0.0, float(club.tactic.get("familiarity", 50.0)) - 0.25)
	return OK

func resolve(players: Array, club_id: String, tactic: Dictionary) -> Array:
	ensure_tactic(tactic)
	var manager := TacticsManager.new()
	var automatic := manager.select_lineup(players, club_id, tactic)
	var slots := TacticsActions.new().slot_keys(tactic)
	var assignments: Dictionary = tactic.get("lineup_assignments", {})
	var selected_ids := {}
	var result: Array = []
	for slot_key in slots:
		var chosen: Dictionary = {}
		var assigned_id := String(assignments.get(slot_key, ""))
		if assigned_id != "":
			chosen = _eligible_player(players, club_id, assigned_id)
		if chosen.is_empty():
			for candidate in automatic:
				if not selected_ids.has(String(candidate.get("id", ""))):
					chosen = candidate
					break
		if chosen.is_empty():
			continue
		var match_player := chosen.duplicate(true)
		var slot_position := TacticsActions.new().position_for_slot(tactic, String(slot_key))
		match_player["match_slot"] = String(slot_key)
		match_player["natural_position"] = String(match_player.get("position", ""))
		if slot_position != "":
			match_player["position"] = slot_position
		match_player["match_instruction"] = tactic.get("individual_instructions", {}).get(slot_key, {}).duplicate(true)
		result.append(match_player)
		selected_ids[String(chosen.get("id", ""))] = true
		if result.size() >= slots.size():
			break
	return result

func assigned_player_id(tactic: Dictionary, slot_key: String) -> String:
	ensure_tactic(tactic)
	return String(tactic.lineup_assignments.get(slot_key, ""))

func instructions(tactic: Dictionary, slot_key: String) -> Dictionary:
	ensure_tactic(tactic)
	return tactic.individual_instructions.get(slot_key, {}).duplicate(true)

func _eligible_player(players: Array, club_id: String, player_id: String) -> Dictionary:
	for player in players:
		if String(player.get("id", "")) != player_id:
			continue
		if String(player.get("club_id", "")) != club_id or bool(player.get("retired", false)):
			return {}
		if int(player.get("injured_days", 0)) > 0:
			return {}
		return player
	return {}

func _player(world: Dictionary, player_id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == player_id:
			return player
	return {}

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return club
	return {}
