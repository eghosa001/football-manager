class_name PlayerLifecycle
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const POSITIONS := ["GK", "DR", "DC", "DL", "DM", "MC", "AMR", "AML", "ST"]
const ATTRIBUTES := ["pace", "stamina", "passing", "technique", "tackling", "finishing", "positioning", "decisions", "goalkeeping"]

func ensure_player_state(player: Dictionary, seed: int) -> void:
	if not player.has("attributes"):
		var attrs := {}
		for i in range(ATTRIBUTES.size()):
			var offset: int = _rand_int(seed, _stable_key(String(player.id)) + i * 17, -12, 12)
			attrs[ATTRIBUTES[i]] = clampi(int(player.current_ability) + offset, 1, 100)
		if String(player.position) == "GK":
			attrs["goalkeeping"] = clampi(int(player.current_ability) + 8, 1, 100)
		player["attributes"] = attrs
	player["injured_days"] = int(player.get("injured_days", 0))
	player["injury_history"] = player.get("injury_history", [])
	player["training_focus"] = String(player.get("training_focus", "balanced"))
	player["career_seasons"] = int(player.get("career_seasons", 0))

func advance_year(world: Dictionary, season_seed: int, youth_per_club: int = 2) -> Dictionary:
	var retired: Array = []
	var staff_conversions: Array = []
	var injuries: Array = []
	for player in world.players:
		ensure_player_state(player, season_seed)
		if bool(player.get("retired", false)):
			continue
		player.age = int(player.age) + 1
		player.career_seasons = int(player.career_seasons) + 1
		_apply_development(player, season_seed)
		var injury_days: int = _roll_injury_days(player, season_seed)
		player.injured_days = injury_days
		if injury_days > 0:
			player.injury_history.append({"season_year": int(world.get("season_year", 2026)), "days": injury_days})
			injuries.append(String(player.id))
		if _should_retire(player, season_seed):
			player.retired = true
			retired.append(String(player.id))
			if int(player.current_ability) >= 55:
				var staff := _convert_to_staff(player, world, season_seed)
				world.staff.append(staff)
				staff_conversions.append(String(staff.id))
	var youth: Array = _generate_youth_intake(world, season_seed, youth_per_club)
	return {"retired": retired, "staff_conversions": staff_conversions, "injuries": injuries, "youth": youth}

func train_player(player: Dictionary, focus: String, intensity: float, seed: int) -> int:
	ensure_player_state(player, seed)
	if bool(player.get("retired", false)):
		return 0
	player.training_focus = focus
	var room: int = maxi(0, int(player.potential) - int(player.current_ability))
	var age_factor: float = 1.0 if int(player.age) <= 23 else (0.55 if int(player.age) <= 28 else 0.15)
	var gain: int = mini(room, int(round(clampf(intensity, 0.0, 1.0) * age_factor * 2.0)))
	if gain > 0:
		player.current_ability = clampi(int(player.current_ability) + gain, 1, 100)
		_improve_attributes(player, focus, gain)
	return gain

func _apply_development(player: Dictionary, seed: int) -> void:
	var age: int = int(player.age)
	var key: int = _stable_key(String(player.id)) + int(player.career_seasons) * 997
	var delta := 0
	if age <= 21:
		delta = _rand_int(seed, key, 1, 4)
	elif age <= 24:
		delta = _rand_int(seed, key, 0, 3)
	elif age <= 28:
		delta = _rand_int(seed, key, -1, 1)
	elif age <= 31:
		delta = _rand_int(seed, key, -2, 0)
	elif age <= 34:
		delta = _rand_int(seed, key, -3, -1)
	else:
		delta = _rand_int(seed, key, -5, -2)
	if delta > 0:
		delta = mini(delta, maxi(0, int(player.potential) - int(player.current_ability)))
	player.current_ability = clampi(int(player.current_ability) + delta, 1, 100)
	for attribute_name in player.attributes.keys():
		var attr_delta: int = clampi(delta, -3, 2)
		player.attributes[attribute_name] = clampi(int(player.attributes[attribute_name]) + attr_delta, 1, 100)
	player.fitness = clampi(int(player.fitness) + _rand_int(seed, key + 31, -5, 4), 55, 100)
	player.morale = clampi(int(player.morale) + _rand_int(seed, key + 47, -6, 6), 35, 100)

