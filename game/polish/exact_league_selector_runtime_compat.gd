extends "res://game/polish/exact_league_selector_runtime.gd"

func _career_app(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current.has_method("_show_career") and current.has_method("_advance_day"):
			return current
		current = current.get_parent()
	return null
