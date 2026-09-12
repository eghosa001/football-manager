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
var _match_factors = MatchFactorsClass.new()
var _club_index: Dictionary = {}
var _player_index: Dictionary = {}
var _competition_index: Dictionary = {}
var _suspension_index: Dictionary = {}
var _discipline_ban_index: Dictionary = {}
var _yellow_count_index: Dictionary = {}
var _city_index: Dictionary = {}
var _rivalry_index: Dictionary = {}

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

		if result.has("error"):
			continue
		_stats.record_match(world, fixture, result)
		_apply_dressing_room_result(world, home, away, result)
		_apply_match_load(world, result)
		_apply_suspensions(world, fixture, result, date_string)
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
	combined.append_array(_available(home_registered, world))
	combined.append_array(_available(away_registered, world))
	return combined

func _available(players: Array, world: Dictionary) -> Array:
	var result: Array = []
	var day := int(world.get("day_index", 0))
	for player in players:
		if bool(player.get("retired", false)):
			continue
		if int(player.get("injured_days", 0)) > 0:
			continue
		if int(_suspension_index.get(String(player.get("id", "")), 0)) > day:
			continue
		result.append(player)
	return result

func _suspension_map(world: Dictionary) -> Dictionary:
	# Kept for compatibility with direct callers/tests; play_date uses the
	# prebuilt incremental index instead of rebuilding this map per squad.
	var bans := {}
	for row in world.get("suspensions", []):
		bans[String(row.get("player_id", ""))] = int(row.get("until_day", 0))
	for row in world.get("discipline_bans", []):
		var player_id := String(row.get("player_id", ""))
		var fallback_until := int(world.get("day_index", 0)) + int(row.get("matches", 1)) * 7
		bans[player_id] = maxi(int(bans.get(player_id, 0)), int(row.get("until_day", fallback_until)))
	return bans

func _apply_dressing_room_result(world: Dictionary, home: Dictionary, away: Dictionary, result: Dictionary) -> void:
	var room = DressingRoomClass.new()
	var hg := int(result.get("home_goals", 0))
	var ag := int(result.get("away_goals", 0))
	var derby := bool(result.get("match_context", {}).get("derby", false))
	if hg - ag >= 3:
		room.apply_event(world, String(home.id), "big_win")
	elif ag - hg >= 3:
		room.apply_event(world, String(home.id), "heavy_loss")
	if ag - hg >= 3:
		room.apply_event(world, String(away.id), "big_win")
	elif hg - ag >= 3:
		room.apply_event(world, String(away.id), "heavy_loss")
	if derby:
		if hg > ag:
			room.apply_event(world, String(home.id), "derby_win")
			room.apply_event(world, String(away.id), "derby_loss")
		elif ag > hg:
			room.apply_event(world, String(away.id), "derby_win")
			room.apply_event(world, String(home.id), "derby_loss")

func _apply_match_load(world: Dictionary, result: Dictionary) -> void:
	var participants: Dictionary = result.get("participants", result.get("lineups", {}))
	for side in ["home", "away"]:
		for player_id in participants.get(side, []):
			var player := _player(world, String(player_id))
			if player.is_empty():
				continue
			var minutes := 90 if String(player_id) in result.get("final_lineups", {}).get(side, []) else 25
			player["fatigue"] = clampi(int(player.get("fatigue", 0)) + int(minutes / 12), 0, 100)
			player["fitness"] = clampi(int(player.get("fitness", 100)) - int(minutes / 30), 25, 100)
			player["season_appearances"] = int(player.get("season_appearances", 0)) + 1
			player["career_appearances"] = int(player.get("career_appearances", 0)) + 1

func _apply_suspensions(world: Dictionary, fixture: Dictionary, result: Dictionary, date_string: String) -> void:
	world["suspensions"] = world.get("suspensions", [])
	var day := int(world.get("day_index", 0))
	var competition_id := String(fixture.get("competition_id", ""))
	for event in result.get("events", []):
		if String(event.get("type", "")) != "card":
			continue
		var player_id := String(event.get("player_id", ""))
		if String(event.get("card", "")) == "red":
			var until_day := day + 7
			world.suspensions.append({"player_id": player_id, "from": date_string, "until_day": until_day, "reason": "red_card", "competition_id": competition_id})
			_suspension_index[player_id] = maxi(until_day, int(_discipline_ban_index.get(player_id, 0)))
		elif String(event.get("card", "")) == "yellow":
			var count := int(_yellow_count_index.get(player_id, 0))
			if count >= 4:
				var until_day := day + 7
				world.suspensions.append({"player_id": player_id, "from": date_string, "until_day": until_day, "reason": "accumulation", "competition_id": competition_id})
				_suspension_index[player_id] = maxi(until_day, int(_discipline_ban_index.get(player_id, 0)))
			else:
				world.suspensions.append({"player_id": player_id, "from": date_string, "until_day": day, "reason": "yellow_count", "competition_id": competition_id})
				_yellow_count_index[player_id] = count + 1
				_suspension_index[player_id] = maxi(day, int(_discipline_ban_index.get(player_id, 0)))

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
	var importance := _match_factors.importance_for(competition, fixture)
	var stage := ""
	if bool(fixture.get("knockout", false)):
		var round_number := int(fixture.get("round", 1))
		stage = "knockout_r%d" % round_number
	var derby := _is_derby(world, home, away)
	var travel := _travel_fatigue(world, home, away)
	return {
		"is_home": true,
		"importance": float(importance.get("importance", 0.5)),
		"competition_label": String(importance.get("label", "league")),
		"stage": stage,
		"derby": derby,
		"rivalry": derby,
		"travel_fatigue": float(travel.get("away_fatigue", 0.0)),
		"travel_km": float(travel.get("distance_km", 0.0)),
		"competition_id": String(fixture.get("competition_id", "")),
	}

