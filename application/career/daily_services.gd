class_name DailyServices
extends RefCounted

const TrainingSystemClass = preload("res://simulation/players/training_system.gd")
const MedicalSystemClass = preload("res://simulation/players/medical_system.gd")
const ScoutingServiceClass = preload("res://simulation/scouting/scouting_service.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")
const DressingRoomClass = preload("res://simulation/players/dressing_room.gd")
const PlayerPromisesClass = preload("res://simulation/players/player_promises.gd")
const PlayerHappinessClass = preload("res://simulation/players/player_happiness.gd")
const DomainEventBusClass = preload("res://core/events/domain_event_bus.gd")
const EventNewsServiceClass = preload("res://application/career/event_news_service.gd")

var _events = DomainEventBusClass.new()
var _news = EventNewsServiceClass.new()

func run(world: Dictionary, managed_club_id: String, seed: int) -> Dictionary:
	_events.ensure_world(world)
	world["day_index"] = int(world.get("day_index", 0)) + 1
	var day_index: int = int(world.day_index)

	# Build the small indexes once per Continue. Several daily systems used to
	# linearly search the full staff/player arrays again for every assignment or
	# promise outcome, which becomes very visible on mobile-sized CPUs.
	var staff_by_id: Dictionary = {}
	var physios_by_club: Dictionary = {}
	for member in world.get("staff", []):
		var staff_id := String(member.get("id", ""))
		if staff_id != "": staff_by_id[staff_id] = member
		if String(member.get("role", "")) == "physio":
			var club_id := String(member.get("club_id", ""))
			physios_by_club[club_id] = maxi(int(physios_by_club.get(club_id, 50)), int(member.get("ability", 50)))

	var medical := _advance_medical(world, managed_club_id, physios_by_club)
	var training := []
	var happiness := {}
	if day_index % 7 == 0:
		training = _run_training_week(world, managed_club_id, seed + day_index * 101)
	var scouting := _advance_scouting(world, managed_club_id, seed + day_index * 211, staff_by_id)
	_reconcile_training_injuries(world, managed_club_id, seed + day_index * 307)

	var promises: Array = PlayerPromisesClass.new().evaluate(world)
	if not promises.is_empty():
		var players_by_id: Dictionary = {}
		for player in world.get("players", []):
			var player_id := String(player.get("id", ""))
			if player_id != "": players_by_id[player_id] = player
		for outcome in promises:
			var player: Dictionary = players_by_id.get(String(outcome.player_id), {})
			_events.emit(world, "PROMISE_RESOLVED", {"promise_id":String(outcome.promise_id),"player_id":String(outcome.player_id),"fulfilled":bool(outcome.fulfilled),"club_id":String(player.get("club_id", ""))}, "player_promises")
			if not player.is_empty() and String(player.get("club_id", "")) == managed_club_id:
				InboxServiceClass.new().add_message(world, "dressing_room", "Promise %s" % ("kept" if bool(outcome.fulfilled) else "broken"), "%s's promise has been %s." % [_player_name(player), "fulfilled" if bool(outcome.fulfilled) else "broken"])

	if day_index % 7 == 0:
		# One player grouping pass for the entire world instead of rebuilding each
		# club room with a fresh full-world player scan.
		DressingRoomClass.new().rebuild_all(world)
		happiness = PlayerHappinessClass.new().update_week(world)
		var managed_concerns := 0
		for player in world.get("players", []):
			if String(player.get("club_id", "")) == managed_club_id and float(player.get("happiness", 65.0)) < 40.0:
				managed_concerns += 1
		if managed_concerns > 0:
			InboxServiceClass.new().add_message(world, "dressing_room", "Player happiness concerns", "%d first-team players have significant happiness concerns. Review Dynamics for the causes." % managed_concerns)
	var news_result := _news.consume(world)
	return {"day_index":day_index,"medical":medical,"training":training,"scouting":scouting,"promises":promises,"happiness":happiness,"news":news_result}

