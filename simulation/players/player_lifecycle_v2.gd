class_name PlayerLifecycleV2
extends "res://simulation/players/player_lifecycle.gd"

const SpecialAbilityServiceClass = preload("res://simulation/players/special_ability_service.gd")
const NewgenFactoryClass = preload("res://simulation/players/newgen_factory.gd")
const STAFF_ROLES := ["manager","assistant_manager","coach","scout","director","agent"]

func advance_year(world: Dictionary, season_seed: int, youth_per_club: int = 2) -> Dictionary:
	var result: Dictionary = super.advance_year(world, season_seed, youth_per_club)
	result["country_evolution"] = _evolve_country_youth_strength(world, season_seed)
	result["mentored"] = _apply_youth_mentoring(world, season_seed)
	result["academy_decisions"] = _manage_ai_academies(world, season_seed)
	return result

func _roll_injury_days(_player: Dictionary, _seed: int) -> int:
	return 0

func train_player(player: Dictionary, focus: String, intensity: float, seed: int) -> int:
	var before: int = int(player.get("current_ability", 50))
	var gained: int = super.train_player(player, focus, intensity, seed)
	var abilities = SpecialAbilityServiceClass.new()
	var multiplier: float = abilities.development_multiplier(player)
	if multiplier <= 1.0: return gained
	var potential: int = int(player.get("potential", before))
	var room: int = maxi(0, potential - int(player.get("current_ability", before)))
	if room <= 0: return gained
	var extra_chance: float = clampf((multiplier - 1.0) * clampf(intensity, 0.0, 1.0), 0.0, 0.45)
	var key: int = _stable_key(String(player.get("id", ""))) + int(player.get("career_seasons", 0)) * 401 + 17777
	if SeededRngClass.unit_for(seed, key) < extra_chance:
		player["current_ability"] = mini(potential, int(player.get("current_ability", before)) + 1)
		_improve_attributes(player, focus, 1)
		gained += 1
	return gained

func _apply_development(player: Dictionary, world: Dictionary, seed: int) -> Dictionary:
	var before: int = int(player.get("current_ability", 50))
	var record: Dictionary = super._apply_development(player, world, seed)
	NewgenFactoryClass.new().mature_physical(player, seed)
	var abilities = SpecialAbilityServiceClass.new()
	var multiplier: float = abilities.development_multiplier(player)
	if multiplier <= 1.0: return record
	var after: int = int(player.get("current_ability", before))
	var natural_gain: int = maxi(0, after - before)
	var potential: int = int(player.get("potential", after))
	var room: int = maxi(0, potential - after)
	if natural_gain <= 0 or room <= 0: return record
	var extra: int = mini(room, int(round(float(natural_gain) * (multiplier - 1.0))))
	if extra <= 0 and multiplier >= 1.30: extra = 1
	extra = mini(extra, room)
	if extra > 0:
		player["current_ability"] = mini(potential, after + extra)
		_apply_attribute_development(player, extra, int(player.get("age", 20)), seed, _stable_key(String(player.get("id", ""))) + 88111)
		record["after"] = int(player.get("current_ability", after))
		record["delta"] = int(record.get("delta", 0)) + extra
		record["prodigy_bonus"] = extra
		var history: Array = player.get("development_history", [])
		if not history.is_empty(): history[history.size() - 1] = record.duplicate(true)
	return record

func _generate_youth_intake(world: Dictionary, seed: int, per_club: int) -> Array:
	var created: Array = []
	var season_year: int = int(world.get("season_year", 2026))
	var factory = NewgenFactoryClass.new()
	for club in world.clubs:
		for i in range(per_club):
			var player_id: String = "youth-%s-%d-%d" % [String(club.id), season_year, i]
			if _has_player(world.players, player_id): continue
			var player: Dictionary = factory.create(world, club, seed, player_id, i, 16)
			player["squad_status"] = "academy"
			ensure_player_state(player, seed)
			world.players.append(player)
			var key: int = _stable_key(player_id)
			world.contracts.append({"id":"contract-"+player_id,"player_id":player_id,"club_id":String(club.id),"start_year":season_year,"end_year":season_year+3,"weekly_wage":_rand_int(seed,key+4,250,1200),"contract_type":"scholarship"})
			club["academy"] = club.get("academy", {"prospects":[],"recruitment":50,"coaching":50,"reputation":40,"region_knowledge":50,"intake_variance":2})
			club.academy["prospects"] = club.academy.get("prospects", [])
			if player_id not in club.academy.prospects: club.academy.prospects.append(player_id)
			created.append(player_id)
	return created

