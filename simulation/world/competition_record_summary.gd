class_name CompetitionRecordSummary
extends RefCounted

func build(fixtures: Array) -> Dictionary:
	var played: Array = []
	for fixture in fixtures:
		if bool(fixture.get("played",false)): played.append(fixture)
	played.sort_custom(func(a: Dictionary,b: Dictionary):
		var ad: String = String(a.get("date","")); var bd: String = String(b.get("date",""))
		if ad != bd: return ad < bd
		return String(a.get("id","")) < String(b.get("id",""))
	)
	var biggest: Dictionary = {}
	var highest_scoring: Dictionary = {}
	var streaks: Dictionary = {}; var win_streaks: Dictionary = {}
	var best_unbeaten: Dictionary = {"club_id":"","matches":0,"from":"","to":""}
	var best_wins: Dictionary = {"club_id":"","matches":0,"from":"","to":""}
	var streak_start: Dictionary = {}; var win_start: Dictionary = {}
	var clean_sheets: Dictionary = {}; var total_goals: int = 0; var home_wins: int = 0; var away_wins: int = 0; var draws: int = 0; var extra_time_matches: int = 0; var shootouts: int = 0
	for fixture in played:
		var home: String = String(fixture.get("home_club_id","")); var away: String = String(fixture.get("away_club_id","")); var date: String = String(fixture.get("date",""))
		var hg: int = int(fixture.get("final_home_goals",fixture.get("home_goals",0))); var ag: int = int(fixture.get("final_away_goals",fixture.get("away_goals",0)))
		total_goals += hg + ag
		if hg > ag: home_wins += 1
		elif ag > hg: away_wins += 1
		else: draws += 1
		if ag == 0: clean_sheets[home] = int(clean_sheets.get(home,0))+1
		if hg == 0: clean_sheets[away] = int(clean_sheets.get(away,0))+1
		if bool(fixture.get("after_extra_time",false)): extra_time_matches += 1
		if String(fixture.get("shootout_winner","")) != "": shootouts += 1
		var margin: int = absi(hg-ag); var total: int = hg+ag
		if biggest.is_empty() or margin > int(biggest.get("margin",-1)):
			biggest = {"margin":margin,"home_club_id":home,"away_club_id":away,"home_goals":hg,"away_goals":ag,"date":date,"fixture_id":String(fixture.get("id",""))}
		if highest_scoring.is_empty() or total > int(highest_scoring.get("goals",-1)):
			highest_scoring = {"goals":total,"home_club_id":home,"away_club_id":away,"home_goals":hg,"away_goals":ag,"date":date,"fixture_id":String(fixture.get("id",""))}
		_update_streak(home,hg>=ag,hg>ag,date,streaks,win_streaks,streak_start,win_start,best_unbeaten,best_wins)
		_update_streak(away,ag>=hg,ag>hg,date,streaks,win_streaks,streak_start,win_start,best_unbeaten,best_wins)
	var clean_sheet_record: Dictionary = {"club_id":"","matches":0}
	for club_id in clean_sheets.keys():
		if int(clean_sheets[club_id]) > int(clean_sheet_record.matches): clean_sheet_record = {"club_id":String(club_id),"matches":int(clean_sheets[club_id])}
	return {"matches":played.size(),"total_goals":total_goals,"average_goals":snappedf(float(total_goals)/maxf(1.0,float(played.size())),0.01),"home_wins":home_wins,"away_wins":away_wins,"draws":draws,"biggest_victory":biggest,"highest_scoring_match":highest_scoring,"longest_unbeaten":best_unbeaten,"longest_winning_streak":best_wins,"most_clean_sheets":clean_sheet_record,"extra_time_matches":extra_time_matches,"shootouts":shootouts}

func _update_streak(club_id: String, unbeaten: bool, won: bool, date: String, streaks: Dictionary, win_streaks: Dictionary, streak_start: Dictionary, win_start: Dictionary, best_unbeaten: Dictionary, best_wins: Dictionary) -> void:
	if club_id == "": return
	if unbeaten:
		if int(streaks.get(club_id,0)) == 0: streak_start[club_id] = date
		streaks[club_id] = int(streaks.get(club_id,0))+1
		if int(streaks[club_id]) > int(best_unbeaten.matches):
			best_unbeaten["club_id"] = club_id; best_unbeaten["matches"] = int(streaks[club_id]); best_unbeaten["from"] = String(streak_start.get(club_id,date)); best_unbeaten["to"] = date
	else:
		streaks[club_id] = 0; streak_start.erase(club_id)
	if won:
		if int(win_streaks.get(club_id,0)) == 0: win_start[club_id] = date
		win_streaks[club_id] = int(win_streaks.get(club_id,0))+1
		if int(win_streaks[club_id]) > int(best_wins.matches):
			best_wins["club_id"] = club_id; best_wins["matches"] = int(win_streaks[club_id]); best_wins["from"] = String(win_start.get(club_id,date)); best_wins["to"] = date
	else:
		win_streaks[club_id] = 0; win_start.erase(club_id)
