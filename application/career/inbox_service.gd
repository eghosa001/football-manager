class_name InboxService
extends RefCounted

func ensure_world(world: Dictionary) -> void:
	world["inbox"] = world.get("inbox", [])
	world["inbox_next_id"] = int(world.get("inbox_next_id", 1))

func add_message(world: Dictionary, category: String, title: String, body: String, requires_action: bool = false, actions: Array = []) -> Dictionary:
	ensure_world(world)
	var id := int(world.inbox_next_id)
	world.inbox_next_id = id + 1
	var message := {"id":id,"category":category,"title":title,"body":body,"requires_action":requires_action,"actions":actions.duplicate(true),"resolved":false,"read":false}
	world.inbox.append(message)
	return message

func unread(world: Dictionary) -> Array:
	ensure_world(world)
	var result: Array = []
	for message in world.inbox:
		if not bool(message.get("read", false)):
			result.append(message)
	return result

func generate_daily(world: Dictionary, match_results: Array) -> Array:
	ensure_world(world)
	var generated: Array = []
	var human: Dictionary = world.get("human_manager", {})
	var club_id := String(human.get("club_id", ""))
	for item in match_results:
		var fixture: Dictionary = item.get("fixture", {})
		if club_id == "" or (String(fixture.get("home_club_id", "")) != club_id and String(fixture.get("away_club_id", "")) != club_id):
			continue
		var result: Dictionary = item.get("result", {})
		generated.append(add_message(world, "match", "Match completed", "%d-%d" % [int(result.get("home_goals", 0)), int(result.get("away_goals", 0))]))
	var injuries := 0
	for player in world.get("players", []):
		if String(player.get("club_id", "")) == club_id and int(player.get("injured_days", 0)) > 0:
			injuries += 1
	if injuries > 0:
		generated.append(add_message(world, "medical", "Medical update", "%d squad players are currently unavailable." % injuries))
	return generated

func mark_read(world: Dictionary, message_id: int) -> Error:
	var message := _find(world, message_id)
	if message.is_empty(): return ERR_DOES_NOT_EXIST
	message.read = true
	return OK

func resolve(world: Dictionary, message_id: int, action_id: String) -> Error:
	var message := _find(world, message_id)
	if message.is_empty(): return ERR_DOES_NOT_EXIST
	if not bool(message.get("requires_action", false)):
		message.resolved = true
		return OK
	var valid := false
	for action in message.get("actions", []):
		if String(action.get("id", "")) == action_id:
			valid = true
			break
	if not valid: return ERR_INVALID_PARAMETER
	message.resolved = true
	message.selected_action = action_id
	message.read = true
	return OK

func _find(world: Dictionary, message_id: int) -> Dictionary:
	ensure_world(world)
	for message in world.inbox:
		if int(message.id) == message_id: return message
	return {}
