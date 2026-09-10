class_name DressingRoom
extends RefCounted

func ensure_world(world: Dictionary) -> void:
	world["dressing_rooms"] = world.get("dressing_rooms", {})

func rebuild(world: Dictionary, club_id: String) -> Dictionary:
	ensure_world(world)
	var squad: Array = []
	for player in world.get("players", []):
		if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)):
			squad.append(player)
	var ranked := squad.duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary):
		var a_score := influence_score(a)
		var b_score := influence_score(b)
		if is_equal_approx(a_score, b_score): return String(a.id) < String(b.id)
		return a_score > b_score
	)
	var room := {"leaders":[],"highly_influential":[],"influential":[],"others":[],"social_groups":[],"atmosphere":70.0}
	for i in range(ranked.size()):
		var id := String(ranked[i].id)
		if i < 2: room.leaders.append(id)
		elif i < 6: room.highly_influential.append(id)
		elif i < 12: room.influential.append(id)
		else: room.others.append(id)
	room.social_groups = _social_groups(ranked)
	room.atmosphere = _atmosphere(ranked)
	world.dressing_rooms[club_id] = room
	return room

func influence_score(player: Dictionary) -> float:
	var attrs: Dictionary = player.get("attributes", {})
	var hidden: Dictionary = player.get("hidden_attributes", {})
	return float(attrs.get("leadership", 50)) * 0.35 + float(player.get("age", 24)) * 1.0 + float(player.get("current_ability", 50)) * 0.25 + float(hidden.get("professionalism", 50)) * 0.15

func apply_event(world: Dictionary, club_id: String, event: String, subject_id: String = "") -> Dictionary:
	var room: Dictionary = world.get("dressing_rooms", {}).get(club_id, rebuild(world, club_id))
	var delta := 0.0
	match event:
		"captain_sold": delta = -8.0
		"big_win": delta = 4.0
		"heavy_loss": delta = -5.0
		"team_meeting_positive": delta = 3.0
		"broken_promise": delta = -7.0
		"new_contract": delta = 1.5
	room.atmosphere = clampf(float(room.get("atmosphere", 70.0)) + delta, 0.0, 100.0)
	if subject_id != "": room["last_subject_id"] = subject_id
	room["last_event"] = event
	world.dressing_rooms[club_id] = room
	return room

func _social_groups(squad: Array) -> Array:
	var groups := {"senior":[],"prime":[],"young":[]}
	for player in squad:
		var age := int(player.get("age", 24))
		if age >= 29: groups.senior.append(String(player.id))
		elif age <= 21: groups.young.append(String(player.id))
		else: groups.prime.append(String(player.id))
	var result: Array = []
	for name in ["senior","prime","young"]:
		if not groups[name].is_empty(): result.append({"name":name,"members":groups[name]})
	return result

func _atmosphere(squad: Array) -> float:
	if squad.is_empty(): return 50.0
	var total := 0.0
	for player in squad:
		total += float(player.get("morale", 70))
	return clampf(total / float(squad.size()), 0.0, 100.0)
