class_name ScoutingService
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func ensure_world(world: Dictionary) -> void:
	world["scouting_knowledge"] = world.get("scouting_knowledge", {})
	world["country_knowledge"] = world.get("country_knowledge", {})
	world["scout_assignments"] = world.get("scout_assignments", [])
	world["recruitment_focuses"] = world.get("recruitment_focuses", [])
	world["scouting_networks"] = world.get("scouting_networks", {})
	world["scouting_budgets"] = world.get("scouting_budgets", {})
	world["scouting_reports"] = world.get("scouting_reports", [])

func configure_network(world: Dictionary, club_id: String, regions: Array, countries: Array, monthly_budget: int) -> Dictionary:
	ensure_world(world)
	var network := {"club_id":club_id,"regions":regions.duplicate(),"countries":countries.duplicate(),"last_decay_day":int(world.get("day_index",0))}
	world.scouting_networks[club_id] = network
	world.scouting_budgets[club_id] = maxi(0,monthly_budget)
	return network

func assign_scout(world: Dictionary, scout_id: String, target_type: String, target_id: String, start_day: int = 0) -> Dictionary:
	ensure_world(world)
	var assignment := {"id":"assignment-%s-%s-%d" % [scout_id,target_id,world.scout_assignments.size()+1],"scout_id":scout_id,"target_type":target_type,"target_id":target_id,"start_day":start_day,"progress":0.0,"complete":false,"travel_days":0,"workload_penalty":0.0}
	world.scout_assignments.append(assignment)
	return assignment

func create_recruitment_focus(world: Dictionary, club_id: String, scout_id: String, country_id: String, position: String = "", max_age: int = 30, min_potential: int = 0) -> Dictionary:
	ensure_world(world)
	var focus := {"id":"focus-%s-%d" % [club_id,world.recruitment_focuses.size()+1],"club_id":club_id,"scout_id":scout_id,"country_id":country_id,"position":position,"max_age":max_age,"min_potential":min_potential,"progress":0.0,"active":true,"discovered":[]}
	world.recruitment_focuses.append(focus)
	return focus

func advance_assignment(world: Dictionary, assignment: Dictionary, days: int, scout_ability: int, seed: int) -> Dictionary:
	ensure_world(world)
	var scout := _staff(world.get("staff",[]),String(assignment.get("scout_id","")))
	var workload := _active_workload(world,String(assignment.get("scout_id","")))
	var workload_factor := clampf(1.0-float(maxi(0,workload-1))*0.15,0.45,1.0)
	var target_country := _target_country(world,assignment)
	var language_factor := _language_factor(world,scout,target_country)
	var network_factor := _network_factor(world,String(scout.get("club_id","")),target_country)
	var travel_factor := _travel_factor(world,scout,target_country)
	assignment.workload_penalty = 1.0-workload_factor
	assignment.travel_days = int(round((1.0-travel_factor)*4.0))
	var rate := days * (0.45 + scout_ability / 100.0) * workload_factor * language_factor * network_factor * travel_factor
	assignment.progress = clampf(float(assignment.get("progress",0.0)) + rate,0.0,100.0)
	assignment.complete = float(assignment.progress) >= 100.0
	if assignment.complete:
		if String(assignment.target_type) == "player":
			world.scouting_knowledge[String(assignment.target_id)] = maxf(float(world.scouting_knowledge.get(String(assignment.target_id),0.0)),clampf(scout_ability/100.0*language_factor*network_factor,0.15,1.0))
		elif String(assignment.target_type) == "country":
			world.country_knowledge[String(assignment.target_id)] = maxf(float(world.country_knowledge.get(String(assignment.target_id),0.0)),clampf(scout_ability/100.0*network_factor,0.15,1.0))
	return assignment

