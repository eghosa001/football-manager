class_name RegionalContinentalEngine
extends RefCounted

const LeagueTableClass = preload("res://simulation/competitions/league_table.gd")
const ResolutionClass = preload("res://simulation/competitions/knockout_resolution_service.gd")
const CalendarClass = preload("res://core/calendar/calendar_service.gd")

func initialize(world: Dictionary, competition: Dictionary, season_year: int) -> void:
	if String(competition.get("competition_type","")) != "regional_continental": return
	_remove_fixtures(world,String(competition.get("id","")))
	competition["season_year"] = season_year
	competition["champion_club_id"] = ""
	competition["stage_history"] = []
	match String(competition.get("format_kind","")):
		"group_knockout": _initialize_groups(world,competition,season_year)
		"concacaf_27": _initialize_concacaf(world,competition,season_year)
		"afc_elite_32": _initialize_afc_elite(world,competition,season_year)
		_: competition["stage"] = "inactive"

func advance_ready(world: Dictionary, competition_id: String, current_date: String) -> Dictionary:
	var competition := _competition(world,competition_id)
	if competition.is_empty() or String(competition.get("competition_type","")) != "regional_continental": return {}
	var stage := String(competition.get("stage","inactive"))
	if stage in ["inactive","complete"]: return competition
	var fixtures := _stage_fixtures(world,competition_id,stage)
	if fixtures.is_empty(): return competition
	for fixture in fixtures:
		if not bool(fixture.get("played",false)): return competition
	if stage == "group_stage": _finish_groups(world,competition,current_date)
	elif stage == "league_stage" and String(competition.get("format_kind","")) == "afc_elite_32": _finish_afc_league_stage(world,competition,current_date)
	else: _finish_knockout(world,competition,stage,current_date)
	return competition

func record(world: Dictionary, competition: Dictionary) -> Dictionary:
	var fixtures: Array=[]
	for fixture in world.get("fixtures",[]):
		if String(fixture.get("competition_id","")) == String(competition.get("id","")): fixtures.append(fixture)
	return {"competition_id":String(competition.get("id","")),"competition_name":String(competition.get("name","")),"season_start_year":int(competition.get("season_year",world.get("season_year",2026))),"tier":int(competition.get("continental_tier",1)),"complete":String(competition.get("stage","")) in ["complete","inactive"],"fixture_count":fixtures.size(),"table":[],"champion_club_id":String(competition.get("champion_club_id","")),"competition_type":"regional_continental","stage_history":competition.get("stage_history",[]).duplicate(true)}

func _initialize_groups(world: Dictionary, competition: Dictionary, season_year: int) -> void:
	var group_count := int(competition.get("format",{}).get("groups",0)); var group_size := int(competition.get("format",{}).get("group_size",4))
	var required := group_count*group_size; var clubs: Array=competition.get("club_ids",[]).duplicate(); clubs.sort()
	if required <= 0 or clubs.size() < required:
		competition["stage"]="inactive"; return
	clubs=clubs.slice(0,required)
	var groups: Array=[]
	for i in range(group_count): groups.append([])
	for i in range(clubs.size()):
		var pot := i/group_count; var slot := i%group_count; var group_index := slot if pot%2==0 else group_count-1-slot
		groups[group_index].append(String(clubs[i]))
	competition["groups"]=groups; competition["group_tables"]=[]; competition["stage"]="group_stage"
	_append_group_fixtures(world,competition,groups,season_year)

func _append_group_fixtures(world: Dictionary, competition: Dictionary, groups: Array, season_year: int) -> void:
	var base := "%04d-09-15" % season_year
	for gi in range(groups.size()):
		var teams: Array=groups[gi].duplicate(); var n:=teams.size()
		if n < 2 or n%2!=0: continue
		for leg in range(2):
			for round_index in range(n-1):
				for pair in range(n/2):
					var a:=String(teams[pair]); var b:=String(teams[n-1-pair]); var home:=a if (round_index+pair+leg)%2==0 else b; var away:=b if home==a else a
					var round_no:=leg*(n-1)+round_index+1; var requested:=_add_days(base,(round_no-1)*14); var date:=_conflict_free_date(world,home,away,requested)
					world.fixtures.append({"id":"rc-%s-g%d-r%d-m%d"%[String(competition.id),gi+1,round_no,pair],"competition_id":String(competition.id),"stage":"group_stage","group":gi+1,"round":round_no,"home_club_id":home,"away_club_id":away,"date":date,"season_year":season_year,"played":false,"home_goals":0,"away_goals":0})
				var fixed: String=String(teams[0]); var rotating:Array=teams.slice(1); rotating.push_front(rotating.pop_back()); teams=[fixed]; teams.append_array(rotating)

