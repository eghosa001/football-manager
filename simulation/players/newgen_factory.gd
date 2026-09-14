class_name NewgenFactory
extends RefCounted

const DatabaseLoaderClass = preload("res://data/database_loader.gd")
const RealismProfileClass = preload("res://data/realism_profile.gd")
const PlayerProfileClass = preload("res://simulation/players/player_profile.gd")
const SpecialAbilityServiceClass = preload("res://simulation/players/special_ability_service.gd")
const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

const POSITION_WEIGHTS := ["GK","DR","DC","DC","DL","DM","MC","MC","AMC","AMR","AML","ST","ST"]
const FEET := ["right","right","right","left","both"]
const BODY_TYPES := ["lean","balanced","powerful","compact","tall"]

const POSITION_BIASES := {
	"GK":{"reflexes":12,"handling":11,"one_on_ones":10,"aerial_reach":9,"gk_positioning":10,"communication":7,"kicking":5,"throwing":5,"command":8,"finishing":-18,"dribbling":-14},
	"DC":{"marking":10,"tackling":10,"positioning":9,"heading":9,"jumping":8,"strength":7,"bravery":6,"finishing":-8,"dribbling":-5},
	"DR":{"pace":8,"acceleration":7,"stamina":7,"crossing":7,"tackling":6,"work_rate":7,"marking":5},
	"DL":{"pace":8,"acceleration":7,"stamina":7,"crossing":7,"tackling":6,"work_rate":7,"marking":5},
	"DM":{"positioning":8,"tackling":7,"passing":7,"decisions":7,"teamwork":7,"stamina":6,"vision":5},
	"MC":{"passing":8,"vision":8,"decisions":7,"first_touch":7,"technique":7,"stamina":5,"teamwork":6},
	"AMC":{"vision":9,"technique":8,"first_touch":8,"passing":7,"flair":8,"off_the_ball":6,"finishing":5},
	"AMR":{"pace":9,"acceleration":9,"dribbling":9,"crossing":7,"flair":7,"off_the_ball":6,"finishing":5},
	"AML":{"pace":9,"acceleration":9,"dribbling":9,"crossing":7,"flair":7,"off_the_ball":6,"finishing":5},
	"ST":{"finishing":11,"off_the_ball":10,"composure":8,"acceleration":6,"pace":6,"heading":5,"strength":4,"passing":-4,"marking":-12,"tackling":-12},
}

func create(world: Dictionary, club: Dictionary, seed: int, unique_id: String, index: int = 0, age_override: int = -1) -> Dictionary:
	var data: Dictionary = DatabaseLoaderClass.new().load_seed("res://data/seed/launch_database.json", true)
	var realism = RealismProfileClass.new()
	var country_id: String = String(club.get("country_id", ""))
	var key: int = _stable_key(unique_id)
	var age: int = age_override if age_override >= 0 else 15 + int(SeededRngClass.value_for(seed, key + 8) % 3)
	var position: String = String(POSITION_WEIGHTS[int(SeededRngClass.value_for(seed, key + 2) % POSITION_WEIGHTS.size())])
	var nationality: String = _nationality(world, country_id, seed, key + 3)
	var second_nationality: String = _second_nationality(world, nationality, seed, key + 4)
	var used: Dictionary = _used_names(world)
	var identity: Dictionary = realism.generated_name(data, nationality, seed, key + 6 + index * 17, used, unique_id)
	var ca_pa: Dictionary = _ability_profile(world, club, nationality, seed, key)
	var ca: int = int(ca_pa.ca)
	var potential: int = int(ca_pa.pa)
	var height: int = _height_for_position(position, seed, key + 7)
	var player := {
		"id":unique_id,"club_id":String(club.get("id", "")),"country_id":nationality,"nationality_id":nationality,
		"second_nationality_id":second_nationality,"first_name":String(identity.first_name),"last_name":String(identity.last_name),"name":String(identity.full_name),
		"age":age,"position":position,"current_ability":ca,"potential":potential,"development_ceiling":potential,"base_potential":potential,
		"development_trajectory":_trajectory(seed, key + 15),"fitness":100,"morale":70,"retired":false,"injured_days":0,
		"season_appearances":0,"career_seasons":0,"preferred_foot":FEET[int(SeededRngClass.value_for(seed,key+9)%FEET.size())],
		"weak_foot":30 + int(SeededRngClass.value_for(seed,key+19)%56),"height_cm":height,"weight_kg":_weight(height,seed,key+10),
		"body_type":BODY_TYPES[int(SeededRngClass.value_for(seed,key+11)%BODY_TYPES.size())],"growth_stage":"adolescent" if age <= 16 else "late_adolescent",
		"physical_maturity":clampf(0.66 + float(age - 15) * 0.08 + float(SeededRngClass.value_for(seed,key+20)%9)/100.0,0.62,0.92),
		"homegrown":nationality == country_id,"squad_status":"academy","newgen":true,"fictional_identity":true,
	}
	player["hidden_attributes"] = _hidden_attributes(seed, key, ca, potential)
	player["attributes"] = _attributes(position, ca, float(player.physical_maturity), seed, key)
	var profile = PlayerProfileClass.new()
	profile.ensure(player)
	# Keep the persisted schema identical for freshly generated and reloaded players.
	# A previous dictionary-shaped personality value was normalized to a string by
	# CareerSession on load, which made the second season diverge after save/reload.
	player["personality"] = profile.personality(player)
	var abilities = SpecialAbilityServiceClass.new()
	player["special_abilities"] = abilities.assign_for_player(player, seed, key + 5000)
	player["special_ability_labels"] = abilities.labels_for(player)
	return player

