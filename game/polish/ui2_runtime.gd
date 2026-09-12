extends Node

const UI = preload("res://game/presentation/fd_ui2.gd")
const LeagueTable = preload("res://simulation/competitions/league_table.gd")
const TacticsManager = preload("res://simulation/tactics/tactics_manager.gd")
const CareerCommand = preload("res://application/career/career_command_service.gd")
const PlayerProfileDialog = preload("res://game/presentation/player_profile_dialog.gd")

var _next_scan := 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan:
		return
	_next_scan = now + 700
	_scan()

func _scan() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is TabContainer:
		_upgrade_tabs(node as TabContainer)
	for child in node.get_children():
		_scan_node(child)

func _upgrade_tabs(tabs: TabContainer) -> void:
	if _tab_index(tabs, "Dashboard") < 0 or _tab_index(tabs, "Squad") < 0 or _tab_index(tabs, "Tactics") < 0:
		return
	var session = _career_session(tabs)
	if session == null or session.world.is_empty():
		return
	# Stop legacy enhancement runtimes from layering old widgets over UI2.
	tabs.set_meta("dashboard_complete", true)
	tabs.set_meta("advanced_squad_tools", true)
	tabs.set_meta("tactics_board_added", true)
	tabs.set_meta("ui2_active", true)
	_enhance_shell(tabs, session)
	_build_home(_page(tabs, "Dashboard"), tabs, session)
	_build_squad(_page(tabs, "Squad"), tabs, session)
	_build_tactics(_page(tabs, "Tactics"), tabs, session)

func _enhance_shell(tabs: TabContainer, session) -> void:
	var shell := tabs.get_parent()
	if shell == null or shell.has_meta("ui2_shell_enhanced"):
		return
	var sidebar := shell.get_node_or_null("CareerSidebar")
	if sidebar == null:
		return
	shell.set_meta("ui2_shell_enhanced", true)
	if sidebar is Control:
		(sidebar as Control).custom_minimum_size.x = 184
	var identity := sidebar.get_node_or_null("DynastyIdentity")
	if identity != null:
		var club := _club(session.world, session.managed_club_id)
		var crest := Label.new()
		crest.text = "◆"
		crest.add_theme_font_size_override("font_size", 32)
		crest.add_theme_color_override("font_color", UI.CYAN)
		identity.add_child(crest)
		identity.move_child(crest, 0)
		var club_label := Label.new()
		club_label.text = String(club.get("name", "Club"))
		club_label.add_theme_font_size_override("font_size", 12)
		club_label.add_theme_color_override("font_color", UI.MUTED)
		identity.add_child(club_label)
	for child in sidebar.get_children():
		if child is Button:
			var button := child as Button
			button.custom_minimum_size.y = 38
			button.add_theme_font_size_override("font_size", 13)