func advance_focus(world: Dictionary, focus: Dictionary, days: int, scout_ability: int, seed: int) -> Dictionary:
	ensure_world(world)
	if not bool(focus.get("active",true)): return focus
	var scout := _staff(world.get("staff",[]),String(focus.get("scout_id","")))
	var club_id := String(focus.get("club_id",""))
	var country_id := String(focus.get("country_id", ""))
	var budget := int(world.scouting_budgets.get(club_id,0))
	var budget_factor := clampf(0.65+float(budget)/500000.0,0.65,1.25)
	var network_factor := _network_factor(world,club_id,country_id)
	var language_factor := _language_factor(world,scout,country_id)
	focus.progress = minf(100.0,float(focus.get("progress",0.0))+days*(0.20+scout_ability/170.0)*budget_factor*network_factor*language_factor)
	var country_gain := clampf(float(days)*(0.0015+scout_ability/55000.0)*network_factor*budget_factor,0.0,0.15)
	world.country_knowledge[country_id] = clampf(float(world.country_knowledge.get(country_id,0.0))+country_gain,0.0,1.0)
	var discovered: Array = focus.get("discovered", [])
	for player in world.get("players", []):
		if String(player.get("country_id", "")) != country_id or bool(player.get("retired",false)): continue
		if String(focus.get("position", "")) != "" and String(player.get("position", "")) != String(focus.position): continue
		if int(player.get("age",99)) > int(focus.get("max_age",30)) or int(player.get("potential",0)) < int(focus.get("min_potential",0)): continue
		var key := _stable_key(String(focus.id)+String(player.id))
		var discovery_chance := clampf((0.015 + scout_ability/1100.0 + float(world.country_knowledge[country_id])*0.08)*network_factor*budget_factor,0.01,0.28)
		if SeededRngClass.unit_for(seed,key) < discovery_chance:
			var player_id := String(player.id)
			if player_id not in discovered: discovered.append(player_id)
			world.scouting_knowledge[player_id] = clampf(maxf(float(world.scouting_knowledge.get(player_id,0.0)),0.15+float(world.country_knowledge[country_id])*0.5),0.0,1.0)
	focus.discovered = discovered
	if float(focus.progress) >= 100.0: focus.active = false
	return focus

func decay_knowledge(world: Dictionary, days: int = 7) -> Dictionary:
	ensure_world(world)
	var player_decay := pow(0.992,float(days))
	var country_decay := pow(0.997,float(days))
	for id in world.scouting_knowledge.keys(): world.scouting_knowledge[id] = clampf(float(world.scouting_knowledge[id])*player_decay,0.0,1.0)
	for id in world.country_knowledge.keys(): world.country_knowledge[id] = clampf(float(world.country_knowledge[id])*country_decay,0.0,1.0)
	return {"player_factor":player_decay,"country_factor":country_decay}

func player_report(world: Dictionary, player: Dictionary, observer_quality: int, seed: int) -> Dictionary:
	ensure_world(world)
	var country_id := String(player.get("country_id", ""))
	var country_bonus := float(world.country_knowledge.get(country_id,0.0))*0.25
	var knowledge: float = clampf(maxf(maxf(float(world.scouting_knowledge.get(String(player.id),0.0)),observer_quality/100.0*0.5),country_bonus),0.0,1.0)
	var attrs: Dictionary = player.get("attributes", {})
	var visible := {}
	for name in attrs.keys():
		var actual: int = int(attrs[name]); var uncertainty: int = int(round((1.0-knowledge)*12.0))
		var noise: int = int(SeededRngClass.value_for(seed,_stable_key(String(player.id)+String(name)))%(uncertainty*2+1))-uncertainty if uncertainty > 0 else 0
		var center := clampi(actual+noise,1,100)
		visible[name] = {"min":clampi(center-uncertainty,1,100),"max":clampi(center+uncertainty,1,100),"exact":actual if knowledge >= 0.95 else null}
	var hidden_visible := {}
	if knowledge >= 0.55:
		for name in player.get("hidden_attributes",{}).keys():
			var actual := int(player.hidden_attributes[name])
			var spread := int(round((1.0-knowledge)*20.0))
			hidden_visible[name] = {"min":clampi(actual-spread,1,100),"max":clampi(actual+spread,1,100),"exact":actual if knowledge>=0.92 else null}
	return {"player_id":String(player.id),"knowledge":knowledge,"attributes":visible,"hidden_traits":hidden_visible,"ability_estimate":_range(int(player.get("current_ability",50)),knowledge),"potential_estimate":_range(int(player.get("development_ceiling",player.get("potential",50))),knowledge)}

