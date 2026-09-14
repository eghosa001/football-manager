extends "res://game/polish/background_save_runtime.gd"

func _find_app(node: Node) -> Node:
	if node.has_method("_show_career") and node.has_method("_advance_day"):
		return node
	for child in node.get_children():
		var found := _find_app(child)
		if found != null:
			return found
	return null