func _build_home(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_screen"):
		return
	var root := _replace_page(page, "Dashboard")
	if root == null:
		return
	var world: Dictionary = session.world
	var club := _club(world, session.managed_club_id)
	_screen_header(root, "HOME", "%s • Season %s" % [String(club.get("name", "Club")), str(world.get("season_year", ""))], tabs, session)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.custom_minimum_size.y = 225
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(top)
	var hero := UI.panel(top, Vector2(0, 220), UI.CYAN)
	(hero.get_parent() as Control).size_flags_stretch_ratio = 2.1
	UI.section(hero, "NEXT MATCH")
	var fixture := _next_fixture(world, session.managed_club_id)
	if fixture.is_empty():
		UI.metric(hero, "Schedule", "No fixture", "Advance the calendar to the next round", UI.AMBER)
	else:
		var home_name := _club_name(world, String(fixture.get("home_club_id", "")))
		var away_name := _club_name(world, String(fixture.get("away_club_id", "")))
		var versus := Label.new()
		versus.text = "%s  v  %s" % [home_name, away_name]
		versus.add_theme_font_size_override("font_size", 26)
		versus.add_theme_color_override("font_color", UI.TEXT)
		versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hero.add_child(versus)
		var meta := HBoxContainer.new(); meta.alignment = BoxContainer.ALIGNMENT_CENTER; hero.add_child(meta)
		meta.add_child(UI.chip(String(fixture.get("date", "TBD")), UI.CYAN))
		meta.add_child(UI.chip(_competition_name(world, String(fixture.get("competition_id", ""))), UI.PURPLE))
		meta.add_child(UI.chip("HOME" if String(fixture.get("home_club_id", "")) == session.managed_club_id else "AWAY", UI.GREEN))
		UI.body(hero, "Prepare the squad, review availability and confirm your tactical plan before continuing.", true)
	var continue_button := UI.action("CONTINUE  ›", UI.CYAN)
	continue_button.custom_minimum_size = Vector2(180, 46)
	continue_button.pressed.connect(func(): _career_app(tabs).call("_advance_day"))
	hero.add_child(continue_button)

	var news := UI.panel(top, Vector2(300, 220), UI.PURPLE)
	(news.get_parent() as Control).size_flags_stretch_ratio = 1.0
	UI.section(news, "CLUB STATUS", UI.PURPLE)
	var unread := _unread(world)
	UI.metric(news, "Inbox", "%d unread" % unread, "Manager messages requiring attention", UI.AMBER if unread > 0 else UI.GREEN)
	UI.divider(news)
	var squad := _squad(world, session.managed_club_id)
	var unavailable := 0
	var morale := 0.0
	for player in squad:
		morale += float(player.get("morale", 50))
		if int(player.get("injured_days", 0)) > 0: unavailable += 1
	UI.metric(news, "Squad", "%d players" % squad.size(), "%d unavailable • %.0f avg morale" % [unavailable, morale / maxf(1.0, squad.size())], UI.GREEN if unavailable < 4 else UI.RED)

	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 12)
	lower.custom_minimum_size.y = 315
	root.add_child(lower)
	_build_league_widget(lower, world, session.managed_club_id)
	_build_preparation_widget(lower, tabs, world, session.managed_club_id)
	_build_medical_widget(lower, world, session.managed_club_id)
	_build_finance_widget(lower, club)

func _build_league_widget(parent: HBoxContainer, world: Dictionary, club_id: String) -> void:
	var box := UI.panel(parent, Vector2(270, 300), UI.CYAN)
	UI.section(box, "LEAGUE TABLE")
	var competition := _league_for_club(world, club_id)
	if competition.is_empty():
		UI.body(box, "League table unavailable", true)
		return
	var rows := _league_table(world, competition)
	var grid := GridContainer.new(); grid.columns = 4; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_child(grid)
	UI.table_header(grid, ["POS", "CLUB", "P", "PTS"])
	for i in range(mini(9, rows.size())):
		var row: Dictionary = rows[i]
		var accent := UI.CYAN if String(row.get("club_id", "")) == club_id else UI.TEXT
		UI.cell(grid, str(i + 1), 28, accent)
		UI.cell(grid, _club_name(world, String(row.get("club_id", ""))).left(18), 110, accent)
		UI.cell(grid, str(row.get("played", 0)), 30, accent, HORIZONTAL_ALIGNMENT_CENTER)
		UI.cell(grid, str(row.get("points", 0)), 34, accent, HORIZONTAL_ALIGNMENT_CENTER)

func _build_preparation_widget(parent: HBoxContainer, tabs: TabContainer, world: Dictionary, club_id: String) -> void:
	var box := UI.panel(parent, Vector2(250, 300), UI.GREEN)
	UI.section(box, "MATCH PREPARATION", UI.GREEN)
	var club := _club(world, club_id)
	var tactic: Dictionary = club.get("tactic", {})
	UI.metric(box, "Formation", String(tactic.get("formation", "4-3-3")), String(tactic.get("mentality", "balanced")).capitalize(), UI.GREEN)
	UI.body(box, "Tempo: %s" % String(tactic.get("tempo", "standard")).capitalize(), true)
	UI.body(box, "Pressing: %s" % String(tactic.get("pressing", "standard")).capitalize(), true)
	var button := UI.action("OPEN TACTICS", UI.GREEN)
	button.pressed.connect(func(): _open_tab(tabs, "Tactics"))
	box.add_child(button)

func _build_medical_widget(parent: HBoxContainer, world: Dictionary, club_id: String) -> void:
	var box := UI.panel(parent, Vector2(250, 300), UI.RED)
	UI.section(box, "MEDICAL CENTRE", UI.RED)
	var squad := _squad(world, club_id)
	var risks: Array = []
	for player in squad:
		var risk := 100 - int(player.get("fitness", 100)) + int(player.get("fatigue", 0))
		if int(player.get("injured_days", 0)) > 0: risk += 40
		risks.append({"name":_player_name(player), "risk":risk, "injured":int(player.get("injured_days", 0))})
	risks.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.risk) > int(b.risk))
	for item in risks.slice(0, mini(5, risks.size())):
		var row := HBoxContainer.new(); box.add_child(row)
		var name := UI.body(row, String(item.name).left(18)); name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var status := "INJ" if int(item.injured) > 0 else ("HIGH" if int(item.risk) > 55 else "OK")
		row.add_child(UI.chip(status, UI.RED if status != "OK" else UI.GREEN))

