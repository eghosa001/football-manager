class_name LeagueTable
extends RefCounted

static func build(club_ids: Array, fixtures: Array, points_win: int = 3, points_draw: int = 1) -> Array:
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
		elif fixture.home_goals < fixture.away_goals:
			away.won += 1
			home.lost += 1
			away.points += points_win
		else:
			home.drawn += 1
			away.drawn += 1
			home.points += points_draw
			away.points += points_draw
		home.goal_difference = home.goals_for - home.goals_against
		away.goal_difference = away.goals_for - away.goals_against

	var table: Array = rows.values()
	table.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.points != b.points:
			return a.points > b.points
		if a.goal_difference != b.goal_difference:
			return a.goal_difference > b.goal_difference
		if a.goals_for != b.goals_for:
			return a.goals_for > b.goals_for
		if a.won != b.won:
			return a.won > b.won
		return String(a.club_id) < String(b.club_id)
	)
	return table
