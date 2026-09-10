class_name StaffMarket
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func ensure_world(world: Dictionary) -> void:
	world["staff_vacancies"] = world.get("staff_vacancies", [])
	world["staff_history"] = world.get("staff_history", [])

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