func _build_finance_widget(parent: HBoxContainer, club: Dictionary) -> void:
	var box := UI.panel(parent, Vector2(240, 300), UI.PURPLE)
	UI.section(box, "FINANCES", UI.PURPLE)
	UI.metric(box, "Balance", UI.money(int(club.get("cash", 0))), "Available cash", UI.PURPLE)
	UI.divider(box)
	UI.metric(box, "Transfer budget", UI.money(int(club.get("transfer_budget", 0))), "Recruitment capacity", UI.CYAN)
	UI.metric(box, "Wage budget", UI.money(int(club.get("wage_budget", 0))), "Weekly payroll ceiling", UI.GREEN)

func _build_squad(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_screen"):
		return
	var root := _replace_page(page, "Squad")
	if root == null: return
	_screen_header(root, "SQUAD", "First-team players • availability • ability • contracts", tabs, session)
	var controls := HBoxContainer.new(); controls.add_theme_constant_override("separation", 8); root.add_child(controls)
	var search := LineEdit.new(); search.placeholder_text = "Search player"; search.custom_minimum_size.x = 240; controls.add_child(search)
	var position := OptionButton.new();
	for p in ["ALL","GK","DL","DC","DR","DM","MC","AML","AMC","AMR","ST"]: position.add_item(p)
	controls.add_child(position)
	var quick := UI.action("QUICK PICK", UI.CYAN); controls.add_child(quick)
	var table_panel := UI.panel(root, Vector2(0, 470), UI.CYAN)
	var summary := HBoxContainer.new(); table_panel.add_child(summary)
	UI.section(summary, "PLAYERS")
	var count_label := UI.body(summary, "", true); count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var table := GridContainer.new(); table.columns = 11; table.size_flags_horizontal = Control.SIZE_EXPAND_FILL; table_panel.add_child(table)
	var render := func():
		for child in table.get_children(): child.queue_free()
		UI.table_header(table, ["NAME","POS","AGE","STATUS","FIT","MOR","ABILITY","POT","WAGE","VALUE","CONTRACT"])
		var rows := _squad(session.world, session.managed_club_id)
		rows.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("current_ability",0)) > int(b.get("current_ability",0)))
		var shown := 0
		var filter := position.get_item_text(position.selected)
		for player in rows:
			if filter != "ALL" and String(player.get("position", "")) != filter: continue
			if search.text.strip_edges() != "" and not _player_name(player).to_lower().contains(search.text.strip_edges().to_lower()): continue
			shown += 1
			var name_button := Button.new(); name_button.text = _player_name(player); name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT; name_button.flat = true; name_button.custom_minimum_size = Vector2(150,34); name_button.pressed.connect(_open_player.bind(session.world, String(player.get("id","")), session.managed_club_id, tabs)); table.add_child(name_button)
			UI.cell(table, String(player.get("position","-")), 45, UI.CYAN)
			UI.cell(table, str(player.get("age",0)), 34)
			var status := "INJ" if int(player.get("injured_days",0)) > 0 else ("LOW" if int(player.get("fitness",100)) < 70 else "OK")
			var chip := UI.chip(status, UI.RED if status == "INJ" else (UI.AMBER if status == "LOW" else UI.GREEN)); chip.custom_minimum_size.x = 48; table.add_child(chip)
			UI.cell(table, "%d" % int(player.get("fitness",0)), 42, UI.score_color(float(player.get("fitness",0))))
			UI.cell(table, "%d" % int(player.get("morale",0)), 42, UI.score_color(float(player.get("morale",0))))
			UI.cell(table, _stars(int(player.get("current_ability",0))), 82, UI.AMBER)
			UI.cell(table, _stars(int(player.get("potential",0))), 82, UI.AMBER)
			UI.cell(table, UI.money(_weekly_wage(session.world, String(player.get("id","")))), 76, UI.MUTED)
			UI.cell(table, UI.money(_estimated_value(player)), 80)
			UI.cell(table, _contract_end(session.world, String(player.get("id",""))), 60, UI.MUTED)
		count_label.text = "%d players" % shown
	search.text_changed.connect(func(_v): render.call())
	position.item_selected.connect(func(_i): render.call())
	quick.pressed.connect(func(): search.text = ""; position.select(0); render.call())
	render.call()

