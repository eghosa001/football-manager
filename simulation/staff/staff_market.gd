class_name StaffMarket
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func ensure_world(world: Dictionary) -> void:
	world["staff_vacancies"] = world.get("staff_vacancies", [])
	world["staff_history"] = world.get("staff_history", [])
	world["staff_applicants"] = world.get("staff_applicants", [])

func run_staff_market(world: Dictionary, year: int, seed: int) -> Dictionary:
	ensure_world(world)
	var filled := 0
	var created := 0
	_open_vacancies(world, year)
	for vacancy in world.staff_vacancies:
		if String(vacancy.get("status", "open")) != "open":
			continue
		var role := String(vacancy.get("role", "coach"))
		var club_id := String(vacancy.get("club_id", ""))
		var options := staff_candidates(world, club_id, role, 6)
		if options.is_empty():
			if SeededRngClass.unit_for(seed, _stable_key(club_id + role + str(year))) < 0.35:
				_generate_applicant(world, club_id, role, year, seed)
				created += 1
			continue
		var best: Dictionary = options[0]
		if hire_staff(world, club_id, String(best.get("staff_id", "")), year) == OK:
			filled += 1
	return {"filled": filled, "applicants_created": created, "open": open_vacancy_count(world)}

func staff_candidates(world: Dictionary, club_id: String, role: String, limit: int = 10) -> Array:
	var club := _club(world.get("clubs", []), club_id)
	var list: Array = []
	for member in world.get("staff", []):
		if String(member.get("role", "")) != role:
			continue
		var current_club := String(member.get("club_id", ""))
		if current_club == club_id:
			continue
		var reputation := float(member.get("reputation", member.get("ability", 50)))
		var fit := 100.0 - absf(reputation - float(club.get("reputation", 50)))
		fit += float(member.get("staff_attributes", {}).get("adaptability", 50)) * 0.12
		fit += float(member.get("licenses", [] ).size()) * 2.0
		if current_club == "":
			fit += 8.0
		list.append({"staff_id": String(member.id), "score": fit, "employed": current_club != ""})
	list.sort_custom(func(a: Dictionary, b: Dictionary):
		if is_equal_approx(float(a.score), float(b.score)): return String(a.staff_id) < String(b.staff_id)
		return float(a.score) > float(b.score)
	)
	if list.size() > limit:
		list.resize(limit)
	return list

func hire_staff(world: Dictionary, club_id: String, staff_id: String, year: int) -> Error:
	ensure_world(world)
	var target := _staff(world.get("staff", []), staff_id)
	if target.is_empty():
		return ERR_INVALID_PARAMETER
	var role := String(target.get("role", ""))
	for member in world.get("staff", []):
		if String(member.get("club_id", "")) == club_id and String(member.get("role", "")) == role and role in ["manager", "assistant_manager"]:
			return ERR_ALREADY_EXISTS
	var previous := String(target.get("club_id", ""))
	target.club_id = club_id
	world.staff_history.append({"staff_id": staff_id, "club_id": club_id, "previous_club_id": previous, "event": "hired", "role": role, "year": year})
	for vacancy in world.staff_vacancies:
		if String(vacancy.club_id) == club_id and String(vacancy.role) == role and String(vacancy.status) == "open":
			vacancy.status = "filled"
	return OK

func open_vacancy_count(world: Dictionary) -> int:
	var count := 0
	for vacancy in world.get("staff_vacancies", []):
		if String(vacancy.get("status", "open")) == "open":
			count += 1
	return count

func _open_vacancies(world: Dictionary, year: int) -> void:
	var roles := ["assistant_manager", "coach", "scout", "physio", "director"]
	for club in world.get("clubs", []):
		for role in roles:
			var has := false
			for member in world.get("staff", []):
				if String(member.get("club_id", "")) == String(club.get("id", "")) and String(member.get("role", "")) == role:
					has = true
					break
			if has:
				continue
			var exists := false
			for vacancy in world.staff_vacancies:
				if String(vacancy.get("club_id", "")) == String(club.get("id", "")) and String(vacancy.get("role", "")) == role and String(vacancy.get("status", "")) == "open":
					exists = true
					break
			if not exists:
				world.staff_vacancies.append({"id": "vacancy-%s-%s-%d" % [String(club.get("id", "")), role, year], "club_id": String(club.get("id", "")), "role": role, "year": year, "status": "open"})

func _generate_applicant(world: Dictionary, club_id: String, role: String, year: int, seed: int) -> void:
	var key := _stable_key(club_id + role + str(year) + str(world.staff.size()))
	var ability := 35 + int(SeededRngClass.value_for(seed, key) % 41)
	var member := {"id": "staff-applicant-%d-%d" % [year, world.staff.size() + 1], "club_id": "", "role": role, "ability": ability, "age": 28 + int(SeededRngClass.value_for(seed, key + 1) % 25), "reputation": ability, "first_name": "Free", "last_name": "Agent %d" % (world.staff.size() + 1), "licenses": ["national_c"] if ability >= 55 else [], "career_origin": "applicant"}
	ensure_staff_attributes(member, seed + key)
	world.staff.append(member)
	world.staff_applicants.append(String(member.id))

