class_name LivingWorldDepth
extends RefCounted

const LEGEND_LEVELS := {"favoured":90.0,"icon":180.0,"legend":300.0}

func advance_year(world: Dictionary, completed_year: int) -> Dictionary:
	world["club_legends"] = world.get("club_legends", [])
	world["rivalries"] = world.get("rivalries", [])
	var legends := _update_legends(world, completed_year)
	var rivalries := _update_rivalries(world, completed_year)
	return {"legends":legends,"rivalries":rivalries}

func _update_legends(world: Dictionary, year: int) -> Dictionary:
	var by_player_club := {}
	for row in world.get("history_archive",{}).get("players",[]):
		var key := String(row.get("player_id",""))+"|"+String(row.get("club_id",""))
		if not by_player_club.has(key):
			by_player_club[key] = {"appearances":0,"goals":0,"seasons":{},"knockout_goals":0}
		var aggregate: Dictionary = by_player_club[key]
		aggregate.appearances = int(aggregate.appearances)+int(row.get("appearances",0))
		aggregate.goals = int(aggregate.goals)+int(row.get("goals",0))
		aggregate.seasons[int(row.get("year",0))] = true
		if _competition_type(world,String(row.get("competition_id",""))) == "knockout":
			aggregate.knockout_goals = int(aggregate.knockout_goals)+int(row.get("goals",0))
	var title_counts := {}
	for row in world.get("history_archive",{}).get("competitions",[]):
		var club_id := String(row.get("winner_club_id",""))
		if club_id != "": title_counts[club_id] = int(title_counts.get(club_id,0))+1
	var updated := 0
	for key in by_player_club.keys():
		var parts := String(key).split("|")
		if parts.size()!=2: continue
		var player_id := String(parts[0]); var club_id := String(parts[1])
		if player_id=="" or club_id=="": continue
		var aggregate: Dictionary = by_player_club[key]
		var player := _player(world,player_id)
		var club := _club(world,club_id)
		var loyalty := float(player.get("hidden_attributes",{}).get("loyalty",50)) if not player.is_empty() else 50.0
		var popularity := float(player.get("reputation",50)) if not player.is_empty() else 50.0
		var captain_bonus := 35.0 if String(club.get("captain_id",""))==player_id else 0.0
		var score := float(aggregate.appearances)*0.32+float(aggregate.goals)*0.85+float(aggregate.knockout_goals)*0.65+float(aggregate.seasons.size())*7.0+float(title_counts.get(club_id,0))*8.0+captain_bonus+loyalty*0.20+popularity*0.18
		var level := _legend_level(score)
		if level=="": continue
		var row := _legend_row(world.club_legends,player_id,club_id)
		if row.is_empty():
			row={"player_id":player_id,"club_id":club_id,"score":score,"level":level,"first_recognized_year":year,"last_updated_year":year}
			world.club_legends.append(row)
		else:
			row.score=score; row.level=level; row.last_updated_year=year
		updated += 1
	# Compatibility with the older global legends collection.
	world["legends"] = world.get("legends",[])
	var global_ids := {}
	for row in world.legends: global_ids[String(row.get("person_id",""))]=true
	for row in world.club_legends:
		if String(row.level)!="legend" or global_ids.has(String(row.player_id)): continue
		var player := _player(world,String(row.player_id))
		world.legends.append({"person_id":row.player_id,"name":_player_name(player),"club_id":row.club_id,"inducted_year":year,"reputation":int(player.get("reputation",50)),"legend_score":float(row.score)})
		global_ids[String(row.player_id)]=true
	return {"recognized":updated,"total":world.club_legends.size()}

