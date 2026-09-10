class_name CareerCommandService
extends RefCounted

const TrainingSystemClass = preload("res://simulation/players/training_system.gd")
const ScoutingServiceClass = preload("res://simulation/scouting/scouting_service.gd")
const TransferNegotiationClass = preload("res://simulation/transfers/transfer_negotiation.gd")
const TacticsManagerClass = preload("res://simulation/tactics/tactics_manager.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")

func set_training(world: Dictionary, club_id: String, sessions: Array, intensity: float) -> Error:
	var club := _club(world, club_id)
	if club.is_empty():
		return ERR_DOES_NOT_EXIST
	var err := TrainingSystemClass.new().set_schedule(club, sessions, intensity)
	if err == OK:
		InboxServiceClass.new().add_message(world, "training", "Training schedule updated", "The first-team training schedule has been updated.")
	return err

func set_tactic(world: Dictionary, club_id: String, formation: String, mentality: String, tempo: String, pressing: String) -> Error:
	var club := _club(world, club_id)
	if club.is_empty():
		return ERR_DOES_NOT_EXIST
	var manager = TacticsManagerClass.new()
	club["tactic"] = manager.create_tactic(formation, mentality, tempo, pressing)
	InboxServiceClass.new().add_message(world, "tactics", "Tactical plan changed", "%s will now use %s with a %s mentality." % [String(club.get("name", "Club")), formation, mentality])
	return OK

func assign_scout(world: Dictionary, club_id: String, player_id: String) -> Dictionary:
	var scout := _best_staff(world, club_id, "scout")
	if scout.is_empty():
		return {"error":ERR_DOES_NOT_EXIST}
	var player := _player(world, player_id)
	if player.is_empty():
		return {"error":ERR_DOES_NOT_EXIST}
	var assignment := ScoutingServiceClass.new().assign_scout(world, String(scout.id), "player", player_id, int(world.get("day_index", 0)))
	InboxServiceClass.new().add_message(world, "scouting", "Scouting assignment started", "%s has been assigned to scout %s." % [String(scout.get("name", "Scout")), _player_name(player)])
	return assignment

func submit_transfer_offer(world: Dictionary, club_id: String, player_id: String, fee: int, clauses: Dictionary = {}, seed: int = 1) -> Dictionary:
	var buyer := _club(world, club_id)
	var player := _player(world, player_id)
	if buyer.is_empty() or player.is_empty():
		return {"error":ERR_DOES_NOT_EXIST}
	var negotiation = TransferNegotiationClass.new()
	if not negotiation.is_window_open(world, String(world.get("date", ""))):
		return {"error":ERR_UNAVAILABLE,"reason":"transfer_window_closed"}
	if String(player.get("club_id", "")) == club_id:
		return {"error":ERR_INVALID_PARAMETER,"reason":"player_already_at_club"}
	var offer: Dictionary = negotiation.create_offer(world, player, buyer, fee, clauses)
	var status := negotiation.evaluate_offer(world, offer, seed)
	InboxServiceClass.new().add_message(world, "transfers", "Transfer offer %s" % status, "Your offer for %s was %s." % [_player_name(player), status], status == "accepted", [{"id":"negotiate_contract","label":"Negotiate contract"}] if status == "accepted" else [])
	return offer

func shortlist(world: Dictionary, club_id: String, limit: int = 30) -> Array:
	var club := _club(world, club_id)
	if club.is_empty():
		return []
	var candidates: Array = []
	for player in world.get("players", []):
		if String(player.get("club_id", "")) == club_id or bool(player.get("retired", false)):
			continue
		var score := float(player.get("current_ability", 50)) + float(player.get("potential", 50)) * 0.35
		score -= maxf(0.0, float(int(player.get("age", 25)) - 27)) * 2.0
		candidates.append({"player":player,"score":score})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary):
		if is_equal_approx(float(a.score), float(b.score)):
			return String(a.player.id) < String(b.player.id)
		return float(a.score) > float(b.score)
	)
	var result: Array = []
	for i in range(mini(limit, candidates.size())):
		result.append(candidates[i].player)
	return result

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return club
	return {}

func _player(world: Dictionary, player_id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == player_id:
			return player
	return {}

func _best_staff(world: Dictionary, club_id: String, role: String) -> Dictionary:
	var best := {}
	for member in world.get("staff", []):
		if String(member.get("club_id", "")) != club_id or String(member.get("role", "")) != role:
			continue
		if best.is_empty() or int(member.get("ability", 0)) > int(best.get("ability", 0)):
			best = member
	return best

func _player_name(player: Dictionary) -> String:
	if player.has("name"):
		return String(player.name)
	return (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()
