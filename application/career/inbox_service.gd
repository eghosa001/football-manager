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
