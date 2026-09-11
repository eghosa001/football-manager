class_name DailyServices
extends RefCounted

const TrainingSystemClass = preload("res://simulation/players/training_system.gd")
const MedicalSystemClass = preload("res://simulation/players/medical_system.gd")
const ScoutingServiceClass = preload("res://simulation/scouting/scouting_service.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")
const DressingRoomClass = preload("res://simulation/players/dressing_room.gd")
const PlayerPromisesClass = preload("res://simulation/players/player_promises.gd")
const PlayerHappinessClass = preload("res://simulation/players/player_happiness.gd")

func run(world: Dictionary, managed_club_id: String, seed: int) -> Dictionary:
	world["day_index"] = int(world.get("day_index", 0)) + 1
	var day_index: int = int(world.day_index)
	var medical := _advance_medical(world, managed_club_id)
	var training := []
	var happiness := {}
	if day_index % 7 == 0:
		training = _run_training_week(world, managed_club_id, seed + day_index * 101)
	var scouting := _advance_scouting(world, managed_club_id, seed + day_index * 211)
	_reconcile_training_injuries(world, managed_club_id, seed + day_index * 307)
	var promises: Array = PlayerPromisesClass.new().evaluate(world)
	for outcome in promises:
		var player := _player(world.get("players", []), String(outcome.player_id))
		if not player.is_empty() and String(player.get("club_id", "")) == managed_club_id:
			InboxServiceClass.new().add_message(world, "dressing_room", "Promise %s" % ("kept" if bool(outcome.fulfilled) else "broken"), "%s's promise has been %s." % [_player_name(player), "fulfilled" if bool(outcome.fulfilled) else "broken"])
	if day_index % 7 == 0:
		# Build atmosphere first so squad-harmony happiness uses the latest room.
		for club in world.get("clubs", []):
			DressingRoomClass.new().rebuild(world, String(club.get("id", "")))
		happiness = PlayerHappinessClass.new().update_week(world)
		var managed_concerns := 0
		for player in world.get("players", []):
			if String(player.get("club_id", "")) == managed_club_id and float(player.get("happiness", 65.0)) < 40.0:
				managed_concerns += 1
		if managed_concerns > 0:
			InboxServiceClass.new().add_message(world, "dressing_room", "Player happiness concerns", "%d first-team players have significant happiness concerns. Review Dynamics for the causes." % managed_concerns)
	return {"day_index":day_index,"medical":medical,"training":training,"scouting":scouting,"promises":promises,"happiness":happiness}

func _advance_medical(world: Dictionary, managed_club_id: String) -> Array:
	var medical_system = MedicalSystemClass.new()
	var updates: Array = []
	var physios: Dictionary = {}
	for member in world.get("staff", []):
		if String(member.get("role", "")) != "physio": continue
		var club_id := String(member.get("club_id", ""))
		physios[club_id] = maxi(int(physios.get(club_id, 50)), int(member.get("ability", 50)))
	for player in world.get("players", []):
		if bool(player.get("retired", false)): continue
		var was_injured := int(player.get("injured_days", 0)) > 0
		var physio_quality := int(physios.get(String(player.get("club_id", "")), 50))
		var result: Dictionary = medical_system.advance_day(player, physio_quality, 0.65)
		if bool(result.get("recovered", false)):
			updates.append({"player_id":String(player.get("id", "")),"type":"recovered"})
			if String(player.get("club_id", "")) == managed_club_id:
				InboxServiceClass.new().add_message(world, "medical", "%s returns to training" % _player_name(player), "The medical team has cleared the player to return to training.")
		elif was_injured and int(player.get("injured_days", 0)) > 0:
			updates.append({"player_id":String(player.get("id", "")),"type":"rehab","days_remaining":int(player.get("injured_days", 0))})
	return updates

func _run_training_week(world: Dictionary, managed_club_id: String, seed: int) -> Array:
	var system = TrainingSystemClass.new()
	var reports: Array = []
	for club in world.get("clubs", []):
		var club_id := String(club.get("id", ""))
		var report: Dictionary = system.run_week(world, club_id, seed + _stable_key(club_id))
		reports.append({"club_id":club_id,"report":report})
		if club_id == managed_club_id:
			InboxServiceClass.new().add_message(world, "training", "Weekly training report", "Players improved: %d. Individual focus gains: %d. Training injuries: %d." % [int(report.get("players_improved", 0)), int(report.get("individual_focus_gains", 0)), int(report.get("training_injuries", 0))])
	return reports

func _advance_scouting(world: Dictionary, managed_club_id: String, seed: int) -> Array:
	var service = ScoutingServiceClass.new()
	service.ensure_world(world)
	var updates: Array = []
	for assignment in world.get("scout_assignments", []):
		if bool(assignment.get("complete", false)): continue
		var scout: Dictionary = _staff(world.get("staff", []), String(assignment.get("scout_id", "")))
		var ability := int(scout.get("ability", 50))
		var before := bool(assignment.get("complete", false))
		service.advance_assignment(world, assignment, 1, ability, seed + _stable_key(String(assignment.get("id", ""))))
		updates.append(assignment.duplicate(true))
		if not before and bool(assignment.get("complete", false)) and String(scout.get("club_id", "")) == managed_club_id:
			InboxServiceClass.new().add_message(world, "scouting", "Scout report completed", "A scouting assignment has been completed for %s." % String(assignment.get("target_id", "target")))
	return updates

func _reconcile_training_injuries(world: Dictionary, managed_club_id: String, seed: int) -> void:
	var medical_system = MedicalSystemClass.new()
	for player in world.get("players", []):
		if int(player.get("injured_days", 0)) <= 0: continue
		medical_system.ensure_player(player)
		if not Dictionary(player.medical.get("current", {})).is_empty(): continue
		var injury: Dictionary = medical_system.suffer_injury(player, seed + _stable_key(String(player.get("id", ""))), "training")
		if String(player.get("club_id", "")) == managed_club_id:
			InboxServiceClass.new().add_message(world, "medical", "%s injured" % _player_name(player), "%s suffered a %s and is expected to miss about %d days." % [_player_name(player), String(injury.get("name", "injury")), int(injury.get("days_total", 0))])

func _physio_quality(staff: Array, club_id: String) -> int:
	var best := 50
	for member in staff:
		if String(member.get("club_id", "")) == club_id and String(member.get("role", "")) == "physio": best = maxi(best, int(member.get("ability", 50)))
	return best

func _staff(staff: Array, id: String) -> Dictionary:
	for member in staff:
		if String(member.get("id", "")) == id: return member
	return {}

func _player(players: Array, id: String) -> Dictionary:
	for player in players:
		if String(player.get("id", "")) == id: return player
	return {}

func _player_name(player: Dictionary) -> String:
	if player.has("name"): return String(player.name)
	return (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()

func _stable_key(text: String) -> int:
	var value := 79
	for character in text.to_utf8_buffer(): value = posmod(value * 181 + int(character), 2_147_483_647)
	return value