func _build_tactics(page: Control, tabs: TabContainer, session) -> void:
	if page == null or page.has_meta("ui2_screen"):
		return
	var root := _replace_page(page, "Tactics")
	if root == null: return
	_screen_header(root, "TACTICS", "Shape • roles • duties • selection", tabs, session)
	var club := _club(session.world, session.managed_club_id)
	var tactic: Dictionary = club.get("tactic", TacticsManager.new().create_tactic("4-3-3"))
	club["tactic"] = tactic
	var toolbar := HBoxContainer.new(); toolbar.add_theme_constant_override("separation",8); root.add_child(toolbar)
	var formation := OptionButton.new();
	var formations: Array = TacticsManager.FORMATIONS.keys(); formations.sort()
	for value in formations: formation.add_item(String(value))
	formation.select(maxi(0, formations.find(String(tactic.get("formation","4-3-3")))))
	toolbar.add_child(formation)
	var mentality := OptionButton.new();
	for value in TacticsManager.VALID_MENTALITIES: mentality.add_item(String(value).capitalize())
	mentality.select(maxi(0, TacticsManager.VALID_MENTALITIES.find(String(tactic.get("mentality","balanced")))))
	toolbar.add_child(mentality)
	var tempo := OptionButton.new();
	for value in TacticsManager.VALID_TEMPOS: tempo.add_item(String(value).capitalize())
	tempo.select(maxi(0, TacticsManager.VALID_TEMPOS.find(String(tactic.get("tempo","standard")))))
	toolbar.add_child(tempo)
	var pressing := OptionButton.new();
	for value in TacticsManager.VALID_PRESSING: pressing.add_item(String(value).capitalize())
	pressing.select(maxi(0, TacticsManager.VALID_PRESSING.find(String(tactic.get("pressing","standard")))))
	toolbar.add_child(pressing)
	var apply := UI.action("APPLY PLAN", UI.GREEN); toolbar.add_child(apply)
	var body := HBoxContainer.new(); body.add_theme_constant_override("separation",12); body.custom_minimum_size.y = 500; root.add_child(body)
	var left := UI.panel(body, Vector2(660,500), UI.GREEN); (left.get_parent() as Control).size_flags_stretch_ratio = 1.65
	UI.section(left, "FORMATION", UI.GREEN)
	var pitch := TacticalPitch.new(); pitch.custom_minimum_size = Vector2(620,360); pitch.world = session.world; pitch.tactic = tactic; left.add_child(pitch)
	var summary := HBoxContainer.new(); left.add_child(summary)
	UI.metric(summary, "Familiarity", "%.0f%%" % float(tactic.get("familiarity",0)), "Team understanding", UI.GREEN)
	UI.metric(summary, "Mentality", String(tactic.get("mentality","balanced")).capitalize(), "Current plan", UI.CYAN)
	var right := UI.panel(body, Vector2(390,500), UI.PURPLE); (right.get_parent() as Control).size_flags_stretch_ratio = 1.0
	UI.section(right, "SQUAD SELECTION", UI.PURPLE)
	var roster := GridContainer.new(); roster.columns = 5; roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL; right.add_child(roster)
	UI.table_header(roster, ["POS","PLAYER","FIT","MOR","CA"])
	var players := _squad(session.world, session.managed_club_id)
	players.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.get("current_ability",0)) > int(b.get("current_ability",0)))
	for player in players.slice(0, mini(16, players.size())):
		UI.cell(roster, String(player.get("position","")), 42, UI.CYAN)
		UI.cell(roster, _player_name(player).left(18), 135)
		UI.cell(roster, str(player.get("fitness",0)), 38, UI.score_color(float(player.get("fitness",0))))
		UI.cell(roster, str(player.get("morale",0)), 38, UI.score_color(float(player.get("morale",0))))
		UI.cell(roster, str(player.get("current_ability",0)), 38, UI.AMBER)
	apply.pressed.connect(func():
		CareerCommand.new().set_tactic(session.world, session.managed_club_id, formation.get_item_text(formation.selected), TacticsManager.VALID_MENTALITIES[mentality.selected], TacticsManager.VALID_TEMPOS[tempo.selected], TacticsManager.VALID_PRESSING[pressing.selected])
		_career_app(tabs).call("_show_career")
	)

