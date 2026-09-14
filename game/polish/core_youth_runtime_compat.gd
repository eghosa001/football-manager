extends "res://game/polish/core_youth_runtime.gd"

func _career_session(node: Node):
	var current := node
	while current != null:
		if current.has_method("_show_career") and current.has_method("_advance_day"):
			return current.get("session")
		current = current.get_parent()
	return null
