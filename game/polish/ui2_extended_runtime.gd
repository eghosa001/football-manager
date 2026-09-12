extends Node

const UI = preload("res://game/presentation/fd_ui2.gd")
const CareerQuery = preload("res://application/career/career_query.gd")
const TrainingSystem = preload("res://simulation/players/training_system.gd")
const PlayerProfileDialog = preload("res://game/presentation/player_profile_dialog.gd")

var _next_scan := 0
var _query = CareerQuery.new()

class MiniChart:
	extends Control
	var values: Array[float] = []
	var positive := Color(0.18, 0.83, 0.73, 1.0)
	func setup(data: Array, color: Color) -> void:
		values.clear()
		for v in data: values.append(float(v))
		positive = color
		custom_minimum_size = Vector2(220, 96)
		queue_redraw()
	func _draw() -> void:
		if values.size() < 2: return
		var lo := values.min(); var hi := values.max(); var span := maxf(1.0, hi - lo)
		var pts := PackedVector2Array()
		for i in range(values.size()):
			var x := 8.0 + (size.x - 16.0) * float(i) / float(values.size() - 1)
			var y := size.y - 10.0 - (size.y - 20.0) * ((values[i] - lo) / span)
			pts.append(Vector2(x, y))
		for i in range(pts.size() - 1): draw_line(pts[i], pts[i + 1], positive, 3.0, true)
		for p in pts: draw_circle(p, 3.0, positive)

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan: return
	_next_scan = now + 900
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer: _upgrade(node as TabContainer)
	for child in node.get_children(): _scan_node(child)

func _upgrade(tabs: TabContainer) -> void:
	if not bool(tabs.get_meta("ui2_active", false)): return
	var session = _career_session(tabs)
	if session == null or session.world.is_empty(): return
	tabs.set_meta("individual_training_added", true)
	_build_training(_page(tabs, "Training"), tabs, session)
	_build_scouting(_page(tabs, "Scouting"), tabs, session)
	_build_finances(_page(tabs, "Finances"), tabs, session)
	_build_transfers(_page(tabs, "Transfers"), tabs, session)
	_build_medical(_page(tabs, "Medical"), tabs, session)
	_build_competitions(_page(tabs, "Competitions"), tabs, session)
	_build_schedule(_page(tabs, "Schedule"), tabs, session)