func _is_derby(world: Dictionary, home: Dictionary, away: Dictionary) -> bool:
	if String(home.get("country_id", "")) != "" and String(home.get("country_id", "")) != String(away.get("country_id", "")):
		return false
	if String(home.get("city_id", "")) != "" and String(home.get("city_id", "")) == String(away.get("city_id", "")):
		return true
	if _rivalry_index.has(_rivalry_key(String(home.get("id", "")), String(away.get("id", "")))):
		return true
	return String(home.get("country_id", "")) != "" and String(home.get("country_id", "")) == String(away.get("country_id", "")) and abs(int(home.get("reputation", 50)) - int(away.get("reputation", 50))) <= 12

func _travel_fatigue(world: Dictionary, home: Dictionary, away: Dictionary) -> Dictionary:
	var home_city := String(home.get("city_id", ""))
	var away_city := String(away.get("city_id", ""))
	if home_city == "" or away_city == "" or home_city == away_city:
		return {"away_fatigue": 0.0, "distance_km": 0.0}
	var home_coords := _city_coords(world, home_city)
	var away_coords := _city_coords(world, away_city)
	if home_coords.is_empty() or away_coords.is_empty():
		return {"away_fatigue": 0.0, "distance_km": 0.0}
	var km := _haversine(home_coords, away_coords)
	return {"away_fatigue": clampf(km / 4000.0, 0.0, 0.38), "distance_km": km}

func _city_coords(world: Dictionary, city_id: String) -> Dictionary:
	if _city_index.has(city_id):
		return _city_index[city_id]
	for city in world.get("cities", []):
		if String(city.get("id", "")) == city_id:
			var coords := {"lat": float(city.get("latitude", city.get("lat", 0.0))), "lon": float(city.get("longitude", city.get("lon", 0.0)))}
			_city_index[city_id] = coords
			return coords
	return {}

func _haversine(a: Dictionary, b: Dictionary) -> float:
	var lat1 := deg_to_rad(float(a.get("lat", 0.0)))
	var lat2 := deg_to_rad(float(b.get("lat", 0.0)))
	var dlat := deg_to_rad(float(b.get("lat", 0.0)) - float(a.get("lat", 0.0)))
	var dlon := deg_to_rad(float(b.get("lon", 0.0)) - float(a.get("lon", 0.0)))
	var h := sin(dlat / 2.0) * sin(dlat / 2.0) + cos(lat1) * cos(lat2) * sin(dlon / 2.0) * sin(dlon / 2.0)
	return 6371.0 * 2.0 * atan2(sqrt(h), sqrt(maxf(0.0, 1.0 - h)))

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
	_suspension_index.clear()
	_discipline_ban_index.clear()
	_yellow_count_index.clear()
	_city_index.clear()
	_rivalry_index.clear()
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
	for city in world.get("cities", []):
		var id := String(city.get("id", ""))
		if id != "":
			_city_index[id] = {"lat": float(city.get("latitude", city.get("lat", 0.0))), "lon": float(city.get("longitude", city.get("lon", 0.0)))}
	for rivalry in world.get("rivalries", []):
		if int(rivalry.get("intensity", 0)) < 25:
			continue
		var club_a := String(rivalry.get("club_a", ""))
		var club_b := String(rivalry.get("club_b", ""))
		if club_a != "" and club_b != "":
			_rivalry_index[_rivalry_key(club_a, club_b)] = true
	for row in world.get("suspensions", []):
		var player_id := String(row.get("player_id", ""))
		if player_id == "":
			continue
		_suspension_index[player_id] = int(row.get("until_day", 0))
		if String(row.get("reason", "")) == "yellow_count":
			_yellow_count_index[player_id] = int(_yellow_count_index.get(player_id, 0)) + 1
	var day := int(world.get("day_index", 0))
	for row in world.get("discipline_bans", []):
		var player_id := String(row.get("player_id", ""))
		if player_id == "":
			continue
		var fallback_until := day + int(row.get("matches", 1)) * 7
		var until_day := int(row.get("until_day", fallback_until))
		_discipline_ban_index[player_id] = maxi(int(_discipline_ban_index.get(player_id, 0)), until_day)
		_suspension_index[player_id] = maxi(int(_suspension_index.get(player_id, 0)), until_day)

func _rivalry_key(club_a: String, club_b: String) -> String:
	return "%s|%s" % [club_a, club_b] if club_a <= club_b else "%s|%s" % [club_b, club_a]

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