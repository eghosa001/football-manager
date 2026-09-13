extends SceneTree

const DatabaseEditor = preload("res://game/career/database_editor.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = load("res://game/scenes/career_app.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var editor = DatabaseEditor.new(scene)
	editor.show()
	await process_frame
	assert(_find_button(scene, "Apply field change") != null)
	assert(_find_button(scene, "Add new entity") != null)
	assert(_find_button(scene, "Validate mod") != null)
	assert(_find_button(scene, "Use for new careers") != null)
	assert(editor.collection_selector != null and editor.collection_selector.item_count >= 6)
	assert(editor.entity_selector != null and editor.entity_selector.item_count > 0)
	assert(editor.field_selector != null and editor.field_selector.item_count > 0)
	var validate := _find_button(scene, "Validate mod")
	validate.pressed.emit()
	await process_frame
	assert(editor.notice != null)
	assert(String(editor.notice.text).contains("validation passed") or String(editor.notice.text).contains("patched"))
	scene.queue_free()
	await process_frame
	print("[TEST] DATABASE EDITOR UI PASS")
	quit(0)

func _find_button(node: Node, text: String) -> Button:
	if node is Button and String((node as Button).text) == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null
