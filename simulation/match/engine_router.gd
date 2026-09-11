class_name MatchEngineRouter
extends RefCounted

const ContinuousClass = preload("res://simulation/match/continuous_full_match_engine.gd")
const EventClass = preload("res://simulation/match/event_match_engine.gd")
const AbstractClass = preload("res://simulation/match/abstract_match_engine.gd")
const AggregateClass = preload("res://simulation/match/background_aggregate_engine.gd")

const DETAILED := "detailed"
const EVENT := "event"
const ABSTRACT := "abstract"
const AGGREGATE := "aggregate"

var _engines := {
	DETAILED: ContinuousClass.new(),
	EVENT: EventClass.new(),
	ABSTRACT: AbstractClass.new(),
	AGGREGATE: AggregateClass.new(),
}

func simulate(tier: String, home_club: Dictionary, away_club: Dictionary, players: Array, seed: int, context: Dictionary = {}) -> Dictionary:
	var canonical := tier if tier in _engines else ABSTRACT
	var engine = _engines[canonical]
	# Context-aware engines accept (home, away, players, seed, context);
	# legacy engines keep the 4-argument contract.
	var result: Dictionary
	if canonical == EVENT or canonical == ABSTRACT:
		result = engine.simulate_match(home_club, away_club, players, seed, context)
	else:
		result = engine.simulate_match(home_club, away_club, players, seed)
	if result.has("error"): return result
	result["simulation_tier"] = canonical
	result["engine_interface_version"] = 1
	result["legacy_engine"] = canonical != DETAILED
	_normalize_result(result)
	return result

func detailed(home_club: Dictionary, away_club: Dictionary, players: Array, seed: int, context: Dictionary = {}) -> Dictionary:
	return simulate(DETAILED, home_club, away_club, players, seed, context)

func event(home_club: Dictionary, away_club: Dictionary, players: Array, seed: int, context: Dictionary = {}) -> Dictionary:
	return simulate(EVENT, home_club, away_club, players, seed, context)

func abstract(home_club: Dictionary, away_club: Dictionary, players: Array, seed: int, context: Dictionary = {}) -> Dictionary:
	return simulate(ABSTRACT, home_club, away_club, players, seed, context)

func aggregate(home_club: Dictionary, away_club: Dictionary, players: Array, seed: int, _context: Dictionary = {}) -> Dictionary:
	return simulate(AGGREGATE, home_club, away_club, players, seed)

func supported_tiers()->Array:
	return [DETAILED,EVENT,ABSTRACT,AGGREGATE]

func authoritative_engine()->String:
	return DETAILED

func _normalize_result(result:Dictionary)->void:
	result["home_goals"] = int(result.get("home_goals",0))
	result["away_goals"] = int(result.get("away_goals",0))
	result["events"] = result.get("events",[])
	result["stats"] = result.get("stats",{"home":{},"away":{}})
	result["lineups"] = result.get("lineups",{"home":[],"away":[]})
	result["participants"] = result.get("participants",result.lineups.duplicate(true))
