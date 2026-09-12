class_name DressingRoom
extends RefCounted

var _player_index: Dictionary = {}

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
	ensure_world(world)
	# Do not pass rebuild() as Dictionary.get's fallback value: function
	# arguments are evaluated before the get call, which used to rebuild the
	# room even when it already existed. Matchdays can emit many dressing-room
	# events, so that eager fallback repeatedly scanned the full player world.
	var room: Dictionary = world.dressing_rooms.get(club_id, {})
	if room.is_empty():
		room = rebuild(world, club_id)
	var delta := 0.0
	match event:
		"captain_sold": delta = -8.0
		"captain_changed": delta = -2.0
		"big_win": delta = 4.0
		"heavy_loss": delta = -5.0
		"team_meeting_positive": delta = 3.0
		"broken_promise": delta = -7.0
		"new_contract": delta = 1.5
		"transfer_request": delta = -4.0
		"marquee_signing": delta = 3.5
		"derby_win": delta = 5.0
		"derby_loss": delta = -6.0
	room.atmosphere = clampf(float(room.get("atmosphere", 70.0)) + delta, 0.0, 100.0)
	if subject_id != "":
		room["last_subject_id"] = subject_id
	_propagate_mood(world, club_id, room, delta)
	room["last_event"] = event
	world.dressing_rooms[club_id] = room
	return room

func _propagate_mood(world: Dictionary, club_id: String, room: Dictionary, delta: float) -> void:
	# Leaders amplify atmosphere shifts; young players follow. Matchday code can
	# apply multiple events through the same DressingRoom instance, so build one
	# lazy index and then touch only the members of this room instead of scanning
	# the entire world once per event.
	if is_zero_approx(delta):
		return
	if _player_index.is_empty():
		for player in world.get("players", []):
			var player_id := String(player.get("id", ""))
			if player_id != "":
				_player_index[player_id] = player
	var leaders: Array = room.get("leaders", []) + room.get("highly_influential", [])
	var member_ids: Array = []
	member_ids.append_array(room.get("leaders", []))
	member_ids.append_array(room.get("highly_influential", []))
	member_ids.append_array(room.get("influential", []))
	member_ids.append_array(room.get("others", []))
	var weight := clampf(absf(delta) / 8.0, 0.25, 1.0)
	for member_id in member_ids:
		var id := String(member_id)
		var player: Dictionary = _player_index.get(id, {})
		if player.is_empty() or String(player.get("club_id", "")) != club_id or bool(player.get("retired", false)):
			continue
		var factor := 1.0
		if id in leaders:
			factor = 0.6
		elif int(player.get("age", 24)) <= 21:
			factor = 1.35
		var shift := delta * weight * factor * 0.45
		player["morale"] = clampi(int(player.get("morale", 60)) + int(round(shift)), 0, 100)

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
