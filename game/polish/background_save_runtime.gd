extends Node

var _next_scan: int = 0
var _jobs: Array = []

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	_poll_jobs()
	var now: int = Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 500
	_scan()

func _scan() -> void:
	var app: Node = _find_app(get_tree().root)
	if app == null:
		return
	if _find_career_tabs(app) == null:
		return
	for node in app.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button == null or button.has_meta("background_save"):
			continue
		var text: String = button.text.strip_edges()
		if not text.begins_with("Save Slot "):
			continue
		button.set_meta("background_save", true)
		for connection in button.pressed.get_connections():
			var callback: Callable = connection.get("callable")
			if callback.is_valid() and button.pressed.is_connected(callback):
				button.pressed.disconnect(callback)
		button.pressed.connect(_start_save.bind(app, button))

func _start_save(app: Node, button: Button) -> void:
	if bool(app.get("_busy")):
		return
	var slot: int = int(app.get("active_slot"))
	if slot <= 0:
		app.call("_show_save_as")
		return
	var session = app.get("session")
	if session == null:
		return
	# Make a stable snapshot once, then move serialization, backups and package I/O to a worker.
	var world: Dictionary = session.get("world").duplicate(true)
	var history: Array = session.get("history").duplicate(true)
	var manager: Dictionary = session.get("manager").duplicate(true)
	var slots = app.get("slots")
	var worker := Thread.new()
	var job: Callable = Callable(slots, "save_slot").bind(slot, world, history, manager)
	var error: Error = worker.start(job)
	if error != OK:
		_set_status(app, "Save failed (%d)" % error)
		return
	button.disabled = true
	button.text = "Saving…"
	_set_status(app, "Saving in background…")
	_jobs.append({"thread": worker, "app": app, "button": button, "slot": slot})

func _poll_jobs() -> void:
	for index in range(_jobs.size() - 1, -1, -1):
		var row: Dictionary = _jobs[index]
		var worker: Thread = row.get("thread") as Thread
		if worker == null or worker.is_alive():
			continue
		var result: int = int(worker.wait_to_finish())
		var app: Node = row.get("app") as Node
		var button: Button = row.get("button") as Button
		var slot: int = int(row.get("slot", 0))
		if is_instance_valid(button):
			button.disabled = false
			button.text = "Save Slot %d" % slot
		if is_instance_valid(app):
			_set_status(app, "Saved to slot %d" % slot if result == OK else "Save failed (%d)" % result)
		_jobs.remove_at(index)

func _set_status(app: Node, text: String) -> void:
	var status = app.get("status")
	if status is Label:
		(status as Label).text = text

func _find_app(node: Node) -> Node:
	var script = node.get_script()
	if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
		return node
	for child in node.get_children():
		var found: Node = _find_app(child)
		if found != null:
			return found
	return null

func _find_career_tabs(app: Node) -> TabContainer:
	for node in app.find_children("*", "TabContainer", true, false):
		var tabs: TabContainer = node as TabContainer
		if tabs == null:
			continue
		for i in range(tabs.get_tab_count()):
			if tabs.get_tab_title(i).strip_edges().to_lower() == "dashboard":
				return tabs
	return null
