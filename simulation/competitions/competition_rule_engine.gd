class_name CompetitionRuleEngine
extends RefCounted

func normalize_rules(rules: Dictionary) -> Dictionary:
	return {
		"points_win":int(rules.get("points_win",3)),
		"points_draw":int(rules.get("points_draw",1)),
		"tie_breakers":rules.get("tie_breakers",["points","goal_difference","goals_scored","wins","head_to_head"]),
		"substitutes_allowed":clampi(int(rules.get("substitutes_allowed",5)),0,12),
		"substitution_windows":clampi(int(rules.get("substitution_windows",3)),0,6),
		"extra_time_substitute":clampi(int(rules.get("extra_time_substitute",1)),0,3),
		"extra_time":bool(rules.get("extra_time",true)),
		"extra_time_minutes":clampi(int(rules.get("extra_time_minutes",30)),0,30),
		"penalties":bool(rules.get("penalties",true)),
		"away_goals":bool(rules.get("away_goals",false)),
		"replays":bool(rules.get("replays",false)),
		"seeded_draw":bool(rules.get("seeded_draw",false)),
		"same_country_restriction":bool(rules.get("same_country_restriction",false)),
		"byes":maxi(0,int(rules.get("byes",0))),
		"squad_size":maxi(11,int(rules.get("squad_size",25))),
		"homegrown_min":maxi(0,int(rules.get("homegrown_min",0))),
		"foreign_max":maxi(0,int(rules.get("foreign_max",999))),
		"yellow_limit":maxi(1,int(rules.get("yellow_limit",5))),
		"red_ban_matches":maxi(1,int(rules.get("red_ban_matches",1))),
		"two_yellow_ban_matches":maxi(1,int(rules.get("two_yellow_ban_matches",1))),
		"qualification":rules.get("qualification",{}),
		"registration_windows":rules.get("registration_windows",[])
	}

func rank_table(rows: Array, rules: Dictionary, head_to_head: Dictionary = {}) -> Array:
	var normalized := normalize_rules(rules)
	var result := rows.duplicate(true)
	var breakers: Array = normalized.tie_breakers
	result.sort_custom(func(a: Dictionary,b: Dictionary):
		for breaker in breakers:
			var av = _metric(a,String(breaker),head_to_head)
			var bv = _metric(b,String(breaker),head_to_head)
			if av == bv: continue
			return av > bv
		return String(a.get("club_id",a.get("id",""))) < String(b.get("club_id",b.get("id","")))
	)
	return result

func resolve_knockout(home_goals: int, away_goals: int, rules: Dictionary, extra_time_home: int = 0, extra_time_away: int = 0, penalties_home: int = 0, penalties_away: int = 0) -> Dictionary:
	var normalized := normalize_rules(rules)
	if home_goals != away_goals:
		return {"winner":"home" if home_goals > away_goals else "away","method":"normal_time","home_total":home_goals,"away_total":away_goals}
	if bool(normalized.extra_time) and int(normalized.extra_time_minutes) > 0:
		var ht := home_goals + extra_time_home
		var at := away_goals + extra_time_away
		if ht != at:
			return {"winner":"home" if ht > at else "away","method":"extra_time","home_total":ht,"away_total":at}
	if bool(normalized.penalties) and penalties_home != penalties_away:
		return {"winner":"home" if penalties_home > penalties_away else "away","method":"penalties","home_total":home_goals+extra_time_home,"away_total":away_goals+extra_time_away,"penalties_home":penalties_home,"penalties_away":penalties_away}
	if bool(normalized.replays): return {"winner":"","method":"replay_required"}
	return {"winner":"","method":"unresolved"}

