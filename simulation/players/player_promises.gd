class_name PlayerPromises
extends RefCounted

const DressingRoomClass = preload("res://simulation/players/dressing_room.gd")

func ensure_world(world: Dictionary) -> void:
	world["player_promises"] = world.get("player_promises", [])

func make_promise(world: Dictionary, player_id: String, promise_type: String, target_value: int, deadline_day: int) -> Dictionary:
	ensure_world(world)
	var promise := {
		"id":"promise-%s-%d" % [player_id, world.player_promises.size() + 1],
		"player_id":player_id,
		"type":promise_type,
		"target_value":target_value,
		"deadline_day":deadline_day,
		"status":"active"
	}
	world.player_promises.append(promise)
	return promise

func evaluate(world: Dictionary) -> Array:
	ensure_world(world)
	var outcomes: Array = []
	var day_index := int(world.get("day_index", 0))
	for promise in world.player_promises:
		if String(promise.get("status", "")) != "active" or day_index < int(promise.get("deadline_day", 0)):
			continue
		var player := _player(world, String(promise.player_id))
		if player.is_empty():
			promise.status = "invalid"
			continue
		var fulfilled := _fulfilled(player, promise)
		promise.status = "fulfilled" if fulfilled else "broken"
		var delta := 8 if fulfilled else -14
		player.morale = clampi(int(player.get("morale", 50)) + delta, 0, 100)
		player.happiness = clampi(int(player.get("happiness", player.get("morale", 50))) + delta, 0, 100)
		var club_id := String(player.get("club_id", ""))
		if club_id != "":
			DressingRoomClass.new().apply_event(world, club_id, "team_meeting_positive" if fulfilled else "broken_promise", String(player.id))
		outcomes.append({"promise_id":String(promise.id),"player_id":String(player.id),"fulfilled":fulfilled})
	return outcomes

func hold_team_meeting(world: Dictionary, club_id: String, tone: String) -> Dictionary:
	var morale_delta := 0
	match tone:
		"praise": morale_delta = 4
		"encourage": morale_delta = 2
		"criticize": morale_delta = -3
		_: morale_delta = 0
	for player in world.get("players", []):
		if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)):
			player.morale = clampi(int(player.get("morale", 50)) + morale_delta, 0, 100)
	return DressingRoomClass.new().apply_event(world, club_id, "team_meeting_positive" if morale_delta >= 0 else "heavy_loss")

func _fulfilled(player: Dictionary, promise: Dictionary) -> bool:
	match String(promise.get("type", "")):
		"playing_time": return int(player.get("season_appearances", 0)) >= int(promise.get("target_value", 0))
		"morale": return int(player.get("morale", 0)) >= int(promise.get("target_value", 0))
		"training": return int(player.get("current_ability", 0)) >= int(promise.get("target_value", 0))
		_: return false

func _player(world: Dictionary, player_id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == player_id:
			return player
	return {}
