extends "res://game/polish/polish_runtime.gd"

# Registry-based career scenes extend the base career app script, so identify
# the live career node by its capabilities instead of an exact script path.
func _career_session(node: Node):
	var current: Node = node
	while current != null:
		if current.has_method("_show_career") and current.has_method("_advance_day"):
			return current.get("session")
		current = current.get_parent()
	return null