func validate_registration(players: Array, rules: Dictionary) -> Dictionary:
	var normalized := normalize_rules(rules)
	var reasons: Array = []
	if players.size() > int(normalized.squad_size): reasons.append("squad_size_exceeded")
	var homegrown := 0
	var foreign := 0
	for player in players:
		if bool(player.get("homegrown",false)): homegrown += 1
		if bool(player.get("foreign",false)): foreign += 1
	if homegrown < int(normalized.homegrown_min): reasons.append("homegrown_minimum_not_met")
	if foreign > int(normalized.foreign_max): reasons.append("foreign_player_limit_exceeded")
	return {"ok":reasons.is_empty(),"reason_codes":reasons,"homegrown":homegrown,"foreign":foreign}

func validate_modern_rules(rules: Dictionary) -> Array:
	var normalized := normalize_rules(rules)
	var errors: Array = []
	if int(normalized.substitutes_allowed) != 5: errors.append("substitutes_allowed")
	if int(normalized.substitution_windows) != 3: errors.append("substitution_windows")
	if int(normalized.extra_time_minutes) != 30: errors.append("extra_time_minutes")
	if bool(normalized.away_goals): errors.append("away_goals")
	return errors

func draw_round(teams: Array, rules: Dictionary, seed: int) -> Dictionary:
	var normalized := normalize_rules(rules)
	var pool := teams.duplicate(true)
	pool.sort_custom(func(a: Dictionary,b: Dictionary): return _stable_order(String(a.get("id","")),seed) < _stable_order(String(b.get("id","")),seed))
	var byes: Array = []
	for i in range(mini(int(normalized.byes),pool.size())):
		byes.append(pool.pop_front())
	var ties: Array = []
	while pool.size() >= 2:
		var home: Dictionary = pool.pop_front()
		var opponent_index := _eligible_opponent_index(home,pool,normalized)
		if opponent_index < 0: opponent_index = 0
		var away: Dictionary = pool[opponent_index]
		pool.remove_at(opponent_index)
		ties.append({"home":home,"away":away})
	if not pool.is_empty(): byes.append(pool.pop_front())
	return {"ties":ties,"byes":byes}

func qualification_cascade(table: Array, rules: Dictionary) -> Dictionary:
	var q: Dictionary = normalize_rules(rules).qualification
	var result := {"champions":[],"continental":[],"playoff":[],"relegated":[]}
	for i in range(table.size()):
		var id := String(table[i].get("club_id",table[i].get("id","")))
		if i < int(q.get("champions",1)): result.champions.append(id)
		if i < int(q.get("continental_places",0)): result.continental.append(id)
		if i >= maxi(0,table.size()-int(q.get("relegation_places",0))): result.relegated.append(id)
	for pos in q.get("playoff_positions",[]):
		var idx := int(pos)-1
		if idx >= 0 and idx < table.size(): result.playoff.append(String(table[idx].get("club_id",table[idx].get("id",""))))
	return result

func _metric(row: Dictionary, key: String, head_to_head: Dictionary):
	match key:
		"points": return int(row.get("points",0))
		"goal_difference": return int(row.get("goal_difference",int(row.get("goals_for",0))-int(row.get("goals_against",0))))
		"goals_for", "goals_scored": return int(row.get("goals_for",0))
		"wins": return int(row.get("wins",row.get("won",0)))
		"head_to_head": return float(head_to_head.get(String(row.get("club_id",row.get("id",""))),0.0))
	return 0

func _eligible_opponent_index(team: Dictionary, pool: Array, rules: Dictionary) -> int:
	for i in range(pool.size()):
		var opponent: Dictionary = pool[i]
		if bool(rules.same_country_restriction) and String(team.get("country_id","")) == String(opponent.get("country_id","")): continue
		if bool(rules.seeded_draw) and String(team.get("seed_group","")) == String(opponent.get("seed_group","")) and String(team.get("seed_group","")) != "": continue
		return i
	return -1

func _stable_order(text: String, seed: int) -> int:
	var value := seed + 31
	for b in text.to_utf8_buffer(): value = posmod(value*131+int(b),2_147_483_647)
	return value