func _advance_medical(world: Dictionary, managed_club_id: String, physios: Dictionary) -> Array:
	var medical_system = MedicalSystemClass.new()
	var updates: Array = []
	for player in world.get("players", []):
		if bool(player.get("retired", false)): continue
		var was_injured := int(player.get("injured_days", 0)) > 0
		var physio_quality := int(physios.get(String(player.get("club_id", "")), 50))
		var result: Dictionary = medical_system.advance_day(player, physio_quality, 0.65)
		if bool(result.get("recovered", false)):
			var recovery := {"player_id":String(player.get("id", "")),"club_id":String(player.get("club_id", "")),"type":"recovered"}
			updates.append(recovery)
			_events.emit(world, "PLAYER_RECOVERED", recovery, "medical")
			if String(player.get("club_id", "")) == managed_club_id:
				InboxServiceClass.new().add_message(world, "medical", "%s returns to training" % _player_name(player), "The medical team has cleared the player to return to training.")
		elif was_injured and int(player.get("injured_days", 0)) > 0:
			updates.append({"player_id":String(player.get("id", "")),"type":"rehab","days_remaining":int(player.get("injured_days", 0))})
	return updates

func _run_training_week(world: Dictionary, managed_club_id: String, seed: int) -> Array:
	var system = TrainingSystemClass.new()
	var reports: Array = []
	var players_by_club := {}
	var staff_by_club := {}
	for player in world.get("players", []):
		var player_club_id := String(player.get("club_id", ""))
		if player_club_id == "": continue
		if not players_by_club.has(player_club_id): players_by_club[player_club_id] = []
		players_by_club[player_club_id].append(player)
	for member in world.get("staff", []):
		var staff_club_id := String(member.get("club_id", ""))
		if staff_club_id == "": continue
		if not staff_by_club.has(staff_club_id): staff_by_club[staff_club_id] = []
		staff_by_club[staff_club_id].append(member)
	for club in world.get("clubs", []):
		var club_id := String(club.get("id", ""))
		var report: Dictionary = system.run_week(world, club_id, seed + _stable_key(club_id), players_by_club.get(club_id, []), staff_by_club.get(club_id, []))
		reports.append({"club_id":club_id,"report":report})
		if club_id == managed_club_id:
			InboxServiceClass.new().add_message(world, "training", "Weekly training report", "Players improved: %d. Individual focus gains: %d. Training injuries: %d." % [int(report.get("players_improved", 0)), int(report.get("individual_focus_gains", 0)), int(report.get("training_injuries", 0))])
	return reports

func _advance_scouting(world: Dictionary, managed_club_id: String, seed: int, staff_by_id: Dictionary) -> Array:
	var service = ScoutingServiceClass.new()
	service.ensure_world(world)
	var updates: Array = []
	for assignment in world.get("scout_assignments", []):
		if bool(assignment.get("complete", false)): continue
		var scout: Dictionary = staff_by_id.get(String(assignment.get("scout_id", "")), {})
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
		_events.emit(world, "PLAYER_INJURED", {"player_id":String(player.get("id", "")),"club_id":String(player.get("club_id", "")),"injury":String(injury.get("name", "injury")),"days_total":int(injury.get("days_total", 0)),"source":"training"}, "medical")
		if String(player.get("club_id", "")) == managed_club_id:
			InboxServiceClass.new().add_message(world, "medical", "%s injured" % _player_name(player), "%s suffered a %s and is expected to miss about %d days." % [_player_name(player), String(injury.get("name", "injury")), int(injury.get("days_total", 0))])

func _player_name(player: Dictionary) -> String:
	if player.has("name"): return String(player.name)
	return (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()

func _stable_key(text: String) -> int:
	var value := 79
	for character in text.to_utf8_buffer(): value = posmod(value * 181 + int(character), 2_147_483_647)
	return value