func _screen_header(parent: VBoxContainer, heading: String, subtitle: String, tabs: TabContainer, session) -> void:
	var bar := HBoxContainer.new(); bar.add_theme_constant_override("separation",12); bar.custom_minimum_size.y = 64; parent.add_child(bar)
	var titles := UI.title(bar, heading, subtitle); titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var snap = session.snapshot()
	var date := VBoxContainer.new(); bar.add_child(date)
	UI.body(date, String(snap.get("date", "")), false)
	UI.body(date, "Season %s" % str(snap.get("season_year", "")), true)
	var continue_button := UI.action("CONTINUE  ›", UI.CYAN); continue_button.custom_minimum_size.x = 160; continue_button.pressed.connect(func(): _career_app(tabs).call("_advance_day")); bar.add_child(continue_button)
	UI.divider(parent)

func _replace_page(page: Control, screen_name: String) -> VBoxContainer:
	if page == null: return null
	page.set_meta("ui2_screen", true)
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(margin)
	var root := VBoxContainer.new()
	root.name = "%sUI2" % screen_name
	root.add_theme_constant_override("separation", 10)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)
	return root

func _open_player(world: Dictionary, player_id: String, club_id: String, owner: Control) -> void:
	var dialog = PlayerProfileDialog.new()
	dialog.setup(world, player_id, club_id)
	owner.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(940,700))

func _stars(ability: int) -> String:
	var count := clampi(int(round(float(ability) / 20.0)), 1, 5)
	return "★".repeat(count) + "☆".repeat(5-count)

func _estimated_value(player: Dictionary) -> int:
	var ca := int(player.get("current_ability",50)); var pa := int(player.get("potential",ca)); var age := int(player.get("age",25))
	var age_factor := 1.25 if age <= 23 else (1.0 if age <= 28 else maxf(0.35,1.0-float(age-28)*0.09))
	return int((ca*ca*900 + maxi(0,pa-ca)*ca*450)*age_factor)

func _weekly_wage(world: Dictionary, player_id: String) -> int:
	for contract in world.get("contracts",[]):
		if String(contract.get("player_id","")) == player_id and not bool(contract.get("expired",false)):
			return int(contract.get("weekly_wage",0))
	return 0

func _contract_end(world: Dictionary, player_id: String) -> String:
	for contract in world.get("contracts",[]):
		if String(contract.get("player_id","")) == player_id and not bool(contract.get("expired",false)):
			return str(contract.get("end_year","-"))
	return "-"

func _league_table(world: Dictionary, competition: Dictionary) -> Array:
	var fixtures: Array = []
	for fixture in world.get("fixtures", []):
		if String(fixture.get("competition_id","")) == String(competition.get("id","")): fixtures.append(fixture)
	return LeagueTable.build(competition.get("club_ids",[]), fixtures, int(competition.get("points_win",3)), int(competition.get("points_draw",1)))

func _league_for_club(world: Dictionary, club_id: String) -> Dictionary:
	for competition in world.get("competitions", []):
		if String(competition.get("competition_type","league")) == "league" and club_id in competition.get("club_ids",[]): return competition
	return {}

func _next_fixture(world: Dictionary, club_id: String) -> Dictionary:
	var future: Array = []
	for fixture in world.get("fixtures",[]):
		if bool(fixture.get("played",false)): continue
		if String(fixture.get("home_club_id","")) == club_id or String(fixture.get("away_club_id","")) == club_id: future.append(fixture)
	future.sort_custom(func(a:Dictionary,b:Dictionary): return String(a.get("date","9999")) < String(b.get("date","9999")))
	return future[0] if not future.is_empty() else {}

func _squad(world: Dictionary, club_id: String) -> Array:
	var rows: Array = []
	for player in world.get("players",[]):
		if String(player.get("club_id","")) == club_id and not bool(player.get("retired",false)): rows.append(player)
	return rows

func _unread(world: Dictionary) -> int:
	var count := 0
	for message in world.get("inbox",[]):
		if not bool(message.get("read",false)): count += 1
	return count

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs",[]):
		if String(club.get("id","")) == club_id: return club
	return {}