func _build_training(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_extended"): return
	var root := _replace_page(page); if root == null: return
	_header(root, "TRAINING", "Weekly programme • workload • development", tabs, session)
	var data: Dictionary = _query.training(session.world, session.managed_club_id)
	var status := HBoxContainer.new(); status.add_theme_constant_override("separation", 12); root.add_child(status)
	var summary := UI.panel(status, Vector2(300, 110), UI.CYAN); UI.metric(summary, "Intensity", "%.0f%%" % (float(data.get("intensity", 0.65)) * 100.0), "Facilities %d" % int(data.get("facilities", 0)), UI.CYAN)
	var squad := _squad(session.world, session.managed_club_id)
	var avg_fit := 0.0; var avg_morale := 0.0
	for p in squad: avg_fit += float(p.get("fitness", 0)); avg_morale += float(p.get("morale", 0))
	var pulse := UI.panel(status, Vector2(300, 110), UI.GREEN); UI.metric(pulse, "Squad readiness", "%.0f%% fit" % (avg_fit / maxf(1.0, squad.size())), "%.0f morale" % (avg_morale / maxf(1.0, squad.size())), UI.GREEN)
	var risk := UI.panel(status, Vector2(300, 110), UI.RED); var high := 0
	for p in squad:
		if int(p.get("fatigue", 0)) > 60 or int(p.get("fitness", 100)) < 70: high += 1
	UI.metric(risk, "Workload risk", str(high), "players need attention", UI.RED if high > 2 else UI.AMBER)

	var week := UI.panel(root, Vector2(0, 265), UI.CYAN); UI.section(week, "THIS WEEK")
	var grid := GridContainer.new(); grid.columns = 7; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; week.add_child(grid)
	var names := ["MON","TUE","WED","THU","FRI","SAT","SUN"]
	var schedule: Array = data.get("schedule", [])
	for i in range(7):
		var day := VBoxContainer.new(); day.custom_minimum_size = Vector2(116, 170); day.add_theme_constant_override("separation", 7); grid.add_child(day)
		var label := UI.body(day, names[i]); label.add_theme_color_override("font_color", UI.CYAN)
		var session_name := String(schedule[i]) if i < schedule.size() else "rest"
		var chip_color := UI.GREEN if session_name in ["recovery", "rest"] else (UI.AMBER if session_name in ["physical", "fitness"] else UI.PURPLE)
		day.add_child(UI.chip(session_name.replace("_", " ").capitalize(), chip_color))
		var load := 0.25 if session_name == "rest" else (0.45 if session_name == "recovery" else 0.75)
		day.add_child(UI.progress(load, chip_color))
		UI.body(day, "Load %.0f%%" % (load * 100.0), true)

	var lower := HBoxContainer.new(); lower.add_theme_constant_override("separation", 12); root.add_child(lower)
	var performers := UI.panel(lower, Vector2(430, 250), UI.GREEN); UI.section(performers, "TRAINING PERFORMANCE", UI.GREEN)
	var sorted := squad.duplicate(); sorted.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("morale", 0)) + int(a.get("fitness", 0)) > int(b.get("morale", 0)) + int(b.get("fitness", 0)))
	for p in sorted.slice(0, mini(6, sorted.size())):
		var row := HBoxContainer.new(); performers.add_child(row)
		var n := UI.body(row, _player_name(p)); n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(UI.chip("FIT %d" % int(p.get("fitness", 0)), UI.GREEN if int(p.get("fitness", 0)) >= 80 else UI.AMBER))
		row.add_child(UI.chip("MOR %d" % int(p.get("morale", 0)), UI.CYAN))
	var individual := UI.panel(lower, Vector2(430, 250), UI.PURPLE); UI.section(individual, "INDIVIDUAL DEVELOPMENT", UI.PURPLE)
	for p in squad.slice(0, mini(6, squad.size())):
		var row := HBoxContainer.new(); individual.add_child(row)
		var n := UI.body(row, _player_name(p)); n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(UI.chip(String(p.get("training_focus", "balanced")).capitalize(), UI.PURPLE))

func _build_scouting(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_extended"): return
	var root := _replace_page(page); if root == null: return
	_header(root, "SCOUTING", "Recruitment focus • coverage • recommendations", tabs, session)
	var data: Dictionary = _query.scouting(session.world, session.managed_club_id)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 12); root.add_child(top)
	var known := UI.panel(top, Vector2(250, 105), UI.CYAN); UI.metric(known, "Known players", str(data.get("knowledge_count", 0)), "scouting database", UI.CYAN)
	var assignments: Array = data.get("assignments", []); var active := UI.panel(top, Vector2(250,105), UI.GREEN); UI.metric(active, "Assignments", str(assignments.size()), "active / completed", UI.GREEN)
	var club := _club(session.world, session.managed_club_id); var budget := UI.panel(top, Vector2(250,105), UI.PURPLE); UI.metric(budget, "Scouting budget", UI.money(int(club.get("scouting_budget", club.get("transfer_budget",0) / 30))), "recruitment resources", UI.PURPLE)
	var body := HBoxContainer.new(); body.add_theme_constant_override("separation", 12); root.add_child(body)
	var focus := UI.panel(body, Vector2(300, 390), UI.CYAN); UI.section(focus, "RECRUITMENT FOCUSES")
	if assignments.is_empty(): UI.body(focus, "No active scouting assignments", true)
	for a in assignments.slice(0, mini(8, assignments.size())):
		var row := VBoxContainer.new(); focus.add_child(row)
		UI.body(row, String(a.get("target_id", "Assignment")).left(26))
		row.add_child(UI.progress(clampf(float(a.get("progress", 0.0)) / 100.0, 0, 1), UI.GREEN))
	var rec := UI.panel(body, Vector2(0, 390), UI.GREEN); rec.size_flags_horizontal = Control.SIZE_EXPAND_FILL; UI.section(rec, "SCOUTING RECOMMENDATIONS", UI.GREEN)
	var grid := GridContainer.new(); grid.columns = 6; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rec.add_child(grid)
	UI.table_header(grid, ["PLAYER","POS","AGE","ABILITY","POTENTIAL","VALUE"])
	var candidates := _shortlist(session.world, session.managed_club_id, 10)
	for p in candidates:
		UI.cell(grid, _player_name(p).left(19), 155); UI.cell(grid, String(p.get("position","")), 55, UI.CYAN); UI.cell(grid, str(p.get("age",0)), 42)
		UI.cell(grid, UI.stars(int(p.get("current_ability",0))), 105, UI.AMBER); UI.cell(grid, UI.stars(int(p.get("potential",0))), 105, UI.AMBER); UI.cell(grid, UI.money(_value(p)), 95, UI.GREEN)

