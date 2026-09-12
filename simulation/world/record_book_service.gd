class_name RecordBookService
extends RefCounted

func refresh(world: Dictionary) -> Dictionary:
	world["history_archive"] = world.get("history_archive",{})
	var archive: Dictionary = world.history_archive
	archive["competitions"] = _dedupe(archive.get("competitions",[]),["year","competition_id"])
	archive["clubs"] = _dedupe(archive.get("clubs",[]),["year","competition_id","club_id"])
	archive["players"] = _dedupe(archive.get("players",[]),["year","competition_id","player_id"])
	_sort_archive(archive.competitions)
	_sort_archive(archive.clubs)
	_sort_archive(archive.players)
	var books := {}
	var competition_ids := {}
	for row in archive.competitions: competition_ids[String(row.get("competition_id",""))] = true
	for row in archive.clubs: competition_ids[String(row.get("competition_id",""))] = true
	for row in archive.players: competition_ids[String(row.get("competition_id",""))] = true
	for competition_id in competition_ids.keys():
		if String(competition_id) == "": continue
		books[String(competition_id)] = _competition_book(archive,String(competition_id))
	archive["record_books"] = books
	archive["record_book_version"] = 2
	world["history_archive"] = archive
	return {"competition_books":books.size(),"competition_rows":archive.competitions.size(),"club_rows":archive.clubs.size(),"player_rows":archive.players.size()}

func _competition_book(archive: Dictionary, competition_id: String) -> Dictionary:
	var titles := {}
	var most_points := {"value":-1}
	var most_wins := {"value":-1}
	var most_goals := {"value":-1}
	var fewest_conceded := {"value":2_147_483_647}
	var best_attendance := {"value":-1}
	for row in archive.clubs:
		if String(row.get("competition_id","")) != competition_id: continue
		var club_id := String(row.get("club_id","")); var year := int(row.get("year",0))
		if bool(row.get("champion",false)): titles[club_id] = int(titles.get(club_id,0))+1
		if int(row.get("played",0)) > 0:
			most_points = _max_record(most_points,int(row.get("points",0)),club_id,year)
			most_wins = _max_record(most_wins,int(row.get("won",0)),club_id,year)
			most_goals = _max_record(most_goals,int(row.get("goals_for",0)),club_id,year)
			var conceded := int(row.get("goals_against",0))
			if conceded < int(fewest_conceded.value): fewest_conceded = {"value":conceded,"club_id":club_id,"year":year}
		if int(row.get("average_attendance",0)) > int(best_attendance.value): best_attendance = {"value":int(row.get("average_attendance",0)),"club_id":club_id,"year":year}
	var title_ranking: Array = []
	for club_id in titles.keys(): title_ranking.append({"club_id":String(club_id),"titles":int(titles[club_id])})
	title_ranking.sort_custom(func(a: Dictionary,b: Dictionary):
		if int(a.titles) == int(b.titles): return String(a.club_id) < String(b.club_id)
		return int(a.titles) > int(b.titles)
	)
	var career := {}
	var season_goal_record := {"value":-1}
	var season_assist_record := {"value":-1}
	var season_appearance_record := {"value":-1}
	for row in archive.players:
		if String(row.get("competition_id","")) != competition_id: continue
		var player_id := String(row.get("player_id","")); var year := int(row.get("year",0))
		if not career.has(player_id): career[player_id] = {"appearances":0,"goals":0,"assists":0}
		career[player_id].appearances = int(career[player_id].appearances)+int(row.get("appearances",0))
		career[player_id].goals = int(career[player_id].goals)+int(row.get("goals",0))
		career[player_id].assists = int(career[player_id].assists)+int(row.get("assists",0))
		season_goal_record = _max_player_record(season_goal_record,int(row.get("goals",0)),player_id,year)
		season_assist_record = _max_player_record(season_assist_record,int(row.get("assists",0)),player_id,year)
		season_appearance_record = _max_player_record(season_appearance_record,int(row.get("appearances",0)),player_id,year)
	var career_goals := {"value":-1}; var career_assists := {"value":-1}; var career_apps := {"value":-1}
	for player_id in career.keys():
		career_goals = _max_player_record(career_goals,int(career[player_id].goals),String(player_id),0)
		career_assists = _max_player_record(career_assists,int(career[player_id].assists),String(player_id),0)
		career_apps = _max_player_record(career_apps,int(career[player_id].appearances),String(player_id),0)
	var seasonal_top_scorers: Array = []
	for row in archive.competitions:
		if String(row.get("competition_id","")) == competition_id:
			seasonal_top_scorers.append({"year":int(row.get("year",0)),"player_id":String(row.get("top_scorer_id","")),"goals":int(row.get("top_scorer_goals",0)),"winner_club_id":String(row.get("winner_club_id",""))})
	return {
		"competition_id":competition_id,
		"titles":title_ranking,
		"club_records":{"most_points":_clean(most_points),"most_wins":_clean(most_wins),"most_goals":_clean(most_goals),"fewest_conceded":_clean(fewest_conceded),"highest_average_attendance":_clean(best_attendance)},
		"player_records":{"career_goals":_clean(career_goals),"career_assists":_clean(career_assists),"career_appearances":_clean(career_apps),"season_goals":_clean(season_goal_record),"season_assists":_clean(season_assist_record),"season_appearances":_clean(season_appearance_record)},
		"seasonal_top_scorers":seasonal_top_scorers,
	}

func _dedupe(rows: Array, fields: Array) -> Array:
	var by_key := {}
	for row in rows:
		if not row is Dictionary: continue
		var parts: Array = []
		for field in fields: parts.append(String(row.get(String(field),"")))
		by_key["|".join(parts)] = row.duplicate(true)
	return by_key.values()

func _sort_archive(rows: Array) -> void:
	rows.sort_custom(func(a: Dictionary,b: Dictionary):
		if int(a.get("year",0)) != int(b.get("year",0)): return int(a.get("year",0)) < int(b.get("year",0))
		var ac := String(a.get("competition_id","")); var bc := String(b.get("competition_id",""))
		if ac != bc: return ac < bc
		return String(a.get("club_id",a.get("player_id",""))) < String(b.get("club_id",b.get("player_id","")))
	)

func _max_record(current: Dictionary, value: int, club_id: String, year: int) -> Dictionary:
	if value > int(current.get("value",-1)): return {"value":value,"club_id":club_id,"year":year}
	return current

func _max_player_record(current: Dictionary, value: int, player_id: String, year: int) -> Dictionary:
	if value > int(current.get("value",-1)): return {"value":value,"player_id":player_id,"year":year}
	return current

func _clean(record: Dictionary) -> Dictionary:
	if int(record.get("value",-1)) < 0 or int(record.get("value",0)) == 2_147_483_647: return {}
	return record
