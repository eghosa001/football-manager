extends SceneTree

const InboxServiceClass = preload("res://application/career/inbox_service.gd")

var _output_dir := ""
var _manifest: Array[String] = []
var _capture_index := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_output_dir = OS.get_environment("VISUAL_QA_DIR")
	if _output_dir.strip_edges() == "":
		_output_dir = ProjectSettings.globalize_path("res://visual-qa")
	DirAccess.make_dir_recursive_absolute(_output_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))

	var packed := load("res://game/scenes/career_app.tscn") as PackedScene
	if packed == null:
		_fail("Could not load career_app.tscn")
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await _settle(10, 0.25)

	await _capture("main-menu")

	scene.call("_show_settings")
	await _settle(8, 0.15)
	await _capture("settings")

	scene.call("_show_help")
	await _settle(8, 0.15)
	await _capture("how-to-play")

	scene.call("_show_load_menu")
	await _settle(8, 0.15)
	await _capture("load-career")

	scene.call("_show_new_career")
	await _settle(20, 1.0)
	await _capture("new-career")

	var snap: Dictionary = scene.session.new_career("Visual QA Manager", "", 12345, 1)
	if snap.is_empty() or snap.has("error"):
		_fail("Could not create deterministic visual QA career")
		return
	InboxServiceClass.new().add_message(
		scene.session.world,
		"board",
		"Welcome to the visual QA career",
		"Review every department screen. This deterministic career exists only for screenshot validation."
	)
	scene.call("_show_career")
	await _settle(24, 1.0)

	var tabs := _find_career_tabs(scene)
	if tabs == null:
		_fail("Could not find the runtime career TabContainer")
		return
	if tabs.get_tab_count() == 0:
		_fail("Career TabContainer contains no screens")
		return

	for i in range(tabs.get_tab_count()):
		tabs.current_tab = i
		await _settle(10, 0.18)
		var page := tabs.get_tab_control(i)
		_reset_scroll(page)
		await _settle(4, 0.08)
		var title := tabs.get_tab_title(i)
		if title.strip_edges() == "":
			title = String(page.name)
		await _capture("career-%02d-%s" % [i + 1, _slug(title)])

	_write_manifest()
	print("[VISUAL QA] captured %d screens in %s" % [_manifest.size(), _output_dir])
	scene.queue_free()
	await process_frame
	quit(0)

func _capture(label: String) -> void:
	# Keep the pointer away from interactive controls so hover states/tooltips do
	# not contaminate deterministic visual QA screenshots.
	Input.warp_mouse(Vector2(4, 4))
	await _settle(3, 0.05)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Viewport capture failed for %s" % label)
		return
	_capture_index += 1
	var filename := "%02d-%s.png" % [_capture_index, _slug(label)]
	var path := _output_dir.path_join(filename)
	var error := image.save_png(path)
	if error != OK:
		_fail("Could not save %s (%d)" % [path, error])
		return
	_manifest.append("%s\t%s" % [filename, label])
	print("[VISUAL QA] %s" % filename)

func _settle(frames: int, seconds: float = 0.0) -> void:
	for _i in range(frames):
		await process_frame
	if seconds > 0.0:
		await create_timer(seconds).timeout

func _find_career_tabs(node: Node) -> TabContainer:
	if node is TabContainer:
		var tabs := node as TabContainer
		if _tab_index(tabs, "Dashboard") >= 0 and _tab_index(tabs, "Squad") >= 0 and _tab_index(tabs, "Tactics") >= 0:
			return tabs
	for child in node.get_children():
		var found := _find_career_tabs(child)
		if found != null:
			return found
	return null

func _tab_index(tabs: TabContainer, wanted: String) -> int:
	for i in range(tabs.get_tab_count()):
		var page := tabs.get_tab_control(i)
		if String(page.name) == wanted or tabs.get_tab_title(i) == wanted:
			return i
	return -1

func _reset_scroll(node: Node) -> void:
	if node is ScrollContainer:
		(node as ScrollContainer).scroll_vertical = 0
		(node as ScrollContainer).scroll_horizontal = 0
	for child in node.get_children():
		_reset_scroll(child)

func _slug(value: String) -> String:
	var s := value.strip_edges().to_lower()
	var out := ""
	for i in range(s.length()):
		var ch := s.substr(i, 1)
		var code := ch.unicode_at(0)
		if (code >= 97 and code <= 122) or (code >= 48 and code <= 57):
			out += ch
		elif out != "" and not out.ends_with("-"):
			out += "-"
	return out.trim_suffix("-") if out != "" else "screen"

func _write_manifest() -> void:
	var path := _output_dir.path_join("manifest.txt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not create screenshot manifest")
		return
	file.store_line("Football Dynasty visual QA screenshots")
	file.store_line("Viewport: 1280x720")
	file.store_line("Commit: %s" % OS.get_environment("GITHUB_SHA"))
	file.store_line("")
	for line in _manifest:
		file.store_line(line)
	file.close()

func _fail(message: String) -> void:
	push_error("[VISUAL QA] %s" % message)
	print("[VISUAL QA] FAILED: %s" % message)
	quit(1)
