class_name CareerViews
extends RefCounted

const CareerQueryClass = preload("res://application/career/career_query.gd")
const CommandClass = preload("res://application/career/career_command_service.gd")
const MatchViewerClass = preload("res://game/match_viewer.gd")
const TacticsManagerClass = preload("res://simulation/tactics/tactics_manager.gd")
const Institutions = preload("res://application/career/institution_commands.gd")

var query = CareerQueryClass.new()
var command = CommandClass.new()
var app: Control
var session

func _init(owner_app: Control = null, career_session = null) -> void:
	app = owner_app
	session = career_session

func add_dashboard(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Dashboard")
	var data: Dictionary = query.dashboard(session.world, session.managed_club_id)
	_heading(box, String(data.get("club", {}).get("name", "Club")), 22)
	_label(box, tr("Date: %s   Season: %d") % [String(data.date), int(data.season_year)])
	_label(box, tr("Squad: %d   Cash: %d   Transfer budget: %d   Wage budget: %d") % [int(data.squad_size), int(data.cash), int(data.transfer_budget), int(data.wage_budget)])
	_label(box, tr("Unread inbox: %d") % int(data.unread_messages))
	var next: Dictionary = data.get("next_fixture", {})
	if not next.is_empty(): _label(box, tr("Next fixture: %s — %s vs %s") % [String(next.get("date", "TBD")), _club_name(String(next.get("home_club_id", ""))), _club_name(String(next.get("away_club_id", "")))])
	if session.world.has("last_managed_match"):
		_button(box, tr("Open last match analysis"), func(): _focus_tab(tabs, "Match Analysis"))

func add_squad(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Squad")
	for row in query.squad(session.world, session.managed_club_id):
		var line := HBoxContainer.new(); box.add_child(line)
		var text := "%s  %-4s  Age %d  CA %d  PA %d  Fit %d  Morale %d" % [String(row.name), String(row.position), int(row.age), int(row.ability), int(row.potential), int(row.fitness), int(row.morale)]
		_button(line, text, _show_player.bind(String(row.id)))

func add_training(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Training")
	var current: Dictionary = query.training(session.world, session.managed_club_id)
	_label(box, tr("Current intensity: %.0f%%   Facilities: %d") % [float(current.intensity) * 100.0, int(current.facilities)])
	_label(box, tr("Weekly schedule: %s") % ", ".join(current.schedule))
	var row := HBoxContainer.new(); box.add_child(row)
	for preset in [{"name":"Recovery","value":0.40},{"name":"Balanced","value":0.65},{"name":"Intense","value":0.85}]:
		_button(row, String(preset.name), _set_training.bind(float(preset.value)))
	var choices: Array = []
	var sessions: Array = preload("res://simulation/players/training_system.gd").SESSIONS
	for day in range(7):
		var choice := OptionButton.new()
		for value in sessions: choice.add_item(tr(String(value).replace("_", " ").capitalize()))
		choice.select(maxi(0, sessions.find(current.schedule[day])))
		box.add_child(app.call("_labeled", tr("Day %d") % (day + 1), choice))
		choices.append(choice)
	_button(box, tr("Save weekly schedule"), func():
		var selected: Array = []
		for choice in choices: selected.append(sessions[choice.selected])
		_report_command(command.set_training(session.world, session.managed_club_id, selected, float(current.intensity)))
	)

func add_tactics(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Tactics")
	var tactic: Dictionary = query.tactics(session.world, session.managed_club_id)
	_label(box, tr("Formation: %s   Mentality: %s   Tempo: %s   Pressing: %s   Familiarity: %.0f") % [String(tactic.get("formation","")), String(tactic.get("mentality","")), String(tactic.get("tempo","")), String(tactic.get("pressing","")), float(tactic.get("familiarity",0.0))])
	var formation := OptionButton.new(); formation.name = "Formation"
	var formations: Array = TacticsManagerClass.FORMATIONS.keys(); formations.sort()
	for value in formations: formation.add_item(String(value))
	formation.select(maxi(0, formations.find(String(tactic.get("formation","4-3-3")))))
	box.add_child(formation)
	var mentality := OptionButton.new(); mentality.name = "Mentality"
	for value in TacticsManagerClass.VALID_MENTALITIES: mentality.add_item(String(value))
	mentality.select(maxi(0, TacticsManagerClass.VALID_MENTALITIES.find(String(tactic.get("mentality","balanced")))))
	box.add_child(mentality)
	var tempo := OptionButton.new(); tempo.name = "Tempo"
	for value in TacticsManagerClass.VALID_TEMPOS: tempo.add_item(String(value))
	tempo.select(maxi(0, TacticsManagerClass.VALID_TEMPOS.find(String(tactic.get("tempo","standard")))))
	box.add_child(tempo)
	var pressing := OptionButton.new(); pressing.name = "Pressing"
	for value in TacticsManagerClass.VALID_PRESSING: pressing.add_item(String(value))
	pressing.select(maxi(0, TacticsManagerClass.VALID_PRESSING.find(String(tactic.get("pressing","standard")))))
	box.add_child(pressing)
	_button(box, tr("Apply tactical plan"), func():
		command.set_tactic(session.world, session.managed_club_id, formation.get_item_text(formation.selected), mentality.get_item_text(mentality.selected), tempo.get_item_text(tempo.selected), pressing.get_item_text(pressing.selected))
		app.call("_show_career")
	)
	_label(box, tr("In possession / transition / out of possession instructions"))
	var instructions: Dictionary = tactic.get("instructions", {})
	for phase in instructions.keys(): _label(box, tr("%s: %s") % [String(phase).replace("_"," ").capitalize(), str(instructions[phase])])
	var toggles := HBoxContainer.new(); box.add_child(toggles)
	_button(toggles, tr("Toggle counter-press"), _toggle_instruction.bind("transition","counter_press", bool(instructions.get("transition",{}).get("counter_press",false))))
	_button(toggles, tr("Toggle counter"), _toggle_instruction.bind("transition","counter", bool(instructions.get("transition",{}).get("counter",false))))
	_button(toggles, tr("Toggle work ball into box"), _toggle_instruction.bind("in_possession","work_ball_into_box", bool(instructions.get("in_possession",{}).get("work_ball_into_box",false))))

func add_medical(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Medical")
	var rows: Array = query.medical(session.world, session.managed_club_id)
	if rows.is_empty(): _label(box, tr("No injured first-team players."))
	for row in rows:
		_label(box, tr("%s — %s — %d days — Match fitness %.0f%%") % [String(row.name), String(row.status.injury), int(row.status.days_remaining), float(row.status.match_fitness)])

func add_scouting(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Scouting")
	var data: Dictionary = query.scouting(session.world, session.managed_club_id)
	_label(box, tr("Known players: %d   Active/completed assignments: %d") % [int(data.knowledge_count), data.assignments.size()])
	for assignment in data.assignments:
		_label(box, tr("%s — %.0f%% %s") % [String(assignment.get("target_id","")), float(assignment.get("progress",0.0)), "complete" if bool(assignment.get("complete",false)) else ""])
	_label(box, tr("Top recruitment candidates"))
	var candidates: Array = command.shortlist(session.world, session.managed_club_id, 12)
	for player in candidates:
		var row := HBoxContainer.new(); box.add_child(row)
		_button(row, tr("%s  %s  Age %d") % [_player_name(player), String(player.get("position","")), int(player.get("age",0))], _show_player.bind(String(player.id)))
		_button(row, tr("Scout"), _scout_player.bind(String(player.id)))
		_button(row, tr("Bid"), _bid_player.bind(String(player.id)))

func add_transfers(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Transfers")
	var data: Dictionary = query.transfer_market(session.world, session.managed_club_id)
	_label(box, tr("Transfer window: %s") % ("OPEN" if bool(data.window_open) else "CLOSED"))
	for offer in data.offers:
		var line := HBoxContainer.new(); box.add_child(line)
		_label(line, tr("%s — fee %d — %s") % [String(offer.player_id), int(offer.fee), String(offer.status)])
		if String(offer.status) == "accepted": _button(line, tr("Accept agent demand & complete"), _complete_offer.bind(String(offer.id), String(offer.player_id)))

func add_staff(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Staff")
	var recruitment = preload("res://simulation/staff/staff_recruitment.gd").new()
	for member in query.staff(session.world, session.managed_club_id):
		_button(box, tr("%s — %s — Ability %d") % [String(member.get("name","Staff")), String(member.get("role","")), int(member.get("ability",0))], _show_staff.bind(String(member.id)))
		_button(box, tr("Release staff member"), func():
			app.call("_confirm", tr("Release this staff member? Twelve weeks of wages may be charged."), func(): _report_command(recruitment.fire(session.world, session.managed_club_id, String(member.id))))
		)
	_heading(box, tr("Staff recruitment"), 22)
	for role in ["assistant", "coach", "scout", "physio"]:
		for candidate in recruitment.candidates(session.world, session.managed_club_id, role, 2):
			_label(box, "%s — %s — %s: %d — %s: %d" % [String(candidate.name), role, tr("Weekly wage"), int(candidate.weekly_wage), tr("Compensation"), int(candidate.compensation)])
			_button(box, tr("Hire for two years"), func():
				app.call("_confirm", tr("Hire this staff member on the displayed terms?"), func(): _report_command(recruitment.hire(session.world, session.managed_club_id, String(candidate.staff_id), int(candidate.weekly_wage), 2))))

func add_schedule(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Schedule")
	for fixture in query.schedule(session.world, session.managed_club_id, 40):
		var state := "%d-%d" % [int(fixture.get("home_goals",0)),int(fixture.get("away_goals",0))] if bool(fixture.get("played",false)) else "vs"
		_label(box, tr("%s  %s  %s  %s") % [String(fixture.get("date","TBD")), _club_name(String(fixture.get("home_club_id",""))), state, _club_name(String(fixture.get("away_club_id","")))])

func add_competitions(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Competitions")
	for competition in session.world.get("competitions", []):
		_button(box, String(competition.get("name", "Competition")), _show_competition.bind(String(competition.id)))

func _show_competition(competition_id: String) -> void:
	var box: VBoxContainer = app.call("_clear")
	for competition in session.world.competitions:
		if String(competition.id) != competition_id: continue
		_heading(box, String(competition.name), 26)
		if session.managed_club_id in competition.get("club_ids", []):
			_button(box, tr("Register best eligible squad"), func():
				var result: Dictionary = command.auto_register_competition_squad(session.world, session.managed_club_id, competition_id)
				app.call("_show_error", "Registration result: %s" % str(result))
			)
		if String(competition.get("competition_type", "league")) == "league":
			for row in query.competition_table(session.world, competition_id):
				_label(box, tr("%s   P %d   W %d   D %d   L %d   Pts %d") % [_club_name(String(row.club_id)),int(row.get("played",0)),int(row.get("won",0)),int(row.get("drawn",0)),int(row.get("lost",0)),int(row.get("points",0))])
		else:
			var champion := String(competition.get("champion_club_id", ""))
			_label(box, tr("Winner: %s") % _club_name(champion) if champion != "" else "Cup in progress")
			for fixture in session.world.fixtures:
				if String(fixture.get("competition_id", "")) == competition_id:
					_label(box, tr("%s vs %s: %s") % [_club_name(String(fixture.home_club_id)),_club_name(String(fixture.away_club_id)),"%d-%d" % [int(fixture.home_goals),int(fixture.away_goals)] if bool(fixture.played) else "Scheduled"])
	_button(box, tr("Back to career"), app.call.bind("_show_career"))

func add_finances(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Finances")
	var data: Dictionary = query.finances(session.world, session.managed_club_id)
	_heading(box, tr("Club finances"), 18)
	var institutions = Institutions.new()
	var ticket := SpinBox.new(); ticket.min_value = 1; ticket.max_value = 200; ticket.value = 20; box.add_child(ticket)
	_button(box, tr("Set ticket price"), func(): _report_command(institutions.set_ticket_price(session.world, session.managed_club_id, int(ticket.value))))
	for facility in ["training", "youth", "medical"]:
		_button(box, tr("Improve %s facilities") % facility, func(): _report_command(institutions.invest_facility(session.world, session.managed_club_id, facility)))
	_button(box, tr("Request transfer budget"), func():
		var result: Dictionary = institutions.request_budget(session.world, session.managed_club_id, "transfer", 100000)
		app.call("_show_career")
		app.call("_show_error", "Board request approved." if bool(result.get("approved", false)) else "Board request declined.")
	)
	_label(box, tr("Cash: %d   Debt: %d   Transfer budget: %d   Wage budget: %d") % [int(data.cash),int(data.debt),int(data.transfer_budget),int(data.wage_budget)])
	for entry in data.ledger.slice(maxi(0, data.ledger.size()-20)):
		_label(box, tr("%s  %s  %+d") % [String(entry.get("reference","")), String(entry.get("category","")), int(entry.get("amount",0))])

func add_search(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Search")
	var input := LineEdit.new(); input.placeholder_text = "Search clubs, players and staff"; box.add_child(input)
	var results := VBoxContainer.new(); box.add_child(results)
	var run := func():
		for child in results.get_children(): child.queue_free()
		for item in query.world_search(session.world, input.text, 30):
			var callback: Callable
			if String(item.type) == "player": callback = _show_player.bind(String(item.id))
			elif String(item.type) == "staff": callback = _show_staff.bind(String(item.id))
			else: callback = _show_club.bind(String(item.id))
			_button(results, tr("%s — %s") % [String(item.type).capitalize(), String(item.name)], callback)
	_button(box, tr("Search"), run)
	input.text_submitted.connect(func(_text): run.call())

func add_match_analysis(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Match Analysis")
	var data: Dictionary = query.last_match_analysis(session.world)
	if data.is_empty():
		_label(box, tr("No managed match has been played yet."))
		return
	var analysis: Dictionary = data.analysis
	_heading(box, tr("%s — %d:%d") % [String(data.date), int(analysis.score[0]), int(analysis.score[1])], 20)
	_label(box, tr("Stats: %s") % str(analysis.stats))
	var viewer = MatchViewerClass.new(); viewer.custom_minimum_size = Vector2(900, 480); viewer.set_match(session.world.last_managed_match.result); box.add_child(viewer)
	var controls := HBoxContainer.new(); box.add_child(controls)
	_button(controls, tr("◀"), viewer.previous_frame)
	_button(controls, tr("Play/Pause"), viewer.toggle_playback)
	_button(controls, tr("▶"), viewer.next_frame)
	for speed in [1.0,2.0,4.0]: _button(controls, tr("%dx") % int(speed), viewer.set_speed.bind(speed))

func _show_player(player_id: String) -> void:
	var root := app.call("_clear") as VBoxContainer
	_heading(root, tr("Player Profile"), 28)
	var profile: Dictionary = query.player_profile(session.world, player_id, session.managed_club_id)
	_label(root, tr("%s — %s — Age %d") % [String(profile.get("name","Player")), String(profile.get("position","")), int(profile.get("age",0))])
	_label(root, tr("Ability: %s   Potential: %s   Foot: %s   Weak foot: %d") % [str(profile.get("ability","?")),str(profile.get("potential","?")),String(profile.get("preferred_foot","")),int(profile.get("weak_foot",0))])
	_label(root, tr("Fitness %d   Morale %d   Medical: %s") % [int(profile.get("fitness",0)),int(profile.get("morale",0)),str(profile.get("medical",{}))])
	_label(root, tr("Contract: %s") % str(profile.get("contract",{})))
	if String(_player(player_id).get("club_id", "")) == session.managed_club_id:
		_button(root, tr("Renew contract"), _show_contract_offer.bind(player_id))
	var attrs: Dictionary = profile.get("attributes",{})
	for name in attrs.keys(): _label(root, tr("%s: %s") % [String(name).replace("_"," ").capitalize(), str(attrs[name])])
	_button(root, tr("Back to career"), app.call.bind("_show_career"))

func _show_staff(staff_id: String) -> void:
	var root := app.call("_clear") as VBoxContainer
	_heading(root, tr("Staff Profile"), 28)
	var profile := query.staff_profile(session.world, staff_id)
	_label(root, str(profile))
	_button(root, tr("Back to career"), app.call.bind("_show_career"))

func _show_contract_offer(player_id: String) -> void:
	var box: VBoxContainer = app.call("_clear")
	_heading(box, tr("Renew contract"), 26)
	var demand: Dictionary = command.contract_demand(session.world, session.managed_club_id, player_id, session.seed)
	var wage := SpinBox.new(); wage.min_value = 1; wage.max_value = 1000000; wage.value = int(demand.get("weekly_wage", 1000))
	var bonus := SpinBox.new(); bonus.min_value = 0; bonus.max_value = 100000000; bonus.value = int(demand.get("signing_bonus", 0))
	var years := SpinBox.new(); years.min_value = 1; years.max_value = 5; years.value = int(demand.get("years_preferred", 2))
	box.add_child(app.call("_labeled", tr("Weekly wage"), wage))
	box.add_child(app.call("_labeled", tr("Signing bonus"), bonus))
	box.add_child(app.call("_labeled", tr("Contract years"), years))
	_button(box, tr("Submit contract offer"), func():
		var result: Dictionary = command.renew_contract(session.world, session.managed_club_id, player_id, int(wage.value), int(bonus.value), int(years.value), session.seed)
		_report_command(int(result.get("error", FAILED)))
	)
	_button(box, tr("Back to career"), app.call.bind("_show_career"))

func _show_club(club_id: String) -> void:
	var root := app.call("_clear") as VBoxContainer
	_heading(root, tr("Club Profile"), 28)
	var profile := query.club_profile(session.world, club_id)
	_label(root, str(profile))
	_button(root, tr("Back to career"), app.call.bind("_show_career"))

func _set_training(intensity: float) -> void:
	command.set_training(session.world, session.managed_club_id, ["recovery","technical","tactical","physical","set_pieces","match_prep","rest"], intensity)
	app.call("_show_career")

func _report_command(error: Error) -> void:
	app.call("_show_career")
	app.call("_show_error", "Change applied." if error == OK else "The change could not be applied (%d). Check your funds and the request." % error)

func _toggle_instruction(phase: String, key: String, current: bool) -> void:
	command.set_tactical_instruction(session.world, session.managed_club_id, phase, key, not current)
	app.call("_show_career")

func _scout_player(player_id: String) -> void:
	command.assign_scout(session.world, session.managed_club_id, player_id)
	app.call("_show_career")

func _bid_player(player_id: String) -> void:
	var player: Dictionary = _player(player_id)
	if player.is_empty(): return
	var estimated := maxi(100000, int(player.get("current_ability",50))*int(player.get("current_ability",50))*1000)
	command.submit_transfer_offer(session.world, session.managed_club_id, player_id, estimated, {"sell_on_percentage":10}, session.seed + int(session.world.get("day_index",0)))
	app.call("_show_career")

func _complete_offer(offer_id: String, player_id: String) -> void:
	var demand := command.contract_demand(session.world, session.managed_club_id, player_id, session.seed + int(session.world.get("day_index",0)))
	if demand.has("error"): return
	command.complete_transfer(session.world, offer_id, int(demand.weekly_wage), int(demand.signing_bonus), int(demand.years_preferred), session.seed + int(session.world.get("day_index",0)))
	app.call("_show_career")

func _tab(tabs: TabContainer, name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new(); scroll.name = name; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new(); box.custom_minimum_size = Vector2(920, 480); box.add_theme_constant_override("separation",8); scroll.add_child(box); tabs.add_child(scroll); tabs.set_tab_title(tabs.get_tab_count()-1,tr(name)); return box

func _heading(parent: Control, text: String, size: int) -> void:
	var label := Label.new(); label.text=tr(text); label.add_theme_font_size_override("font_size",size); parent.add_child(label)

func _label(parent: Control, text: String) -> void:
	var label := Label.new(); label.text=tr(text); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; parent.add_child(label)

func _button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new(); button.text=tr(text); button.pressed.connect(callback); parent.add_child(button)

func _focus_tab(tabs: TabContainer, name: String) -> void:
	for i in range(tabs.get_tab_count()):
		if tabs.get_tab_title(i) == name: tabs.current_tab=i; return

func _player(player_id: String) -> Dictionary:
	for player in session.world.get("players",[]):
		if String(player.get("id","")) == player_id: return player
	return {}

func _player_name(player: Dictionary) -> String:
	return String(player.get("name", (String(player.get("first_name",""))+" "+String(player.get("last_name",""))).strip_edges()))

func _club_name(club_id: String) -> String:
	for club in session.world.get("clubs",[]):
		if String(club.get("id","")) == club_id: return String(club.get("name",club_id))
	return club_id
