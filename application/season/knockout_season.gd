class_name KnockoutSeason
extends RefCounted

const KnockoutClass = preload("res://simulation/competitions/knockout_competition.gd")
const CalendarClass = preload("res://core/calendar/calendar_service.gd")

func initialize_all(world: Dictionary, season_year: int) -> void:
	for competition in world.get("competitions", []):
		if String(competition.get("competition_type", "league")) != "knockout": continue
		initialize_competition(world, competition, season_year)

func initialize_competition(world: Dictionary, competition: Dictionary, season_year: int) -> void:
	var bracket: Dictionary = KnockoutClass.new().create_bracket(competition.get("club_ids", []), _stable_seed(String(competition.get("id", "cup")), season_year))
	competition["knockout_bracket"] = bracket
	competition["season_year"] = season_year
	competition["champion_club_id"] = ""
	_append_round_fixtures(world, competition, bracket, season_year, "%04d-09-%02d" % [season_year, 14 if bool(competition.get("continental", false)) else 10])
	_advance_bye_only_rounds(world, competition, season_year)

func advance_ready(world: Dictionary, competition_id: String, current_date: String) -> Dictionary:
	var competition := _competition(world, competition_id)
	if competition.is_empty() or String(competition.get("competition_type", "")) != "knockout": return {}
	var bracket: Dictionary = competition.get("knockout_bracket", {})
	if bracket.is_empty() or bool(bracket.get("complete", false)): return bracket
	var round_number := int(bracket.get("round", 1))
	var fixtures := _round_fixtures(world, competition_id, round_number)
	for fixture in fixtures:
		if not bool(fixture.get("played", false)): return bracket
	var indexed := {}
	for fixture in fixtures: indexed[int(fixture.get("bracket_index", -1))] = fixture
	var results: Array = []
	for i in range(bracket.get("matches", []).size()):
		var pairing: Dictionary = bracket.matches[i]
		if String(pairing.get("home", "")) == "" or String(pairing.get("away", "")) == "":
			results.append({})
			continue
		var fixture: Dictionary = indexed.get(i, {})
		if fixture.is_empty(): return bracket
		var row := {"home_goals":int(fixture.get("home_goals",0)),"away_goals":int(fixture.get("away_goals",0))}
		if int(row.home_goals) == int(row.away_goals):
			row["shootout_winner"] = _shootout_winner(String(pairing.home), String(pairing.away), String(fixture.get("id", "")))
		results.append(row)
	var next: Dictionary = KnockoutClass.new().advance_round(bracket, results)
	if next.is_empty(): return bracket
	competition.knockout_bracket = next
	if bool(next.get("complete", false)):
		competition.champion_club_id = String(next.get("winner", ""))
		return next
	var next_date := _add_days(current_date, 14)
	_append_round_fixtures(world, competition, next, int(competition.get("season_year", world.get("season_year", 2026))), next_date)
	_advance_bye_only_rounds(world, competition, int(competition.get("season_year", world.get("season_year", 2026))))
	return competition.knockout_bracket

func record(world: Dictionary, competition: Dictionary) -> Dictionary:
	var bracket: Dictionary = competition.get("knockout_bracket", {})
	var fixtures := []
	for fixture in world.get("fixtures", []):
		if String(fixture.get("competition_id", "")) == String(competition.get("id", "")): fixtures.append(fixture)
	return {"competition_id":String(competition.get("id", "")),"competition_name":String(competition.get("name", "")),"season_start_year":int(competition.get("season_year", world.get("season_year", 2026))),"tier":0,"complete":bool(bracket.get("complete", false)),"fixture_count":fixtures.size(),"table":[],"champion_club_id":String(competition.get("champion_club_id", "")),"competition_type":"knockout"}

func _advance_bye_only_rounds(world: Dictionary, competition: Dictionary, season_year: int) -> void:
	# If a bracket round contains only byes, advance it immediately.
	for guard in range(8):
		var bracket: Dictionary = competition.get("knockout_bracket", {})
		if bracket.is_empty() or bool(bracket.get("complete", false)): return
		var has_real_match := false
		for pairing in bracket.get("matches", []):
			if String(pairing.get("home", "")) != "" and String(pairing.get("away", "")) != "": has_real_match = true; break
		if has_real_match: return
		var results: Array = []
		for _pairing in bracket.get("matches", []): results.append({})
		var next := KnockoutClass.new().advance_round(bracket, results)
		competition.knockout_bracket = next
		if bool(next.get("complete", false)):
			competition.champion_club_id = String(next.get("winner", "")); return
		_append_round_fixtures(world, competition, next, season_year, "%04d-09-10" % season_year)

func _append_round_fixtures(world: Dictionary, competition: Dictionary, bracket: Dictionary, season_year: int, date_string: String) -> void:
	# League dates may not have been materialized yet during initialization.
	for fixture in world.fixtures:
		if String(fixture.get("date", "")) == "":
			fixture["date"] = _add_days("%04d-08-01" % season_year, (int(fixture.get("round", 1)) - 1) * 7)
	for i in range(bracket.get("matches", []).size()):
		var pairing: Dictionary = bracket.matches[i]
		var home := String(pairing.get("home", "")); var away := String(pairing.get("away", ""))
		if home == "" or away == "": continue
		var candidate := date_string
		while _has_conflict(world, home, away, candidate): candidate = _add_days(candidate, 1)
		date_string = candidate
		world.fixtures.append({"id":"cup-%s-%d-r%d-m%d" % [String(competition.get("id", "cup")),season_year,int(bracket.get("round",1)),i],"competition_id":String(competition.get("id","")),"round":int(bracket.get("round",1)),"bracket_index":i,"home_club_id":home,"away_club_id":away,"played":false,"home_goals":0,"away_goals":0,"date":date_string,"season_year":season_year,"knockout":true})

func _has_conflict(world: Dictionary, home: String, away: String, date_string: String) -> bool:
	for fixture in world.fixtures:
		if String(fixture.get("date", "")) != date_string: continue
		if String(fixture.get("home_club_id", "")) in [home, away] or String(fixture.get("away_club_id", "")) in [home, away]: return true
	return false

func _round_fixtures(world: Dictionary, competition_id: String, round_number: int) -> Array:
	var rows: Array = []
	for fixture in world.get("fixtures", []):
		if String(fixture.get("competition_id", "")) == competition_id and int(fixture.get("round", 0)) == round_number and bool(fixture.get("knockout", false)): rows.append(fixture)
	return rows

func _competition(world: Dictionary, id: String) -> Dictionary:
	for competition in world.get("competitions", []):
		if String(competition.get("id", "")) == id: return competition
	return {}

func _add_days(date_string: String, days: int) -> String:
	var pieces := date_string.split("-")
	var calendar = CalendarClass.new()
	calendar.set_date(int(pieces[0]), int(pieces[1]), int(pieces[2]))
	calendar.advance_days(days)
	return calendar.get_date_string()

func _shootout_winner(home: String, away: String, fixture_id: String) -> String:
	return home if _stable_seed(fixture_id, 0) % 2 == 0 else away

func _stable_seed(text: String, salt: int) -> int:
	var value := 101 + salt
	for c in text.to_utf8_buffer(): value = posmod(value * 197 + int(c), 2_147_483_647)
	return value if value != 0 else 1
