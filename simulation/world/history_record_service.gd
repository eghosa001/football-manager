class_name HistoryRecordService
extends RefCounted

func ensure_world(world: Dictionary) -> void:
	world["history_archive"] = world.get("history_archive", {})
	var archive: Dictionary = world.history_archive
	archive["competitions"] = archive.get("competitions", [])
	archive["clubs"] = archive.get("clubs", [])
	archive["players"] = archive.get("players", [])
	archive["records"] = archive.get("records", {})
	world["history_archive"] = archive

func record_season(world: Dictionary, season_records: Array, completed_year: int) -> Dictionary:
	ensure_world(world)
	var competition_rows := 0
	var club_rows := 0
	_record_players(world, completed_year)
	for record in season_records:
		var competition_id := String(record.get("competition_id", ""))
		var table: Array = record.get("table", [])
		var winner := String(record.get("champion_club_id", ""))
		if winner == "" and not table.is_empty():
			winner = String(table[0].get("club_id", ""))
		var runner_up := String(table[1].get("club_id", "")) if table.size() > 1 else _knockout_runner_up(world, competition_id, winner)
		var awards := _competition_player_leaders(world, competition_id, completed_year)
		world.history_archive.competitions.append({
			"year":completed_year,
			"competition_id":competition_id,
			"competition_name":String(record.get("competition_name", competition_id)),
			"winner_club_id":winner,
			"runner_up_club_id":runner_up,
			"competition_type":String(record.get("competition_type", "league")),
			"top_scorer_id":String(awards.get("top_scorer_id", "")),
			"top_scorer_goals":int(awards.get("top_scorer_goals", 0)),
			"best_player_id":String(awards.get("best_player_id", "")),
			"best_player_rating":float(awards.get("best_player_rating", 0.0))
		})
		competition_rows += 1
		if not table.is_empty():
			for i in range(table.size()):
				var row: Dictionary = table[i]
				world.history_archive.clubs.append({
					"year":completed_year,"club_id":String(row.get("club_id", "")),"competition_id":competition_id,"position":i+1,
					"played":int(row.get("played",0)),"won":int(row.get("won",0)),"drawn":int(row.get("drawn",0)),"lost":int(row.get("lost",0)),
					"goals_for":int(row.get("goals_for",row.get("gf",0))),"goals_against":int(row.get("goals_against",row.get("ga",0))),"points":int(row.get("points",0)),
					"champion":String(row.get("club_id", "")) == winner,"cup_performance":""
				})
				club_rows += 1
		else:
			if winner != "":
				world.history_archive.clubs.append({"year":completed_year,"club_id":winner,"competition_id":competition_id,"position":1,"champion":true,"cup_performance":"winner"})
				club_rows += 1
			if runner_up != "":
				world.history_archive.clubs.append({"year":completed_year,"club_id":runner_up,"competition_id":competition_id,"position":2,"champion":false,"cup_performance":"runner_up"})
				club_rows += 1
	_refresh_records(world)
	return {"competition_rows":competition_rows,"club_rows":club_rows,"player_rows":_player_rows_for_year(world,completed_year)}

func enrich_club_context(world: Dictionary, economy_result: Dictionary, year: int) -> void:
	ensure_world(world)
	var economy_by_club := {}
	for report in economy_result.get("clubs", []):
		economy_by_club[String(report.get("club_id", ""))] = report
	for row in world.history_archive.clubs:
		if int(row.get("year",0)) != year:
			continue
		var club_id := String(row.get("club_id", ""))
		var report: Dictionary = economy_by_club.get(club_id, {})
		if not report.is_empty():
			row["revenue"] = int(report.get("income",0))
			row["expenses"] = int(report.get("expenses",0))
			row["average_attendance"] = int(report.get("average_attendance",0))
			row["attendance_rate"] = float(report.get("attendance_rate",0.0))
		row["manager_id"] = _manager_id(world, club_id)

func _record_players(world: Dictionary, year: int) -> void:
	var existing := {}
	for row in world.history_archive.players:
		if int(row.get("year",0)) == year:
			existing[String(row.get("player_id",""))+"|"+String(row.get("competition_id",""))] = true
	for row in world.get("player_history", []):
		if int(row.get("season_year",0)) != year:
			continue
		var key := String(row.get("player_id",""))+"|"+String(row.get("competition_id",""))
		if existing.has(key):
			continue
		world.history_archive.players.append({
			"year":year,"player_id":String(row.get("player_id","")),"club_id":String(row.get("club_id","")),"competition_id":String(row.get("competition_id","")),
			"appearances":int(row.get("appearances",0)),"starts":int(row.get("starts",0)),"goals":int(row.get("goals",0)),"assists":int(row.get("assists",0)),
			"xg":float(row.get("xg",0.0)),"rating":float(row.get("rating",0.0))
		})
		existing[key] = true

