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
	await scene._advance_day()
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
	var views = preload("res://game/career/career_views.gd").new(scene, scene.session)
	views._show_competition(String(scene.session.world.competitions[0].id))
	await process_frame
	scene._show_career()
	await process_frame
	scene._delete_slot(1)
	await process_frame
	assert(FileAccess.file_exists(scene.slots.slot_path(1)))
	var confirmation: ConfirmationDialog
	for child in scene.get_children():
		if child is ConfirmationDialog: confirmation = child
	assert(confirmation != null)
	confirmation.canceled.emit()
	await process_frame
	assert(FileAccess.file_exists(scene.slots.slot_path(1)))
	scene.settings.language = "fr"
	scene.settings.high_contrast = true
	scene.settings.font_scale = 2.0
	scene.settings.ui_scale = 2.0
	scene._apply_runtime_settings()
	assert(TranslationServer.translate("New Career") == "Nouvelle carrière")
	assert(scene.scale == Vector2.ONE)
	assert(scene.theme.get_stylebox("normal", "Button").bg_color == Color.BLACK)
	scene._show_main_menu()
	await process_frame
	scene.settings.language = "en"
	scene._apply_runtime_settings()
	scene.queue_free()
	await process_frame
	print("[TEST] CAREER UI PASS")
	quit(0)
