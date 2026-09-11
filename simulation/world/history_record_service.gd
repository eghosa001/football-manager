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
	for record in season_records:
		var competition_id := String(record.get("competition_id", ""))
		var table: Array = record.get("table", [])
		var winner := String(record.get("champion_club_id", ""))
		if winner == "" and not table.is_empty():
			winner = String(table[0].get("club_id", ""))
		var runner_up := String(table[1].get("club_id", "")) if table.size() > 1 else ""
		world.history_archive.competitions.append({
			"year":completed_year,"competition_id":competition_id,"competition_name":String(record.get("competition_name", competition_id)),
			"winner_club_id":winner,"runner_up_club_id":runner_up,"competition_type":String(record.get("competition_type", "league"))
		})
		competition_rows += 1
		for i in range(table.size()):
			var row: Dictionary = table[i]
			world.history_archive.clubs.append({
				"year":completed_year,"club_id":String(row.get("club_id", "")),"competition_id":competition_id,"position":i+1,
				"played":int(row.get("played",0)),"won":int(row.get("won",0)),"drawn":int(row.get("drawn",0)),"lost":int(row.get("lost",0)),
				"goals_for":int(row.get("goals_for",row.get("gf",0))),"goals_against":int(row.get("goals_against",row.get("ga",0))),"points":int(row.get("points",0)),
				"champion":String(row.get("club_id", "")) == winner
			})
			club_rows += 1
	_record_players(world, completed_year)
	_refresh_records(world)
	return {"competition_rows":competition_rows,"club_rows":club_rows,"player_rows":_player_rows_for_year(world,completed_year)}

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
			"appearances":int(row.get("appearances",0)),"goals":int(row.get("goals",0)),"xg":float(row.get("xg",0.0))
		})
		existing[key] = true

func _refresh_records(world: Dictionary) -> void:
	var records: Dictionary = world.history_archive.records
	var title_counts := {}
	for row in world.history_archive.competitions:
		var winner := String(row.get("winner_club_id",""))
		if winner != "": title_counts[winner] = int(title_counts.get(winner,0))+1
	var top_club := ""; var top_titles := -1
	for club_id in title_counts:
		if int(title_counts[club_id]) > top_titles:
			top_club = String(club_id); top_titles = int(title_counts[club_id])
	var player_totals := {}
	for row in world.history_archive.players:
		var player_id := String(row.get("player_id",""))
		if not player_totals.has(player_id): player_totals[player_id] = {"appearances":0,"goals":0}
		player_totals[player_id].appearances = int(player_totals[player_id].appearances)+int(row.get("appearances",0))
		player_totals[player_id].goals = int(player_totals[player_id].goals)+int(row.get("goals",0))
	var appearance_player := ""; var appearances := -1; var goals_player := ""; var goals := -1
	for player_id in player_totals:
		if int(player_totals[player_id].appearances) > appearances:
			appearance_player = String(player_id); appearances = int(player_totals[player_id].appearances)
		if int(player_totals[player_id].goals) > goals:
			goals_player = String(player_id); goals = int(player_totals[player_id].goals)
	records["most_decorated_club"] = {"club_id":top_club,"titles":maxi(0,top_titles)}
	records["most_appearances"] = {"player_id":appearance_player,"appearances":maxi(0,appearances)}
	records["most_goals"] = {"player_id":goals_player,"goals":maxi(0,goals)}
	world.history_archive.records = records

func _player_rows_for_year(world: Dictionary, year: int) -> int:
	var count := 0
	for row in world.history_archive.players:
		if int(row.get("year",0)) == year: count += 1
	return count
