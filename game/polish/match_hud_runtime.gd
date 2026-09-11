extends Node

const MatchHud = preload("res://game/analysis/match_hud.gd")
const MatchRatings = preload("res://application/career/match_rating_service.gd")
var _next_scan := 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now:=Time.get_ticks_msec()
	if now<_next_scan: return
	_next_scan=now+900
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer: _wire(node)
	for child in node.get_children(): _scan_node(child)

func _wire(tabs: TabContainer) -> void:
	if tabs.has_meta("match_hud_added"): return
	var tab: Control=null
	for child in tabs.get_children():
		if String(child.name)=="Match Analysis": tab=child; break
	if tab==null: return
	var session=_career_session(tabs)
	if session==null or not session.world.has("last_managed_match"): return
	var box:=_first_vbox(tab); var viewer:=_find_viewer(tab)
	if box==null or viewer==null: return
	tabs.set_meta("match_hud_added",true)
	var result:Dictionary=session.world.last_managed_match.get("result",{})
	var hud=MatchHud.new(); hud.setup(viewer,result); box.add_child(hud); box.move_child(hud,1)
	var heading:=Label.new(); heading.text=tr("Player ratings"); heading.add_theme_font_size_override("font_size",18); box.add_child(heading)
	var ratings:=MatchRatings.new().ratings(result)
	for row in ratings.slice(0,mini(22,ratings.size())):
		var label:=Label.new(); label.text="%s  %s  %.1f%s" % [String(row.side).to_upper(),_player_name(session.world,String(row.player_id)),float(row.rating),"  • %d goal(s)"%int(row.goals) if int(row.goals)>0 else ""]; box.add_child(label)

func _player_name(world:Dictionary,id:String)->String:
	for p in world.get("players",[]):
		if String(p.get("id",""))==id:
			var n:=String(p.get("name","")).strip_edges(); return n if n!="" else (String(p.get("first_name",""))+" "+String(p.get("last_name",""))).strip_edges()
	return id

func _find_viewer(node: Node):
	var script=node.get_script()
	if script!=null and String(script.resource_path).ends_with("game/match_viewer.gd"): return node
	for child in node.get_children():
		var found=_find_viewer(child); if found!=null: return found
	return null

func _first_vbox(node: Node) -> VBoxContainer:
	if node is VBoxContainer: return node
	for child in node.get_children():
		var found:=_first_vbox(child); if found!=null: return found
	return null

func _career_session(node: Node):
	var current: Node=node
	while current!=null:
		var script=current.get_script()
		if script!=null and String(script.resource_path).ends_with("game/career/career_app.gd"): return current.get("session")
		current=current.get_parent()
	return null
