class_name TrainingActions
extends RefCounted

const TrainingSystemClass = preload("res://simulation/players/training_system.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")

func set_individual_focus(world: Dictionary, club_id: String, player_id: String, focus: String) -> Error:
	var player := _player(world, player_id)
	if player.is_empty() or String(player.get("club_id", "")) != club_id:
		return ERR_INVALID_PARAMETER
	var err := TrainingSystemClass.new().set_individual_focus(player, focus)
	if err == OK:
		InboxServiceClass.new().add_message(world, "training", "Individual training updated", "%s will now focus on %s." % [_player_name(player), focus.replace("_", " ")])
	return err

func available_focuses() -> Array:
	return TrainingSystemClass.INDIVIDUAL_FOCUSES.duplicate()

func _player(world: Dictionary, player_id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == player_id:
			return player
	return {}

func _player_name(player: Dictionary) -> String:
	return String(player.get("name", (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()))
