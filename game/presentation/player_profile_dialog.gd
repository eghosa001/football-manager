class_name PlayerProfileDialog
extends AcceptDialog

const UI = preload("res://game/presentation/fd_ui2.gd")
const PlayerStats = preload("res://application/career/player_stats_service.gd")
const Medical = preload("res://simulation/players/medical_system.gd")

var world: Dictionary
var player_id: String
var managed_club_id: String

func setup(career_world: Dictionary, id: String, club_id: String) -> void:
	world = career_world
	player_id = id
	managed_club_id = club_id
	var player := _player()
	title = _name(player)
	min_size = Vector2i(980, 700)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(940, 610)
	add_child(tabs)
	_add_overview(tabs, player)
	_add_attributes(tabs, player)
	_add_performance(tabs, player)
	_add_development(tabs, player)
	_add_contract(tabs, player)
	_add_medical(tabs, player)
	_add_history(tabs, player)
	_add_relationships(tabs, player)
	_add_reports(tabs, player)

func _add_overview(tabs: TabContainer, player: Dictionary) -> void:
	var box := _tab(tabs, "Overview")
	var hero := HBoxContainer.new(); hero.add_theme_constant_override("separation", 14); box.add_child(hero)
	var identity := UI.panel(hero, Vector2(350, 220), UI.CYAN)
	var name := Label.new(); name.text = _name(player); name.add_theme_font_size_override("font_size", 28); name.add_theme_color_override("font_color", UI.TEXT); identity.add_child(name)
	identity.add_child(UI.chip(String(player.get("position", "—")), UI.CYAN))
	UI.body(identity, "Age %d • %s • %s foot" % [int(player.get("age",0)), String(player.get("country_id",player.get("nationality_id","—"))).to_upper(), String(player.get("preferred_foot","—")).capitalize()], true)
	UI.metric(identity, "Market value", UI.money(_estimated_value(player)), "Weekly wage %s" % UI.money(_weekly_wage()), UI.GREEN)
	var ratings := UI.panel(hero, Vector2(260, 220), UI.PURPLE)
	UI.section(ratings, "PLAYER LEVEL", UI.PURPLE)
	UI.metric(ratings, "Current ability", UI.stars(int(player.get("current_ability",0))), str(player.get("current_ability",0)), UI.AMBER)
	UI.metric(ratings, "Potential", UI.stars(int(player.get("potential",0))), str(player.get("potential",0)), UI.AMBER)
	UI.metric(ratings, "Reputation", str(player.get("reputation",0)), "standing in the game", UI.PURPLE)
	var readiness := UI.panel(hero, Vector2(260,220), UI.GREEN)
	UI.section(readiness, "READINESS", UI.GREEN)
	_ready_metric(readiness, "Condition", int(player.get("fitness",0)))
	_ready_metric(readiness, "Sharpness", int(player.get("match_sharpness",0)))
	_ready_metric(readiness, "Morale", int(player.get("morale",0)))
	var traits: Array = player.get("traits", [])
	var traits_box := UI.panel(box, Vector2(0, 120), UI.CYAN); UI.section(traits_box, "PLAYER TRAITS")
	if traits.is_empty(): UI.body(traits_box, "No notable player traits recorded.", true)
	else:
		var flow := HFlowContainer.new(); traits_box.add_child(flow)
		for trait in traits: flow.add_child(UI.chip(String(trait).replace("_"," ").capitalize(), UI.CYAN))

func _ready_metric(parent: Control, label: String, value: int) -> void:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",8); parent.add_child(row)
	var text := Label.new(); text.text = label; text.custom_minimum_size.x=85; text.add_theme_color_override("font_color",UI.MUTED); row.add_child(text)
	UI.progress(row,float(value),UI.score_color(value),120)
	var number := Label.new(); number.text=str(value); number.add_theme_color_override("font_color",UI.score_color(value)); row.add_child(number)

