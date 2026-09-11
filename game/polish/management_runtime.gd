extends Node

const DressingRoom = preload("res://simulation/players/dressing_room.gd")
const DynamicsActions = preload("res://application/career/dynamics_actions.gd")
const CareerCommand = preload("res://application/career/career_command_service.gd")
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
	if node is TabContainer: _wire(node)
	for child in node.get_children(): _scan_node(child)

func _wire(tabs: TabContainer) -> void:
	if tabs.has_meta("management_tabs_added"): return
	var session = _career_session(tabs)
	if session == null or session.world.is_empty(): return
	var names: Array[String] = []
	for child in tabs.get_children(): names.append(String(child.name))
	if "Dashboard" not in names or "Squad" not in names: return
	tabs.set_meta("management_tabs_added", true)
	if "Club" not in names: _add_club_tab(tabs, session)
	if "Dynamics" not in names: _add_dynamics_tab(tabs, session)

func _add_club_tab(tabs: TabContainer, session) -> void:
	var box := _tab(tabs,"Club")
	var club := _club(session.world,session.managed_club_id)
	if club.is_empty(): return
	_heading(box,String(club.get("name","Club")))
	_label(box,"Reputation %d   Cash %d   Transfer budget %d   Wage budget %d" % [int(club.get("reputation",0)),int(club.get("cash",0)),int(club.get("transfer_budget",0)),int(club.get("wage_budget",0))])
	var stadium: Dictionary = club.get("stadium",{})
	_label(box,"Stadium: %s   Capacity: %d" % [String(stadium.get("name",club.get("stadium_name","Stadium"))),int(stadium.get("capacity",club.get("stadium_capacity",0)))])
	var facilities: Dictionary = club.get("facilities",{})
	_label(box,"Facilities — Training %d   Youth %d   Medical %d" % [int(facilities.get("training",club.get("training_facilities",0))),int(facilities.get("youth",club.get("youth_facilities",0))),int(facilities.get("medical",club.get("medical_facilities",0)))])
	var board: Dictionary = club.get("board",{})
	_label(box,"Board — Ambition %d   Patience %d   Financial prudence %d" % [int(board.get("ambition",50)),int(board.get("patience",50)),int(board.get("financial_prudence",50))])
	var supporters: Dictionary = club.get("supporters",{})
	_label(box,"Supporters — Loyalty %d   Passion %d   Expectation %d" % [int(supporters.get("loyalty",50)),int(supporters.get("passion",50)),int(supporters.get("expectation",50))])
	_heading(box,"Honours & recent history")
	var count := 0
	for row in session.world.get("club_honours",[]):
		if String(row.get("club_id","")) != session.managed_club_id: continue
		_label(box,"%s — %s" % [String(row.get("season_year",row.get("year",""))),String(row.get("competition_name",row.get("competition_id","Honour")))])
		count += 1
	if count == 0: _label(box,"No recorded honours yet.")
	_heading(box,"Institutional identity")
	_label(box,"Country: %s   Tier: %d   Ticket price: %d" % [String(club.get("country_id","")),int(club.get("tier",1)),int(club.get("ticket_price",0))])

