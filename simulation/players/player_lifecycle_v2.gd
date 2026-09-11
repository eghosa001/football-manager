class_name PlayerLifecycleV2
extends "res://simulation/players/player_lifecycle.gd"

const STAFF_ROLES := ["manager","assistant_manager","coach","scout","director","agent"]

func _should_retire(player: Dictionary, seed: int) -> bool:
	var age := int(player.get("age", 25))
	if age >= 42:
		return true
	if age < 31:
		return false
	var ability := float(player.get("current_ability",50))
	var fitness := float(player.get("fitness",80))
	var injuries := player.get("injury_history",[]).size()
	var injured_days := float(player.get("injured_days",0))
	var hidden: Dictionary = player.get("hidden_attributes",{})
	var professionalism := float(hidden.get("professionalism",50))
	var ambition := float(hidden.get("ambition",50))
	var loyalty := float(hidden.get("loyalty",50))
	var natural_fitness := float(player.get("attributes",{}).get("natural_fitness",50))
	var motivation := (professionalism+ambition+loyalty)/3.0
	var club_level := float(player.get("club_reputation",50))
	var contract_years_left := maxf(0.0,float(player.get("contract_end_year",age))-float(player.get("season_year",age)))
	var age_pressure := maxf(0.0,float(age-31))*0.085
	var ability_pressure := clampf((48.0-ability)/130.0,-0.08,0.20)
	var fitness_pressure := clampf((75.0-fitness)/180.0,-0.05,0.22)
	var injury_pressure := clampf(float(injuries)*0.012+injured_days/900.0,0.0,0.24)
	var motivation_resistance := clampf((motivation-50.0)/300.0,-0.12,0.16)
	var natural_resistance := clampf((natural_fitness-50.0)/350.0,-0.10,0.14)
	var level_resistance := clampf((club_level-50.0)/500.0,-0.06,0.08)
	var contract_resistance := clampf(contract_years_left*0.025,0.0,0.08)
	var chance := clampf(0.02+age_pressure+ability_pressure+fitness_pressure+injury_pressure-motivation_resistance-natural_resistance-level_resistance-contract_resistance,0.01,0.92)
	return SeededRngClass.unit_for(seed,_stable_key(String(player.get("id","")))+int(player.get("career_seasons",0))*211+99001) < chance

func _convert_to_staff(player: Dictionary, world: Dictionary, seed: int) -> Dictionary:
	var hidden: Dictionary = player.get("hidden_attributes",{})
	var attrs: Dictionary = player.get("attributes",{})
	var leadership := float(attrs.get("leadership",player.get("current_ability",50)))
	var decisions := float(attrs.get("decisions",player.get("current_ability",50)))
	var vision := float(attrs.get("vision",player.get("current_ability",50)))
	var adaptability := float(hidden.get("adaptability",50))
	var professionalism := float(hidden.get("professionalism",50))
	var ambition := float(hidden.get("ambition",50))
	var loyalty := float(hidden.get("loyalty",50))
	var role_scores := {
		"manager":leadership*0.35+decisions*0.30+ambition*0.20+professionalism*0.15,
		"assistant_manager":leadership*0.25+decisions*0.30+professionalism*0.30+loyalty*0.15,
		"coach":professionalism*0.35+decisions*0.20+float(player.get("current_ability",50))*0.30+leadership*0.15,
		"scout":vision*0.35+adaptability*0.35+decisions*0.20+professionalism*0.10,
		"director":leadership*0.25+ambition*0.30+decisions*0.30+adaptability*0.15,
		"agent":adaptability*0.35+ambition*0.35+vision*0.15+leadership*0.15,
	}
	var role := "coach"
	var best := -INF
	for candidate in STAFF_ROLES:
		var jitter := (SeededRngClass.unit_for(seed,_stable_key(String(player.get("id",""))+String(candidate))+7000)-0.5)*8.0
		var score := float(role_scores[candidate])+jitter
		if score > best:
			best = score
			role = candidate
	var ability := clampi(int(round(float(player.get("current_ability",50))*0.48+decisions*0.22+professionalism*0.20+leadership*0.10)),20,88)
	return {
		"id":"staff-from-"+String(player.get("id","")),
		"club_id":"" if role=="agent" else String(player.get("club_id","")),
		"name":String(player.get("first_name",""))+" "+String(player.get("last_name","")),
		"role":role,
		"ability":ability,
		"age":int(player.get("age",35)),
		"reputation":clampi(int(player.get("reputation",player.get("current_ability",50))),1,100),
		"adaptability":int(adaptability),
		"motivation":int(professionalism),
		"working_with_youngsters":int(hidden.get("sportsmanship",50)),
		"former_player_id":String(player.get("id","")),
		"career_origin":"retired_player"
	}
