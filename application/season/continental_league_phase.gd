class_name ContinentalLeaguePhase
extends RefCounted

const LeagueTableClass = preload("res://simulation/competitions/league_table.gd")
const ResolutionClass = preload("res://simulation/competitions/knockout_resolution_service.gd")
const CalendarClass = preload("res://core/calendar/calendar_service.gd")

const STAGES := ["knockout_playoff","round_of_16","quarterfinal","semifinal","final"]

func initialize(world: Dictionary, competition: Dictionary, season_year: int) -> void:
	if String(competition.get("competition_type","")) != "continental_league_phase": return
	_remove_competition_fixtures(world, String(competition.get("id","")))
	competition["season_year"] = season_year
	competition["stage"] = "league_phase"
	competition["champion_club_id"] = ""
	competition["league_phase_table"] = []
	competition["stage_history"] = []
	var clubs: Array = competition.get("club_ids",[]).duplicate()
	clubs.sort()
	var matches_per_club := int(competition.get("modern_league_phase",{}).get("matches_per_club",8))
	_append_league_phase(world,competition,clubs,matches_per_club,season_year)

func advance_ready(world: Dictionary, competition_id: String, current_date: String) -> Dictionary:
	var competition := _competition(world,competition_id)
	if competition.is_empty() or String(competition.get("competition_type","")) != "continental_league_phase": return {}
	var stage := String(competition.get("stage","league_phase"))
	if stage == "complete": return competition
	var fixtures := _stage_fixtures(world,competition_id,stage)
	if fixtures.is_empty(): return competition
	for fixture in fixtures:
		if not bool(fixture.get("played",false)): return competition
	match stage:
		"league_phase": _finish_league_phase(world,competition,current_date)
		"knockout_playoff", "round_of_16", "quarterfinal", "semifinal": _finish_two_leg_stage(world,competition,stage,current_date)
		"final": _finish_final(world,competition,fixtures)
	return competition

func record(world: Dictionary, competition: Dictionary) -> Dictionary:
	var fixtures: Array = []
	for fixture in world.get("fixtures",[]):
		if String(fixture.get("competition_id","")) == String(competition.get("id","")): fixtures.append(fixture)
	return {
		"competition_id":String(competition.get("id","")),
		"competition_name":String(competition.get("name","")),
		"season_start_year":int(competition.get("season_year",world.get("season_year",2026))),
		"tier":int(competition.get("continental_tier",1)),
		"complete":String(competition.get("stage","")) == "complete",
		"fixture_count":fixtures.size(),
		"table":competition.get("league_phase_table",[]).duplicate(true),
		"champion_club_id":String(competition.get("champion_club_id","")),
		"competition_type":"continental_league_phase",
		"stage_history":competition.get("stage_history",[]).duplicate(true),
	}

func _append_league_phase(world: Dictionary, competition: Dictionary, clubs: Array, matches_per_club: int, season_year: int) -> void:
	if clubs.size() < 4 or matches_per_club <= 0: return
	matches_per_club = mini(matches_per_club, clubs.size()-1)
	if matches_per_club % 2 != 0: matches_per_club -= 1
	var edges := _selected_round_robin_edges(clubs,matches_per_club)
	_orient_even_degree_edges(edges,clubs)
	var base := "%04d-09-17" % season_year
	for edge_index in range(edges.size()):
		var edge: Dictionary = edges[edge_index]
		var round_no := int(edge.round)
		var date := _add_days(base,(round_no-1)*21)
		world.fixtures.append({
			"id":"elp-%s-%d-r%d-%d" % [String(competition.id),season_year,round_no,edge_index],
			"competition_id":String(competition.id),"round":round_no,"stage":"league_phase","league_phase":true,
			"home_club_id":String(edge.home),"away_club_id":String(edge.away),"played":false,"home_goals":0,"away_goals":0,
			"date":date,"season_year":season_year,"away_goals":false,
		})

func _selected_round_robin_edges(clubs: Array, round_count: int) -> Array:
	var teams := clubs.duplicate()
	if teams.size() % 2 != 0: teams.append("")
	var count := teams.size()
	var edges: Array = []
	for round_index in range(round_count):
		for pair_index in range(count/2):
			var a := String(teams[pair_index]); var b := String(teams[count-1-pair_index])
			if a != "" and b != "": edges.append({"a":a,"b":b,"round":round_index+1,"home":"","away":""})
		var fixed := teams[0]
		var rotating := teams.slice(1)
		rotating.push_front(rotating.pop_back())
		teams = [fixed]; teams.append_array(rotating)
	return edges