func _competition_player_leaders(world: Dictionary, competition_id: String, year: int) -> Dictionary:
	var top_scorer := ""
	var top_goals := -1
	var best_player := ""
	var best_rating := -1.0
	for row in world.history_archive.players:
		if int(row.get("year",0)) != year or String(row.get("competition_id","")) != competition_id:
			continue
		var goals := int(row.get("goals",0))
		if goals > top_goals:
			top_goals = goals
			top_scorer = String(row.get("player_id",""))
		var rating := float(row.get("rating",0.0))
		if int(row.get("appearances",0)) >= 3 and rating > best_rating:
			best_rating = rating
			best_player = String(row.get("player_id",""))
	return {"top_scorer_id":top_scorer,"top_scorer_goals":maxi(0,top_goals),"best_player_id":best_player,"best_player_rating":maxf(0.0,best_rating)}

func _knockout_runner_up(world: Dictionary, competition_id: String, winner: String) -> String:
	var final_fixture: Dictionary = {}
	var max_round := -1
	for fixture in world.get("fixtures", []):
		if String(fixture.get("competition_id","")) != competition_id or not bool(fixture.get("knockout",false)) or not bool(fixture.get("played",false)):
			continue
		var round_number := int(fixture.get("round",0))
		if round_number > max_round:
			max_round = round_number
			final_fixture = fixture
	if final_fixture.is_empty():
		return ""
	var home := String(final_fixture.get("home_club_id",""))
	var away := String(final_fixture.get("away_club_id",""))
	if winner == home:
		return away
	if winner == away:
		return home
	return ""

func _refresh_records(world: Dictionary) -> void:
	var records: Dictionary = world.history_archive.records
	var title_counts := {}
	for row in world.history_archive.competitions:
		var winner := String(row.get("winner_club_id",""))
		if winner != "":
			title_counts[winner] = int(title_counts.get(winner,0))+1
	var top_club := ""
	var top_titles := -1
	for club_id in title_counts:
		if int(title_counts[club_id]) > top_titles:
			top_club = String(club_id)
			top_titles = int(title_counts[club_id])
	var player_totals := {}
	for row in world.history_archive.players:
		var player_id := String(row.get("player_id",""))
		if not player_totals.has(player_id):
			player_totals[player_id] = {"appearances":0,"goals":0,"assists":0}
		player_totals[player_id].appearances = int(player_totals[player_id].appearances)+int(row.get("appearances",0))
		player_totals[player_id].goals = int(player_totals[player_id].goals)+int(row.get("goals",0))
		player_totals[player_id].assists = int(player_totals[player_id].assists)+int(row.get("assists",0))
	var appearance_player := ""
	var appearances := -1
	var goals_player := ""
	var goals := -1
	var assists_player := ""
	var assists := -1
	for player_id in player_totals:
		if int(player_totals[player_id].appearances) > appearances:
			appearance_player = String(player_id)
			appearances = int(player_totals[player_id].appearances)
		if int(player_totals[player_id].goals) > goals:
			goals_player = String(player_id)
			goals = int(player_totals[player_id].goals)
		if int(player_totals[player_id].assists) > assists:
			assists_player = String(player_id)
			assists = int(player_totals[player_id].assists)
	records["most_decorated_club"] = {"club_id":top_club,"titles":maxi(0,top_titles)}
	records["most_appearances"] = {"player_id":appearance_player,"appearances":maxi(0,appearances)}
	records["most_goals"] = {"player_id":goals_player,"goals":maxi(0,goals)}
	records["most_assists"] = {"player_id":assists_player,"assists":maxi(0,assists)}
	world.history_archive.records = records

func _manager_id(world: Dictionary, club_id: String) -> String:
	for member in world.get("staff", []):
		if String(member.get("club_id","")) == club_id and String(member.get("role","")) == "manager":
			return String(member.get("id",""))
	return ""

func _player_rows_for_year(world: Dictionary, year: int) -> int:
	var count := 0
	for row in world.history_archive.players:
		if int(row.get("year",0)) == year:
			count += 1
	return count
