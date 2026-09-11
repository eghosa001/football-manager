class_name CareerMatchdayService
extends RefCounted

const SeasonRunnerClass = preload("res://application/season/season_runner.gd")
const AbstractMatchEngineClass = preload("res://simulation/match/abstract_match_engine.gd")
const TacticalMatchEngineClass = preload("res://simulation/match/tactical_match_engine.gd")
const FullMatchEngineV2Class = preload("res://simulation/match/full_match_engine_v2.gd")
const AggregateMatchEngineClass = preload("res://simulation/match/background_aggregate_engine.gd")
const SimulationTierPolicyClass = preload("res://application/performance/simulation_tier_policy.gd")
const DomainEventBusClass = preload("res://core/events/domain_event_bus.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")
const PlayerStatsServiceClass = preload("res://application/career/player_stats_service.gd")
const MedicalSystemClass = preload("res://simulation/players/medical_system.gd")
const DressingRoomClass = preload("res://simulation/players/dressing_room.gd")
const KnockoutSeasonClass = preload("res://application/season/knockout_season.gd")
const RegistrationServiceClass = preload("res://simulation/competitions/registration_service.gd")
const MatchFactorsClass = preload("res://simulation/match/match_factors.gd")

const CONTINUOUS_ENGINE_PATH := "res://simulation/match/continuous_full_match_engine.gd"

var _abstract = AbstractMatchEngineClass.new()
var _tactical = TacticalMatchEngineClass.new()
var _aggregate = AggregateMatchEngineClass.new()
var _tier_policy = SimulationTierPolicyClass.new()
var _events = DomainEventBusClass.new()
var _medical = MedicalSystemClass.new()
var _detailed = FullMatchEngineV2Class.new()
var _continuous = null
var _continuous_attempted := false
var _stats = PlayerStatsServiceClass.new()
var _knockout = KnockoutSeasonClass.new()
var _registration = RegistrationServiceClass.new()
var _club_index: Dictionary = {}
var _player_index: Dictionary = {}
var _competition_index: Dictionary = {}

func play_date(world: Dictionary, date_string: String, managed_club_id: String, season_seed: int) -> Array:
	SeasonRunnerClass.new().assign_fixture_dates(world)
	_build_indexes(world)
	_events.ensure_world(world)
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
		var match_context := _match_context(world, fixture, home, away)
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
				result = _detailed.simulate_match(home, away, eligible_players, match_seed, match_context)
				_detailed.apply_to_fixture(fixture, result)
				detailed_model = "persistent_action_v2"
			if not result.has("error"):
				world["last_managed_match"] = {"fixture": fixture.duplicate(true), "result": result.duplicate(true), "date": date_string, "model": detailed_model, "simulation_tier": tier}
				_add_match_message(world, home, away, result, managed_club_id)
		elif tier == SimulationTierPolicyClass.DETAILED_LEAGUE:
			result = _tactical.simulate_match(home, away, eligible_players, match_seed, match_context)
			_tactical.apply_to_fixture(fixture, result)
		elif tier == SimulationTierPolicyClass.BACKGROUND_LEAGUE:
			result = _abstract.simulate_match(home, away, eligible_players, match_seed, match_context)
			_abstract.apply_to_fixture(fixture, result)
		else:
			result = _aggregate.simulate_match(home, away, [], match_seed)
			_aggregate.apply_to_fixture(fixture, result)
		if not result.has("error"):
			_stats.record_match(world, fixture, result)
			_apply_dressing_room_result(world, home, away, result)
			_update_club_form(world, home, away, result)
			if tier != SimulationTierPolicyClass.INACTIVE_WORLD:
				result["injuries"] = _apply_match_injuries(world, fixture, result, tier, match_seed, managed_club_id)
			_emit_match_events(world, fixture, result, tier, detailed_model, date_string)
		results.append({"fixture":fixture,"result":result,"match_seed":match_seed,"detailed":is_managed,"model":detailed_model,"simulation_tier":tier})
		touched_competitions[competition_id] = true
	for competition_id in touched_competitions.keys():
		_knockout.advance_ready(world, String(competition_id), date_string)
	world["date"] = date_string
	return results

