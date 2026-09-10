class_name CareerCycle
extends RefCounted

const SeasonRunnerClass = preload("res://application/season/season_runner.gd")
const LifecycleClass = preload("res://simulation/players/player_lifecycle.gd")
const MarketClass = preload("res://simulation/transfers/transfer_market.gd")

var _season_runner = SeasonRunnerClass.new()
var _lifecycle = LifecycleClass.new()
var _market = MarketClass.new()

func complete_year(world: Dictionary, history: Array, season_seed: int, promotion_places: int = 3) -> Dictionary:
	var season_result: Dictionary = _season_runner.complete_and_rollover(world, history, season_seed, promotion_places)
	var next_year: int = int(season_result.next_season_year)
	var loans_returned: int = _market.return_expired_loans(world, next_year)
	var lifecycle_result: Dictionary = _lifecycle.advance_year(world, season_seed + 700_001, 2)
	var contract_result: Dictionary = _market.process_contracts(world, next_year, season_seed + 700_003)
	var squad_result: Dictionary = _market.rebalance_ai_squads(world, next_year, season_seed + 700_007, 20, 30)
	return {
		"season": season_result,
		"lifecycle": lifecycle_result,
		"contracts": contract_result,
		"squads": squad_result,
		"loans_returned": loans_returned,
		"season_year": next_year,
	}
