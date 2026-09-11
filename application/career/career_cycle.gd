class_name CareerCycle
extends RefCounted

const SeasonRunnerClass = preload("res://application/season/season_runner.gd")
const LifecycleClass = preload("res://simulation/players/player_lifecycle_service.gd")
const YouthQualityClass = preload("res://simulation/players/youth_quality_service.gd")
const MarketClass = preload("res://simulation/transfers/transfer_market.gd")
const EconomyClass = preload("res://simulation/finance/club_economy.gd")
const StadiumServiceClass = preload("res://simulation/finance/stadium_service.gd")
const BoardEvaluationClass = preload("res://simulation/finance/board_evaluation.gd")
const TacticsClass = preload("res://simulation/tactics/tactics_manager.gd")
const LivingWorldClass = preload("res://simulation/world/living_world.gd")
const LivingWorldDepthClass = preload("res://simulation/world/living_world_depth.gd")
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
var _living_depth = LivingWorldDepthClass.new()
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
	_history_records.enrich_club_context(world, economy_result, completed_year)
	var board_result: Dictionary = _board.evaluate_world(world, season_result.records)
	var manager_market_result: Dictionary = _process_ai_manager_market(world, season_result.records, completed_year)
	var next_year: int = int(season_result.next_season_year)
	var stadium_projects: Array = _stadiums.advance_projects(world, next_year)
	var loans_returned: int = _market.return_expired_loans(world, next_year)
	var lifecycle_result: Dictionary = _lifecycle.advance_year(world, season_seed + 700_001, 2)
	for player_id in lifecycle_result.get("retired", []):
		_events.emit(world, "PLAYER_RETIRED", {"year":completed_year,"player_id":String(player_id)}, "player_lifecycle")
	var youth_result: Dictionary = _youth_quality.generate_intakes(world, season_seed + 710_001, next_year)
	var market_result: Dictionary = _market.simulate_window(world, season_seed + 720_001, next_year)
	var happiness_result: Dictionary = _happiness.advance_world(world, completed_year)
	var staff_result: Dictionary = _staff_development.advance_world(world, completed_year)
	var international_result: Dictionary = _international.advance_year(world, completed_year, season_seed + 730_001)
	_registration.auto_register_world(world, next_year)
	_names.fill_missing_names(world, season_seed + 740_001)
	var living_result: Dictionary = _living_world.advance_year(world, completed_year, season_seed + 750_001)
	var living_depth_result: Dictionary = _living_depth.advance_year(world, completed_year, season_seed + 760_001)
	var reputation_result: Dictionary = _reputation.advance_year(world, completed_year, season_result.records)
	for club in world.clubs:
		var club_id := String(club.get("id", ""))
		var board: Dictionary = club.get("board", {})
		if not board.is_empty() and float(board.get("confidence",50.0)) < 20.0:
			_events.emit(world,"BOARD_CRISIS",{"year":completed_year,"club_id":club_id,"confidence":float(board.get("confidence",50.0))},"board_evaluation")
		if float(club.get("cash",0.0)) < 0.0:
			_events.emit(world,"CLUB_FINANCIAL_STRESS",{"year":completed_year,"club_id":club_id,"cash":float(club.get("cash",0.0))},"club_economy")
	return {
		"season_year":next_year,
		"season":season_result,
		"history":history_result,
		"economy":economy_result,
		"board":board_result,
		"manager_market":manager_market_result,
		"stadium_projects":stadium_projects,
		"loans_returned":loans_returned,
		"lifecycle":lifecycle_result,
		"youth":youth_result,
		"market":market_result,
		"happiness":happiness_result,
		"staff":staff_result,
		"international":international_result,
		"living_world":living_result,
		"living_world_depth":living_depth_result,
		"reputation":reputation_result,
	}

func _process_ai_manager_market(world: Dictionary, season_records: Array, completed_year: int) -> Dictionary:
	var by_club := {}
	for record in season_records:
		var competition_id := String(record.get("competition_id", ""))
		var competition := _competition(world, competition_id)
		if competition.is_empty(): continue
		for row in record.get("table", []): by_club[String(row.get("club_id",""))] = row
	var changes := 0
	for club in world.clubs:
		var club_id := String(club.get("id", ""))
		var manager := _manager_for_club(world, club_id)
		if manager.is_empty(): continue
		var row: Dictionary = by_club.get(club_id,{})
		var position := int(row.get("position",10))
		var points := int(row.get("points",0))
		var board_confidence := float(club.get("board",{}).get("confidence",50.0))
		if position > 14 and points < 42 and board_confidence < 42.0:
			manager.club_id = ""
			manager["employment"] = "unemployed"
			manager["last_club_id"] = club_id
			manager["last_change_year"] = completed_year
			changes += 1
	return {"changes":changes}

func _competition(world: Dictionary, competition_id: String) -> Dictionary:
	for competition in world.competitions:
		if String(competition.get("id","")) == competition_id: return competition
	return {}

func _manager_for_club(world: Dictionary, club_id: String) -> Dictionary:
	for manager in world.get("manager_careers", []):
		if String(manager.get("club_id","")) == club_id: return manager
	return {}
