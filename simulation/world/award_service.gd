class_name AwardService
extends RefCounted

func ensure_world(world: Dictionary) -> void:
	world["awards"] = world.get("awards", [])

func calculate_season_awards(world: Dictionary, season_year: int, competition_id: String = "") -> Array:
	ensure_world(world)
	var stats := _aggregate(world,season_year,competition_id)
	var awards: Array = []
	if not stats.is_empty():
		awards.append(_winner("player_of_the_year",stats,func(row): return _overall_score(row),season_year,competition_id))
		awards.append(_winner("top_scorer",stats,func(row): return float(row.get("goals",0)),season_year,competition_id))
		awards.append(_winner("playmaker",stats,func(row): return float(row.get("assists",0))*1.5+float(row.get("key_passes",0))*0.15+float(row.get("xa",0.0)),season_year,competition_id))
		awards.append(_winner("young_player",stats.filter(func(row): return int(row.get("age",99))<=21),func(row): return _overall_score(row),season_year,competition_id))
		awards.append(_winner("goalkeeper",stats.filter(func(row): return String(row.get("position",""))=="GK"),func(row): return float(row.get("clean_sheets",0))*2.0+float(row.get("saves",0))*0.12-float(row.get("goals_conceded",0))*0.25+float(row.get("rating_sum",0.0))*0.08,season_year,competition_id))
	awards=awards.filter(func(row): return not row.is_empty())
	for award in awards:
		world.awards.append(award)
	return awards

func _aggregate(world: Dictionary, season_year: int, competition_id: String) -> Array:
	var rows := {}
	for stat in world.get("player_match_stats",[]):
		if int(stat.get("season_year",season_year))!=season_year: continue
		if competition_id!="" and String(stat.get("competition_id",""))!=competition_id: continue
		var id:=String(stat.get("player_id",""))
		if id=="":continue
		if not rows.has(id):
			var player:=_player(world.get("players",[]),id)
			rows[id]={"player_id":id,"age":int(player.get("age",25)),"position":String(player.get("position","")),"club_id":String(player.get("club_id","")),"appearances":0,"minutes":0,"goals":0,"assists":0,"key_passes":0,"xa":0.0,"xg":0.0,"clean_sheets":0,"saves":0,"goals_conceded":0,"rating_sum":0.0,"rating_count":0,"competition_strength_sum":0.0}
		var row:Dictionary=rows[id]
		row.appearances=int(row.appearances)+1
		row.minutes=int(row.minutes)+int(stat.get("minutes",90))
		row.goals=int(row.goals)+int(stat.get("goals",0))
		row.assists=int(row.assists)+int(stat.get("assists",0))
		row.key_passes=int(row.key_passes)+int(stat.get("key_passes",0))
		row.xa=float(row.xa)+float(stat.get("xa",0.0))
		row.xg=float(row.xg)+float(stat.get("xg",0.0))
		row.clean_sheets=int(row.clean_sheets)+int(stat.get("clean_sheet",0))
		row.saves=int(row.saves)+int(stat.get("saves",0))
		row.goals_conceded=int(row.goals_conceded)+int(stat.get("goals_conceded",0))
		if stat.has("rating"):
			row.rating_sum=float(row.rating_sum)+float(stat.rating); row.rating_count=int(row.rating_count)+1
		row.competition_strength_sum=float(row.competition_strength_sum)+_competition_strength(world,String(stat.get("competition_id","")))
	var result:Array=[]
	for id in rows.keys(): result.append(rows[id])
	return result

func _overall_score(row: Dictionary) -> float:
	var appearances:=maxi(1,int(row.get("appearances",0)))
	var avg_rating:=float(row.get("rating_sum",0.0))/maxf(1.0,float(row.get("rating_count",0)))
	var competition_strength:=float(row.get("competition_strength_sum",0.0))/float(appearances)
	var contribution:=float(row.get("goals",0))*2.1+float(row.get("assists",0))*1.65+float(row.get("key_passes",0))*0.08+float(row.get("xg",0.0))*0.16+float(row.get("xa",0.0))*0.22
	if String(row.get("position",""))=="GK": contribution+=float(row.get("clean_sheets",0))*1.9+float(row.get("saves",0))*0.09-float(row.get("goals_conceded",0))*0.22
	return contribution+avg_rating*appearances*0.12+competition_strength*appearances*0.08

func _winner(kind: String, rows: Array, scorer: Callable, year: int, competition_id: String) -> Dictionary:
	if rows.is_empty():return {}
	var best:Dictionary={};var best_score:=-INF
	for row in rows:
		if int(row.get("appearances",0))<3:continue
		var score:=float(scorer.call(row))
		if score>best_score or (is_equal_approx(score,best_score) and String(row.get("player_id",""))<String(best.get("player_id","~"))):best=row;best_score=score
	if best.is_empty():return {}
	return {"type":kind,"season_year":year,"competition_id":competition_id,"player_id":String(best.player_id),"club_id":String(best.get("club_id","")),"score":best_score,"reason_codes":["season_statistics","competition_strength","positional_performance"]}

func _competition_strength(world: Dictionary, id: String) -> float:
	for competition in world.get("competitions",[]):
		if String(competition.get("id",""))==id:return clampf(float(competition.get("reputation",competition.get("strength",50)))/100.0,0.1,1.0)
	return 0.5

func _player(players:Array,id:String)->Dictionary:
	for player in players:
		if String(player.get("id",""))==id:return player
	return {}