func _finish_groups(world: Dictionary, competition: Dictionary, current_date: String) -> void:
	var groups:Array=competition.get("groups",[]); var qualifiers_per_group:=int(competition.get("format",{}).get("qualifiers_per_group",2)); var tables:Array=[]; var qualifiers:Array=[]
	var tie_breakers:Array=competition.get("group_tie_breakers",["points","head_to_head_points","head_to_head_goal_difference","head_to_head_goals","goal_difference","goals_scored"])
	for gi in range(groups.size()):
		var fixtures:Array=[]
		for fixture in _stage_fixtures(world,String(competition.id),"group_stage"):
			if int(fixture.get("group",0))==gi+1: fixtures.append(fixture)
		var table:=LeagueTableClass.build(groups[gi],fixtures,3,1,tie_breakers); tables.append(table)
		for q in range(mini(qualifiers_per_group,table.size())): qualifiers.append({"club_id":String(table[q].club_id),"group":gi,"position":q+1})
	competition["group_tables"]=tables; competition.stage_history.append({"stage":"group_stage","tables":tables.duplicate(true)})
	var next_stage:=String(competition.get("format",{}).get("first_knockout","round_of_16")); var pairings:Array=[]
	if qualifiers_per_group==2 and groups.size()>=2:
		for gi in range(0,groups.size(),2):
			var a1:=_qualifier(qualifiers,gi,1); var a2:=_qualifier(qualifiers,gi,2); var b1:=_qualifier(qualifiers,gi+1,1); var b2:=_qualifier(qualifiers,gi+1,2)
			if a1!="" and b2!="": pairings.append([a1,b2])
			if b1!="" and a2!="": pairings.append([b1,a2])
	else:
		var ids:Array=[]
		for row in qualifiers: ids.append(String(row.club_id))
		for i in range(0,ids.size(),2):
			if i+1<ids.size(): pairings.append([ids[i],ids[i+1]])
	competition["stage"]=next_stage
	_append_knockout_stage(world,competition,next_stage,pairings,_add_days(current_date,21),_stage_two_leg(competition,next_stage))

func _initialize_afc_elite(world: Dictionary, competition: Dictionary, season_year: int) -> void:
	var clubs: Array = competition.get("club_ids",[]).duplicate()
	if clubs.size() < 32:
		competition["stage"] = "inactive"
		return
	clubs = clubs.slice(0,32)
	var west: Array = []
	var east: Array = []
	# The launch database does not yet encode the complete AFC association map,
	# so qualification ranking is split deterministically into two balanced
	# 16-club regional leagues while preserving the 2026/27 competition shape.
	for i in range(clubs.size()):
		if i % 2 == 0: west.append(String(clubs[i]))
		else: east.append(String(clubs[i]))
	competition["regional_leagues"] = [west,east]
	competition["regional_tables"] = []
	competition["stage"] = "league_stage"
	_append_afc_league_fixtures(world,competition,west,0,season_year)
	_append_afc_league_fixtures(world,competition,east,1,season_year)

func _append_afc_league_fixtures(world: Dictionary, competition: Dictionary, teams: Array, region_index: int, season_year: int) -> void:
	if teams.size() != 16: return
	var dates: Array = [
		"%04d-09-14" % season_year,
		"%04d-10-12" % season_year,
		"%04d-10-26" % season_year,
		"%04d-11-02" % season_year,
		"%04d-11-23" % season_year,
		"%04d-12-07" % season_year,
		"%04d-02-08" % (season_year+1),
		"%04d-02-15" % (season_year+1)
	]
	# Offsets 1..4 form four even cycle systems. Splitting each cycle's edges
	# by alternating parity yields eight perfect matchdays. Orienting every edge
	# from i to i+offset gives every club exactly four home and four away games.
	for offset in range(1,5):
		var visited: Dictionary = {}
		for start in range(16):
			if visited.has(start): continue
			var cycle: Array = []
			var current: int = start
			while not visited.has(current):
				visited[current] = true
				cycle.append(current)
				current = (current + offset) % 16
			for step in range(cycle.size()):
				var home_index: int = int(cycle[step])
				var away_index: int = (home_index + offset) % 16
				var round_no: int = (offset-1)*2 + (step % 2) + 1
				var home: String = String(teams[home_index])
				var away: String = String(teams[away_index])
				var requested: String = String(dates[round_no-1])
				var date: String = _conflict_free_date(world,home,away,requested)
				world.fixtures.append({"id":"afc-%s-z%d-r%d-%d-%d"%[String(competition.id),region_index+1,round_no,home_index,away_index],"competition_id":String(competition.id),"stage":"league_stage","afc_region":region_index,"round":round_no,"home_club_id":home,"away_club_id":away,"date":date,"season_year":season_year,"played":false,"home_goals":0,"away_goals":0})