func _build_finances(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_extended"): return
	var root := _replace_page(page); if root == null: return
	_header(root, "FINANCES", "Balance • income • expenditure • budgets", tabs, session)
	var club := _club(session.world, session.managed_club_id)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 12); root.add_child(top)
	for item in [["BALANCE", int(club.get("cash",0)), UI.CYAN],["TRANSFER BUDGET",int(club.get("transfer_budget",0)),UI.GREEN],["WAGE BUDGET",int(club.get("wage_budget",0)),UI.PURPLE]]:
		var p := UI.panel(top, Vector2(280,110), item[2]); UI.metric(p, item[0], UI.money(item[1]), "current allocation", item[2])
	var charts := HBoxContainer.new(); charts.add_theme_constant_override("separation", 12); root.add_child(charts)
	var ledger: Array = session.world.get("ledger", []); var cash_values: Array = []
	var income_values: Array = []; var cost_values: Array = []
	var balance := float(club.get("cash",0)); var count := 0
	for e in ledger:
		if String(e.get("club_id","")) != session.managed_club_id: continue
		var amount := float(e.get("amount", e.get("value",0)))
		balance += amount; cash_values.append(balance)
		if amount >= 0: income_values.append(amount)
		else: cost_values.append(absf(amount))
		count += 1
		if count >= 18: break
	if cash_values.size() < 2: cash_values = [float(club.get("cash",0))*0.82, float(club.get("cash",0))*0.9, float(club.get("cash",0))]
	var balance_panel := UI.panel(charts, Vector2(430,230), UI.CYAN); UI.section(balance_panel,"BALANCE HISTORY"); var c1 := MiniChart.new(); c1.setup(cash_values, UI.CYAN); balance_panel.add_child(c1)
	var flow := UI.panel(charts, Vector2(430,230), UI.GREEN); UI.section(flow,"CASH FLOW",UI.GREEN); var combined: Array = []
	var maxn := maxi(income_values.size(), cost_values.size()); for i in range(maxn): combined.append((income_values[i] if i < income_values.size() else 0.0) - (cost_values[i] if i < cost_values.size() else 0.0))
	if combined.size() < 2: combined = [0.0, 1.0, 0.5]
	var c2 := MiniChart.new(); c2.setup(combined, UI.GREEN); flow.add_child(c2)
	var lower := HBoxContainer.new(); lower.add_theme_constant_override("separation", 12); root.add_child(lower)
	var inc := UI.panel(lower, Vector2(420,210), UI.GREEN); UI.section(inc,"INCOME",UI.GREEN); UI.metric(inc,"Recorded income",UI.money(int(_sum(income_values))),"ledger total",UI.GREEN)
	var exp := UI.panel(lower, Vector2(420,210), UI.RED); UI.section(exp,"EXPENDITURE",UI.RED); UI.metric(exp,"Recorded expenditure",UI.money(int(_sum(cost_values))),"ledger total",UI.RED)