func mature_physical(player: Dictionary, seed: int) -> void:
	if not bool(player.get("newgen", false)): return
	var age: int = int(player.get("age", 18))
	var maturity: float = float(player.get("physical_maturity", 0.8))
	if maturity >= 1.0 or age >= 22:
		player["physical_maturity"] = 1.0
		player["growth_stage"] = "mature"
		return
	var key: int = _stable_key(String(player.get("id", ""))) + age * 313
	var increment: float = 0.05 + float(SeededRngClass.value_for(seed,key)%5)/100.0
	var next_maturity: float = minf(1.0, maturity + increment)
	var attrs: Dictionary = player.get("attributes", {})
	var delta: float = next_maturity - maturity
	for name in ["strength","stamina","jumping","balance","natural_fitness"]:
		if attrs.has(name): attrs[name] = clampi(int(attrs[name]) + int(round(delta * 28.0)), 1, 100)
	if age <= 19 and SeededRngClass.unit_for(seed,key+2) < 0.55:
		player["height_cm"] = mini(208, int(player.get("height_cm",180)) + 1)
		player["weight_kg"] = mini(115, int(player.get("weight_kg",75)) + 1)
	player["physical_maturity"] = next_maturity
	player["growth_stage"] = "mature" if next_maturity >= 0.98 else "developing"

func _ability_profile(world: Dictionary, club: Dictionary, country_id: String, seed: int, key: int) -> Dictionary:
	var academy: int = int(club.get("youth_facilities", club.get("training_facilities", 50)))
	var recruitment: int = int(club.get("youth_recruitment", club.get("academy", {}).get("recruitment", 50)))
	var coaching: int = int(club.get("academy", {}).get("coaching", 50))
	var rep: int = int(club.get("reputation", 50))
	var talent: float = _country_talent(world, country_id)
	var environment: float = academy * 0.24 + recruitment * 0.28 + coaching * 0.16 + rep * 0.12 + talent * 100.0 * 0.20
	var roll: float = float(SeededRngClass.value_for(seed,key+21)%10000)/10000.0
	var tier_bonus := 0
	if roll > 0.998: tier_bonus = 24
	elif roll > 0.985: tier_bonus = 14
	elif roll > 0.93: tier_bonus = 7
	var ca: int = clampi(int(environment * 0.58) + int(SeededRngClass.value_for(seed,key)%23)-11 + tier_bonus/3, 18, 68)
	var gap: int = 10 + int(SeededRngClass.value_for(seed,key+1)%30) + int(environment/11.0) + tier_bonus
	var pa: int = clampi(ca + gap, ca, 99)
	return {"ca":ca,"pa":pa}

