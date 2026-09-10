class_name SocialService
extends RefCounted

const DressingRoomClass = preload("res://simulation/players/dressing_room.gd")
const InboxServiceClass = preload("res://application/career/inbox_service.gd")

func ensure_world(world: Dictionary) -> void:
	world["player_promises"] = world.get("player_promises", [])
	world["team_meetings"] = world.get("team_meetings", [])

func make_promise(world: Dictionary, club_id: String, player_id: String, promise_type: String, due_day: int) -> Dictionary:
	ensure_world(world)
	var promise := {"id":"promise-%s-%d" % [player_id, world.player_promises.size()+1],"club_id":club_id,"player_id":player_id,"type":promise_type,"created_day":int(world.get("day_index",0)),"due_day":due_day,"status":"active"}
	world.player_promises.append(promise)
	return promise

func resolve_promise(world: Dictionary, promise_id: String, fulfilled: bool) -> Error:
	ensure_world(world)
	for promise in world.player_promises:
		if String(promise.get("id","")) != promise_id: continue
		if String(promise.get("status","")) != "active": return ERR_ALREADY_EXISTS
		promise.status = "fulfilled" if fulfilled else "broken"
		var player := _player(world, String(promise.player_id))
		if not player.is_empty():
			player.morale = clampi(int(player.get("morale",70)) + (6 if fulfilled else -12), 0, 100)
			player["happiness"] = clampi(int(player.get("happiness",player.morale)) + (8 if fulfilled else -16), 0, 100)
		DressingRoomClass.new().apply_event(world, String(promise.club_id), "new_contract" if fulfilled else "broken_promise", String(promise.player_id))
		return OK
	return ERR_DOES_NOT_EXIST

func team_meeting(world: Dictionary, club_id: String, tone: String) -> Dictionary:
	ensure_world(world)
	var delta := 0
	match tone:
		"encourage": delta = 3
		"praise": delta = 4
		"demand_more": delta = -1
		"criticize": delta = -4
		_: delta = 0
	var affected := 0
	for player in world.get("players", []):
		if String(player.get("club_id","")) != club_id or bool(player.get("retired",false)): continue
		var professionalism := int(player.get("hidden_attributes",{}).get("professionalism",50))
		var individual_delta := delta
		if tone == "demand_more" and professionalism >= 65: individual_delta = 2
		if tone == "criticize" and professionalism >= 75: individual_delta = -1
		player.morale = clampi(int(player.get("morale",70)) + individual_delta, 0, 100)
		affected += 1
	var meeting := {"id":"meeting-%s-%d" % [club_id, world.team_meetings.size()+1],"club_id":club_id,"day":int(world.get("day_index",0)),"tone":tone,"affected":affected}
	world.team_meetings.append(meeting)
	DressingRoomClass.new().apply_event(world, club_id, "team_meeting_positive" if delta >= 0 else "heavy_loss")
	InboxServiceClass.new().add_message(world, "dressing_room", "Team meeting held", "The %s team meeting affected %d players." % [tone.replace("_"," "), affected])
	return meeting

func check_due_promises(world: Dictionary) -> Array:
	ensure_world(world)
	var broken: Array = []
	var current_day := int(world.get("day_index",0))
	for promise in world.player_promises:
		if String(promise.get("status","")) == "active" and int(promise.get("due_day",999999)) < current_day:
			resolve_promise(world, String(promise.id), false)
			broken.append(String(promise.id))
	return broken

func _player(world: Dictionary, id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id","")) == id: return player
	return {}