func analyst_report(world: Dictionary, player: Dictionary, observer_quality: int, seed: int) -> Dictionary:
	var report := player_report(world,player,observer_quality,seed)
	var attrs: Dictionary = player.get("attributes",{})
	var strengths: Array = []
	var weaknesses: Array = []
	for key in attrs.keys():
		var score := int(attrs[key])
		if score >= 75: strengths.append({"attribute":String(key),"score":score})
		elif score <= 40: weaknesses.append({"attribute":String(key),"score":score})
	strengths.sort_custom(func(a:Dictionary,b:Dictionary): return int(a.score)>int(b.score))
	weaknesses.sort_custom(func(a:Dictionary,b:Dictionary): return int(a.score)<int(b.score))
	report["strengths"] = strengths.slice(0,mini(5,strengths.size()))
	report["weaknesses"] = weaknesses.slice(0,mini(5,weaknesses.size()))
	report["role_fit"] = _role_fit(player)
	world.scouting_reports.append(report.duplicate(true))
	return report

func _role_fit(player: Dictionary) -> Dictionary:
	var attrs: Dictionary = player.get("attributes",{})
	return {
		"creator":_average(attrs,["passing","vision","technique","decisions"]),
		"finisher":_average(attrs,["finishing","composure","off_the_ball"]),
		"ball_winner":_average(attrs,["tackling","positioning","aggression","work_rate"]),
		"runner":_average(attrs,["pace","acceleration","stamina","work_rate"])
	}

func _active_workload(world: Dictionary, scout_id: String) -> int:
	var count := 0
	for assignment in world.get("scout_assignments",[]):
		if String(assignment.get("scout_id","")) == scout_id and not bool(assignment.get("complete",false)): count += 1
	for focus in world.get("recruitment_focuses",[]):
		if String(focus.get("scout_id","")) == scout_id and bool(focus.get("active",true)): count += 1
	return maxi(1,count)

func _target_country(world: Dictionary, assignment: Dictionary) -> String:
	if String(assignment.get("target_type","")) == "country": return String(assignment.get("target_id",""))
	if String(assignment.get("target_type","")) == "player":
		for player in world.get("players",[]):
			if String(player.get("id","")) == String(assignment.get("target_id","")): return String(player.get("country_id",""))
	return ""

func _network_factor(world: Dictionary, club_id: String, country_id: String) -> float:
	var network: Dictionary = world.get("scouting_networks",{}).get(club_id,{})
	if country_id in network.get("countries",[]): return 1.18
	return 0.88 if not network.is_empty() else 0.75

func _language_factor(world: Dictionary, scout: Dictionary, country_id: String) -> float:
	var language := ""
	for country in world.get("countries",[]):
		if String(country.get("id","")) == country_id: language = String(country.get("language","")); break
	if language == "": return 1.0
	return 1.0 if language in scout.get("languages",[]) else 0.82

func _travel_factor(world: Dictionary, scout: Dictionary, country_id: String) -> float:
	var home_country := String(scout.get("country_id",scout.get("nationality_id","")))
	return 1.0 if home_country == country_id or country_id == "" else 0.90

func _average(attrs: Dictionary, keys: Array) -> float:
	var total := 0.0; var count := 0
	for key in keys:
		if attrs.has(key): total += float(attrs[key]); count += 1
	return total/maxf(1.0,float(count))

func _staff(staff: Array, id: String) -> Dictionary:
	for member in staff:
		if String(member.get("id","")) == id: return member
	return {}

func _range(value: int, knowledge: float) -> Dictionary:
	var spread := int(round((1.0-knowledge)*20.0))
	return {"min":clampi(value-spread,1,100),"max":clampi(value+spread,1,100)}

func _stable_key(text: String) -> int:
	var value := 29
	for character in text.to_utf8_buffer(): value = posmod(value*139+int(character),2_147_483_647)
	return value