func _finish_afc_league_stage(world: Dictionary, competition: Dictionary, current_date: String) -> void:
	var leagues: Array = competition.get("regional_leagues",[])
	if leagues.size() != 2: return
	var tables: Array = []
	var pairings: Array = []
	var tie_breakers: Array = ["points","goal_difference","goals_scored","wins"]
	for region_index in range(2):
		var fixtures: Array = []
		for fixture in _stage_fixtures(world,String(competition.id),"league_stage"):
			if int(fixture.get("afc_region",-1)) == region_index: fixtures.append(fixture)
		var table: Array = LeagueTableClass.build(leagues[region_index],fixtures,3,1,tie_breakers)
		tables.append(table)
		if table.size() < 8: return
		for seed in range(4):
			var high: String = String(table[seed].club_id)
			var low: String = String(table[7-seed].club_id)
			pairings.append([low,high])
	competition["regional_tables"] = tables
	competition.stage_history.append({"stage":"league_stage","regional_tables":tables.duplicate(true)})
	competition["stage"] = "round_of_16"
	_append_knockout_stage(world,competition,"round_of_16",pairings,_add_days(current_date,14),true)

func _initialize_concacaf(world: Dictionary, competition: Dictionary, season_year: int) -> void:
	var clubs:Array=competition.get("club_ids",[]).duplicate(); clubs.sort()
	if clubs.size()<27: competition["stage"]="inactive"; return
	clubs=clubs.slice(0,27)
	competition["direct_round_of_16"]=clubs.slice(0,5)
	var r1:=clubs.slice(5,27); var pairings:Array=[]
	for i in range(0,r1.size(),2): pairings.append([String(r1[i]),String(r1[i+1])])
	competition["stage"]="round_one"
	_append_knockout_stage(world,competition,"round_one",pairings,"%04d-02-03"%(season_year+1),true)

func _finish_knockout(world: Dictionary, competition: Dictionary, stage: String, current_date: String) -> void:
	var winners:=_stage_winners(world,competition,stage)
	if winners.is_empty(): return
	competition.stage_history.append({"stage":stage,"winners":winners.duplicate()})
	if stage=="final":
		competition["champion_club_id"]=String(winners[0]); competition["stage"]="complete"; return
	var next_stage:=_next_stage(competition,stage)
	var entrants:Array=winners.duplicate()
	if stage=="round_one" and String(competition.get("format_kind",""))=="concacaf_27": entrants.append_array(competition.get("direct_round_of_16",[]))
	var pairings:Array=[]
	if stage=="round_of_16" and String(competition.get("format_kind",""))=="afc_elite_32" and entrants.size()==8:
		for i in range(4): pairings.append([String(entrants[i]),String(entrants[4+((i+1)%4)])])
	else:
		for i in range(0,entrants.size(),2):
			if i+1<entrants.size(): pairings.append([String(entrants[i]),String(entrants[i+1])])
	competition["stage"]=next_stage
	_append_knockout_stage(world,competition,next_stage,pairings,_add_days(current_date,21),_stage_two_leg(competition,next_stage))

func _stage_winners(world: Dictionary, competition: Dictionary, stage: String) -> Array:
	var fixtures:=_stage_fixtures(world,String(competition.id),stage); var two_leg:=_stage_two_leg(competition,stage); var winners:Array=[]
	if two_leg:
		var ties:Dictionary={}
		for fixture in fixtures:
			var tie_id:=String(fixture.get("tie_id","")); if not ties.has(tie_id): ties[tie_id]=[]
			ties[tie_id].append(fixture)
		for tie_id in ties.keys():
			var legs:Array=ties[tie_id]; legs.sort_custom(func(a:Dictionary,b:Dictionary): return int(a.get("leg",1))<int(b.get("leg",1)))
			if legs.size()!=2: return []
			var first:Dictionary=legs[0]; var second:Dictionary=legs[1]; var club_a:=String(first.home_club_id); var club_b:=String(first.away_club_id)
			var a_goals:=int(first.home_goals)+int(second.away_goals); var b_goals:=int(first.away_goals)+int(second.home_goals); var winner:=""
			if a_goals!=b_goals: winner=club_a if a_goals>b_goals else club_b
			else:
				var resolution:=ResolutionClass.new().resolve_level_match(world,second,competition,_stable_seed(String(second.id),int(competition.get("season_year",0))))
				for key in resolution.keys(): second[key]=resolution[key]
				winner=String(resolution.get("winner",""))
			second["aggregate_a_goals"]=a_goals; second["aggregate_b_goals"]=b_goals; second["aggregate_winner"]=winner; winners.append(winner)
	else:
		for fixture in fixtures:
			var home:=String(fixture.home_club_id); var away:=String(fixture.away_club_id); var winner:=""
			if int(fixture.home_goals)!=int(fixture.away_goals): winner=home if int(fixture.home_goals)>int(fixture.away_goals) else away
			else:
				var resolution:=ResolutionClass.new().resolve_level_match(world,fixture,competition,_stable_seed(String(fixture.id),int(competition.get("season_year",0))))
				for key in resolution.keys(): fixture[key]=resolution[key]
				winner=String(resolution.get("winner",""))
			winners.append(winner)
	return winners

