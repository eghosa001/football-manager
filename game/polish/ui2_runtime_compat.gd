extends "res://game/polish/ui2_runtime.gd"

# The production scene uses registry_career_app.gd, which subclasses career_app.gd.
# Resolve the live app by capabilities rather than by an exact script filename.
func _career_app(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current.has_method("_show_career") and current.has_method("_advance_day"):
			return current
		current = current.get_parent()
	return null
