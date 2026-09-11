class_name CareerMatchdayService
extends RefCounted

const SeasonRunnerClass = preload("res://application/season/season_runner.gd")
const AbstractMatchEngineClass = preload("res://simulation/match/abstract_match_engine.gd")
const TacticalMatchEngineClass = preload("res://simulation/match/tactical_match_engine.gd")
const FullMatchEngineV2Class = preload("res://simulation/match/full_match_engine_v2.gd")
const AggregateMatchEngineClass = preload("res://simulation/match/background_aggregate_engine.gd")
const SimulationTierPolicyClass = preload("res://application/performance/simulation_tier_policy.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")
const PlayerStatsServiceClass = preload("res://application/career/player_stats_service.gd")
const DressingRoomClass = preload("res://simulation/players/dressing_room.gd")
const KnockoutSeasonClass = preload("res://application/season/knockout_season.gd")
const RegistrationServiceClass = preload("res://simulation/competitions/registration_service.gd")

const CONTINUOUS_ENGINE_PATH := "res://simulation/match/continuous_full_match_engine.gd"

var _abstract = AbstractMatchEngineClass.new()
var _tactical = TacticalMatchEngineClass.new()
var _aggregate = AggregateMatchEngineClass.new()
var _tier_policy = SimulationTierPolicyClass.new()
var _detailed = FullMatchEngineV2Class.new()
var _continuous = null
var _continuous_attempted := false
var _stats = PlayerStatsServiceClass.new()
var _knockout = KnockoutSeasonClass.new()
var _registration = RegistrationServiceClass.new()

func play_date(world: Dictionary, date_string: String, managed_club_id: String, season_seed: int) -> Array:
	SeasonRunnerClass.new().assign_fixture_dates(world)
	var results: Array = []
	var touched_competitions := {}
	for fixture in world.get("fixtures", []):
		if bool(fixture.get("played", false)) or String(fixture.get("date", "")) != date_string:
			continue
		var home := _club(world, String(fixture.get("home_club_id", "")))
		var away := _club(world, String(fixture.get("away_club_id", "")))
		if home.is_empty() or away.is_empty():
			continue
		var match_seed := _fixture_seed(season_seed, String(fixture.get("id", "")))
		var competition_id := String(fixture.get("competition_id", ""))
		var tier := _tier_policy.tier_for_fixture(world, home, away, managed_club_id, competition_id)
		var is_managed := tier == SimulationTierPolicyClass.USER_LEAGUE
		var eligible_players: Array = []
		if tier != SimulationTierPolicyClass.INACTIVE_WORLD:
			eligible_players = _eligible_match_players(world, String(home.id), String(away.id), competition_id)
		var result: Dictionary
		var detailed_model := _tier_policy.label(tier)
		if is_managed:
			var preferred := String(world.get("detailed_match_model", "continuous"))
			var engine = _continuous_engine() if preferred == "continuous" else null
			if engine != null:
				result = engine.simulate_match(home, away, eligible_players, match_seed)
				if not result.has("error"):
					engine.apply_to_fixture(fixture, result)
					detailed_model = "continuous"
			if engine == null or result.has("error"):
				result = _detailed.simulate_match(home, away, eligible_players, match_seed)
				_detailed.apply_to_fixture(fixture, result)
				detailed_model = "persistent_action_v2"
			if not result.has("error"):
				world["last_managed_match"] = {"fixture":fixture.duplicate(true),"result":result.duplicate(true),"date":date_string,"model":detailed_model,"simulation_tier":tier}
				_add_match_message(world, home, away, result, managed_club_id)
		elif tier == SimulationTierPolicyClass.DETAILED_LEAGUE:
			result = _tactical.simulate_match(home, away, eligible_players, match_seed)
			_tactical.apply_to_fixture(fixture, result)
		elif tier == SimulationTierPolicyClass.BACKGROUND_LEAGUE:
			result = _abstract.simulate_match(home, away, eligible_players, match_seed)
			_abstract.apply_to_fixture(fixture, result)
		else:
			result = _aggregate.simulate_match(home, away, [], match_seed)
			_aggregate.apply_to_fixture(fixture, result)
		if not result.has("error"):
			_stats.record_match(world, fixture, result)
			_apply_dressing_room_result(world, home, away, result)
		results.append({"fixture":fixture,"result":result,"match_seed":match_seed,"detailed":is_managed,"model":detailed_model,"simulation_tier":tier})
		touched_competitions[competition_id] = true
	for competition_id in touched_competitions.keys():
		_knockout.advance_ready(world, String(competition_id), date_string)
	world["date"] = date_string
	return results

func _continuous_engine():
	if _continuous_attempted:
		return _continuous
	_continuous_attempted = true
	if not ResourceLoader.exists(CONTINUOUS_ENGINE_PATH):
		return null
	var script = ResourceLoader.load(CONTINUOUS_ENGINE_PATH)
	if script == null:
		return null
	_continuous = script.new()
	return _continuous

func _eligible_match_players(world: Dictionary, home_id: String, away_id: String, competition_id: String) -> Array:
	var season_year := int(world.get("season_year", 2026))
	var home_registered: Array = _registration.registered_players(world, home_id, competition_id, season_year)
	var away_registered: Array = _registration.registered_players(world, away_id, competition_id, season_year)
	if home_registered.size() < 11 or away_registered.size() < 11:
		var competition := _competition(world, competition_id)
		if not competition.is_empty():
			_registration.auto_register_world(world, season_year)
			home_registered = _registration.registered_players(world, home_id, competition_id, season_year)
			away_registered = _registration.registered_players(world, away_id, competition_id, season_year)
	var combined: Array = []
	combined.append_array(home_registered)
	combined.append_array(away_registered)
	return combined

func _apply_dressing_room_result(world: Dictionary, home: Dictionary, away: Dictionary, result: Dictionary) -> void:
	var room = DressingRoomClass.new()
	var hg := int(result.get("home_goals", 0))
	var ag := int(result.get("away_goals", 0))
	if hg - ag >= 3:
		room.apply_event(world, String(home.id), "big_win")
	elif ag - hg >= 3:
		room.apply_event(world, String(home.id), "heavy_loss")
	if ag - hg >= 3:
		room.apply_event(world, String(away.id), "big_win")
	elif hg - ag >= 3:
		room.apply_event(world, String(away.id), "heavy_loss")

func _add_match_message(world: Dictionary, home: Dictionary, away: Dictionary, result: Dictionary, managed_club_id: String) -> void:
	var managed_home := String(home.id) == managed_club_id
	var gf := int(result.get("home_goals", 0)) if managed_home else int(result.get("away_goals", 0))
	var ga := int(result.get("away_goals", 0)) if managed_home else int(result.get("home_goals", 0))
	var opponent := away if managed_home else home
	var outcome := "draw"
	if gf > ga:
		outcome = "win"
	elif gf < ga:
		outcome = "defeat"
	InboxServiceClass.new().add_message(world, "match", "Match result: %d-%d" % [gf, ga], "%s against %s. Review the match analysis for spatial frames, xG and events." % [outcome.capitalize(), String(opponent.get("name", "opponent"))])

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return club
	return {}

func _competition(world: Dictionary, competition_id: String) -> Dictionary:
	for competition in world.get("competitions", []):
		if String(competition.get("id", "")) == competition_id:
			return competition
	return {}

func _fixture_seed(season_seed: int, fixture_id: String) -> int:
	var value := season_seed
	for character in fixture_id.to_utf8_buffer():
		value = posmod(value * 31 + int(character), 2_147_483_647)
	return value if value != 0 else 1
