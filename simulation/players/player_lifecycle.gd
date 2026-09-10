class_name PlayerLifecycle
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const PlayerProfileClass = preload("res://simulation/players/player_profile.gd")

const POSITIONS := ["GK", "DR", "DC", "DL", "DM", "MC", "AMR", "AML", "ST"]
const LEGACY_ATTRIBUTES := ["pace", "stamina", "passing", "technique", "tackling", "finishing", "positioning", "decisions", "goalkeeping"]
const PHYSICAL_ATTRIBUTES := ["acceleration", "pace", "agility", "balance", "jumping", "strength", "stamina", "natural_fitness"]
const MENTAL_ATTRIBUTES := ["anticipation", "composure", "concentration", "decisions", "determination", "flair", "leadership", "off_the_ball", "positioning", "teamwork", "vision", "work_rate", "aggression", "bravery"]

func ensure_player_state(player: Dictionary, seed: int) -> void:
	if not player.has("attributes"):
		var attrs := {}
		for i in range(LEGACY_ATTRIBUTES.size()):
			var offset: int = _rand_int(seed, _stable_key(String(player.id)) + i * 17, -12, 12)
			attrs[LEGACY_ATTRIBUTES[i]] = clampi(int(player.current_ability) + offset, 1, 100)
		if String(player.position) == "GK":
			attrs["goalkeeping"] = clampi(int(player.current_ability) + 8, 1, 100)
		player["attributes"] = attrs
	_seed_hidden_attributes(player, seed)
	PlayerProfileClass.new().ensure(player)
	player["injured_days"] = int(player.get("injured_days", 0))
	player["injury_history"] = player.get("injury_history", [])
	player["training_focus"] = String(player.get("training_focus", "balanced"))
	player["career_seasons"] = int(player.get("career_seasons", 0))
	player["season_appearances"] = int(player.get("season_appearances", 0))
	player["development_history"] = player.get("development_history", [])

func advance_year(world: Dictionary, season_seed: int, youth_per_club: int = 2) -> Dictionary:
	var retired: Array = []
	var staff_conversions: Array = []
	var injuries: Array = []
	var development: Array = []
	for player in world.players:
		ensure_player_state(player, season_seed)
		if bool(player.get("retired", false)):
			continue
		player.age = int(player.age) + 1
		player.career_seasons = int(player.career_seasons) + 1
		var change: Dictionary = _apply_development(player, world, season_seed)
		development.append(change)
		var injury_days: int = _roll_injury_days(player, season_seed)
		player.injured_days = maxi(int(player.get("injured_days", 0)), injury_days)
		if injury_days > 0:
			player.injury_history.append({"season_year": int(world.get("season_year", 2026)), "days": injury_days, "source":"season_rollover"})
			injuries.append(String(player.id))
		if _should_retire(player, season_seed):
			player.retired = true
			retired.append(String(player.id))
			if int(player.current_ability) >= 55:
				var staff := _convert_to_staff(player, world, season_seed)
				world.staff.append(staff)
				staff_conversions.append(String(staff.id))
		player.season_appearances = 0
	var youth: Array = _generate_youth_intake(world, season_seed, youth_per_club)
	return {"retired": retired, "staff_conversions": staff_conversions, "injuries": injuries, "youth": youth, "development":development}

func train_player(player: Dictionary, focus: String, intensity: float, seed: int) -> int:
	ensure_player_state(player, seed)
	if bool(player.get("retired", false)):
		return 0
	player.training_focus = focus
	var room: int = maxi(0, int(player.potential) - int(player.current_ability))
	var age_factor: float = 1.0 if int(player.age) <= 23 else (0.55 if int(player.age) <= 28 else 0.15)
	var professionalism := float(player.get("hidden_attributes", {}).get("professionalism", 50))
	var gain: int = mini(room, int(round(clampf(intensity, 0.0, 1.0) * age_factor * (0.8 + professionalism / 125.0) * 1.5)))
	if gain > 0:
		player.current_ability = clampi(int(player.current_ability) + gain, 1, 100)
		_improve_attributes(player, focus, gain)
	return gain

