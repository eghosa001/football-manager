extends Node

const YouthAcademy = preload("res://simulation/players/youth_academy.gd")

var _next_scan := 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 900
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer:
		_upgrade(node as TabContainer)
	for child in node.get_children():
		_scan_node(child)

func _upgrade(tabs: TabContainer) -> void:
	var session = _career_session(tabs)
	if session == null or session.world.is_empty(): return
	var index := _tab_index(tabs, "Youth Academy")
	if index < 0: return
	var page := tabs.get_tab_control(index)
	if page == null or page.has_meta("core_youth_progress"): return
	var box := _first_vbox(page)
	if box == null: return
	page.set_meta("core_youth_progress", true)
	var club := _club(session.world, String(session.managed_club_id))
	if club.is_empty(): return
	YouthAcademy.new().ensure_club(club)
	var divider := HSeparator.new(); box.add_child(divider)
	var title := Label.new(); title.text = "Academy development"; title.add_theme_font_size_override("font_size", 18); box.add_child(title)
	var help := Label.new(); help.text = "Current ability shows where the player is now; potential is the estimated ceiling. Progress records actual academy development over time."; help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(help)
	var prospects: Array = []
	for player_id in club.get("academy", {}).get("prospects", []):
		var player := _player(session.world, String(player_id))
		if not player.is_empty(): prospects.append(player)
	prospects.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.get("potential",0)) > int(b.get("potential",0)))
	if prospects.is_empty():
		var empty := Label.new(); empty.text = "No academy prospects are currently registered. The next youth intake will populate this list."; empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(empty)
		return
	var header := HBoxContainer.new(); box.add_child(header)
	for data in [["PLAYER",210],["POS",55],["AGE",45],["CA",55],["PA",55],["PROGRESS",150],["LAST",60],["ACTION",190]]:
		var label := Label.new(); label.text = String(data[0]); label.custom_minimum_size.x = int(data[1]); header.add_child(label)
	for player in prospects:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation",6); box.add_child(row)
		_add_cell(row,_player_name(player),210)
		_add_cell(row,String(player.get("position","")),55)
		_add_cell(row,str(player.get("age",0)),45)
		var ca := int(player.get("current_ability",0)); var pa := maxi(ca,int(player.get("potential",ca)))
		_add_cell(row,str(ca),55); _add_cell(row,str(pa),55)
		var progress := ProgressBar.new(); progress.min_value=0; progress.max_value=100; progress.value=100.0*float(ca)/maxf(1.0,float(pa)); progress.custom_minimum_size=Vector2(150,24); progress.show_percentage=true; row.add_child(progress)
		_add_cell(row,"+%d" % int(player.get("last_development_gain",0)),60)
		var promote := Button.new(); promote.text="Promote"; promote.pressed.connect(func():
			var err := YouthAcademy.new().promote(session.world,String(session.managed_club_id),String(player.get("id","")))
			if err == OK: row.visible=false
		); row.add_child(promote)
		var release := Button.new(); release.text="Release"; release.pressed.connect(func():
			var err := YouthAcademy.new().release(session.world,String(session.managed_club_id),String(player.get("id","")))
			if err == OK: row.visible=false
		); row.add_child(release)

func _add_cell(row: HBoxContainer,text: String,width: int) -> void:
	var label := Label.new(); label.text=text; label.custom_minimum_size.x=width; label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; row.add_child(label)

func _club(world: Dictionary,id: String) -> Dictionary:
	for club in world.get("clubs",[]):
		if String(club.get("id",""))==id:return club
	return {}

func _player(world: Dictionary,id: String) -> Dictionary:
	for player in world.get("players",[]):
		if String(player.get("id",""))==id:return player
	return {}

func _player_name(player: Dictionary) -> String:
	var name := String(player.get("name","")).strip_edges()
	if name!="":return name
	return (String(player.get("first_name",""))+" "+String(player.get("last_name",""))).strip_edges()

func _tab_index(tabs: TabContainer,title: String)->int:
	for i in range(tabs.get_tab_count()):
		if tabs.get_tab_title(i)==title or String(tabs.get_tab_control(i).name)==title:return i
	return -1

func _first_vbox(node: Node)->VBoxContainer:
	if node is VBoxContainer:return node
	for child in node.get_children():
		var found:=_first_vbox(child)
		if found!=null:return found
	return null

func _career_session(node: Node):
	var current: Node=node
	while current!=null:
		var script=current.get_script()
		if script!=null and String(script.resource_path).ends_with("game/career/career_app.gd"):return current.get("session")
		current=current.get_parent()
	return null