func _improve_attributes(player: Dictionary, focus: String, gain: int) -> void:
	if gain <= 0:
		return
	var focused: Array = []
	match focus:
		"attacking": focused = ["finishing", "technique", "pace"]
		"defending": focused = ["tackling", "positioning", "stamina"]
		"passing": focused = ["passing", "decisions", "technique"]
		"goalkeeping": focused = ["goalkeeping", "positioning", "decisions"]
		_: focused = ATTRIBUTES
	for name in focused:
		player.attributes[name] = clampi(int(player.attributes[name]) + gain, 1, 100)

func _roll_injury_days(player: Dictionary, seed: int) -> int:
	var age_risk: int = maxi(0, int(player.age) - 28)
	var key: int = _stable_key(String(player.id)) + int(player.career_seasons) * 1543
	var chance_per_thousand: int = 75 + age_risk * 7
	if _rand_int(seed, key + 71, 0, 999) >= chance_per_thousand:
		return 0
	return _rand_int(seed, key + 73, 7, 70)

func _should_retire(player: Dictionary, seed: int) -> bool:
	var age: int = int(player.age)
	if age >= 39:
		return true
	if age < 33:
		return false
	var threshold: int = (age - 32) * 120
	return _rand_int(seed, _stable_key(String(player.id)) + int(player.career_seasons) * 211, 0, 999) < threshold

func _generate_youth_intake(world: Dictionary, seed: int, per_club: int) -> Array:
	var created: Array = []
	var season_year: int = int(world.get("season_year", 2026))
	for club in world.clubs:
		for i in range(per_club):
			var player_id := "youth-%s-%d-%d" % [String(club.id), season_year, i]
			if _has_player(world.players, player_id):
				continue
			var key: int = _stable_key(player_id)
			var ca: int = _rand_int(seed, key + 1, 28, 52)
			var potential: int = clampi(ca + _rand_int(seed, key + 2, 15, 42), ca, 95)
			var player := {
				"id": player_id, "club_id": String(club.id), "first_name": "Youth", "last_name": str(i + 1),
				"age": 16, "position": POSITIONS[_rand_int(seed, key + 3, 0, POSITIONS.size() - 1)],
				"current_ability": ca, "potential": potential, "fitness": 100, "morale": 70, "retired": false
			}
			ensure_player_state(player, seed)
			world.players.append(player)
			world.contracts.append({"id": "contract-" + player_id, "player_id": player_id, "club_id": String(club.id), "start_year": season_year, "end_year": season_year + 3, "weekly_wage": _rand_int(seed, key + 4, 250, 1200)})
			created.append(player_id)
	return created

func _convert_to_staff(player: Dictionary, world: Dictionary, seed: int) -> Dictionary:
	var key: int = _stable_key(String(player.id))
	return {"id": "staff-from-" + String(player.id), "club_id": String(player.club_id), "name": String(player.first_name) + " " + String(player.last_name), "role": "coach", "ability": clampi(int(player.current_ability) + _rand_int(seed, key, -8, 8), 25, 90)}

func _has_player(players: Array, player_id: String) -> bool:
	for player in players:
		if String(player.id) == player_id:
			return true
	return false

func _stable_key(text: String) -> int:
	var value := 17
	for character in text.to_utf8_buffer():
		value = posmod(value * 131 + int(character), 2_147_483_647)
	return value

func _rand_int(seed: int, key: int, min_value: int, max_value: int) -> int:
	return min_value + (SeededRngClass.value_for(seed, key) % (max_value - min_value + 1))