func _apply_development(player: Dictionary, world: Dictionary, seed: int) -> Dictionary:
	var age := int(player.age)
	var before := int(player.current_ability)
	var key := _stable_key(String(player.id)) + int(player.career_seasons) * 997
	var club := _club(world.get("clubs", []), String(player.get("club_id", "")))
	var potential_gap := maxi(0, int(player.potential) - before)
	var hidden: Dictionary = player.get("hidden_attributes", {})
	var professionalism := float(hidden.get("professionalism", 50))
	var natural_fitness := float(hidden.get("natural_fitness", player.get("attributes", {}).get("natural_fitness", 50)))
	var morale := float(player.get("morale", 70))
	var facilities := float(club.get("training_facilities", 50)) if not club.is_empty() else 35.0
	var coaching := _coaching_quality(world.get("staff", []), String(player.get("club_id", "")))
	var appearances := int(player.get("season_appearances", 0))
	var playing_time := clampf(float(appearances) / 30.0, 0.15, 1.0)
	var injury_days := int(player.get("injured_days", 0))
	var injury_factor := clampf(1.0 - float(injury_days) / 180.0, 0.45, 1.0)
	var competition_factor := clampf(0.75 + float(club.get("reputation", 50)) / 180.0, 0.75, 1.25) if not club.is_empty() else 0.8
	var random_factor := 0.85 + _rand_int(seed, key + 13, 0, 30) / 100.0

	var age_growth := 0.0
	if age <= 19: age_growth = 3.2
	elif age <= 21: age_growth = 2.6
	elif age <= 24: age_growth = 1.8
	elif age <= 27: age_growth = 0.7
	elif age <= 29: age_growth = 0.15
	elif age <= 31: age_growth = -0.6
	elif age <= 34: age_growth = -1.5
	else: age_growth = -2.8

	var delta := 0
	if age_growth >= 0.0:
		var gap_factor := clampf(float(potential_gap) / 22.0, 0.0, 1.35)
		var environment := (0.65 + professionalism / 170.0) * (0.75 + facilities / 200.0) * (0.75 + coaching / 200.0)
		var wellbeing := (0.8 + morale / 350.0) * playing_time * injury_factor * competition_factor
		delta = int(round(age_growth * gap_factor * environment * wellbeing * random_factor))
		delta = clampi(delta, 0, 5)
		delta = mini(delta, potential_gap)
	else:
		var decline_resistance := clampf(0.65 + natural_fitness / 170.0 + professionalism / 300.0, 0.7, 1.45)
		var injury_penalty := 1.0 + float(injury_days) / 240.0
		delta = -int(round(absf(age_growth) * injury_penalty / decline_resistance * random_factor))
		delta = clampi(delta, -5, 0)

	player.current_ability = clampi(before + delta, 1, 100)
	_apply_attribute_development(player, delta, age, seed, key)
	player.fitness = clampi(int(player.get("fitness", 100)) + _rand_int(seed, key + 31, -4, 4), 55, 100)
	player.morale = clampi(int(player.get("morale", 70)) + _rand_int(seed, key + 47, -5, 5), 30, 100)
	var record := {"season_year":int(world.get("season_year", 2026)),"player_id":String(player.id),"before":before,"after":int(player.current_ability),"delta":delta,"appearances":appearances,"facilities":int(facilities),"coaching":int(round(coaching))}
	player.development_history.append(record.duplicate(true))
	return record

func _apply_attribute_development(player: Dictionary, ability_delta: int, age: int, seed: int, key: int) -> void:
	var attrs: Dictionary = player.attributes
	for name in attrs.keys():
		var delta := ability_delta
		if ability_delta < 0:
			if String(name) in PHYSICAL_ATTRIBUTES:
				delta = mini(-1, ability_delta - (1 if age >= 33 else 0))
			elif String(name) in MENTAL_ATTRIBUTES:
				delta = mini(0, int(round(float(ability_delta) * 0.35)))
			else:
				delta = mini(0, int(round(float(ability_delta) * 0.6)))
		elif ability_delta > 0:
			var focus := String(player.get("training_focus", "balanced"))
			if _focus_matches(focus, String(name)):
				delta += 1
			elif _rand_int(seed, key + _stable_key(String(name)), 0, 3) == 0:
				delta = maxi(0, delta - 1)
		attrs[name] = clampi(int(attrs[name]) + clampi(delta, -6, 5), 1, 100)

func _focus_matches(focus: String, attribute_name: String) -> bool:
	match focus:
		"attacking": return attribute_name in ["finishing","technique","off_the_ball","composure","dribbling"]
		"defending": return attribute_name in ["tackling","marking","positioning","concentration","strength"]
		"passing": return attribute_name in ["passing","vision","decisions","technique","first_touch"]
		"physical": return attribute_name in PHYSICAL_ATTRIBUTES
		"goalkeeping": return attribute_name in PlayerProfileClass.GOALKEEPING
		_: return false

func _improve_attributes(player: Dictionary, focus: String, gain: int) -> void:
	if gain <= 0: return
	for name in player.attributes.keys():
		if focus == "balanced" or _focus_matches(focus, String(name)):
			player.attributes[name] = clampi(int(player.attributes[name]) + gain, 1, 100)