func _apply_match_injuries(world: Dictionary, fixture: Dictionary, result: Dictionary, tier: int, match_seed: int, managed_club_id: String) -> Array:
	var injuries: Array = []
	var participants: Dictionary = result.get("participants", result.get("lineups", {}))
	var surface := _pitch_surface(_club(world, String(fixture.get("home_club_id", ""))))
	var match_intensity := 1.0 if tier == SimulationTierPolicyClass.USER_LEAGUE else (0.82 if tier == SimulationTierPolicyClass.DETAILED_LEAGUE else 0.64)
	var final_frame: Dictionary = {}
	var frames: Array = result.get("spatial", {}).get("frames", [])
	if not frames.is_empty():
		final_frame = frames[frames.size()-1]
	for side in ["home","away"]:
		var loads: Dictionary = final_frame.get("home_loads" if side=="home" else "away_loads", {})
		for player_id in participants.get(side, []):
			var player := _player(world, String(player_id))
			if player.is_empty() or int(player.get("injured_days",0)) > 0:
				continue
			var load: Dictionary = loads.get(String(player_id), {})
			var energy := clampf(float(load.get("energy",1.0)),0.0,1.0)
			var fatigue := maxf(maxf(float(player.get("fatigue", 0)), (1.0 - energy) * 100.0), 100.0 - float(player.get("fitness", 100)))
			var context := {"fatigue":fatigue,"match_intensity":match_intensity,"training_load":0.0,"surface":surface,"base_risk":0.0035}
			var injury := _medical.maybe_suffer_injury(player, match_seed + _stable_key(String(player_id)), "match", context)
			if not bool(injury.get("injured",false)):
				continue
			var row := {"player_id":String(player_id),"club_id":String(player.get("club_id","")),"injury":String(injury.get("name","injury")),"severity":String(injury.get("severity","moderate")),"days_total":int(injury.get("days_total",0)),"surface":surface}
			injuries.append(row)
			_events.emit(world, "PLAYER_INJURED", row, "match_medical")
			if String(player.get("club_id","")) == managed_club_id:
				InboxServiceClass.new().add_message(world, "medical", "%s injured" % _player_name(player), "%s suffered a %s during the match. The medical team will provide a recovery range." % [_player_name(player), String(injury.get("name","injury"))])
	return injuries

func _emit_match_events(world: Dictionary, fixture: Dictionary, result: Dictionary, tier: int, model: String, date_string: String) -> void:
	var common := {
		"fixture_id":String(fixture.get("id", "")),"competition_id":String(fixture.get("competition_id", "")),
		"home_club_id":String(fixture.get("home_club_id", "")),"away_club_id":String(fixture.get("away_club_id", "")),
		"date":date_string,"simulation_tier":tier,"model":model,
	}
	var finished := common.duplicate(true)
	finished["home_goals"] = int(result.get("home_goals", 0))
	finished["away_goals"] = int(result.get("away_goals", 0))
	finished["stats"] = result.get("stats", {}).duplicate(true)
	finished["injuries"] = result.get("injuries", []).duplicate(true)
	_events.emit(world, "MATCH_FINISHED", finished, "career_matchday")
	for match_event in result.get("events", []):
		var is_goal := (String(match_event.get("type", "")) == "shot" and String(match_event.get("outcome", "")) == "goal") or String(match_event.get("type", "")) == "goal"
		if not is_goal:
			continue
		var goal := common.duplicate(true)
		goal["minute"] = int(match_event.get("minute", 0))
		goal["side"] = String(match_event.get("side", ""))
		goal["player_id"] = String(match_event.get("player_id", ""))
		goal["xg"] = float(match_event.get("xg", 0.0))
		_events.emit(world, "GOAL_SCORED", goal, "match_engine")

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