func _club_name(world: Dictionary, club_id: String) -> String:
	var club := _club(world, club_id)
	return String(club.get("name",club_id))

func _competition_name(world: Dictionary, id: String) -> String:
	for competition in world.get("competitions",[]):
		if String(competition.get("id","")) == id: return String(competition.get("name",id))
	return id

func _player_name(player: Dictionary) -> String:
	var name := String(player.get("name","")).strip_edges()
	return name if name != "" else (String(player.get("first_name",""))+" "+String(player.get("last_name",""))).strip_edges()

func _page(tabs: TabContainer, name: String) -> Control:
	var index := _tab_index(tabs,name)
	return tabs.get_tab_control(index) if index >= 0 else null

func _tab_index(tabs: TabContainer, name: String) -> int:
	for i in range(tabs.get_tab_count()):
		if String(tabs.get_tab_control(i).name) == name or tabs.get_tab_title(i) == name: return i
	return -1

func _open_tab(tabs: TabContainer, name: String) -> void:
	var index := _tab_index(tabs,name)
	if index >= 0: tabs.current_tab = index

func _career_session(node: Node):
	var app = _career_app(node)
	return app.get("session") if app != null else null

func _career_app(node: Node) -> Node:
	var current: Node = node
	while current != null:
		var script = current.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"): return current
		current = current.get_parent()
	return null

class TacticalPitch:
	extends Control
	var world: Dictionary = {}
	var tactic: Dictionary = {}
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2(24,14), Vector2(maxf(300,size.x-48),maxf(260,size.y-28)))
		draw_rect(r, Color(0.03,0.34,0.18,1), true)
		for i in range(6):
			var stripe := Rect2(r.position.x + r.size.x*float(i)/6.0, r.position.y, r.size.x/6.0, r.size.y)
			draw_rect(stripe, Color(1,1,1,0.025 if i%2==0 else 0.0), true)
		draw_rect(r, Color(0.75,1,0.86,0.72), false, 2)
		draw_line(Vector2(r.position.x,r.get_center().y),Vector2(r.end.x,r.get_center().y),Color(0.75,1,0.86,0.55),2)
		draw_circle(r.get_center(), minf(r.size.x,r.size.y)*0.11, Color(0.75,1,0.86,0.55), false, 2)
		var formation := String(tactic.get("formation","4-3-3"))
		var positions: Array = TacticsManager.FORMATIONS.get(formation,TacticsManager.FORMATIONS["4-3-3"])
		var coords := _coords(positions)
		var counts := {}
		for i in range(positions.size()):
			var pos := String(positions[i]); counts[pos]=int(counts.get(pos,0))+1
			var key := pos if int(counts[pos])==1 else "%s_%d" % [pos,int(counts[pos])]
			var p := Vector2(r.position.x + coords[i].x*r.size.x, r.position.y + coords[i].y*r.size.y)
			draw_circle(p,18,Color(0.05,0.78,0.68,1))
			draw_circle(p,18,Color.WHITE,false,2)
			draw_string(ThemeDB.fallback_font,p+Vector2(-10,5),pos,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)
			var player_id := String(tactic.get("lineup_assignments",{}).get(key,""))
			if player_id != "": draw_string(ThemeDB.fallback_font,p+Vector2(-42,35),_name(player_id).left(13),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)
	func _name(id:String) -> String:
		for player in world.get("players",[]):
			if String(player.get("id","")) == id:
				var n := String(player.get("name","")).strip_edges()
				return n if n != "" else (String(player.get("first_name",""))+" "+String(player.get("last_name",""))).strip_edges()
		return id
	func _coords(positions:Array) -> Array:
		var groups := {"GK":[],"DEF":[],"MID":[],"AM":[],"ST":[]}
		for i in range(positions.size()):
			var p := String(positions[i]); var g := "MID"
			if p=="GK": g="GK"
			elif p in ["DL","DC","DR","WBL","WBR"]: g="DEF"
			elif p in ["AML","AMC","AMR"]: g="AM"
			elif p=="ST": g="ST"
			groups[g].append(i)
		var result:Array=[]; result.resize(positions.size())
		var ys := {"GK":0.90,"DEF":0.72,"MID":0.52,"AM":0.32,"ST":0.13}
		for group in groups.keys():
			var ids:Array=groups[group]
			for j in range(ids.size()): result[int(ids[j])] = Vector2(float(j+1)/float(ids.size()+1),float(ys[group]))
		return result