func _evolve_country_youth_strength(world: Dictionary, seed: int) -> Array:
	var changes: Array = []
	for country in world.get("countries", []):
		var country_id := String(country.get("id", ""))
		var club_count := 0
		var facilities_total := 0.0
		var rep_total := 0.0
		for club in world.get("clubs", []):
			if String(club.get("country_id", "")) != country_id: continue
			club_count += 1
			facilities_total += float(club.get("youth_facilities", club.get("training_facilities",50)))
			rep_total += float(club.get("reputation",50))
		if club_count == 0: continue
		var avg_facilities := facilities_total / float(club_count)
		var avg_rep := rep_total / float(club_count)
		var success := float(country.get("national_success",50))
		var target := avg_facilities*0.42 + avg_rep*0.28 + success*0.30
		var youth_before := float(country.get("youth_rating",50))
		var infrastructure_before := float(country.get("youth_infrastructure", country.get("infrastructure",50)))
		var random_drift := (SeededRngClass.unit_for(seed,_stable_key(country_id)+700001)-0.5)*1.2
		var youth_after := clampf(youth_before + clampf((target-youth_before)*0.035,-1.2,1.2)+random_drift,15.0,95.0)
		var infrastructure_after := clampf(infrastructure_before + clampf((avg_facilities-infrastructure_before)*0.025,-0.8,0.8),15.0,95.0)
		country["youth_rating"] = snappedf(youth_after,0.1)
		country["youth_infrastructure"] = snappedf(infrastructure_after,0.1)
		changes.append({"country_id":country_id,"youth_before":youth_before,"youth_after":youth_after,"infrastructure_after":infrastructure_after})
	return changes

func _apply_youth_mentoring(world: Dictionary, seed: int) -> Array:
	var affected: Array = []
	for club in world.get("clubs", []):
		var club_id := String(club.get("id", ""))
		var mentors: Array = []
		var youngsters: Array = []
		for player in world.get("players", []):
			if String(player.get("club_id", "")) != club_id or bool(player.get("retired",false)): continue
			if int(player.get("age",25)) >= 27 and int(player.get("current_ability",50)) >= 60:
				mentors.append(player)
			elif int(player.get("age",25)) <= 21:
				youngsters.append(player)
		if mentors.is_empty() or youngsters.is_empty(): continue
		mentors.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.get("hidden_attributes",{}).get("professionalism",50)) > int(b.get("hidden_attributes",{}).get("professionalism",50)))
		var mentor: Dictionary = mentors[0]
		var mentor_hidden: Dictionary = mentor.get("hidden_attributes",{})
		for young in youngsters:
			var key := _stable_key(String(young.get("id",""))) + int(world.get("season_year",2026))*53
			if SeededRngClass.unit_for(seed,key) > 0.45: continue
			var hidden: Dictionary = young.get("hidden_attributes",{})
			for name in ["professionalism","determination","pressure","sportsmanship"]:
				if name == "determination":
					var attrs: Dictionary = young.get("attributes",{})
					if attrs.has(name): attrs[name] = mini(100,int(attrs[name])+1)
				elif hidden.has(name) and int(mentor_hidden.get(name,50)) > int(hidden[name]):
					hidden[name] = mini(100,int(hidden[name])+1)
			young["mentored_by"] = String(mentor.get("id",""))
			affected.append(String(young.get("id","")))
	return affected

func _manage_ai_academies(world: Dictionary, seed: int) -> Dictionary:
	var promoted: Array = []
	var development_listed: Array = []
	var released: Array = []
	var human_club := String(world.get("managed_club_id", ""))
	for club in world.get("clubs", []):
		var club_id := String(club.get("id", ""))
		if club_id == human_club or bool(club.get("human_managed",false)): continue
		var academy: Dictionary = club.get("academy",{})
		var prospects: Array = academy.get("prospects",[]).duplicate()
		if prospects.is_empty(): continue
		var senior_threshold := _senior_threshold(world, club_id)
		for player_id in prospects:
			var player := _player_in(world, String(player_id))
			if player.is_empty(): continue
			var age := int(player.get("age",16))
			var ca := int(player.get("current_ability",40))
			var pa := int(player.get("potential",ca))
			if ca >= senior_threshold-7 or (age >= 18 and pa >= senior_threshold+10):
				player["squad_status"] = "first_team"
				academy.prospects.erase(player_id)
				promoted.append(String(player_id))
			elif age >= 18 and pa >= senior_threshold and ca < senior_threshold-8:
				player["squad_status"] = "development_list"
				player["loan_candidate"] = true
				development_listed.append(String(player_id))
			elif age >= 20 and pa < senior_threshold-4:
				player["club_id"] = ""
				player["squad_status"] = "free_agent"
				academy.prospects.erase(player_id)
				released.append(String(player_id))
		club["academy"] = academy
	return {"promoted":promoted,"development_listed":development_listed,"released":released}

func _senior_threshold(world: Dictionary, club_id: String) -> int:
	var values: Array = []
	for player in world.get("players", []):
		if String(player.get("club_id", "")) == club_id and String(player.get("squad_status","")) != "academy" and not bool(player.get("retired",false)):
			values.append(int(player.get("current_ability",50)))
	if values.is_empty(): return 50
	values.sort()
	return int(values[maxi(0,values.size()/2)])