func _add_attributes(tabs: TabContainer, player: Dictionary) -> void:
	var box := _tab(tabs, "Attributes")
	var attrs: Dictionary = player.get("attributes", {})
	var keys: Array = attrs.keys(); keys.sort()
	var columns := HBoxContainer.new(); columns.add_theme_constant_override("separation",12); box.add_child(columns)
	for c in range(3):
		var pane := UI.panel(columns, Vector2(275, 500), [UI.CYAN,UI.GREEN,UI.PURPLE][c]); UI.section(pane,["TECHNICAL","MENTAL","PHYSICAL"][c],[UI.CYAN,UI.GREEN,UI.PURPLE][c])
		var start := int(ceil(float(keys.size())/3.0))*c; var finish := mini(keys.size(), int(ceil(float(keys.size())/3.0))*(c+1))
		for i in range(start,finish):
			var key = keys[i]; var row := HBoxContainer.new(); pane.add_child(row)
			var l := UI.body(row,String(key).replace("_"," ").capitalize()); l.custom_minimum_size.x=145
			var v := int(attrs[key]); UI.progress(row,float(v)*5.0,UI.score_color(float(v)*5.0),80)
			var n := UI.body(row,str(v)); n.add_theme_color_override("font_color",UI.score_color(float(v)*5.0))

func _add_performance(tabs: TabContainer, player: Dictionary) -> void:
	var box := _tab(tabs, "Performance")
	var totals := PlayerStats.new().season_totals(world, player_id)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation",12); box.add_child(top)
	for item in [["APPEARANCES",int(totals.appearances),UI.CYAN],["GOALS",int(totals.goals),UI.GREEN],["SHOTS",int(totals.shots),UI.PURPLE],["xG",float(totals.xg),UI.AMBER]]:
		var p := UI.panel(top,Vector2(190,105),item[2]); UI.metric(p,item[0],"%.2f"%item[1] if item[0]=="xG" else str(item[1]),"this season",item[2])
	var passing := UI.panel(box,Vector2(0,100),UI.CYAN); UI.section(passing,"EFFICIENCY"); UI.body(passing,"Passing %d/%d • Dribbles %d/%d"%[int(totals.passes_completed),int(totals.passes),int(totals.dribbles_completed),int(totals.dribbles)])
	var panel := UI.panel(box,Vector2(0,300),UI.PURPLE); UI.section(panel,"RECENT MATCHES",UI.PURPLE)
	var grid := GridContainer.new(); grid.columns=5; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; panel.add_child(grid); UI.table_header(grid,["MATCH","GOALS","SHOTS","xG","PASSES"])
	var rows:Array=[]
	for row in world.get("player_match_stats",[]): if String(row.get("player_id",""))==player_id: rows.append(row)
	for row in rows.slice(maxi(0,rows.size()-10)):
		UI.cell(grid,String(row.get("fixture_id","Match")).left(22),170); UI.cell(grid,str(row.get("goals",0)),55,UI.GREEN); UI.cell(grid,str(row.get("shots",0)),55); UI.cell(grid,"%.2f"%float(row.get("xg",0.0)),60,UI.AMBER); UI.cell(grid,"%d/%d"%[int(row.get("passes_completed",0)),int(row.get("passes",0))],85,UI.CYAN)

func _add_development(tabs: TabContainer, player: Dictionary) -> void:
	var box := _tab(tabs, "Development")
	var plan := UI.panel(box,Vector2(0,125),UI.PURPLE); UI.section(plan,"CURRENT DEVELOPMENT PLAN",UI.PURPLE); UI.metric(plan,"Training focus",String(player.get("training_focus","balanced")).capitalize(),"individual programme",UI.PURPLE)
	var history: Array = player.get("development_history", []); var panel := UI.panel(box,Vector2(0,330),UI.CYAN); UI.section(panel,"DEVELOPMENT HISTORY")
	if history.is_empty(): UI.body(panel,"No annual development record yet.",true)
	for row in history.slice(maxi(0,history.size()-12)):
		var line:=HBoxContainer.new(); panel.add_child(line); var season:=UI.body(line,String(row.get("season_year",""))); season.custom_minimum_size.x=100; var delta:=int(row.get("delta",0)); line.add_child(UI.chip("CA %d → %d"%[int(row.get("before",0)),int(row.get("after",0))],UI.GREEN if delta>=0 else UI.RED)); line.add_child(UI.chip("%+d"%delta,UI.GREEN if delta>=0 else UI.RED)); UI.body(line,"%d apps"%int(row.get("appearances",0)),true)

