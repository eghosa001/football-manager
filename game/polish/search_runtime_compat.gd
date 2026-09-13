extends "res://game/polish/search_runtime.gd"

func _career_session(node: Node):
	var current: Node = node
	while current != null:
		if current.has_method("_show_career") and current.has_method("_advance_day"):
			return current.get("session")
		current = current.get_parent()
	return null

func _refresh_app(node: Node) -> void:
	var current: Node = node
	while current != null:
		if current.has_method("_show_career") and current.has_method("_advance_day"):
			current.call("_show_career")
			return
		current = current.get_parent()