func _player_in(world: Dictionary, player_id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == player_id: return player
	return {}

func _should_retire(player: Dictionary, seed: int) -> bool:
	var age: int = int(player.get("age", 25))
	if age >= 42: return true
	if age < 31: return false
	var ability: float = float(player.get("current_ability",50))
	var fitness: float = float(player.get("fitness",80))
	var injuries: int = int(player.get("injury_history", []).size())
	var injured_days: float = float(player.get("injured_days",0))
	var hidden: Dictionary = player.get("hidden_attributes",{})
	var professionalism: float = float(hidden.get("professionalism",50))
	var ambition: float = float(hidden.get("ambition",50))
	var loyalty: float = float(hidden.get("loyalty",50))
	var natural_fitness: float = float(player.get("attributes",{}).get("natural_fitness",50))
	var motivation: float = (professionalism+ambition+loyalty)/3.0
	var club_level: float = float(player.get("club_reputation",50))
	var contract_years_left: float = maxf(0.0,float(player.get("contract_end_year",age))-float(player.get("season_year",age)))
	var age_pressure: float = maxf(0.0,float(age-31))*0.085
	var ability_pressure: float = clampf((48.0-ability)/130.0,-0.08,0.20)
	var fitness_pressure: float = clampf((75.0-fitness)/180.0,-0.05,0.22)
	var injury_pressure: float = clampf(float(injuries)*0.012+injured_days/900.0,0.0,0.24)
	var motivation_resistance: float = clampf((motivation-50.0)/300.0,-0.12,0.16)
	var natural_resistance: float = clampf((natural_fitness-50.0)/350.0,-0.10,0.14)
	var level_resistance: float = clampf((club_level-50.0)/500.0,-0.06,0.08)
	var contract_resistance: float = clampf(contract_years_left*0.025,0.0,0.08)
	var chance: float = clampf(0.02+age_pressure+ability_pressure+fitness_pressure+injury_pressure-motivation_resistance-natural_resistance-level_resistance-contract_resistance,0.01,0.92)
	return SeededRngClass.unit_for(seed,_stable_key(String(player.get("id","")))+int(player.get("career_seasons",0))*211+99001) < chance

func _convert_to_staff(player: Dictionary, world: Dictionary, seed: int) -> Dictionary:
	var hidden: Dictionary = player.get("hidden_attributes",{})
	var attrs: Dictionary = player.get("attributes",{})
	var leadership: float = float(attrs.get("leadership",player.get("current_ability",50)))
	var decisions: float = float(attrs.get("decisions",player.get("current_ability",50)))
	var vision: float = float(attrs.get("vision",player.get("current_ability",50)))
	var adaptability: float = float(hidden.get("adaptability",50))
	var professionalism: float = float(hidden.get("professionalism",50))
	var ambition: float = float(hidden.get("ambition",50))
	var loyalty: float = float(hidden.get("loyalty",50))
	var role_scores: Dictionary = {
		"manager":leadership*0.35+decisions*0.30+ambition*0.20+professionalism*0.15,
		"assistant_manager":leadership*0.25+decisions*0.30+professionalism*0.30+loyalty*0.15,
		"coach":professionalism*0.35+decisions*0.20+float(player.get("current_ability",50))*0.30+leadership*0.15,
		"scout":vision*0.35+adaptability*0.35+decisions*0.20+professionalism*0.10,
		"director":leadership*0.25+ambition*0.30+decisions*0.30+adaptability*0.15,
		"agent":adaptability*0.35+ambition*0.35+vision*0.15+leadership*0.15,
	}
	var role: String = "coach"
	var best: float = -INF
	for candidate in STAFF_ROLES:
		var jitter: float = (SeededRngClass.unit_for(seed,_stable_key(String(player.get("id",""))+String(candidate))+7000)-0.5)*8.0
		var score: float = float(role_scores[candidate])+jitter
		if score > best:
			best = score
			role = candidate
	var ability: int = clampi(int(round(float(player.get("current_ability",50))*0.48+decisions*0.22+professionalism*0.20+leadership*0.10)),20,88)
	return {
		"id":"staff-from-"+String(player.get("id","")),
		"club_id":"" if role=="agent" else String(player.get("club_id","")),
		"name":String(player.get("first_name",""))+" "+String(player.get("last_name","")),
		"role":role,"ability":ability,"age":int(player.get("age",35)),
		"reputation":clampi(int(player.get("reputation",player.get("current_ability",50))),1,100),
		"adaptability":int(adaptability),"motivation":int(professionalism),"working_with_youngsters":int(hidden.get("sportsmanship",50)),
		"former_player_id":String(player.get("id","")),"career_origin":"retired_player"
	}