func _orient_even_degree_edges(edges: Array, clubs: Array) -> void:
	# Every club has an even league-phase degree (8 or 6). Orienting each closed
	# Euler trail gives every club exactly half its fixtures at home and half away.
	var incident := {}
	for club_id in clubs: incident[String(club_id)] = []
	for index in range(edges.size()):
		incident[String(edges[index].a)].append(index)
		incident[String(edges[index].b)].append(index)
	var used := {}
	for edge_index in range(edges.size()):
		if used.has(edge_index): continue
		var current := String(edges[edge_index].a)
		while true:
			var next_edge := -1
			for candidate in incident.get(current,[]):
				if not used.has(int(candidate)):
					next_edge = int(candidate); break
			if next_edge < 0: break
			used[next_edge] = true
			var edge: Dictionary = edges[next_edge]
			var other := String(edge.b) if String(edge.a) == current else String(edge.a)
			edge.home = current; edge.away = other
			current = other

func _finish_league_phase(world: Dictionary, competition: Dictionary, current_date: String) -> void:
	var fixtures := _stage_fixtures(world,String(competition.id),"league_phase")
	var table := LeagueTableClass.build(competition.club_ids,fixtures,int(competition.get("points_win",3)),int(competition.get("points_draw",1)))
	competition["league_phase_table"] = table.duplicate(true)
	var direct: Array = []
	var playoff: Array = []
	for i in range(table.size()):
		var club_id := String(table[i].club_id)
		if i < 8: direct.append(club_id)
		elif i < 24: playoff.append(club_id)
	competition["direct_round_of_16"] = direct
	competition["knockout_playoff_clubs"] = playoff
	competition.stage_history.append({"stage":"league_phase","table":table.duplicate(true),"qualified_direct":direct.duplicate(),"qualified_playoff":playoff.duplicate()})
	if playoff.size() < 2:
		competition["stage"] = "complete"
		competition["champion_club_id"] = direct[0] if not direct.is_empty() else ""
		return
	var pairings: Array = []
	for i in range(playoff.size()/2): pairings.append({"seeded":String(playoff[i]),"unseeded":String(playoff[playoff.size()-1-i])})
	competition["stage"] = "knockout_playoff"
	_append_two_leg_stage(world,competition,"knockout_playoff",pairings,_add_days(current_date,28))

func _finish_two_leg_stage(world: Dictionary, competition: Dictionary, stage: String, current_date: String) -> void:
	var fixtures := _stage_fixtures(world,String(competition.id),stage)
	var ties := {}
	for fixture in fixtures:
		var tie_id := String(fixture.get("tie_id",""))
		if not ties.has(tie_id): ties[tie_id] = []
		ties[tie_id].append(fixture)
	var winners: Array = []
	for tie_id in ties.keys():
		var legs: Array = ties[tie_id]
		legs.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.get("leg",1)) < int(b.get("leg",1)))
		if legs.size() != 2: return
		var first: Dictionary = legs[0]; var second: Dictionary = legs[1]
		var club_a := String(first.get("away_club_id",""))
		var club_b := String(first.get("home_club_id",""))
		var a_goals := int(first.get("away_goals",0)) + int(second.get("home_goals",0))
		var b_goals := int(first.get("home_goals",0)) + int(second.get("away_goals",0))
		var winner := ""
		if a_goals != b_goals:
			winner = club_a if a_goals > b_goals else club_b
		else:
			var resolution := ResolutionClass.new().resolve_level_aggregate(world,second,competition,_stable_seed(String(second.id),int(competition.get("season_year",0))))
			for key in resolution.keys(): second[key] = resolution[key]
			winner = String(resolution.get("winner",""))
		second["aggregate_home_goals"] = a_goals
		second["aggregate_away_goals"] = b_goals
		second["aggregate_winner"] = winner
		winners.append(winner)
	competition.stage_history.append({"stage":stage,"winners":winners.duplicate()})
	var next_stage := _next_stage(stage)
	competition["stage"] = next_stage
	if next_stage == "round_of_16":
		var direct: Array = competition.get("direct_round_of_16",[]).duplicate()
		var pairings: Array = []
		for i in range(mini(direct.size(),winners.size())): pairings.append({"seeded":String(direct[i]),"unseeded":String(winners[winners.size()-1-i])})
		_append_two_leg_stage(world,competition,next_stage,pairings,_add_days(current_date,21))
	elif next_stage in ["quarterfinal","semifinal"]:
		var pairings: Array = []
		for i in range(0,winners.size(),2):
			if i+1 < winners.size(): pairings.append({"seeded":String(winners[i]),"unseeded":String(winners[i+1])})
		_append_two_leg_stage(world,competition,next_stage,pairings,_add_days(current_date,21))
	elif next_stage == "final":
		_append_final(world,competition,winners,_add_days(current_date,21))

