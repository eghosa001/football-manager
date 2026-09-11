extends Node

const TacticsBoard = preload("res://game/tactics/tactics_board.gd")
var _next_scan := 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan: return
	_next_scan = now + 1000
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer: _wire_tabs(node)
	for child in node.get_children(): _scan_node(child)

func _wire_tabs(tabs: TabContainer) -> void:
	if tabs.has_meta("tactics_board_added"): return
	var tactics_tab: Control = null
	for child in tabs.get_children():
		if String(child.name) == "Tactics": tactics_tab = child; break
	if tactics_tab == null: return
	var session = _career_session(tabs)
	if session == null or session.world.is_empty(): return
	var box := _first_vbox(tactics_tab)
	if box == null: return
	tabs.set_meta("tactics_board_added",true)
	var board = TacticsBoard.new()
	board.setup(session.world,session.managed_club_id)
	box.add_child(board)

func _first_vbox(node: Node) -> VBoxContainer:
	if node is VBoxContainer: return node
	for child in node.get_children():
		var found := _first_vbox(child)
		if found != null: return found
	return null

func _career_session(node: Node):
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"): return current.get("session")
		current = current.get_parent()
	return null
