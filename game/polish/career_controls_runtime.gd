extends Node

const Commands = preload("res://application/career/career_command_service.gd")
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
	if tabs.has_meta("advanced_career_controls"): return
	var session = _career_session(tabs)
	if session == null or session.world.is_empty(): return
	var scouting := _named_tab(tabs,"Scouting")
	var transfers := _named_tab(tabs,"Transfers")
	var dynamics := _named_tab(tabs,"Dynamics")
	if scouting == null or transfers == null: return
	tabs.set_meta("advanced_career_controls",true)
	_add_recruitment_focus(_first_vbox(scouting),session)
	_add_loan_controls(_first_vbox(transfers),session)
	if dynamics != null: _add_promise_controls(_first_vbox(dynamics),session)

func _add_recruitment_focus(box: VBoxContainer, session) -> void:
	if box == null: return
	_heading(box,"Recruitment focus")
	var country := OptionButton.new()
	var countries: Array = session.world.get("countries",[])
	for row in countries: country.add_item(String(row.get("name",row.get("id","Country"))))
	box.add_child(country)
	var position := OptionButton.new()
	var positions := ["Any","GK","DL","DC","DR","WBL","DM","MC","WBR","ML","MR","AML","AMC","AMR","ST"]
	for p in positions: position.add_item(String(p))
	box.add_child(position)
	var max_age:=SpinBox.new(); max_age.min_value=16; max_age.max_value=40; max_age.value=27; box.add_child(_labeled("Maximum age",max_age))
	var potential:=SpinBox.new(); potential.min_value=0; potential.max_value=100; potential.value=60; box.add_child(_labeled("Minimum potential",potential))
	var start:=Button.new(); start.text=tr("Start recruitment focus")
	start.pressed.connect(func():
		if countries.is_empty(): return
		var country_id:=String(countries[clampi(country.selected,0,countries.size()-1)].get("id",""))
		var pos:="" if position.get_item_text(position.selected)=="Any" else position.get_item_text(position.selected)
		var result:=Commands.new().start_recruitment_focus(session.world,session.managed_club_id,country_id,pos,int(max_age.value),int(potential.value))
		_notice(box,"Recruitment focus created." if not result.has("error") else "Could not create recruitment focus: %s"%String(result.get("reason",result.get("error","error"))))
	); box.add_child(start)

func _add_loan_controls(box: VBoxContainer, session) -> void:
	if box == null: return
	_heading(box,"Loan market")
	var candidates: Array = []
	for player in session.world.get("players",[]):
		if bool(player.get("retired",false)) or String(player.get("club_id",""))==session.managed_club_id: continue
		if int(player.get("age",99))>24: continue
		candidates.append(player)
	candidates.sort_custom(func(a:Dictionary,b:Dictionary): return int(a.get("potential",0))>int(b.get("potential",0)))
	for i in range(mini(8,candidates.size())):
		var player:Dictionary=candidates[i]
		var row:=HBoxContainer.new(); box.add_child(row)
		var label:=Label.new(); label.text="%s — %s — Age %d — CA %d / PA %d"%[_name(player),String(player.get("position","")),int(player.get("age",0)),int(player.get("current_ability",0)),int(player.get("potential",0))]; label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(label)
		var button:=Button.new(); button.text=tr("Loan offer")
		button.pressed.connect(func():
			var fee:=maxi(0,int(player.get("current_ability",50))*1500)
			var result:=Commands.new().execute_loan(session.world,session.managed_club_id,String(player.get("id","")),fee,session.seed+int(session.world.get("day_index",0)))
			_notice(box,"Loan completed for %s."%_name(player) if int(result.get("error",FAILED))==OK else "Loan unavailable (%s)."%String(result.get("reason",result.get("error","error"))))
		); row.add_child(button)

func _add_promise_controls(box: VBoxContainer, session) -> void:
	if box == null: return
	_heading(box,"Make player promise")
	var squad:Array=[]
	for player in session.world.get("players",[]):
		if String(player.get("club_id",""))==session.managed_club_id and not bool(player.get("retired",false)): squad.append(player)
	if squad.is_empty(): return
	var player_choice:=OptionButton.new(); for p in squad: player_choice.add_item(_name(p)); box.add_child(player_choice)
	var type_choice:=OptionButton.new(); for value in ["playing_time","morale","training"]: type_choice.add_item(String(value).replace("_"," ").capitalize()); box.add_child(type_choice)
	var target:=SpinBox.new(); target.min_value=1; target.max_value=100; target.value=10; box.add_child(_labeled("Target",target))
	var days:=SpinBox.new(); days.min_value=7; days.max_value=180; days.value=30; box.add_child(_labeled("Deadline days",days))
	var button:=Button.new(); button.text=tr("Make promise")
	button.pressed.connect(func():
		var player:Dictionary=squad[clampi(player_choice.selected,0,squad.size()-1)]
		var types:=["playing_time","morale","training"]
		Commands.new().make_player_promise(session.world,session.managed_club_id,String(player.get("id","")),String(types[type_choice.selected]),int(target.value),int(days.value))
		_notice(box,"Promise made to %s."%_name(player))
	); box.add_child(button)

func _named_tab(tabs: TabContainer,name:String) -> Control:
	for child in tabs.get_children():
		if String(child.name)==name: return child
	return null
func _first_vbox(node:Node)->VBoxContainer:
	if node is VBoxContainer: return node
	for child in node.get_children():
		var found:=_first_vbox(child); if found!=null: return found
	return null
func _heading(parent:Control,text:String)->void:
	var l:=Label.new(); l.text=tr(text); l.add_theme_font_size_override("font_size",18); parent.add_child(l)
func _labeled(text:String,control:Control)->Control:
	var row:=HBoxContainer.new(); var l:=Label.new(); l.text=tr(text); l.custom_minimum_size.x=190; row.add_child(l); control.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(control); return row
func _notice(parent:Control,text:String)->void:
	var dialog:=AcceptDialog.new(); dialog.dialog_text=text; parent.add_child(dialog); dialog.confirmed.connect(dialog.queue_free); dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(520,180))
func _name(player:Dictionary)->String:
	var n:=String(player.get("name","")).strip_edges(); return n if n!="" else (String(player.get("first_name",""))+" "+String(player.get("last_name",""))).strip_edges()
func _career_session(node:Node):
	var current:Node=node
	while current!=null:
		var script=current.get_script()
		if script!=null and String(script.resource_path).ends_with("game/career/career_app.gd"): return current.get("session")
		current=current.get_parent()
	return null
