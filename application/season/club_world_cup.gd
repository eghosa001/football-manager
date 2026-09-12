class_name ClubWorldCup
extends RefCounted

const LeagueTableClass = preload("res://simulation/competitions/league_table.gd")
const ResolutionClass = preload("res://simulation/competitions/knockout_resolution_service.gd")
const CalendarClass = preload("res://core/calendar/calendar_service.gd")

const GROUP_COUNT := 8
const GROUP_SIZE := 4
const STAGES := ["group_stage","round_of_16","quarterfinal","semifinal","final"]

func initialize(world: Dictionary, competition: Dictionary, season_year: int) -> void:
	if String(competition.get("competition_type","")) != "club_world_cup": return
	_remove_fixtures(world,String(competition.get("id","")))
	competition["season_year"] = season_year
	competition["stage"] = "inactive"
	competition["champion_club_id"] = ""
	competition["group_tables"] = []
	competition["stage_history"] = []
	var host_year := season_year + 1
	competition["tournament_year"] = host_year
	if host_year % 4 != 1: return
	var clubs: Array = competition.get("club_ids",[]).duplicate()
	if clubs.size() < 32: return
	clubs = clubs.slice(0,32)
	var groups := _seed_groups(clubs)
	competition["groups"] = groups
	competition["stage"] = "group_stage"
	_append_group_fixtures(world,competition,groups,season_year)

func advance_ready(world: Dictionary, competition_id: String, current_date: String) -> Dictionary:
	var competition := _competition(world,competition_id)
	if competition.is_empty() or String(competition.get("competition_type","")) != "club_world_cup": return {}
	var stage := String(competition.get("stage","inactive"))
	if stage in ["inactive","complete"]: return competition
	var fixtures := _stage_fixtures(world,competition_id,stage)
	if fixtures.is_empty(): return competition
	for fixture in fixtures:
		if not bool(fixture.get("played",false)): return competition
	if stage == "group_stage": _finish_groups(world,competition,current_date)
	else: _finish_knockout_stage(world,competition,stage,current_date)
	return competition

func record(world: Dictionary, competition: Dictionary) -> Dictionary:
	var fixtures: Array = []
	for fixture in world.get("fixtures",[]):
		if String(fixture.get("competition_id","")) == String(competition.get("id","")): fixtures.append(fixture)
	return {
		"competition_id":String(competition.get("id","")),"competition_name":String(competition.get("name","Club World Cup")),
		"season_start_year":int(competition.get("season_year",world.get("season_year",2026))),"tier":0,
		"complete":String(competition.get("stage","")) == "complete" or String(competition.get("stage","")) == "inactive",
		"fixture_count":fixtures.size(),"table":[],"champion_club_id":String(competition.get("champion_club_id","")),
		"competition_type":"club_world_cup","stage_history":competition.get("stage_history",[]).duplicate(true)
	}

func _seed_groups(clubs: Array) -> Array:
	var ordered := clubs.duplicate(); ordered.sort()
	var groups: Array = []
	for i in range(GROUP_COUNT): groups.append([])
	for i in range(ordered.size()):
		var pot := i / GROUP_COUNT
		var slot := i % GROUP_COUNT
		var group_index := slot if pot % 2 == 0 else GROUP_COUNT-1-slot
		groups[group_index].append(String(ordered[i]))
	return groups

func _append_group_fixtures(world: Dictionary, competition: Dictionary, groups: Array, season_year: int) -> void:
	var base := "%04d-06-15" % (season_year+1)
	for group_index in range(groups.size()):
		var teams: Array = groups[group_index].duplicate()
		for round_index in range(3):
			var pairs := [[0,3],[1,2]]
			for pair_index in range(2):
				var a := String(teams[int(pairs[pair_index][0])]); var b := String(teams[int(pairs[pair_index][1])])
				var home := a if (round_index+pair_index)%2==0 else b; var away := b if home==a else a
				world.fixtures.append({"id":"cwc-%d-g%d-r%d-m%d" % [season_year,group_index+1,round_index+1,pair_index+1],"competition_id":String(competition.id),"stage":"group_stage","group":group_index+1,"round":round_index+1,"home_club_id":home,"away_club_id":away,"date":_add_days(base,round_index*5),"season_year":season_year,"played":false,"home_goals":0,"away_goals":0})
			var fixed: String = String(teams[0]); var rotating: Array = teams.slice(1); rotating.push_front(rotating.pop_back()); teams=[fixed]; teams.append_array(rotating)

