class_name LeagueTable
extends RefCounted

static func build(club_ids: Array, fixtures: Array, points_win: int = 3, points_draw: int = 1, tie_breakers: Array = ["points", "goal_difference", "goals_scored", "wins", "head_to_head"]) -> Array:
	var rows := {}
	for club_id in club_ids:
		rows[club_id] = {
			"club_id": club_id,
			"played": 0,
			"won": 0,
			"drawn": 0,
			"lost": 0,
			"goals_for": 0,
			"goals_against": 0,
			"goal_difference": 0,
			"points": 0,
			"form": [],
		}
	for fixture in fixtures:
		if not fixture.played:
			continue
		if not rows.has(fixture.home_club_id) or not rows.has(fixture.away_club_id):
			continue
		var home: Dictionary = rows[fixture.home_club_id]
		var away: Dictionary = rows[fixture.away_club_id]
		home.played += 1
		away.played += 1
		home.goals_for += fixture.home_goals
		home.goals_against += fixture.away_goals
		away.goals_for += fixture.away_goals
		away.goals_against += fixture.home_goals
		if fixture.home_goals > fixture.away_goals:
			home.won += 1
			away.lost += 1
			home.points += points_win
			home.form.append("W")
			away.form.append("L")
		elif fixture.home_goals < fixture.away_goals:
			away.won += 1
			home.lost += 1
			away.points += points_win
			away.form.append("W")
			home.form.append("L")
		else:
			home.drawn += 1
			away.drawn += 1
			home.points += points_draw
			away.points += points_draw
			home.form.append("D")
			away.form.append("D")
		home.goal_difference = home.goals_for - home.goals_against
		away.goal_difference = away.goals_for - away.goals_against
		home.form = home.form.slice(maxi(0, home.form.size() - 5))
		away.form = away.form.slice(maxi(0, away.form.size() - 5))

	var hth := _head_to_head(fixtures, club_ids)
	var table: Array = rows.values()
	table.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		for breaker in tie_breakers:
			match String(breaker):
				"points":
					if int(a.points) != int(b.points):
						return int(a.points) > int(b.points)
				"goal_difference":
					if int(a.goal_difference) != int(b.goal_difference):
						return int(a.goal_difference) > int(b.goal_difference)
				"goals_scored":
					if int(a.goals_for) != int(b.goals_for):
						return int(a.goals_for) > int(b.goals_for)
				"wins":
					if int(a.won) != int(b.won):
						return int(a.won) > int(b.won)
				"head_to_head":
					var key := String(a.club_id) + "|" + String(b.club_id)
					if hth.has(key) and hth.has(String(b.club_id) + "|" + String(a.club_id)) and int(hth[key]) != int(hth[String(b.club_id) + "|" + String(a.club_id)]):
						return int(hth[key]) > int(hth[String(b.club_id) + "|" + String(a.club_id)])
		return String(a.club_id) < String(b.club_id)
	)
	return table

static func _head_to_head(fixtures: Array, club_ids: Array) -> Dictionary:
	var points := {}
	for fixture in fixtures:
		if not bool(fixture.get("played", false)):
			continue
		var home := String(fixture.get("home_club_id", ""))
		var away := String(fixture.get("away_club_id", ""))
		if home not in club_ids or away not in club_ids:
			continue
		var hg := int(fixture.get("home_goals", 0))
		var ag := int(fixture.get("away_goals", 0))
		points["%s|%s" % [home, away]] = int(points.get("%s|%s" % [home, away], 0)) + (3 if hg > ag else (1 if hg == ag else 0))
		points["%s|%s" % [away, home]] = int(points.get("%s|%s" % [away, home], 0)) + (3 if ag > hg else (1 if hg == ag else 0))
	return points
