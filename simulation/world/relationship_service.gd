class_name RelationshipService
extends RefCounted

const TYPES := ["respect","friendship","dislike","mentoring","family","manager","agent","social_group"]

func ensure_world(world: Dictionary) -> void:
	world["relationships"] = world.get("relationships", [])
	world["social_groups"] = world.get("social_groups", [])

func relationship(world: Dictionary, person_a: String, person_b: String, relation_type: String = "respect") -> Dictionary:
	ensure_world(world)
	for row in world.relationships:
		if String(row.get("type","respect")) != relation_type: continue
		if _same_pair(row,person_a,person_b): return row
	return {}

func change(world: Dictionary, person_a: String, person_b: String, relation_type: String, delta: float, reason: String, season_year: int = 0) -> Dictionary:
	ensure_world(world)
	if person_a == "" or person_b == "" or person_a == person_b or relation_type not in TYPES: return {}
	var row := relationship(world,person_a,person_b,relation_type)
	if row.is_empty():
		row = {"person_a":person_a,"person_b":person_b,"type":relation_type,"strength":0.0,"history":[],"last_changed":season_year}
		world.relationships.append(row)
	row.strength = clampf(float(row.get("strength",0.0))+delta,-100.0,100.0)
	row.last_changed = season_year
	row.history.append({"season_year":season_year,"delta":delta,"reason":reason})
	return row

func process_event(world: Dictionary, event: Dictionary) -> Array:
	ensure_world(world)
	var changes: Array = []
	var kind := String(event.get("type",""))
	var year := int(event.get("season_year",world.get("season_year",2026)))
	var payload: Dictionary = event.get("payload",{})
	match kind:
		"PLAYER_MENTORED":
			changes.append(change(world,String(payload.get("mentor_id","")),String(payload.get("player_id","")),"mentoring",12.0,"mentoring",year))
			changes.append(change(world,String(payload.get("mentor_id","")),String(payload.get("player_id","")),"respect",5.0,"mentoring",year))
		"PLAYER_SIGNED":
			var player_id := String(payload.get("player_id","")); var agent_id := String(payload.get("agent_id","")); var manager_id := String(payload.get("manager_id",""))
			if agent_id != "": changes.append(change(world,player_id,agent_id,"agent",4.0,"successful_move",year))
			if manager_id != "": changes.append(change(world,player_id,manager_id,"manager",3.0,"signed_by_manager",year))
		"PLAYER_DROPPED":
			changes.append(change(world,String(payload.get("player_id","")),String(payload.get("manager_id","")),"manager",-5.0,"dropped_from_team",year))
		"CONTRACT_DISPUTE":
			changes.append(change(world,String(payload.get("player_id","")),String(payload.get("manager_id","")),"manager",-10.0,"contract_dispute",year))
		"TEAM_SUCCESS":
			var participants: Array = payload.get("player_ids",[])
			for i in range(participants.size()):
				for j in range(i+1,mini(participants.size(),i+6)):
					changes.append(change(world,String(participants[i]),String(participants[j]),"friendship",1.5,"shared_success",year))
		"TRAINING_DISPUTE":
			changes.append(change(world,String(payload.get("person_a","")),String(payload.get("person_b","")),"dislike",7.0,"training_dispute",year))
	return changes.filter(func(v): return typeof(v)==TYPE_DICTIONARY and not v.is_empty())

func build_social_groups(world: Dictionary, club_id: String, players: Array) -> Array:
	ensure_world(world)
	var groups: Array = []
	var unassigned: Array = []
	for player in players:
		if String(player.get("club_id","")) == club_id and not bool(player.get("retired",false)): unassigned.append(player)
	while not unassigned.is_empty():
		var seed_player: Dictionary = unassigned.pop_front()
		var group := {"id":"social-%s-%d" % [club_id,groups.size()+1],"club_id":club_id,"members":[String(seed_player.id)],"cohesion":50.0}
		var seed_language := String(seed_player.get("language","")); var seed_country := String(seed_player.get("country_id",""))
		for i in range(unassigned.size()-1,-1,-1):
			var candidate: Dictionary = unassigned[i]
			var affinity := 0
			if seed_country != "" and String(candidate.get("country_id","")) == seed_country: affinity += 2
			if seed_language != "" and String(candidate.get("language","")) == seed_language: affinity += 2
			if abs(int(candidate.get("age",25))-int(seed_player.get("age",25))) <= 3: affinity += 1
			if affinity >= 3 and group.members.size() < 8:
				group.members.append(String(candidate.id)); unassigned.remove_at(i)
		for a in group.members:
			for b in group.members:
				if String(a) < String(b): change(world,String(a),String(b),"social_group",4.0,"shared_social_group",int(world.get("season_year",2026)))
		groups.append(group)
	world.social_groups = world.social_groups.filter(func(g): return String(g.get("club_id","")) != club_id)
	world.social_groups.append_array(groups)
	return groups

func decay(world: Dictionary, seasons: int = 1) -> void:
	ensure_world(world)
	var factor := pow(0.92,float(maxi(1,seasons)))
	for row in world.relationships:
		if String(row.get("type","")) == "family": continue
		row.strength = float(row.get("strength",0.0))*factor
	world.relationships = world.relationships.filter(func(row): return String(row.get("type",""))=="family" or absf(float(row.get("strength",0.0)))>=1.0)

func _same_pair(row: Dictionary, a: String, b: String) -> bool:
	return (String(row.get("person_a",""))==a and String(row.get("person_b",""))==b) or (String(row.get("person_a",""))==b and String(row.get("person_b",""))==a)