func _match_context(world: Dictionary, fixture: Dictionary, home: Dictionary, away: Dictionary) -> Dictionary:
	var competition := _competition(world, String(fixture.get("competition_id", "")))
	var importance := MatchFactorsClass.new().importance_for(competition, fixture)
	var stage := ""
	if bool(fixture.get("knockout", false)):
		var round_number := int(fixture.get("round", 1))
		stage = "knockout_r%d" % round_number
	return {
		"is_home": true,
		"importance": float(importance.get("importance", 0.5)),
		"competition_label": String(importance.get("label", "league")),
		"stage": stage,
		"derby": String(home.get("country_id", "")) != "" and String(home.get("country_id", "")) == String(away.get("country_id", "")),
		"competition_id": String(fixture.get("competition_id", "")),
	}

func _update_club_form(world: Dictionary, home: Dictionary, away: Dictionary, result: Dictionary) -> void:
	var hg := int(result.get("home_goals", 0))
	var ag := int(result.get("away_goals", 0))
	_push_form_result(home, "W" if hg > ag else ("D" if hg == ag else "L"))
	_push_form_result(away, "W" if ag > hg else ("D" if ag == hg else "L"))

func _push_form_result(club: Dictionary, outcome: String) -> void:
	if not club.has("recent_results") or not club.get("recent_results") is Array:
		club["recent_results"] = []
	var recent: Array = club.recent_results
	recent.append(outcome)
	while recent.size() > 5: recent.pop_front()
	var points := 0.0
	for r in recent:
		if String(r) == "W": points += 3.0
		elif String(r) == "D": points += 1.0
	club["form_points"] = snappedf(points * (5.0 / maxf(1.0, float(recent.size()))) * 1.5, 0.01)

func _pitch_surface(club: Dictionary) -> String:
	var quality := int(club.get("stadium",{}).get("pitch_quality",75))
	if quality < 40:
		return "poor"
	if quality < 58:
		return "hard"
	return "good"

func _build_indexes(world: Dictionary) -> void:
	_club_index.clear()
	_player_index.clear()
	_competition_index.clear()
	for club in world.get("clubs", []):
		var id := String(club.get("id", ""))
		if id != "":
			_club_index[id] = club
	for player in world.get("players", []):
		var id := String(player.get("id", ""))
		if id != "":
			_player_index[id] = player
	for competition in world.get("competitions", []):
		var id := String(competition.get("id", ""))
		if id != "":
			_competition_index[id] = competition

func _player(world: Dictionary, player_id: String) -> Dictionary:
	if _player_index.has(player_id):
		return _player_index[player_id]
	for player in world.get("players", []):
		if String(player.get("id", "")) == player_id:
			_player_index[player_id] = player
			return player
	return {}

func _player_name(player: Dictionary) -> String:
	var value := String(player.get("name", "")).strip_edges()
	return value if value != "" else (String(player.get("first_name", "")) + " " + String(player.get("last_name", ""))).strip_edges()

func _club(world: Dictionary, club_id: String) -> Dictionary:
	if _club_index.has(club_id):
		return _club_index[club_id]
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			_club_index[club_id] = club
			return club
	return {}

func _competition(world: Dictionary, competition_id: String) -> Dictionary:
	if _competition_index.has(competition_id):
		return _competition_index[competition_id]
	for competition in world.get("competitions", []):
		if String(competition.get("id", "")) == competition_id:
			_competition_index[competition_id] = competition
			return competition
	return {}

func _stable_key(text: String) -> int:
	var value := 89
	for character in text.to_utf8_buffer():
		value = posmod(value * 191 + int(character), 2_147_483_647)
	return value

func _fixture_seed(season_seed: int, fixture_id: String) -> int:
	var value := season_seed
	for character in fixture_id.to_utf8_buffer():
		value = posmod(value * 31 + int(character), 2_147_483_647)
	return value if value != 0 else 1
