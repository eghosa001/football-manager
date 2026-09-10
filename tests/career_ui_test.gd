extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = load("res://game/scenes/career_app.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._show_new_career()
	await process_frame
	assert(scene._wizard_clubs.size() > 0)
	scene.session.new_career("UI Test", "", 12345, 1)
	scene._show_career()
	await process_frame
	assert(is_instance_valid(scene.status))
	scene._advance_day()
	await process_frame
	assert(int(scene.session.world.day_index) == 1)
	scene._show_save_as()
	await process_frame
	scene._save_to_slot(1)
	await process_frame
	assert(scene.status.text == "Saved to slot 1")
	scene._load_slot(1)
	await process_frame
	assert(scene.session.manager.name == "UI Test")
	scene.queue_free()
	await process_frame
	print("[TEST] CAREER UI PASS")
	quit(0)
