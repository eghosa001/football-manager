extends RefCounted

const CALENDAR_PATH = "res://core/calendar/calendar_service.gd"
const SEASON_RUNNER_PATH = "res://application/season/season_runner.gd"
const MATCHDAY_SERVICE_PATH = "res://application/career/career_matchday_service.gd"
const MATCH_SESSION_PATH = "res://simulation/match/managed_match_session.gd"
const COMMITTER_PATH = "res://application/career/managed_matchday_committer.gd"

var fixture = {}
var target_date = ""
var managed_club_id = ""
var season_seed = 1
var fixture_seed = 1
var match_session = null
var home = {}
var away = {}

func has_live_match_tomorrow(world, club_id):
	return not next_managed_fixture(world, club_id).is_empty()

func next_managed_fixture(world, club_id):
	if not world is Dictionary or world.is_empty() or String(club_id) == "":
		return {}
	var runner = _instance(SEASON_RUNNER_PATH)
	if runner == null:
		return {}
	runner.call("assign_fixture_dates", world)
	var date = _next_date(String(world.get("date", "2026-07-01")))
	if date == "":
		return {}
	for row in world.get("fixtures", []):
		if bool(row.get("played", false)):
			continue
		if String(row.get("date", "")) != date:
			continue
		if String(row.get("home_club_id", "")) == String(club_id) or String(row.get("away_club_id", "")) == String(club_id):
			return row
	return {}

func start(world, club_id, seed):
	managed_club_id = String(club_id)
	season_seed = int(seed)
	fixture = next_managed_fixture(world, managed_club_id)
	if fixture.is_empty():
		return {"error": ERR_DOES_NOT_EXIST}
	target_date = String(fixture.get("date", ""))
	var service = _instance(MATCHDAY_SERVICE_PATH)
	if service == null:
		return {"error": ERR_CANT_CREATE}
	service.call("_build_indexes", world)
	home = service.call("_club", world, String(fixture.get("home_club_id", "")))
	away = service.call("_club", world, String(fixture.get("away_club_id", "")))
	if not home is Dictionary or not away is Dictionary or home.is_empty() or away.is_empty():
		return {"error": ERR_INVALID_DATA}
	var players = service.call("_eligible_match_players", world, String(home.get("id", "")), String(away.get("id", "")), String(fixture.get("competition_id", "")))
	var context = service.call("_match_context", world, fixture, home, away)
	fixture_seed = int(service.call("_fixture_seed", season_seed, String(fixture.get("id", ""))))
	match_session = _instance(MATCH_SESSION_PATH)
	if match_session == null:
		return {"error": ERR_CANT_CREATE}
	var started = match_session.call("start_match", home, away, players, fixture_seed, context)
	if not started is Dictionary:
		return {"error": ERR_INVALID_DATA}
	_enrich(started)
	return started

func advance(target_minute):
	if match_session == null:
		return {"error": ERR_UNCONFIGURED}
	return match_session.call("advance_to_minute", int(target_minute))

func substitute(player_out, player_in):
	if match_session == null:
		return ERR_UNCONFIGURED
	return int(match_session.call("make_substitution", _managed_side(), String(player_out), String(player_in)))

func change_tactic(tactic):
	if match_session == null:
		return ERR_UNCONFIGURED
	return int(match_session.call("change_tactic", _managed_side(), tactic))

func snapshot():
	if match_session == null:
		return {"error": ERR_UNCONFIGURED}
	var data = match_session.call("snapshot")
	if not data is Dictionary:
		return {"error": ERR_INVALID_DATA}
	_enrich(data)
	return data

func commit(world):
	if match_session == null or fixture.is_empty():
		return {"error": ERR_UNCONFIGURED}
	var result = match_session.call("finish_match")
	if not result is Dictionary:
		return {"error": ERR_INVALID_DATA}
	if result.has("error"):
		return result
	var committer = _instance(COMMITTER_PATH)
	if committer == null:
		return {"error": ERR_CANT_CREATE, "message": "Unable to finalise matchday."}
	return committer.call("commit", world, fixture, result, home, away, managed_club_id, target_date, season_seed, fixture_seed)

func _enrich(data):
	data["fixture"] = fixture.duplicate(true)
	data["home_name"] = String(home.get("name", "Home"))
	data["away_name"] = String(away.get("name", "Away"))
	data["managed_side"] = _managed_side()

func _managed_side():
	return "home" if String(home.get("id", "")) == managed_club_id else "away"

func _next_date(date_string):
	var parts = String(date_string).split("-")
	if parts.size() != 3:
		return ""
	var calendar = _instance(CALENDAR_PATH)
	if calendar == null:
		return ""
	calendar.call("set_date", int(parts[0]), int(parts[1]), int(parts[2]))
	calendar.call("advance_days", 1)
	return String(calendar.call("get_date_string"))

func _instance(path):
	var script = load(String(path))
	return null if script == null else script.new()