func _build_transfers(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_extended"): return
	var root := _replace_page(page); if root == null: return
	_header(root, "TRANSFERS", "Market activity • bids • budgets", tabs, session)
	var data: Dictionary = _query.transfer_market(session.world, session.managed_club_id)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 12); root.add_child(top)
	var window := UI.panel(top, Vector2(250,110), UI.GREEN if bool(data.get("window_open",false)) else UI.RED); UI.metric(window,"TRANSFER WINDOW","OPEN" if bool(data.get("window_open",false)) else "CLOSED","market status",UI.GREEN if bool(data.get("window_open",false)) else UI.RED)
	var b := UI.panel(top,Vector2(250,110),UI.CYAN); UI.metric(b,"TRANSFER BUDGET",UI.money(int(data.get("transfer_budget",0))),"available",UI.CYAN)
	var w := UI.panel(top,Vector2(250,110),UI.PURPLE); UI.metric(w,"WAGE BUDGET",UI.money(int(data.get("wage_budget",0))),"weekly ceiling",UI.PURPLE)
	var offers: Array = data.get("offers", []); var panel := UI.panel(root,Vector2(0,390),UI.CYAN); UI.section(panel,"ACTIVE NEGOTIATIONS")
	var grid := GridContainer.new(); grid.columns = 6; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; panel.add_child(grid); UI.table_header(grid,["PLAYER","FEE","STATUS","COUNTER","CLAUSES","ACTION"])
	if offers.is_empty(): UI.body(panel,"No active offers. Use Scouting to identify and approach targets.",true)
	for offer in offers.slice(0, mini(12,offers.size())):
		var player := _player(session.world,String(offer.get("player_id","")))
		UI.cell(grid,_player_name(player).left(20),160); UI.cell(grid,UI.money(int(offer.get("fee",0))),90,UI.GREEN); UI.cell(grid,String(offer.get("status","submitted")).capitalize(),90,UI.CYAN)
		UI.cell(grid,UI.money(int(offer.get("counter_fee",0))) if offer.has("counter_fee") else "—",90,UI.AMBER); UI.cell(grid,str(offer.get("clauses",{})).left(22),150,UI.MUTED); UI.cell(grid,"Review",70,UI.PURPLE)

