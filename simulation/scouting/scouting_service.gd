class_name ScoutingService
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func ensure_world(world: Dictionary) -> void:
	world["scouting_knowledge"] = world.get("scouting_knowledge", {})
	world["country_knowledge"] = world.get("country_knowledge", {})
	world["scout_assignments"] = world.get("scout_assignments", [])
	world["recruitment_focuses"] = world.get("recruitment_focuses", [])

func assign_scout(world: Dictionary, scout_id: String, target_type: String, target_id: String, start_day: int = 0) -> Dictionary:
	ensure_world(world)
	var assignment := {"id":"assignment-%s-%s-%d" % [scout_id,target_id,world.scout_assignments.size()+1],"scout_id":scout_id,"target_type":target_type,"target_id":target_id,"start_day":start_day,"progress":0.0,"complete":false}
	world.scout_assignments.append(assignment)
	return assignment

func create_recruitment_focus(world: Dictionary, club_id: String, scout_id: String, country_id: String, position: String = "", max_age: int = 30, min_potential: int = 0) -> Dictionary:
	ensure_world(world)
	var focus := {"id":"focus-%s-%d" % [club_id,world.recruitment_focuses.size()+1],"club_id":club_id,"scout_id":scout_id,"country_id":country_id,"position":position,"max_age":max_age,"min_potential":min_potential,"progress":0.0,"active":true,"discovered":[]}
	world.recruitment_focuses.append(focus)
	return focus

func advance_assignment(world: Dictionary, assignment: Dictionary, days: int, scout_ability: int, seed: int) -> Dictionary:
	ensure_world(world)
	assignment.progress = clampf(float(assignment.get("progress",0.0)) + days * (0.6 + scout_ability / 100.0),0.0,100.0)
	assignment.complete = float(assignment.progress) >= 100.0
	if assignment.complete:
		if String(assignment.target_type) == "player":
			world.scouting_knowledge[String(assignment.target_id)] = maxf(float(world.scouting_knowledge.get(String(assignment.target_id),0.0)),clampf(scout_ability/100.0,0.15,1.0))
		elif String(assignment.target_type) == "country":
			world.country_knowledge[String(assignment.target_id)] = maxf(float(world.country_knowledge.get(String(assignment.target_id),0.0)),clampf(scout_ability/100.0,0.15,1.0))
	return assignment

func advance_focus(world: Dictionary, focus: Dictionary, days: int, scout_ability: int, seed: int) -> Dictionary:
	ensure_world(world)
	if not bool(focus.get("active",true)): return focus
	focus.progress = minf(100.0,float(focus.get("progress",0.0))+days*(0.25+scout_ability/160.0))
	var country_id := String(focus.get("country_id", ""))
	var country_gain := clampf(float(days)*(0.002+scout_ability/50000.0),0.0,0.15)
	world.country_knowledge[country_id] = clampf(float(world.country_knowledge.get(country_id,0.0))+country_gain,0.0,1.0)
	var discovered: Array = focus.get("discovered", [])
	for player in world.get("players", []):
		if String(player.get("country_id", "")) != country_id or bool(player.get("retired",false)): continue
		if String(focus.get("position", "")) != "" and String(player.get("position", "")) != String(focus.position): continue
		if int(player.get("age",99)) > int(focus.get("max_age",30)) or int(player.get("potential",0)) < int(focus.get("min_potential",0)): continue
		var key := _stable_key(String(focus.id)+String(player.id))
		var discovery_chance := clampf(0.02 + scout_ability/1000.0 + float(world.country_knowledge[country_id])*0.08,0.02,0.22)
		if SeededRngClass.unit_for(seed,key) < discovery_chance:
			var player_id := String(player.id)
			if player_id not in discovered: discovered.append(player_id)
			world.scouting_knowledge[player_id] = clampf(maxf(float(world.scouting_knowledge.get(player_id,0.0)),0.15+float(world.country_knowledge[country_id])*0.5),0.0,1.0)
	focus.discovered = discovered
	if float(focus.progress) >= 100.0: focus.active = false
	return focus

func player_report(world: Dictionary, player: Dictionary, observer_quality: int, seed: int) -> Dictionary:
	ensure_world(world)
	var country_id := String(player.get("country_id", ""))
	var country_bonus := float(world.country_knowledge.get(country_id,0.0))*0.25
	var knowledge: float = clampf(maxf(float(world.scouting_knowledge.get(String(player.id),0.0)),observer_quality/100.0*0.5,country_bonus),0.0,1.0)
	var attrs: Dictionary = player.get("attributes", {})
	var visible := {}
	for name in attrs.keys():
		var actual: int = int(attrs[name]); var uncertainty: int = int(round((1.0-knowledge)*12.0))
		var noise: int = int(SeededRngClass.value_for(seed,_stable_key(String(player.id)+String(name)))%(uncertainty*2+1))-uncertainty if uncertainty > 0 else 0
		var center := clampi(actual+noise,1,100)
		visible[name] = {"min":clampi(center-uncertainty,1,100),"max":clampi(center+uncertainty,1,100),"exact":actual if knowledge >= 0.95 else null}
	return {"player_id":String(player.id),"knowledge":knowledge,"attributes":visible,"ability_estimate":_range(int(player.get("current_ability",50)),knowledge),"potential_estimate":_range(int(player.get("potential",50)),knowledge)}

func _range(value: int, knowledge: float) -> Dictionary:
	var spread := int(round((1.0-knowledge)*20.0))
	return {"min":clampi(value-spread,1,100),"max":clampi(value+spread,1,100)}

func _stable_key(text: String) -> int:
	var value := 29
	for character in text.to_utf8_buffer(): value = posmod(value*139+int(character),2_147_483_647)
	return value
