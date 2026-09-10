class_name CareerMatchdayService
extends RefCounted

const SeasonRunnerClass = preload("res://application/season/season_runner.gd")
const AbstractMatchEngineClass = preload("res://simulation/match/abstract_match_engine.gd")
const TacticalMatchEngineClass = preload("res://simulation/match/tactical_match_engine.gd")
const FullMatchEngineV2Class = preload("res://simulation/match/full_match_engine_v2.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")
const PlayerStatsServiceClass = preload("res://application/career/player_stats_service.gd")
const DressingRoomClass = preload("res://simulation/players/dressing_room.gd")

var _abstract = AbstractMatchEngineClass.new()
var _tactical = TacticalMatchEngineClass.new()
var _detailed = FullMatchEngineV2Class.new()
var _stats = PlayerStatsServiceClass.new()

func play_date(world: Dictionary, date_string: String, managed_club_id: String, season_seed: int) -> Array:
	SeasonRunnerClass.new().assign_fixture_dates(world)
	var results: Array = []
	for fixture in world.get("fixtures", []):
		if bool(fixture.get("played", false)) or String(fixture.get("date", "")) != date_string:
			continue
		var home := _club(world, String(fixture.get("home_club_id", "")))
		var away := _club(world, String(fixture.get("away_club_id", "")))
		if home.is_empty() or away.is_empty(): continue
		var match_seed := _fixture_seed(season_seed, String(fixture.get("id", "")))
		var is_managed := managed_club_id != "" and (String(home.id) == managed_club_id or String(away.id) == managed_club_id)
		var result: Dictionary
		if is_managed:
			result = _detailed.simulate_match(home, away, world.get("players", []), match_seed)
			_detailed.apply_to_fixture(fixture, result)
			if not result.has("error"):
				world["last_managed_match"] = {"fixture":fixture.duplicate(true),"result":result.duplicate(true),"date":date_string}
				_add_match_message(world, home, away, result, managed_club_id)
		else:
			var engine = _tactical if home.has("tactic") or away.has("tactic") else _abstract
			result = engine.simulate_match(home, away, world.get("players", []), match_seed)
			engine.apply_to_fixture(fixture, result)
		if not result.has("error"):
			_stats.record_match(world, fixture, result)
			_apply_dressing_room_result(world, home, away, result)
		results.append({"fixture":fixture,"result":result,"match_seed":match_seed,"detailed":is_managed})
	world["date"] = date_string
	return results

func _apply_dressing_room_result(world: Dictionary, home: Dictionary, away: Dictionary, result: Dictionary) -> void:
	var room = DressingRoomClass.new()
	var hg := int(result.get("home_goals", 0)); var ag := int(result.get("away_goals", 0))
	if hg - ag >= 3: room.apply_event(world, String(home.id), "big_win")
	elif ag - hg >= 3: room.apply_event(world, String(home.id), "heavy_loss")
	if ag - hg >= 3: room.apply_event(world, String(away.id), "big_win")
	elif hg - ag >= 3: room.apply_event(world, String(away.id), "heavy_loss")

func _add_match_message(world: Dictionary, home: Dictionary, away: Dictionary, result: Dictionary, managed_club_id: String) -> void:
	var managed_home := String(home.id) == managed_club_id
	var gf := int(result.get("home_goals", 0)) if managed_home else int(result.get("away_goals", 0))
	var ga := int(result.get("away_goals", 0)) if managed_home else int(result.get("home_goals", 0))
	var opponent := away if managed_home else home
	var outcome := "draw"
	if gf > ga: outcome = "win"
	elif gf < ga: outcome = "defeat"
	InboxServiceClass.new().add_message(world, "match", "Match result: %d-%d" % [gf, ga], "%s against %s. Review the match analysis for spatial frames, xG and events." % [outcome.capitalize(), String(opponent.get("name", "opponent"))])

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id: return club
	return {}

func _fixture_seed(season_seed: int, fixture_id: String) -> int:
	var value := season_seed
	for character in fixture_id.to_utf8_buffer(): value = posmod(value * 31 + int(character), 2_147_483_647)
	return value if value != 0 else 1
