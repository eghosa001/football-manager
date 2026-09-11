class_name CareerCycle
extends RefCounted

const SeasonRunnerClass = preload("res://application/season/season_runner.gd")
const LifecycleClass = preload("res://simulation/players/player_lifecycle_v2.gd")
const YouthQualityClass = preload("res://simulation/players/youth_quality_service.gd")
const MarketClass = preload("res://simulation/transfers/transfer_market.gd")
const EconomyClass = preload("res://simulation/finance/club_economy.gd")
const StadiumServiceClass = preload("res://simulation/finance/stadium_service.gd")
const BoardEvaluationClass = preload("res://simulation/finance/board_evaluation.gd")
const TacticsClass = preload("res://simulation/tactics/tactics_manager.gd")
const LivingWorldClass = preload("res://simulation/world/living_world.gd")
const ReputationModelClass = preload("res://simulation/world/reputation_model.gd")
const HistoryRecordServiceClass = preload("res://simulation/world/history_record_service.gd")
const PlayerHappinessClass = preload("res://simulation/players/player_happiness.gd")
const StaffMarketClass = preload("res://simulation/staff/staff_market.gd")
const StaffContractsClass = preload("res://simulation/staff/staff_contracts.gd")
const StaffDevelopmentClass = preload("res://simulation/staff/staff_development.gd")
const InternationalSeasonClass = preload("res://application/season/international_season.gd")
const RegistrationServiceClass = preload("res://simulation/competitions/registration_service.gd")
const NamePoolServiceClass = preload("res://application/career/name_pool_service.gd")
const DomainEventBusClass = preload("res://core/events/domain_event_bus.gd")

var _season_runner = SeasonRunnerClass.new()
var _lifecycle = LifecycleClass.new()
var _youth_quality = YouthQualityClass.new()
var _market = MarketClass.new()
var _economy = EconomyClass.new()
var _stadiums = StadiumServiceClass.new()
var _board = BoardEvaluationClass.new()
var _tactics = TacticsClass.new()
var _living_world = LivingWorldClass.new()
var _reputation = ReputationModelClass.new()
var _history_records = HistoryRecordServiceClass.new()
var _happiness = PlayerHappinessClass.new()
var _staff_market = StaffMarketClass.new()
var _staff_contracts = StaffContractsClass.new()
var _staff_development = StaffDevelopmentClass.new()
var _international = InternationalSeasonClass.new()
var _registration = RegistrationServiceClass.new()
var _names = NamePoolServiceClass.new()
var _events = DomainEventBusClass.new()