func evaluate_manager_security(world: Dictionary, club_id: String, recent_points_per_game: float, board_patience: int = 50) -> Dictionary:
	ensure_world(world)
	var manager := _manager(world.get("staff", []), club_id)
	if manager.is_empty():
		return {"status":"vacant","risk":1.0}
	var risk := clampf(0.65 - recent_points_per_game * 0.25 + (50 - board_patience) / 150.0, 0.0, 1.0)
	return {"status":"secure" if risk < 0.35 else ("pressure" if risk < 0.7 else "critical"),"risk":risk,"manager_id":String(manager.id)}

func sack_manager(world: Dictionary, club_id: String, reason: String, year: int) -> Error:
	ensure_world(world)
	var manager := _manager(world.get("staff", []), club_id)
	if manager.is_empty(): return ERR_DOES_NOT_EXIST
	world.staff_history.append({"staff_id":String(manager.id),"club_id":club_id,"event":"sacked","reason":reason,"year":year})
	manager.club_id = ""
	world.staff_vacancies.append({"id":"vacancy-%s-%d" % [club_id, year],"club_id":club_id,"role":"manager","year":year,"status":"open"})
	return OK

func candidates(world: Dictionary, club_id: String, limit: int = 10) -> Array:
	var club := _club(world.get("clubs", []), club_id)
	var list: Array = []
	for member in world.get("staff", []):
		if String(member.get("role", "")) != "manager": continue
		var current_club := String(member.get("club_id", ""))
		if current_club == club_id: continue
		var profile: Dictionary = member.get("manager_profile", {})
		var reputation := float(member.get("reputation", member.get("ability", 50)))
		var fit := 100.0 - absf(reputation - float(club.get("reputation", 50)))
		fit += float(profile.get("adaptability", 50)) * 0.15
		if current_club == "": fit += 8.0
		list.append({"staff_id":String(member.id),"score":fit,"employed":current_club != ""})
	list.sort_custom(func(a: Dictionary, b: Dictionary):
		if is_equal_approx(float(a.score), float(b.score)): return String(a.staff_id) < String(b.staff_id)
		return float(a.score) > float(b.score)
	)
	if list.size() > limit: list.resize(limit)
	return list

func hire_manager(world: Dictionary, club_id: String, staff_id: String, year: int) -> Error:
	ensure_world(world)
	if not _manager(world.get("staff", []), club_id).is_empty(): return ERR_ALREADY_EXISTS
	var target := _staff(world.get("staff", []), staff_id)
	if target.is_empty() or String(target.get("role", "")) != "manager": return ERR_INVALID_PARAMETER
	var previous := String(target.get("club_id", ""))
	target.club_id = club_id
	world.staff_history.append({"staff_id":staff_id,"club_id":club_id,"previous_club_id":previous,"event":"hired","year":year})
	for vacancy in world.staff_vacancies:
		if String(vacancy.club_id) == club_id and String(vacancy.role) == "manager" and String(vacancy.status) == "open": vacancy.status = "filled"
	return OK

func ensure_staff_attributes(member: Dictionary, seed: int) -> void:
	if member.has("staff_attributes"): return
	var key := _stable_key(String(member.get("id", "")))
	member["staff_attributes"] = {
		"coaching":_range(seed,key+1,25,95),"tactical_knowledge":_range(seed,key+2,25,95),"motivation":_range(seed,key+3,25,95),
		"man_management":_range(seed,key+4,25,95),"judging_ability":_range(seed,key+5,25,95),"judging_potential":_range(seed,key+6,25,95),
		"working_with_youngsters":_range(seed,key+7,25,95),"adaptability":_range(seed,key+8,25,95),"discipline":_range(seed,key+9,25,95)
	}

func _manager(staff: Array, club_id: String) -> Dictionary:
	for member in staff:
		if String(member.get("role", "")) == "manager" and String(member.get("club_id", "")) == club_id: return member
	return {}

func _staff(staff: Array, id: String) -> Dictionary:
	for member in staff:
		if String(member.get("id", "")) == id: return member
	return {}

func _club(clubs: Array, id: String) -> Dictionary:
	for club in clubs:
		if String(club.get("id", "")) == id: return club
	return {}

func _range(seed: int, key: int, lo: int, hi: int) -> int:
	return lo + int(SeededRngClass.value_for(seed, key) % (hi - lo + 1))

func _stable_key(text: String) -> int:
	var value := 59
	for character in text.to_utf8_buffer(): value = posmod(value * 163 + int(character), 2_147_483_647)
	return value