func _update_rivalries(world: Dictionary, year: int) -> Dictionary:
	var touched := {}
	# Geography: clubs in the same city build a persistent local edge.
	var by_city := {}
	for club in world.get("clubs",[]):
		var city := String(club.get("city",""))
		if city=="": continue
		if not by_city.has(city): by_city[city]=[]
		by_city[city].append(String(club.id))
	for city in by_city.keys():
		var clubs: Array=by_city[city]
		for i in range(clubs.size()):
			for j in range(i+1,mini(clubs.size(),i+4)):
				_bump(world,String(clubs[i]),String(clubs[j]),4,"geography",year,touched)
	# Cup finals create or intensify rivalries.
	for row in world.get("history_archive",{}).get("competitions",[]):
		if int(row.get("year",0))!=year or String(row.get("competition_type",""))!="knockout": continue
		var winner:=String(row.get("winner_club_id","")); var runner:=String(row.get("runner_up_club_id",""))
		if winner!="" and runner!="": _bump(world,winner,runner,12,"cup_final",year,touched)
	# Transfers between clubs can create tension, especially repeated movement.
	for event in world.get("domain_events",[]):
		if int(event.get("season_year",0)) < year-1 or String(event.get("type",""))!="PLAYER_SIGNED": continue
		var payload:Dictionary=event.get("payload",{})
		var seller:=String(payload.get("seller_id",payload.get("old_club_id",""))); var buyer:=String(payload.get("buyer_id",payload.get("club_id","")))
		if seller!="" and buyer!="" and seller!=buyer: _bump(world,seller,buyer,3,"transfer",year,touched)
	# Frequent competitive meetings sustain intensity.
	var meetings := {}
	for fixture in world.get("fixtures",[]):
		if not bool(fixture.get("played",false)): continue
		var a:=String(fixture.get("home_club_id","")); var b:=String(fixture.get("away_club_id",""))
		if a=="" or b=="": continue
		var key:=_pair_key(a,b); meetings[key]=int(meetings.get(key,0))+1
	for key in meetings.keys():
		if int(meetings[key])>=3:
			var parts:=String(key).split("|"); _bump(world,String(parts[0]),String(parts[1]),mini(5,int(meetings[key])-2),"frequent_meetings",year,touched)
	# Untouched rivalries decay but never disappear instantly.
	for row in world.rivalries:
		var key:=_pair_key(String(row.get("club_a","")),String(row.get("club_b","")))
		if not touched.has(key): row.intensity=maxi(0,int(row.get("intensity",0))-2)
	world.rivalries=world.rivalries.filter(func(row): return int(row.get("intensity",0))>0)
	return {"total":world.rivalries.size(),"updated":touched.size()}

func _bump(world:Dictionary,a:String,b:String,delta:int,cause:String,year:int,touched:Dictionary)->void:
	if a=="" or b=="" or a==b: return
	var row:=_rivalry(world.rivalries,a,b)
	if row.is_empty():
		row={"club_a":a,"club_b":b,"intensity":0,"last_changed":year,"causes":{}}
		world.rivalries.append(row)
	row.intensity=clampi(int(row.get("intensity",0))+delta,0,100)
	row.last_changed=year
	row["causes"]=row.get("causes",{})
	row.causes[cause]=int(row.causes.get(cause,0))+delta
	touched[_pair_key(a,b)]=true

func _legend_level(score:float)->String:
	if score>=float(LEGEND_LEVELS.legend): return "legend"
	if score>=float(LEGEND_LEVELS.icon): return "icon"
	if score>=float(LEGEND_LEVELS.favoured): return "favoured"
	return ""

func _legend_row(rows:Array,player_id:String,club_id:String)->Dictionary:
	for row in rows:
		if String(row.get("player_id",""))==player_id and String(row.get("club_id",""))==club_id: return row
	return {}
func _rivalry(rows:Array,a:String,b:String)->Dictionary:
	for row in rows:
		if (String(row.get("club_a",""))==a and String(row.get("club_b",""))==b) or (String(row.get("club_a",""))==b and String(row.get("club_b",""))==a): return row
	return {}
func _pair_key(a:String,b:String)->String:
	return a+"|"+b if a<b else b+"|"+a
func _competition_type(world:Dictionary,id:String)->String:
	for competition in world.get("competitions",[]):
		if String(competition.get("id",""))==id: return String(competition.get("competition_type","league"))
	return "league"
func _player(world:Dictionary,id:String)->Dictionary:
	for player in world.get("players",[]):
		if String(player.get("id",""))==id: return player
	return {}
func _club(world:Dictionary,id:String)->Dictionary:
	for club in world.get("clubs",[]):
		if String(club.get("id",""))==id: return club
	return {}
func _player_name(player:Dictionary)->String:
	if player.is_empty(): return ""
	var value:=String(player.get("name","")).strip_edges()
	return value if value!="" else (String(player.get("first_name",""))+" "+String(player.get("last_name",""))).strip_edges()