func _roll_injury_days(player: Dictionary, seed: int) -> int:
	var age_risk: int = maxi(0, int(player.age) - 28)
	var proneness := int(player.get("hidden_attributes", {}).get("injury_proneness", 50))
	var key: int = _stable_key(String(player.id)) + int(player.career_seasons) * 1543
	var chance_per_thousand: int = 35 + age_risk * 5 + proneness / 2
	if _rand_int(seed, key + 71, 0, 999) >= chance_per_thousand: return 0
	return _rand_int(seed, key + 73, 7, 70)

func _should_retire(player: Dictionary, seed: int) -> bool:
	var age: int = int(player.age)
	if age >= 40: return true
	if age < 33: return false
	var professionalism := int(player.get("hidden_attributes", {}).get("professionalism", 50))
	var natural_fitness := int(player.get("attributes", {}).get("natural_fitness", 50))
	var threshold: int = maxi(20, (age - 32) * 105 - professionalism / 3 - natural_fitness / 4)
	return _rand_int(seed, _stable_key(String(player.id)) + int(player.career_seasons) * 211, 0, 999) < threshold

func _generate_youth_intake(world: Dictionary, seed: int, per_club: int) -> Array:
	var created: Array = []
	var season_year: int = int(world.get("season_year", 2026))
	for club in world.clubs:
		var academy := int(club.get("youth_facilities", club.get("training_facilities", 50)))
		var recruitment := int(club.get("youth_recruitment", 50))
		for i in range(per_club):
			var player_id := "youth-%s-%d-%d" % [String(club.id), season_year, i]
			if _has_player(world.players, player_id): continue
			var key: int = _stable_key(player_id)
			var ca: int = clampi(_rand_int(seed, key + 1, 24, 44) + academy / 12, 25, 60)
			var potential: int = clampi(ca + _rand_int(seed, key + 2, 12, 35) + recruitment / 10, ca, 98)
			var player := {"id":player_id,"club_id":String(club.id),"country_id":String(club.get("country_id", "")),"first_name":"Youth","last_name":str(i + 1),"age":16,"position":POSITIONS[_rand_int(seed,key+3,0,POSITIONS.size()-1)],"current_ability":ca,"potential":potential,"fitness":100,"morale":70,"retired":false,"season_appearances":0}
			ensure_player_state(player, seed)
			world.players.append(player)
			world.contracts.append({"id":"contract-"+player_id,"player_id":player_id,"club_id":String(club.id),"start_year":season_year,"end_year":season_year+3,"weekly_wage":_rand_int(seed,key+4,250,1200)})
			created.append(player_id)
	return created

func _convert_to_staff(player: Dictionary, world: Dictionary, seed: int) -> Dictionary:
	var key: int = _stable_key(String(player.id))
	return {"id":"staff-from-"+String(player.id),"club_id":String(player.club_id),"name":String(player.first_name)+" "+String(player.last_name),"role":"coach","ability":clampi(int(player.current_ability)+_rand_int(seed,key,-8,8),25,90),"adaptability":int(player.get("hidden_attributes",{}).get("adaptability",50)),"motivation":int(player.get("hidden_attributes",{}).get("professionalism",50)),"working_with_youngsters":int(player.get("hidden_attributes",{}).get("sportsmanship",50))}

func _seed_hidden_attributes(player: Dictionary, seed: int) -> void:
	var hidden: Dictionary = player.get("hidden_attributes", {})
	var key := _stable_key(String(player.id))
	for i in range(PlayerProfileClass.HIDDEN.size()):
		var name: String = String(PlayerProfileClass.HIDDEN[i])
		if not hidden.has(name):
			hidden[name] = _rand_int(seed, key + 500 + i * 19, 20, 90)
	player.hidden_attributes = hidden

func _coaching_quality(staff: Array, club_id: String) -> float:
	var total := 0.0
	var count := 0
	for member in staff:
		if String(member.get("club_id", "")) == club_id and String(member.get("role", "")) in ["manager","assistant","assistant_manager","coach"]:
			total += float(member.get("ability", 50)); count += 1
	return total / maxf(1.0, float(count))

func _club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if String(club.get("id", "")) == club_id: return club
	return {}

func _has_player(players: Array, player_id: String) -> bool:
	for player in players:
		if String(player.id) == player_id: return true
	return false

func _stable_key(text: String) -> int:
	var value := 17
	for character in text.to_utf8_buffer(): value = posmod(value * 131 + int(character), 2_147_483_647)
	return value

func _rand_int(seed: int, key: int, min_value: int, max_value: int) -> int:
	return min_value + (SeededRngClass.value_for(seed, key) % (max_value - min_value + 1))
