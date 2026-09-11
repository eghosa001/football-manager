extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var session = preload("res://application/career/career_session.gd").new()
	session.new_career("Custom", "", 44, 1)
	var id := String(session.world.clubs[0].id)
	var country_id := String(session.world.countries[0].id)
	var player_id := String(session.world.players[0].id)
	var good := {"metadata":{"id":"custom","version":"1.0"},"patches":{"clubs":[{"id":id,"name":"My Club","reputation":70}],"countries":[{"id":country_id,"name":"My Country","youth_rating":77}],"players":[{"id":player_id,"first_name":"Edited","current_ability":66}]}}
	var bad := {"metadata":{"id":"bad"},"patches":{"clubs":[{"id":id,"reputation":{}}]}}
	var loader = preload("res://tools/modding/mod_loader.gd").new()
	var before: Dictionary = session.world.duplicate(true)
	assert(not loader.apply_mods(session.world, [good, bad]).ok)
	assert(session.world == before)
	assert(session.new_career("Custom", id, 44, 1, [bad]).has("error"))
	assert(session.world == before)
	assert(not session.new_career("Custom", id, 44, 1, [good]).has("error"))
	assert(session.world.clubs[0].name == "My Club")
	assert(session.world.countries[0].name == "My Country")
	assert(session.world.players[0].first_name == "Edited")
	assert(session.save_career("user://custom-test.save") == OK)
	var loaded = preload("res://application/career/career_session.gd").new()
	assert(loaded.load_career("user://custom-test.save") == OK)
	assert(loaded.world.clubs[0].name == "My Club")
	var training = preload("res://simulation/players/training_system.gd").new()
	var rested: Dictionary = session.world.duplicate(true)
	var worked: Dictionary = session.world.duplicate(true)
	assert(training.set_schedule(rested.clubs[0], ["rest","rest","rest","rest","rest","rest","rest"], 0.8) == OK)
	assert(training.set_schedule(worked.clubs[0], ["physical","physical","physical","physical","physical","physical","physical"], 0.8) == OK)
	var rest_result: Dictionary = training.run_week(rested, id, 51)
	var work_result: Dictionary = training.run_week(worked, id, 51)
	assert(int(rest_result.fatigue_added) == 0 and int(rest_result.training_injuries) == 0)
	assert(int(work_result.fatigue_added) > 0)
	before = rested.clubs[0].duplicate(true)
	assert(training.set_schedule(rested.clubs[0], ["invalid","rest","rest","rest","rest","rest","rest"], 0.8) != OK)
	assert(rested.clubs[0] == before)
	var app = load("res://game/scenes/career_app.tscn").instantiate()
	root.add_child(app); await process_frame
	var editor = preload("res://game/career/database_editor.gd").new(app)
	editor.show(); await process_frame
	assert(editor.editors.has("name"))
	(editor.editors.name as LineEdit).text = "Editor Club"
	editor._save_change()
	assert(editor.mod.patches.clubs[0].name == "Editor Club")
	editor.collection_selector.select(1)
	editor._rebuild_entities(); await process_frame
	assert(editor.editors.has("youth_rating"))
	(editor.editors.youth_rating as SpinBox).value = 88
	editor._save_change()
	assert(editor.mod.patches.countries[0].youth_rating == 88)
	editor.collection_selector.select(2)
	editor._rebuild_entities(); await process_frame
	assert(editor.editors.has("current_ability"))
	(editor.editors.current_ability as SpinBox).value = 72
	editor._save_change()
	assert(editor.mod.patches.players[0].current_ability == 72)
	assert(editor._editable(good))
	app.queue_free(); await process_frame
	print("[TEST] CUSTOM DATABASE AND TRAINING PASS")
	quit(0)
