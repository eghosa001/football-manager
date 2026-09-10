class_name CareerCycle
extends RefCounted

const SeasonRunnerClass = preload("res://application/season/season_runner.gd")
const LifecycleClass = preload("res://simulation/players/player_lifecycle.gd")
const MarketClass = preload("res://simulation/transfers/transfer_market.gd")
const EconomyClass = preload("res://simulation/finance/club_economy.gd")
const TacticsClass = preload("res://simulation/tactics/tactics_manager.gd")
const LivingWorldClass = preload("res://simulation/world/living_world.gd")

var _season_runner = SeasonRunnerClass.new()
var _lifecycle = LifecycleClass.new()
var _market = MarketClass.new()
var _economy = EconomyClass.new()
var _tactics = TacticsClass.new()
var _living_world = LivingWorldClass.new()

func complete_year(world: Dictionary, history: Array, season_seed: int, promotion_places: int = 3) -> Dictionary:
	_tactics.ensure_world(world, season_seed + 600_001)
	_living_world.ensure_world(world)
	for club in world.clubs:
		_tactics.train_tactic(club, 8)
	var season_result: Dictionary = _season_runner.complete_and_rollover(world, history, season_seed, promotion_places)
	var completed_year: int = int(season_result.next_season_year) - 1
	var economy_result: Dictionary = _economy.run_season_finances(world, completed_year, season_result.records)
	var next_year: int = int(season_result.next_season_year)
	var loans_returned: int = _market.return_expired_loans(world, next_year)
	var lifecycle_result: Dictionary = _lifecycle.advance_year(world, season_seed + 700_001, 2)
	var contract_result: Dictionary = _market.process_contracts(world, next_year, season_seed + 700_003)
	var squad_result: Dictionary = _market.rebalance_ai_squads(world, next_year, season_seed + 700_007, 20, 30)
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
	var living_result: Dictionary = _living_world.advance_year(world, season_result.records, season_seed + 900_001)
	return {
		"season": season_result,
		"economy": economy_result,
		"lifecycle": lifecycle_result,
		"contracts": contract_result,
		"squads": squad_result,
		"living_world": living_result,
		"loans_returned": loans_returned,
		"season_year": next_year,
	}

func _competition_for_club(competitions: Array, club_id: String) -> Dictionary:
	for competition in competitions:
		if club_id in competition.club_ids:
			return competition
	return {}