func complete_year(world: Dictionary, history: Array, season_seed: int, promotion_places: int = 3) -> Dictionary:
	_events.ensure_world(world)
	_tactics.ensure_world(world, season_seed + 600_001)
	_living_world.ensure_world(world)
	_reputation.ensure_world(world)
	_history_records.ensure_world(world)
	_staff_market.ensure_world(world)
	_staff_contracts.ensure_world(world)
	for club in world.clubs:
		_tactics.train_tactic(club, 8)
	var previous_records: Dictionary = world.history_archive.get("records", {}).duplicate(true)
	var season_result: Dictionary = _season_runner.complete_and_rollover(world, history, season_seed, promotion_places)
	var completed_year: int = int(season_result.next_season_year) - 1
	for record in season_result.records:
		var champion := String(record.get("champion_club_id", ""))
		if champion != "":
			_events.emit(world, "COMPETITION_WON", {"year":completed_year,"competition_id":String(record.get("competition_id","")),"club_id":champion}, "season_runner")
	for movement in season_result.get("movements", []):
		for club_id in movement.get("promoted", []):
			_events.emit(world, "CLUB_PROMOTED", {"year":completed_year,"club_id":String(club_id),"from_competition_id":String(movement.get("lower_competition_id","")),"to_competition_id":String(movement.get("upper_competition_id",""))}, "league_system")
		for club_id in movement.get("relegated", []):
			_events.emit(world, "CLUB_RELEGATED", {"year":completed_year,"club_id":String(club_id),"from_competition_id":String(movement.get("upper_competition_id","")),"to_competition_id":String(movement.get("lower_competition_id",""))}, "league_system")
	var history_result: Dictionary = _history_records.record_season(world, season_result.records, completed_year)
	for key in world.history_archive.records.keys():
		if world.history_archive.records.get(key) != previous_records.get(key):
			_events.emit(world, "RECORD_BROKEN", {"year":completed_year,"record":String(key),"value":world.history_archive.records.get(key)}, "history")
	var economy_result: Dictionary = _economy.run_season_finances(world, completed_year, season_result.records)
	var board_result: Dictionary = _board.evaluate_world(world, season_result.records)
	var manager_market_result: Dictionary = _process_ai_manager_market(world, season_result.records, completed_year)
	var next_year: int = int(season_result.next_season_year)
	var stadium_projects: Array = _stadiums.advance_projects(world, next_year)
	var loans_returned: int = _market.return_expired_loans(world, next_year)
	var lifecycle_result: Dictionary = _lifecycle.advance_year(world, season_seed + 700_001, 2)
	for player_id in lifecycle_result.get("retired", []):
		_events.emit(world, "PLAYER_RETIRED", {"season_year":next_year,"player_id":String(player_id)}, "player_lifecycle")
	_names.rename_youth(world, lifecycle_result.get("youth", []), season_seed + 700_002)
	var youth_quality_result: Dictionary = _youth_quality.apply_to_intake(world, lifecycle_result.get("youth", []), season_seed + 700_002)
	if not lifecycle_result.get("youth", []).is_empty():
		_events.emit(world, "YOUTH_INTAKE", {"season_year":next_year,"player_ids":lifecycle_result.get("youth", []).duplicate(),"count":lifecycle_result.get("youth", []).size(),"elite_prospects":int(youth_quality_result.get("elite_prospects", 0))}, "player_lifecycle")
	var contract_result: Dictionary = _market.process_contracts(world, next_year, season_seed + 700_003)
	var staff_contract_result: Dictionary = _staff_contracts.process_expiring(world, next_year)
	var staff_development_result: Dictionary = _staff_development.advance_year(world, season_result.records, season_seed + 700_005)
	var squad_result: Dictionary = _market.rebalance_ai_squads(world, next_year, season_seed + 700_007, 20, 30)
	var registration_result: Dictionary = _registration.auto_register_world(world, next_year)
	for club in world.clubs:
		var competition: Dictionary = _competition_for_club(world.competitions, String(club.id))
		var opponent_id := ""
		if not competition.is_empty():
			for other_id in competition.club_ids:
				if String(other_id) != String(club.id):
					opponent_id = String(other_id)
					break
		if opponent_id != "":
			club.tactic = _tactics.ai_choose_tactic(world, String(club.id), opponent_id, season_seed + 800_001 + next_year)
	var international_result: Dictionary = _international.run_year(world, completed_year, season_seed + 850_001)
	world["international_history"] = world.get("international_history", [])
	world.international_history.append({"year":completed_year,"champion_country_id":String(international_result.get("champion", "")),"qualified":international_result.get("qualified", []).duplicate()})
	var living_result: Dictionary = _living_world.advance_year(world, season_result.records, season_seed + 900_001)
	var reputation_result: Dictionary = _reputation.advance_year(world, season_result.records)
	var happiness_result: Dictionary = _happiness.update_week(world)
	_events.emit(world, "SEASON_ENDED", {"completed_year":completed_year,"next_year":next_year,"competition_records":season_result.records.duplicate(true),"promotion_movements":season_result.get("movements", []).duplicate(true),"international_champion":String(international_result.get("champion", ""))}, "career_cycle")
	return {"season":season_result,"history_archive":history_result,"economy":economy_result,"board":board_result,"stadium_projects":stadium_projects,"lifecycle":lifecycle_result,"youth_quality":youth_quality_result,"contracts":contract_result,"staff_contracts":staff_contract_result,"staff_development":staff_development_result,"squads":squad_result,"registrations":registration_result,"living_world":living_result,"reputation":reputation_result,"happiness":happiness_result,"manager_market":manager_market_result,"international":international_result,"loans_returned":loans_returned,"season_year":next_year}

func _process_ai_manager_market(world: Dictionary, records: Array, year: int) -> Dictionary:
	var human_club_id := String(world.get("human_manager", {}).get("club_id", ""))
	var sacked: Array = []
	var hired: Array = []
	for club in world.get("clubs", []):
		var club_id := String(club.get("id", ""))
		if club_id == human_club_id:
			continue
		var security: Dictionary = _staff_market.evaluate_manager_security(world, club_id, _season_ppg(records, club_id), int(club.get("board", {}).get("patience", 50)))
		if String(security.get("status", "secure")) == "critical":
			var manager_id := String(security.get("manager_id", ""))
			if _staff_market.sack_manager(world, club_id, "poor_results", year) == OK:
				sacked.append(club_id)
				_events.emit(world, "MANAGER_FIRED", {"manager_id":manager_id,"club_id":club_id,"reason":"poor_results","year":year,"risk":float(security.get("risk",1.0))}, "staff_market")
	for club_id in sacked:
		var options: Array = _staff_market.candidates(world, String(club_id), 8)
		if options.is_empty():
			continue
		var candidate_id := String(options[0].staff_id)
		if _staff_market.hire_manager(world, String(club_id), candidate_id, year) == OK:
			hired.append({"club_id":String(club_id),"staff_id":candidate_id})
			_events.emit(world, "MANAGER_HIRED", {"manager_id":candidate_id,"club_id":String(club_id),"year":year}, "staff_market")
	return {"sacked":sacked,"hired":hired}

func _season_ppg(records: Array, club_id: String) -> float:
	for record in records:
		if String(record.get("competition_type", "league")) != "league":
			continue
		for row in record.get("table", []):
			if String(row.get("club_id", "")) == club_id:
				return float(row.get("points", 0)) / float(maxi(1, int(row.get("played",0))))
	return 1.2

func _competition_for_club(competitions: Array, club_id: String) -> Dictionary:
	for competition in competitions:
		if String(competition.get("competition_type", "league")) == "league" and club_id in competition.club_ids:
			return competition
	return {}