func _finish_groups(world: Dictionary, competition: Dictionary, current_date: String) -> void:
	var groups: Array = competition.get("groups",[])
	var tables: Array = []; var winners: Array = []; var runners: Array = []
	for group_index in range(groups.size()):
		var fixtures: Array = []
		for fixture in _stage_fixtures(world,String(competition.id),"group_stage"):
			if int(fixture.get("group",0)) == group_index+1: fixtures.append(fixture)
		var table := LeagueTableClass.build(groups[group_index],fixtures,3,1,["points","goal_difference","goals_scored","wins"])
		tables.append(table)
		if table.size() >= 2:
			winners.append(String(table[0].club_id)); runners.append(String(table[1].club_id))
	competition["group_tables"] = tables
	competition.stage_history.append({"stage":"group_stage","tables":tables.duplicate(true)})
	var pairings: Array = []
	for i in range(0,8,2):
		pairings.append([String(winners[i]),String(runners[i+1])])
		pairings.append([String(winners[i+1]),String(runners[i])])
	competition["stage"] = "round_of_16"
	_append_knockout_fixtures(world,competition,"round_of_16",pairings,_add_days(current_date,4))

func _finish_knockout_stage(world: Dictionary, competition: Dictionary, stage: String, current_date: String) -> void:
	var winners: Array = []
	for fixture in _stage_fixtures(world,String(competition.id),stage):
		var home := String(fixture.home_club_id); var away := String(fixture.away_club_id); var winner := ""
		if int(fixture.home_goals) != int(fixture.away_goals): winner = home if int(fixture.home_goals)>int(fixture.away_goals) else away
		else:
			var resolution := ResolutionClass.new().resolve_level_match(world,fixture,competition,_stable_seed(String(fixture.id),int(competition.get("season_year",0))))
			for key in resolution.keys(): fixture[key] = resolution[key]
			winner = String(resolution.get("winner",""))
		winners.append(winner)
	competition.stage_history.append({"stage":stage,"winners":winners.duplicate()})
	if stage == "final":
		competition["champion_club_id"] = String(winners[0]) if not winners.is_empty() else ""
		competition["stage"] = "complete"
		return
	var next_stage := "quarterfinal" if stage=="round_of_16" else ("semifinal" if stage=="quarterfinal" else "final")
	var pairings: Array = []
	for i in range(0,winners.size(),2):
		if i+1 < winners.size(): pairings.append([String(winners[i]),String(winners[i+1])])
	competition["stage"] = next_stage
	_append_knockout_fixtures(world,competition,next_stage,pairings,_add_days(current_date,4))

func _append_knockout_fixtures(world: Dictionary, competition: Dictionary, stage: String, pairings: Array, requested: String) -> void:
	for i in range(pairings.size()):
		var home := String(pairings[i][0]); var away := String(pairings[i][1]); var date := _conflict_free_date(world,home,away,requested)
		world.fixtures.append({"id":"cwc-%s-%d-%d" % [stage,int(competition.get("season_year",0)),i],"competition_id":String(competition.id),"stage":stage,"round":i+1,"home_club_id":home,"away_club_id":away,"date":date,"season_year":int(competition.get("season_year",0)),"played":false,"home_goals":0,"away_goals":0,"knockout":true,"single_leg":true,"neutral_venue":true,"extra_time":true,"penalties":true,"away_goals_rule":false})

func _stage_fixtures(world: Dictionary, competition_id: String, stage: String) -> Array:
	var rows: Array = []
	for fixture in world.get("fixtures",[]):
		if String(fixture.get("competition_id","")) == competition_id and String(fixture.get("stage","")) == stage: rows.append(fixture)
	return rows

func _competition(world: Dictionary, id: String) -> Dictionary:
	for competition in world.get("competitions",[]):
		if String(competition.get("id","")) == id: return competition
	return {}

func _remove_fixtures(world: Dictionary, competition_id: String) -> void:
	world["fixtures"] = world.get("fixtures",[]).filter(func(fixture): return String(fixture.get("competition_id","")) != competition_id)

func _conflict_free_date(world: Dictionary, home: String, away: String, requested: String) -> String:
	var date := requested
	for _guard in range(14):
		var conflict := false
		for fixture in world.get("fixtures",[]):
			if String(fixture.get("date","")) != date: continue
			if String(fixture.get("home_club_id","")) in [home,away] or String(fixture.get("away_club_id","")) in [home,away]: conflict = true; break
		if not conflict: return date
		date = _add_days(date,1)
	return date

func _add_days(date_string: String, days: int) -> String:
	var pieces := date_string.split("-"); var calendar = CalendarClass.new(); calendar.set_date(int(pieces[0]),int(pieces[1]),int(pieces[2])); calendar.advance_days(days); return calendar.get_date_string()

func _stable_seed(text: String, salt: int) -> int:
	var value := 113 + salt
	for c in text.to_utf8_buffer(): value = posmod(value*193+int(c),2_147_483_647)
	return value if value != 0 else 1
