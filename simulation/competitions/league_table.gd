class_name LeagueTable
extends RefCounted

static func build(club_ids: Array, fixtures: Array, points_win: int = 3, points_draw: int = 1, tie_breakers: Array = ["points","goal_difference","goals_scored","wins","head_to_head_points"]) -> Array:
	var rows := {}
	for club_id in club_ids:
		rows[String(club_id)] = {"club_id":String(club_id),"played":0,"won":0,"drawn":0,"lost":0,"goals_for":0,"goals_against":0,"goal_difference":0,"points":0,"form":[]}
	for fixture in fixtures:
		if not bool(fixture.get("played",false)): continue
		var home_id := String(fixture.get("home_club_id","")); var away_id := String(fixture.get("away_club_id",""))
		if not rows.has(home_id) or not rows.has(away_id): continue
		var home: Dictionary = rows[home_id]; var away: Dictionary = rows[away_id]
		var hg := int(fixture.get("home_goals",0)); var ag := int(fixture.get("away_goals",0))
		home.played += 1; away.played += 1
		home.goals_for += hg; home.goals_against += ag; away.goals_for += ag; away.goals_against += hg
		if hg > ag:
			home.won += 1; away.lost += 1; home.points += points_win; home.form.append("W"); away.form.append("L")
		elif hg < ag:
			away.won += 1; home.lost += 1; away.points += points_win; away.form.append("W"); home.form.append("L")
		else:
			home.drawn += 1; away.drawn += 1; home.points += points_draw; away.points += points_draw; home.form.append("D"); away.form.append("D")
		home.goal_difference = home.goals_for - home.goals_against; away.goal_difference = away.goals_for - away.goals_against
		home.form = home.form.slice(maxi(0,home.form.size()-5)); away.form = away.form.slice(maxi(0,away.form.size()-5))
	var hth: Dictionary = _head_to_head(fixtures,club_ids,points_win,points_draw)
	var table: Array = rows.values()
	table.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		for breaker_value in tie_breakers:
			var breaker := String(breaker_value)
			match breaker:
				"points":
					if int(a.points) != int(b.points): return int(a.points) > int(b.points)
				"goal_difference":
					if int(a.goal_difference) != int(b.goal_difference): return int(a.goal_difference) > int(b.goal_difference)
				"goals_scored":
					if int(a.goals_for) != int(b.goals_for): return int(a.goals_for) > int(b.goals_for)
				"wins":
					if int(a.won) != int(b.won): return int(a.won) > int(b.won)
				"head_to_head", "head_to_head_points":
					var av := _hth(hth,String(a.club_id),String(b.club_id),"points"); var bv := _hth(hth,String(b.club_id),String(a.club_id),"points")
					if av != bv: return av > bv
				"head_to_head_goal_difference":
					var av := _hth(hth,String(a.club_id),String(b.club_id),"goal_difference"); var bv := _hth(hth,String(b.club_id),String(a.club_id),"goal_difference")
					if av != bv: return av > bv
				"head_to_head_goals":
					var av := _hth(hth,String(a.club_id),String(b.club_id),"goals_for"); var bv := _hth(hth,String(b.club_id),String(a.club_id),"goals_for")
					if av != bv: return av > bv
				"head_to_head_away_goals":
					var av := _hth(hth,String(a.club_id),String(b.club_id),"away_goals"); var bv := _hth(hth,String(b.club_id),String(a.club_id),"away_goals")
					if av != bv: return av > bv
		return String(a.club_id) < String(b.club_id)
	)
	for i in range(table.size()): table[i]["position"] = i+1
	return table

static func _head_to_head(fixtures: Array,club_ids: Array,points_win: int,points_draw: int) -> Dictionary:
	var metrics := {}; var valid := {}
	for id in club_ids: valid[String(id)] = true
	for fixture in fixtures:
		if not bool(fixture.get("played",false)): continue
		var home := String(fixture.get("home_club_id","")); var away := String(fixture.get("away_club_id",""))
		if not valid.has(home) or not valid.has(away): continue
		var hg := int(fixture.get("home_goals",0)); var ag := int(fixture.get("away_goals",0)); var hk := home+"|"+away; var ak := away+"|"+home
		if not metrics.has(hk): metrics[hk] = _empty_hth()
		if not metrics.has(ak): metrics[ak] = _empty_hth()
		metrics[hk].goals_for += hg; metrics[hk].goals_against += ag; metrics[ak].goals_for += ag; metrics[ak].goals_against += hg; metrics[ak].away_goals += ag
		if hg > ag: metrics[hk].points += points_win
		elif hg < ag: metrics[ak].points += points_win
		else: metrics[hk].points += points_draw; metrics[ak].points += points_draw
		metrics[hk].goal_difference = int(metrics[hk].goals_for)-int(metrics[hk].goals_against); metrics[ak].goal_difference = int(metrics[ak].goals_for)-int(metrics[ak].goals_against)
	return metrics

static func _empty_hth() -> Dictionary:
	return {"points":0,"goals_for":0,"goals_against":0,"goal_difference":0,"away_goals":0}

static func _hth(metrics: Dictionary,club_id: String,opponent_id: String,field: String) -> int:
	return int(metrics.get(club_id+"|"+opponent_id,{}).get(field,0))