func _add_contract(tabs: TabContainer, _player_data: Dictionary) -> void:
	var box := _tab(tabs, "Contract")
	var contract := _contract()
	if contract.is_empty(): UI.body(box,"No active contract.",true); return
	var top:=HBoxContainer.new(); top.add_theme_constant_override("separation",12); box.add_child(top)
	var club:=UI.panel(top,Vector2(280,150),UI.CYAN); UI.metric(club,"Club",_club_name(String(contract.get("club_id",""))),"Current employer",UI.CYAN)
	var wage:=UI.panel(top,Vector2(280,150),UI.GREEN); UI.metric(wage,"Weekly wage",UI.money(int(contract.get("weekly_wage",0))),"contract value",UI.GREEN)
	var expiry:=UI.panel(top,Vector2(280,150),UI.PURPLE); UI.metric(expiry,"Contract end",str(contract.get("end_year","—")),"started %s"%str(contract.get("start_year","—")),UI.PURPLE)
	var terms:=UI.panel(box,Vector2(0,260),UI.AMBER); UI.section(terms,"BONUSES & CLAUSES",UI.AMBER)
	for key in ["signing_bonus","release_clause","appearance_fee","goal_bonus"]:
		if contract.has(key): UI.metric(terms,key.replace("_"," ").capitalize(),UI.money(int(contract[key])),"",UI.AMBER)

func _add_medical(tabs: TabContainer, player: Dictionary) -> void:
	var box := _tab(tabs, "Medical")
	var report: Dictionary = Medical.new().report(player)
	var top:=GridContainer.new(); top.columns=3; top.size_flags_horizontal=Control.SIZE_EXPAND_FILL; box.add_child(top)
	for key in report.keys():
		var p:=UI.panel(top,Vector2(250,110),UI.RED); UI.metric(p,String(key).replace("_"," ").capitalize(),str(report[key]),"medical report",UI.RED)
	var history:Array=player.get("injury_history",[]); var panel:=UI.panel(box,Vector2(0,250),UI.RED); UI.section(panel,"INJURY HISTORY",UI.RED)
	if history.is_empty(): UI.body(panel,"No recorded injuries.",true)
	for injury in history:
		UI.body(panel,"%s • %d days • %s"%[String(injury.get("season_year",injury.get("date",""))),int(injury.get("days",0)),String(injury.get("source","injury")).capitalize()])

func _add_history(tabs: TabContainer, player: Dictionary) -> void:
	var box := _tab(tabs, "History")
	var metric:=UI.panel(box,Vector2(0,100),UI.CYAN); UI.metric(metric,"Career appearances",str(player.get("career_appearances",0)),"senior career",UI.CYAN)
	var panel:=UI.panel(box,Vector2(0,360),UI.PURPLE); UI.section(panel,"CAREER RECORD",UI.PURPLE)
	for row in world.get("player_history", []):
		if String(row.get("player_id","")) != player_id: continue
		UI.body(panel,"%s • %s • %s • %d apps • %d goals • %.2f xG"%[String(row.get("season_year","")),_club_name(String(row.get("club_id",""))),_competition_name(String(row.get("competition_id",""))),int(row.get("appearances",0)),int(row.get("goals",0)),float(row.get("xg",0.0))])

