extends Node

const Graphics = preload("res://game/presentation/graphics_override_service.gd")
var _next_scan := 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan: return
	_next_scan = now + 1100
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer: _wire_tabs(node)
	for child in node.get_children(): _scan_node(child)

func _wire_tabs(tabs: TabContainer) -> void:
	if tabs.has_meta("graphics_overrides_rendered"): return
	var session = _career_session(tabs)
	if session == null or session.world.is_empty(): return
	var club_tab := _named_tab(tabs,"Club")
	var match_tab := _named_tab(tabs,"Match Analysis")
	if club_tab == null and match_tab == null: return
	tabs.set_meta("graphics_overrides_rendered",true)
	if club_tab != null: _add_club_graphics(_first_vbox(club_tab),session.world,session.managed_club_id)
	if match_tab != null and session.world.has("last_managed_match"):
		var fixture: Dictionary = session.world.last_managed_match.get("fixture",{})
		_add_match_graphics(_first_vbox(match_tab),session.world,String(fixture.get("home_club_id","")),String(fixture.get("away_club_id","")))

func _add_club_graphics(box: VBoxContainer, world: Dictionary, club_id: String) -> void:
	if box == null: return
	var service=Graphics.new(); var texture=service.texture(world,club_id,"logo")
	if texture != null:
		var logo:=TextureRect.new(); logo.texture=texture; logo.expand_mode=TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL; logo.custom_minimum_size=Vector2(128,128); logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; box.add_child(logo); box.move_child(logo,0)
	var available:=service.available(world,club_id)
	var kit_rows:Array[String]=[]
	for key in ["kit_home","kit_away","kit_third"]:
		if available.has(key): kit_rows.append("%s: %s" % [String(key).replace("_"," ").capitalize(),String(available[key])])
	if not kit_rows.is_empty():
		var label:=Label.new(); label.text=tr("Mod kit assets\n")+"\n".join(kit_rows); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(label)

func _add_match_graphics(box: VBoxContainer, world: Dictionary, home_id: String, away_id: String) -> void:
	if box == null: return
	var row:=HBoxContainer.new(); var any:=false
	for id in [home_id,away_id]:
		var texture=Graphics.new().texture(world,String(id),"logo")
		if texture==null: continue
		any=true; var logo:=TextureRect.new(); logo.texture=texture; logo.custom_minimum_size=Vector2(72,72); logo.expand_mode=TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL; logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; row.add_child(logo)
	if any: box.add_child(row); box.move_child(row,0)

func _named_tab(tabs: TabContainer,name:String)->Control:
	for child in tabs.get_children():
		if String(child.name)==name: return child
	return null
func _first_vbox(node:Node)->VBoxContainer:
	if node is VBoxContainer: return node
	for child in node.get_children():
		var found:=_first_vbox(child); if found!=null: return found
	return null
func _career_session(node:Node):
	var current:Node=node
	while current!=null:
		var script=current.get_script()
		if script!=null and String(script.resource_path).ends_with("game/career/career_app.gd"): return current.get("session")
		current=current.get_parent()
	return null