func _append_knockout_stage(world: Dictionary, competition: Dictionary, stage: String, pairings: Array, requested: String, two_leg: bool) -> void:
	var season_year:=int(competition.get("season_year",world.get("season_year",2026)))
	for i in range(pairings.size()):
		var a:=String(pairings[i][0]); var b:=String(pairings[i][1]); var tie_id:="%s-%s-%d"%[String(competition.id),stage,i]
		if two_leg:
			var d1:=_conflict_free_date(world,a,b,requested); var d2:=_conflict_free_date(world,b,a,_add_days(d1,7))
			world.fixtures.append(_knockout_fixture(tie_id+"-l1",competition,stage,i+1,a,b,d1,season_year,tie_id,1,false))
			world.fixtures.append(_knockout_fixture(tie_id+"-l2",competition,stage,i+1,b,a,d2,season_year,tie_id,2,true))
		else:
			var d:=_conflict_free_date(world,a,b,requested); world.fixtures.append(_knockout_fixture(tie_id,competition,stage,i+1,a,b,d,season_year,tie_id,1,true))

func _knockout_fixture(id:String,competition:Dictionary,stage:String,round_no:int,home:String,away:String,date:String,season_year:int,tie_id:String,leg:int,decisive:bool)->Dictionary:
	var centralised_afc: bool = String(competition.get("format_kind",""))=="afc_elite_32" and stage in ["quarterfinal","semifinal","final"]
	return {"id":id,"competition_id":String(competition.id),"stage":stage,"round":round_no,"home_club_id":home,"away_club_id":away,"date":date,"season_year":season_year,"played":false,"home_goals":0,"away_goals":0,"regional_knockout":true,"tie_id":tie_id,"leg":leg,"extra_time":decisive,"penalties":decisive,"away_goals_rule":false,"neutral_venue":centralised_afc or (stage=="final" and not _stage_two_leg(competition,stage))}

func _stage_two_leg(competition: Dictionary, stage: String) -> bool:
	if stage=="final": return bool(competition.get("format",{}).get("final_two_leg",false))
	return stage in competition.get("format",{}).get("two_leg_stages",["round_one","round_of_16","quarterfinal","semifinal"])

func _next_stage(competition: Dictionary, stage: String) -> String:
	if stage=="round_one": return "round_of_16"
	if stage=="round_of_16": return "quarterfinal"
	if stage=="quarterfinal": return "semifinal"
	if stage=="semifinal": return "final"
	return "complete"

func _qualifier(rows:Array,group:int,position:int)->String:
	for row in rows:
		if int(row.group)==group and int(row.position)==position: return String(row.club_id)
	return ""

func _stage_fixtures(world:Dictionary,competition_id:String,stage:String)->Array:
	var rows:Array=[]
	for fixture in world.get("fixtures",[]):
		if String(fixture.get("competition_id",""))==competition_id and String(fixture.get("stage",""))==stage: rows.append(fixture)
	return rows

func _competition(world:Dictionary,id:String)->Dictionary:
	for competition in world.get("competitions",[]):
		if String(competition.get("id",""))==id: return competition
	return {}

func _remove_fixtures(world:Dictionary,competition_id:String)->void:
	world["fixtures"]=world.get("fixtures",[]).filter(func(fixture): return String(fixture.get("competition_id",""))!=competition_id)

func _conflict_free_date(world:Dictionary,home:String,away:String,requested:String)->String:
	var date:=requested
	for _guard in range(18):
		var conflict:=false
		for fixture in world.get("fixtures",[]):
			if String(fixture.get("date",""))!=date: continue
			if String(fixture.get("home_club_id","")) in [home,away] or String(fixture.get("away_club_id","")) in [home,away]: conflict=true; break
		if not conflict: return date
		date=_add_days(date,1)
	return date

func _add_days(date_string:String,days:int)->String:
	var pieces:=date_string.split("-"); var calendar=CalendarClass.new(); calendar.set_date(int(pieces[0]),int(pieces[1]),int(pieces[2])); calendar.advance_days(days); return calendar.get_date_string()

func _stable_seed(text:String,salt:int)->int:
	var value:=151+salt
	for c in text.to_utf8_buffer(): value=posmod(value*197+int(c),2_147_483_647)
	return value if value!=0 else 1
