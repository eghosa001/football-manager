class_name CareerCycle
extends RefCounted

const SeasonRunnerClass = preload("res://application/season/season_runner.gd")
const LifecycleClass = preload("res://simulation/players/player_lifecycle.gd")
const MarketClass = preload("res://simulation/transfers/transfer_market.gd")
const EconomyClass = preload("res://simulation/finance/club_economy.gd")
const TacticsClass = preload("res://simulation/tactics/tactics_manager.gd")
const LivingWorldClass = preload("res://simulation/world/living_world.gd")
const StaffMarketClass = preload("res://simulation/staff/staff_market.gd")
const StaffContractsClass = preload("res://simulation/staff/staff_contracts.gd")
const InternationalSeasonClass = preload("res://application/season/international_season.gd")
const RegistrationServiceClass = preload("res://simulation/competitions/registration_service.gd")

var _season_runner = SeasonRunnerClass.new()
var _lifecycle = LifecycleClass.new()
var _market = MarketClass.new()
var _economy = EconomyClass.new()
var _tactics = TacticsClass.new()
var _living_world = LivingWorldClass.new()
var _staff_market = StaffMarketClass.new()
var _staff_contracts = StaffContractsClass.new()
var _international = InternationalSeasonClass.new()
var _registration = RegistrationServiceClass.new()

func complete_year(world: Dictionary, history: Array, season_seed: int, promotion_places: int = 3) -> Dictionary:
	_tactics.ensure_world(world, season_seed + 600_001)
	_living_world.ensure_world(world)
	_staff_market.ensure_world(world)
	_staff_contracts.ensure_world(world)
	for club in world.clubs: _tactics.train_tactic(club, 8)
	var season_result: Dictionary = _season_runner.complete_and_rollover(world, history, season_seed, promotion_places)
	var completed_year: int = int(season_result.next_season_year) - 1
	var manager_market_result: Dictionary = _process_ai_manager_market(world, season_result.records, completed_year)
	var economy_result: Dictionary = _economy.run_season_finances(world, completed_year, season_result.records)
	var next_year: int = int(season_result.next_season_year)
	var loans_returned: int = _market.return_expired_loans(world, next_year)
	var lifecycle_result: Dictionary = _lifecycle.advance_year(world, season_seed + 700_001, 2)
	var contract_result: Dictionary = _market.process_contracts(world, next_year, season_seed + 700_003)
	var staff_contract_result: Dictionary = _staff_contracts.process_expiring(world, next_year)
	var squad_result: Dictionary = _market.rebalance_ai_squads(world, next_year, season_seed + 700_007, 20, 30)
	var registration_result: Dictionary = _registration.auto_register_world(world, next_year)
	for club in world.clubs:
		var competition: Dictionary = _competition_for_club(world.competitions, String(club.id))
		var opponent_id := ""
		if not competition.is_empty():
			for other_id in competition.club_ids:
				if String(other_id) != String(club.id): opponent_id = String(other_id); break
		if opponent_id != "": club.tactic = _tactics.ai_choose_tactic(world, String(club.id), opponent_id, season_seed + 800_001 + next_year)
	var international_result: Dictionary = _international.run_year(world, completed_year, season_seed + 850_001)
	world["international_history"] = world.get("international_history", [])
	world.international_history.append({"year":completed_year,"champion_country_id":String(international_result.get("champion", "")),"qualified":international_result.get("qualified", []).duplicate()})
	var living_result: Dictionary = _living_world.advance_year(world, season_result.records, season_seed + 900_001)
	return {"season":season_result,"economy":economy_result,"lifecycle":lifecycle_result,"contracts":contract_result,"staff_contracts":staff_contract_result,"squads":squad_result,"registrations":registration_result,"living_world":living_result,"manager_market":manager_market_result,"international":international_result,"loans_returned":loans_returned,"season_year":next_year}

func _process_ai_manager_market(world: Dictionary, records: Array, year: int) -> Dictionary:
	var human_club_id := String(world.get("human_manager", {}).get("club_id", ""))
	var sacked: Array = []; var hired: Array = []
	for club in world.get("clubs", []):
		var club_id := String(club.get("id", ""))
		if club_id == human_club_id: continue
		var ppg := _season_ppg(records, club_id); var patience := int(club.get("board", {}).get("patience", 50))
		var security: Dictionary = _staff_market.evaluate_manager_security(world, club_id, ppg, patience)
		if String(security.get("status", "secure")) == "critical" and _staff_market.sack_manager(world, club_id, "poor_results", year) == OK: sacked.append(club_id)
	for club_id in sacked:
		var options: Array = _staff_market.candidates(world, String(club_id), 8)
		if options.is_empty(): continue
		var candidate_id := String(options[0].staff_id)
		if _staff_market.hire_manager(world, String(club_id), candidate_id, year) == OK: hired.append({"club_id":String(club_id),"staff_id":candidate_id})
	return {"sacked":sacked,"hired":hired}

func _season_ppg(records: Array, club_id: String) -> float:
	for record in records:
		if String(record.get("competition_type", "league")) != "league": continue
		for row in record.get("table", []):
			if String(row.get("club_id", "")) == club_id:
				return float(row.get("points", 0)) / float(maxi(1, int(row.get("played",0))))
	return 1.2

func _competition_for_club(competitions: Array, club_id: String) -> Dictionary:
	for competition in competitions:
		if String(competition.get("competition_type", "league")) == "league" and club_id in competition.club_ids: return competition
	return {}