func _build_medical(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_extended"): return
	var root := _replace_page(page); if root == null: return
	_header(root,"MEDICAL CENTRE","Injuries • fatigue • player risk",tabs,session)
	var squad := _squad(session.world,session.managed_club_id); var injured := 0; var high := 0
	for p in squad:
		if int(p.get("injured_days",0)) > 0: injured += 1
		if int(p.get("fitness",100)) < 75 or int(p.get("fatigue",0)) > 60: high += 1
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation",12); root.add_child(top)
	var a := UI.panel(top,Vector2(260,105),UI.RED); UI.metric(a,"INJURIES",str(injured),"currently unavailable",UI.RED)
	var b := UI.panel(top,Vector2(260,105),UI.AMBER); UI.metric(b,"PLAYERS AT RISK",str(high),"fatigue / low fitness",UI.AMBER)
	var panel := UI.panel(root,Vector2(0,430),UI.RED); UI.section(panel,"SQUAD RISK REGISTER",UI.RED)
	var grid := GridContainer.new(); grid.columns = 6; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; panel.add_child(grid); UI.table_header(grid,["PLAYER","POS","FITNESS","FATIGUE","INJURY","RISK"])
	var rows := squad.duplicate(); rows.sort_custom(func(x:Dictionary,y:Dictionary): return _risk(x) > _risk(y))
	for p in rows.slice(0,mini(14,rows.size())):
		var r := _risk(p); UI.cell(grid,_player_name(p).left(20),160); UI.cell(grid,String(p.get("position","")),55,UI.CYAN); UI.cell(grid,"%d%%"%int(p.get("fitness",0)),70,UI.GREEN if int(p.get("fitness",0))>=80 else UI.AMBER); UI.cell(grid,str(p.get("fatigue",0)),65,UI.AMBER); UI.cell(grid,"%d d"%int(p.get("injured_days",0)) if int(p.get("injured_days",0))>0 else "—",70,UI.RED); UI.cell(grid,"HIGH" if r>70 else ("MED" if r>45 else "LOW"),65,UI.RED if r>70 else (UI.AMBER if r>45 else UI.GREEN))

func _build_competitions(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_extended"): return
	var root := _replace_page(page); if root == null: return
	_header(root,"COMPETITIONS","League position • fixtures • objectives",tabs,session)
	var comps: Array = []
	for c in session.world.get("competitions",[]):
		if session.managed_club_id in c.get("club_ids",[]): comps.append(c)
	var cards := GridContainer.new(); cards.columns = 2 if not OS.has_feature("mobile") else 1; cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL; root.add_child(cards)
	for c in comps:
		var p := UI.panel(cards,Vector2(380,190),UI.CYAN); UI.section(p,String(c.get("name","Competition"))); UI.body(p,String(c.get("competition_type","league")).capitalize(),true)
		var played:=0; var wins:=0
		for f in session.world.get("fixtures",[]):
			if String(f.get("competition_id",""))!=String(c.get("id","")) or not bool(f.get("played",false)): continue
			if String(f.get("home_club_id",""))==session.managed_club_id or String(f.get("away_club_id",""))==session.managed_club_id:
				played+=1; var home:=String(f.get("home_club_id",""))==session.managed_club_id; var gf:=int(f.get("home_goals",0)) if home else int(f.get("away_goals",0)); var ga:=int(f.get("away_goals",0)) if home else int(f.get("home_goals",0)); if gf>ga: wins+=1
		UI.metric(p,"Record","%d played"%played,"%d wins"%wins,UI.GREEN)

func _build_schedule(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_extended"): return
	var root := _replace_page(page); if root == null: return
	_header(root,"SCHEDULE","Upcoming matches • recent results",tabs,session)
	var panel := UI.panel(root,Vector2(0,500),UI.CYAN); UI.section(panel,"FIXTURE LIST")
	var grid := GridContainer.new(); grid.columns=6; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; panel.add_child(grid); UI.table_header(grid,["DATE","VENUE","OPPONENT","COMPETITION","RESULT","STATUS"])
	var fixtures:Array=[]
	for f in session.world.get("fixtures",[]):
		if String(f.get("home_club_id",""))==session.managed_club_id or String(f.get("away_club_id",""))==session.managed_club_id: fixtures.append(f)
	fixtures.sort_custom(func(a:Dictionary,b:Dictionary): return String(a.get("date","")) < String(b.get("date","")))
	for f in fixtures.slice(maxi(0,fixtures.size()-8),mini(fixtures.size(),maxi(0,fixtures.size()-8)+20)):
		var home:=String(f.get("home_club_id",""))==session.managed_club_id; var opp:=String(f.get("away_club_id","")) if home else String(f.get("home_club_id","")); var played:=bool(f.get("played",false)); var result:="—"
		if played: result="%d-%d"%[int(f.get("home_goals",0)),int(f.get("away_goals",0))]
		UI.cell(grid,String(f.get("date","TBD")),90); UI.cell(grid,"H" if home else "A",45,UI.CYAN); UI.cell(grid,_club_name(session.world,opp).left(20),160); UI.cell(grid,_competition_name(session.world,String(f.get("competition_id",""))).left(18),150,UI.PURPLE); UI.cell(grid,result,70,UI.GREEN if played else UI.MUTED); UI.cell(grid,"FT" if played else "UPCOMING",90,UI.GREEN if played else UI.CYAN)

func _header(root: VBoxContainer, title:String, subtitle:String, tabs:TabContainer, session) -> void:
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",12); root.add_child(row)
	var names:=VBoxContainer.new(); names.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(names)
	var h:=Label.new(); h.text=title; h.add_theme_font_size_override("font_size",24); h.add_theme_color_override("font_color",UI.TEXT); names.add_child(h)
	UI.body(names,subtitle,true)
	var date:=UI.chip(String(session.world.get("current_date", session.world.get("date",""))),UI.CYAN); row.add_child(date)

func _replace_page(page: Control) -> VBoxContainer:
	if page.has_meta("ui2_extended"): return null
	page.set_meta("ui2_extended",true)
	for child in page.get_children(): page.remove_child(child); child.queue_free()
	var scroll:=ScrollContainer.new(); scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; page.add_child(scroll)
	var margin:=MarginContainer.new(); margin.add_theme_constant_override("margin_left",14); margin.add_theme_constant_override("margin_top",10); margin.add_theme_constant_override("margin_right",14); margin.add_theme_constant_override("margin_bottom",14); scroll.add_child(margin)
	var root:=VBoxContainer.new(); root.custom_minimum_size=Vector2(860,0); root.size_flags_horizontal=Control.SIZE_EXPAND_FILL; root.add_theme_constant_override("separation",12); margin.add_child(root); return root
func _page(tabs:TabContainer,name:String)->Control:
	for i in range(tabs.get_tab_count()):
		var p:=tabs.get_tab_control(i); if String(p.name)==name or tabs.get_tab_title(i)==name: return p
	return null
func _career_session(node:Node):
	var current:Node=node
	while current!=null:
		var script=current.get_script(); if script!=null and String(script.resource_path).ends_with("game/career/career_app.gd"): return current.get("session")
		current=current.get_parent()
	return null
func _club(world:Dictionary,id:String)->Dictionary:
	for c in world.get("clubs",[]): if String(c.get("id",""))==id: return c
	return {}
func _club_name(world:Dictionary,id:String)->String:
	var c:=_club(world,id); return String(c.get("name",id))
func _competition_name(world:Dictionary,id:String)->String:
	for c in world.get("competitions",[]): if String(c.get("id",""))==id: return String(c.get("name",id))
	return id
func _squad(world:Dictionary,club_id:String)->Array:
	var rows:Array=[]
	for p in world.get("players",[]): if String(p.get("club_id",""))==club_id and not bool(p.get("retired",false)): rows.append(p)
	return rows
func _player(world:Dictionary,id:String)->Dictionary:
	for p in world.get("players",[]): if String(p.get("id",""))==id: return p
	return {}
func _player_name(p:Dictionary)->String:
	var n:=String(p.get("name","")).strip_edges(); return n if n!="" else (String(p.get("first_name",""))+" "+String(p.get("last_name",""))).strip_edges()
func _shortlist(world:Dictionary,club_id:String,limit:int)->Array:
	var rows:Array=[]
	for p in world.get("players",[]):
		if String(p.get("club_id",""))==club_id or bool(p.get("retired",false)): continue
		rows.append(p)
	rows.sort_custom(func(a:Dictionary,b:Dictionary): return int(a.get("potential",0))+int(a.get("current_ability",0)) > int(b.get("potential",0))+int(b.get("current_ability",0)))
	return rows.slice(0,mini(limit,rows.size()))
func _value(p:Dictionary)->int:
	var ca:=int(p.get("current_ability",50)); var pa:=int(p.get("potential",ca)); var age:=int(p.get("age",25)); var factor:=1.25 if age<=23 else (1.0 if age<=28 else maxf(.35,1.0-float(age-28)*.09)); return int((ca*ca*900+maxi(0,pa-ca)*ca*450)*factor)
func _risk(p:Dictionary)->int: return (100-int(p.get("fitness",100)))+int(p.get("fatigue",0))+(40 if int(p.get("injured_days",0))>0 else 0)
func _sum(values:Array)->float:
	var total:=0.0
	for v in values: total+=float(v)
	return total