func _attributes(position: String, ca: int, maturity: float, seed: int, key: int) -> Dictionary:
	var attrs := {}
	var names: Array = PlayerProfileClass.TECHNICAL + PlayerProfileClass.MENTAL + PlayerProfileClass.PHYSICAL + PlayerProfileClass.GOALKEEPING
	var biases: Dictionary = POSITION_BIASES.get(position, {})
	for i in range(names.size()):
		var name: String = String(names[i])
		var base: int = ca + int(biases.get(name, 0)) + int(SeededRngClass.value_for(seed,key+200+i*13)%15)-7
		if name in PlayerProfileClass.PHYSICAL: base = int(round(float(base) * lerpf(0.78,1.0,maturity)))
		if position != "GK" and name in PlayerProfileClass.GOALKEEPING: base = mini(base, 28 + int(SeededRngClass.value_for(seed,key+900+i)%13))
		if position == "GK" and name in PlayerProfileClass.TECHNICAL and name not in ["passing","first_touch","technique"]: base -= 8
		attrs[name] = clampi(base, 1, 100)
	return attrs

func _hidden_attributes(seed: int, key: int, ca: int, pa: int) -> Dictionary:
	var result := {}
	for i in range(PlayerProfileClass.HIDDEN.size()):
		var name: String = String(PlayerProfileClass.HIDDEN[i])
		result[name] = 25 + int(SeededRngClass.value_for(seed,key+1200+i*29)%66)
	if pa - ca >= 30:
		result["ambition"] = mini(95, int(result.ambition)+5)
		result["professionalism"] = mini(95, int(result.professionalism)+3)
	return result

func _nationality(world: Dictionary, home_country: String, seed: int, key: int) -> String:
	if SeededRngClass.unit_for(seed,key) < 0.84 and home_country != "": return home_country
	var countries: Array = world.get("countries",[])
	if countries.is_empty(): return home_country
	return String(countries[int(SeededRngClass.value_for(seed,key+1)%countries.size())].get("id",home_country))

func _second_nationality(world: Dictionary, primary: String, seed: int, key: int) -> String:
	if SeededRngClass.unit_for(seed,key) > 0.18: return ""
	var choices: Array = []
	for country in world.get("countries",[]):
		if String(country.get("id","")) != primary: choices.append(String(country.get("id","")))
	if choices.is_empty(): return ""
	return String(choices[int(SeededRngClass.value_for(seed,key+1)%choices.size())])

func _country_talent(world: Dictionary, country_id: String) -> float:
	for country in world.get("countries",[]):
		if String(country.get("id","")) != country_id: continue
		var youth: float = float(country.get("youth_rating", country.get("reputation",50)))
		var popularity: float = float(country.get("football_popularity",60))
		var infrastructure: float = float(country.get("youth_infrastructure", country.get("infrastructure",50)))
		var national_success: float = float(country.get("national_success",50))
		var league_rep: float = float(country.get("league_reputation",50))
		return clampf((youth*0.40+popularity*0.16+infrastructure*0.22+national_success*0.10+league_rep*0.12)/100.0,0.08,1.0)
	return 0.45

func _trajectory(seed: int, key: int) -> String:
	var roll: int = int(SeededRngClass.value_for(seed,key)%100)
	if roll < 12: return "early"
	if roll < 77: return "normal"
	if roll < 95: return "late"
	return "volatile"

func _used_names(world: Dictionary) -> Dictionary:
	var used := {}
	for player in world.get("players",[]):
		var full: String = (String(player.get("first_name",""))+" "+String(player.get("last_name",""))).strip_edges()
		if full != "": used[full] = true
	for member in world.get("staff",[]):
		var full: String = String(member.get("name","")).strip_edges()
		if full != "": used[full] = true
	return used

func _height_for_position(position: String, seed: int, key: int) -> int:
	var base: int = 188 if position == "GK" else (185 if position == "DC" else (181 if position == "ST" else 177))
	return clampi(base + int(SeededRngClass.value_for(seed,key)%17)-8,160,205)

func _weight(height: int, seed: int, key: int) -> int:
	return clampi(int(float(height-100)*0.83)+int(SeededRngClass.value_for(seed,key)%9)-4,55,105)

func _stable_key(text: String) -> int:
	var value := 97
	for c in text.to_utf8_buffer(): value = posmod(value*193+int(c),2_147_483_647)
	return value