func _add_relationships(tabs: TabContainer, _player_data: Dictionary) -> void:
	var box := _tab(tabs, "Relationships"); var panel:=UI.panel(box,Vector2(0,420),UI.CYAN); UI.section(panel,"RELATIONSHIPS")
	var count:=0
	for rel in world.get("relationships",[]):
		var source:=String(rel.get("source_person_id",rel.get("source_id",""))); var target:=String(rel.get("target_person_id",rel.get("target_id","")))
		if source!=player_id and target!=player_id: continue
		var other:=target if source==player_id else source; var row:=HBoxContainer.new(); panel.add_child(row); var n:=UI.body(row,_person_name(other)); n.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(UI.chip(String(rel.get("relationship_type",rel.get("type","relationship"))).replace("_"," ").capitalize(),UI.PURPLE)); row.add_child(UI.chip(str(rel.get("strength",0)),UI.CYAN)); count+=1
	if count==0: UI.body(panel,"No notable relationships recorded.",true)

func _add_reports(tabs: TabContainer, player: Dictionary) -> void:
	var box := _tab(tabs, "Reports"); var panel:=UI.panel(box,Vector2(0,430),UI.GREEN); UI.section(panel,"SCOUT REPORT",UI.GREEN)
	var knowledge:Dictionary=world.get("scouting_knowledge",{}).get(managed_club_id,{}); var report=knowledge.get(player_id,{})
	if typeof(report)==TYPE_DICTIONARY and not report.is_empty():
		for key in report.keys(): UI.metric(panel,String(key).replace("_"," ").capitalize(),str(report[key]),"",UI.GREEN)
	else: UI.body(panel,"No current scouting report from your club.",true)
	var hidden:Dictionary=player.get("hidden_attributes",{}); var descriptions:Array[String]=[]
	if int(hidden.get("professionalism",50))>=75: descriptions.append("Highly professional")
	if int(hidden.get("consistency",50))>=75: descriptions.append("Consistent performer")
	if int(hidden.get("important_matches",50))>=75: descriptions.append("Enjoys important matches")
	if int(hidden.get("injury_proneness",50))>=70: descriptions.append("May be susceptible to injuries")
	if int(hidden.get("adaptability",50))<=30: descriptions.append("May need time to adapt")
	for text in descriptions: panel.add_child(UI.chip(text,UI.AMBER))

func _tab(tabs: TabContainer, name: String) -> VBoxContainer:
	var scroll:=ScrollContainer.new(); scroll.name=name; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var margin:=MarginContainer.new(); margin.add_theme_constant_override("margin_left",12); margin.add_theme_constant_override("margin_top",10); margin.add_theme_constant_override("margin_right",12); margin.add_theme_constant_override("margin_bottom",12); scroll.add_child(margin)
	var box:=VBoxContainer.new(); box.custom_minimum_size=Vector2(880,520); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation",12); margin.add_child(box); tabs.add_child(scroll); tabs.set_tab_title(tabs.get_tab_count()-1,name); return box
func _player()->Dictionary:
	for player in world.get("players",[]): if String(player.get("id",""))==player_id: return player
	return {}
func _contract()->Dictionary:
	for contract in world.get("contracts",[]): if String(contract.get("player_id",""))==player_id and not bool(contract.get("expired",false)): return contract
	return {}
func _weekly_wage()->int: return int(_contract().get("weekly_wage",0))
func _club_name(id:String)->String:
	for club in world.get("clubs",[]): if String(club.get("id",""))==id: return String(club.get("name",id))
	return id
func _competition_name(id:String)->String:
	for competition in world.get("competitions",[]): if String(competition.get("id",""))==id: return String(competition.get("name",id))
	return id
func _person_name(id:String)->String:
	for p in world.get("players",[]): if String(p.get("id",""))==id: return _name(p)
	for s in world.get("staff",[]): if String(s.get("id",""))==id: return String(s.get("name",id))
	return id
func _name(player:Dictionary)->String:
	var name:=String(player.get("name","")).strip_edges(); return name if name!="" else (String(player.get("first_name",""))+" "+String(player.get("last_name",""))).strip_edges()
func _estimated_value(player:Dictionary)->int:
	var ability:=int(player.get("current_ability",50)); var potential:=int(player.get("potential",ability)); var age:=int(player.get("age",25)); var age_factor:=1.25 if age<=23 else (1.0 if age<=28 else maxf(0.35,1.0-float(age-28)*0.09)); return int((ability*ability*900+maxi(0,potential-ability)*ability*450)*age_factor)