func _add_dynamics_tab(tabs: TabContainer, session) -> void:
	var box := _tab(tabs,"Dynamics")
	var room := DressingRoom.new().rebuild(session.world,session.managed_club_id)
	_heading(box,"Dressing room")
	_label(box,"Atmosphere: %.1f / 100" % float(room.get("atmosphere",50.0)))
	_label(box,"Team leaders: %s" % _names(session.world,room.get("leaders",[])))
	_label(box,"Highly influential: %s" % _names(session.world,room.get("highly_influential",[])))
	_label(box,"Influential: %s" % _names(session.world,room.get("influential",[])))
	for group in room.get("social_groups",[]): _label(box,"%s group: %s" % [String(group.get("name","Group")).capitalize(),_names(session.world,group.get("members",[]))])
	var club := _club(session.world,session.managed_club_id)
	var captain_id := String(club.get("captain_id",""))
	_label(box,"Captain: %s" % (_player_name(session.world,captain_id) if captain_id!="" else "Not appointed"))
	_heading(box,"Captaincy")
	for candidate in DynamicsActions.new().captain_candidates(session.world,session.managed_club_id):
		var row:=HBoxContainer.new(); box.add_child(row)
		_label(row,"%s — Influence %.1f, Leadership %d, Age %d" % [String(candidate.name),float(candidate.influence),int(candidate.leadership),int(candidate.age)])
		var b:=Button.new(); b.text="Appoint captain"; b.pressed.connect(func(): DynamicsActions.new().set_captain(session.world,session.managed_club_id,String(candidate.id)); _refresh_app(tabs)); row.add_child(b)
	_heading(box,"Team meeting")
	var meetings:=HBoxContainer.new(); box.add_child(meetings)
	for tone in ["praise","encourage","criticize"]:
		var b:=Button.new(); b.text=String(tone).capitalize(); b.pressed.connect(func(): CareerCommand.new().hold_team_meeting(session.world,session.managed_club_id,String(tone)); _refresh_app(tabs)); meetings.add_child(b)
	_heading(box,"Active promises")
	var promises:=0
	for promise in session.world.get("player_promises",[]):
		if String(promise.get("status",""))!="active": continue
		var player:=_player(session.world,String(promise.get("player_id","")))
		if player.is_empty() or String(player.get("club_id",""))!=session.managed_club_id: continue
		_label(box,"%s — %s target %s by day %d" % [_name(player),String(promise.get("type","")),str(promise.get("target_value","")),int(promise.get("deadline_day",0))]); promises+=1
	if promises==0: _label(box,"No active player promises.")
	_heading(box,"Relationships")
	var relationships:=0
	for rel in session.world.get("relationships",[]):
		var a:=String(rel.get("source_person_id",rel.get("source_id",""))); var b:=String(rel.get("target_person_id",rel.get("target_id","")))
		var pa:=_player(session.world,a); var pb:=_player(session.world,b)
		if pa.is_empty() or pb.is_empty(): continue
		if String(pa.get("club_id",""))!=session.managed_club_id and String(pb.get("club_id",""))!=session.managed_club_id: continue
		_label(box,"%s ↔ %s — %s (%d)" % [_name(pa),_name(pb),String(rel.get("relationship_type",rel.get("type","relationship"))),int(rel.get("strength",0))]); relationships+=1
		if relationships>=12: break
	if relationships==0: _label(box,"No notable squad relationships recorded yet.")

func _refresh_app(node: Node) -> void:
	var current: Node=node
	while current!=null:
		var script=current.get_script()
		if script!=null and String(script.resource_path).ends_with("game/career/career_app.gd"): current.call("_show_career"); return
		current=current.get_parent()

func _tab(tabs:TabContainer,name:String)->VBoxContainer:
	var scroll:=ScrollContainer.new(); scroll.name=name; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var box:=VBoxContainer.new(); box.custom_minimum_size=Vector2(900,480); box.add_theme_constant_override("separation",8); scroll.add_child(box); tabs.add_child(scroll); tabs.set_tab_title(tabs.get_tab_count()-1,tr(name)); return box
func _heading(parent:Control,text:String)->void:
	var l:=Label.new(); l.text=tr(text); l.add_theme_font_size_override("font_size",18); parent.add_child(l)
func _label(parent:Control,text:String)->void:
	var l:=Label.new(); l.text=tr(text); l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; parent.add_child(l)
func _club(world:Dictionary,id:String)->Dictionary:
	for club in world.get("clubs",[]):
		if String(club.get("id",""))==id: return club
	return {}
func _player(world:Dictionary,id:String)->Dictionary:
	for player in world.get("players",[]):
		if String(player.get("id",""))==id: return player
	return {}
func _name(player:Dictionary)->String:
	var n:=String(player.get("name","")).strip_edges(); return n if n!="" else (String(player.get("first_name",""))+" "+String(player.get("last_name",""))).strip_edges()
func _player_name(world:Dictionary,id:String)->String:
	var p:=_player(world,id); return _name(p) if not p.is_empty() else id
func _names(world:Dictionary,ids:Array)->String:
	var rows:Array[String]=[]; for id in ids: rows.append(_player_name(world,String(id))); return ", ".join(rows)
func _career_session(node:Node):
	var current:Node=node
	while current!=null:
		var script=current.get_script()
		if script!=null and String(script.resource_path).ends_with("game/career/career_app.gd"): return current.get("session")
		current=current.get_parent()
	return null