func _finish_final(world: Dictionary, competition: Dictionary, fixtures: Array) -> void:
	if fixtures.is_empty(): return
	var fixture: Dictionary = fixtures[0]
	var home := String(fixture.get("home_club_id","")); var away := String(fixture.get("away_club_id",""))
	var winner := ""
	if int(fixture.home_goals) != int(fixture.away_goals): winner = home if int(fixture.home_goals)>int(fixture.away_goals) else away
	else:
		var resolution := ResolutionClass.new().resolve_level_match(world,fixture,competition,_stable_seed(String(fixture.id),int(competition.get("season_year",0))))
		for key in resolution.keys(): fixture[key] = resolution[key]
		winner = String(resolution.get("winner",""))
	competition["champion_club_id"] = winner
	competition["stage"] = "complete"
	competition.stage_history.append({"stage":"final","winner":winner,"runner_up":away if winner==home else home})

func _append_two_leg_stage(world: Dictionary, competition: Dictionary, stage: String, pairings: Array, first_date: String) -> void:
	var season_year := int(competition.get("season_year",world.get("season_year",2026)))
	for i in range(pairings.size()):
		var seeded := String(pairings[i].seeded); var unseeded := String(pairings[i].unseeded)
		var tie_id := "%s-%s-%d" % [String(competition.id),stage,i]
		var date1 := _conflict_free_date(world,unseeded,seeded,first_date)
		var date2 := _conflict_free_date(world,seeded,unseeded,_add_days(date1,7))
		world.fixtures.append(_fixture("%s-l1" % tie_id,String(competition.id),stage,i+1,unseeded,seeded,date1,season_year,tie_id,1))
		world.fixtures.append(_fixture("%s-l2" % tie_id,String(competition.id),stage,i+1,seeded,unseeded,date2,season_year,tie_id,2))

func _append_final(world: Dictionary, competition: Dictionary, winners: Array, date_string: String) -> void:
	if winners.size() < 2: return
	var season_year := int(competition.get("season_year",world.get("season_year",2026)))
	var home := String(winners[0]); var away := String(winners[1])
	var date := _conflict_free_date(world,home,away,date_string)
	var row := _fixture("%s-final-%d" % [String(competition.id),season_year],String(competition.id),"final",1,home,away,date,season_year,"final",1)
	row["neutral_venue"] = true; row["single_leg"] = true
	world.fixtures.append(row)

func _fixture(id: String, competition_id: String, stage: String, round_no: int, home: String, away: String, date: String, season_year: int, tie_id: String, leg: int) -> Dictionary:
	return {"id":id,"competition_id":competition_id,"stage":stage,"round":round_no,"home_club_id":home,"away_club_id":away,"date":date,"season_year":season_year,"played":false,"home_goals":0,"away_goals":0,"continental_knockout":true,"tie_id":tie_id,"leg":leg,"away_goals":false,"extra_time":leg==2,"penalties":leg==2}

func _stage_fixtures(world: Dictionary, competition_id: String, stage: String) -> Array:
	var rows: Array = []
	for fixture in world.get("fixtures",[]):
		if String(fixture.get("competition_id","")) == competition_id and String(fixture.get("stage","")) == stage: rows.append(fixture)
	return rows

func _next_stage(stage: String) -> String:
	match stage:
		"knockout_playoff": return "round_of_16"
		"round_of_16": return "quarterfinal"
		"quarterfinal": return "semifinal"
		"semifinal": return "final"
	return "complete"

func _remove_competition_fixtures(world: Dictionary, competition_id: String) -> void:
	var keep: Array = []
	for fixture in world.get("fixtures",[]):
		if String(fixture.get("competition_id","")) != competition_id: keep.append(fixture)
	world["fixtures"] = keep

func _competition(world: Dictionary, competition_id: String) -> Dictionary:
	for competition in world.get("competitions",[]):
		if String(competition.get("id","")) == competition_id: return competition
	return {}

func _conflict_free_date(world: Dictionary, home: String, away: String, requested: String) -> String:
	var date := requested
	for _guard in range(12):
		var conflict := false
		for fixture in world.get("fixtures",[]):
			if String(fixture.get("date","")) != date: continue
			if String(fixture.get("home_club_id","")) in [home,away] or String(fixture.get("away_club_id","")) in [home,away]: conflict = true; break
		if not conflict: return date
		date = _add_days(date,1)
	return date

func _add_days(date_string: String, days: int) -> String:
	var p := date_string.split("-")
	var calendar = CalendarClass.new(); calendar.set_date(int(p[0]),int(p[1]),int(p[2])); calendar.advance_days(days)
	return calendar.get_date_string()

func _stable_seed(text: String, salt: int) -> int:
	var value := 113 + salt
	for c in text.to_utf8_buffer(): value = posmod(value*199+int(c),2_147_483_647)
	return value if value != 0 else 1
