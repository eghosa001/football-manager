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
	var club: Dictionary = data.get("club", {})
	_heading(box, String(club.get("name", "Club")), 22)
	_label(box, tr("Date: %s   Season: %d") % [String(data.get("date", "")), int(data.get("season_year", 2026))])
	_label(box, tr("Squad: %d   Cash: %d   Transfer budget: %d   Wage budget: %d") % [int(data.get("squad_size", 0)), int(data.get("cash", 0)), int(data.get("transfer_budget", 0)), int(data.get("wage_budget", 0))])
	_label(box, tr("Unread inbox: %d") % int(data.get("unread_messages", 0)))
	_label(box, tr("Form: %s   Nation: %s") % [_form_string(), _club_nation()])
	var next: Dictionary = data.get("next_fixture", {})
	if next.is_empty():
		_label(box, tr("No upcoming fixtures scheduled. Advance the calendar to generate the next round."))
	else:
		_label(box, tr("Next fixture: %s — %s vs %s") % [String(next.get("date", "TBD")), _club_name(String(next.get("home_club_id", ""))), _club_name(String(next.get("away_club_id", "")))])
	if session.world.has("last_managed_match"):
		_button(box, tr("Open last match analysis"), func(): _focus_tab(tabs, "Match Analysis"))
	else:
		_label(box, tr("No managed match played yet — match analysis will appear here after your first fixture."))

func add_squad(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Squad")
	var rows: Array = query.squad(session.world, session.managed_club_id)
	if rows.is_empty():
		_label(box, tr("No squad players found. Check registrations under Competitions."))
		return
	for row in rows:
		var line := HBoxContainer.new(); box.add_child(line)
		var text := "%s  %-4s  Age %d  CA %d  PA %d  Fit %d  Morale %d" % [String(row.get("name", "?")), String(row.get("position", "?")), int(row.get("age", 0)), int(row.get("ability", 0)), int(row.get("potential", 0)), int(row.get("fitness", 0)), int(row.get("morale", 0))]
		_button(line, text, _show_player.bind(String(row.get("id", ""))))

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
	_label(box, tr("Transfer window: %s") % ("OPEN" if bool(data.get("window_open", false)) else "CLOSED"))
	_label(box, tr("Budgets — transfer %d • wage %d • cash %d") % [int(data.get("transfer_budget", 0)), int(data.get("wage_budget", 0)), int(data.get("cash", 0))])
	var offers: Array = data.get("offers", [])
	if offers.is_empty():
		_label(box, tr("No offers submitted yet. Use Scouting to find targets, then Bid."))
	for offer in offers:
		var line := VBoxContainer.new(); box.add_child(line)
		var player_name := _player_name(_player(String(offer.get("player_id", ""))))
		_label(line, tr("%s — fee %d — %s") % [player_name, int(offer.get("fee", 0)), String(offer.get("status", "submitted"))])
		_label(line, tr("Clauses: %s") % _clauses_text(offer.get("clauses", {})))
		if String(offer.get("status", "")) == "rejected":
			_label(line, tr("Seller wants ~%d. Reasons: %s") % [int(offer.get("counter_fee", offer.get("fee", 0))), ", ".join(offer.get("reason_codes", []))])
		var row := HBoxContainer.new(); line.add_child(row)
		_button(row, tr("View player"), _show_player.bind(String(offer.get("player_id", ""))))
		if String(offer.get("status", "")) == "accepted":
			_button(row, tr("Accept agent demand & complete"), _complete_offer.bind(String(offer.get("id", "")), String(offer.get("player_id", ""))))
	_heading(box, tr("Boardroom"), 18)
	_label(box, tr("Request funds, review objectives and check job security from the Board tab."))

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
	var fixtures: Array = query.schedule(session.world, session.managed_club_id, 40)
	if fixtures.is_empty():
		_label(box, tr("No fixtures found for your club this season."))
		return
	for fixture in fixtures:
		var state := "%d-%d" % [int(fixture.get("home_goals", 0)), int(fixture.get("away_goals", 0))] if bool(fixture.get("played", false)) else "vs"
		_label(box, tr("%s  %s  %s  %s") % [String(fixture.get("date", "TBD")), _club_name(String(fixture.get("home_club_id", ""))), state, _club_name(String(fixture.get("away_club_id", "")))])

func add_competitions(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Competitions")
	var competitions: Array = session.world.get("competitions", [])
	if competitions.is_empty():
		_label(box, tr("No competitions available. Start a new career to generate leagues and cups."))
		return
	var relevant: Array = []
	var others: Array = []
	for competition in competitions:
		if session.managed_club_id in competition.get("club_ids", []): relevant.append(competition)
		else: others.append(competition)
	_label(box, tr("Your competitions (%d)") % relevant.size())
	if relevant.is_empty():
		_label(box, tr("Your club is not entered in any competition. Check registration rules."))
	for competition in relevant:
		_button(box, "%s%s" % [String(competition.get("name", "Competition")), _competition_suffix(competition)], _show_competition.bind(String(competition.get("id", ""))))
	_label(box, tr("Other competitions (%d) — continental tiers, Club World Cup and internationals included") % others.size())
	for competition in others.slice(0, 40):
		_button(box, "%s%s" % [String(competition.get("name", "Competition")), _competition_suffix(competition)], _show_competition.bind(String(competition.get("id", ""))))

func _show_competition(competition_id: String) -> void:
	var box: VBoxContainer = app.call("_clear")
	for competition in session.world.competitions:
		if String(competition.id) != competition_id: continue
		_heading(box, "%s%s" % [String(competition.name), _competition_suffix(competition)], 26)
		_label(box, _competition_qualification_text(competition))
		if session.managed_club_id in competition.get("club_ids", []):
			_button(box, tr("Register best eligible squad"), func():
				var result: Dictionary = command.auto_register_competition_squad(session.world, session.managed_club_id, competition_id)
				app.call("_show_error", "Registration result: %s" % str(result))
			)
		if String(competition.get("competition_type", "league")) == "league":
			_label(box, tr("Pos  Club  P  W  D  L  GF  GA  GD  Pts  Form"))
			var pos := 0
			for row in query.competition_table(session.world, competition_id):
				pos += 1
				var form := _club_form(String(row.get("club_id", "")), competition_id)
				_label(box, "%2d  %s  %d  %d  %d  %d  %d  %d  %+d  %d  %s" % [pos, _club_name(String(row.get("club_id", ""))), int(row.get("played", 0)), int(row.get("won", 0)), int(row.get("drawn", 0)), int(row.get("lost", 0)), int(row.get("goals_for", 0)), int(row.get("goals_against", 0)), int(row.get("goal_difference", 0)), int(row.get("points", 0)), form])
		else:
			var champion := String(competition.get("champion_club_id", ""))
			_label(box, tr("Winner: %s") % _club_name(champion) if champion != "" else tr("Cup in progress — %d clubs entered") % competition.get("club_ids", []).size())
			var bracket: Dictionary = competition.get("knockout_bracket", {})
			if not bracket.is_empty() and not bool(bracket.get("complete", true)):
				_label(box, tr("Current round: %d • ties remaining: %d") % [int(bracket.get("round", 1)), bracket.get("matches", []).size()])
			for fixture in session.world.fixtures:
				if String(fixture.get("competition_id", "")) == competition_id:
					_label(box, tr("%s vs %s: %s") % [_club_name(String(fixture.home_club_id)), _club_name(String(fixture.away_club_id)), "%d-%d" % [int(fixture.home_goals), int(fixture.away_goals)] if bool(fixture.played) else "Scheduled %s" % String(fixture.get("date", ""))])
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
	preload("res://simulation/players/player_attributes.gd").new().ensure(_player(player_id), session.seed)
	var profile: Dictionary = query.player_profile(session.world, player_id, session.managed_club_id)
	var raw := _player(player_id)
	_label(root, tr("%s — %s — Age %d — %s") % [String(profile.get("name", "Player")), String(profile.get("position", "")), int(profile.get("age", 0)), String(raw.get("personality", "Balanced"))])
	_label(root, tr("Ability %d • Potential %d • Foot %s (weak %d) • Value %d") % [int(raw.get("current_ability", 0)), int(raw.get("potential", 0)), String(raw.get("preferred_foot", "")), int(raw.get("weak_foot", 0)), int(raw.get("market_value", 0))])
	_label(root, tr("Fitness %d • Morale %d • Happiness %d • Medical: %s") % [int(profile.get("fitness", 0)), int(profile.get("morale", 0)), int(raw.get("happiness", raw.get("morale", 0))), str(profile.get("medical", {}))])
	_label(root, tr("Traits: %s") % (", ".join(raw.get("traits", [])) if not raw.get("traits", []).is_empty() else "None"))
	_label(root, tr("Contract: %s") % str(profile.get("contract", {})))
	_label(root, tr("Season: %d apps • %d goals • avg rating %.1f") % [int(raw.get("season_appearances", 0)), int(raw.get("season_goals", 0)), float(raw.get("average_rating", 0.0))])
	if String(raw.get("club_id", "")) == session.managed_club_id:
		_button(root, tr("Renew contract"), _show_contract_offer.bind(player_id))
	_heading(root, tr("Attributes (1–20)"), 20)
	for block in ["technical", "mental", "physical", "goalkeeping"]:
		var rows: Array = _attribute_block(raw, String(block))
		if rows.is_empty():
			continue
		_label(root, tr(block.capitalize()))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root.add_child(grid)
		for row in rows:
			var name_label := Label.new()
			name_label.text = String(row.get("name", "")).replace("_", " ").capitalize()
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(name_label)
			var bar := ProgressBar.new()
			bar.min_value = 0
			bar.max_value = 20
			bar.value = int(row.get("display", 10))
			bar.show_percentage = true
			bar.custom_minimum_size = Vector2(220, 0)
			grid.add_child(bar)
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
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new(); box.custom_minimum_size = Vector2(600, 400); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 8); scroll.add_child(box); tabs.add_child(scroll); tabs.set_tab_title(tabs.get_tab_count() - 1, tr(name)); return box

func _heading(parent: Control, text: String, size: int) -> void:
	var label := Label.new(); label.text=tr(text); label.add_theme_font_size_override("font_size",size); parent.add_child(label)

func _label(parent: Control, text: String) -> void:
	var label := Label.new(); label.text=tr(text); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; parent.add_child(label)

func _button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new(); button.text=tr(text); button.pressed.connect(callback); parent.add_child(button)

func _focus_tab(tabs: TabContainer, name: String) -> void:
	for i in range(tabs.get_tab_count()):
		if tabs.get_tab_title(i) == name or tabs.get_tab_title(i) == tr(name): tabs.current_tab = i; return

func _form_string() -> String:
	for club in session.world.get("clubs", []):
		if String(club.get("id", "")) == session.managed_club_id:
			var recent: Array = club.get("recent_results", [])
			if recent.is_empty(): return "—"
			return "".join(recent.slice(maxi(0, recent.size() - 5)))
	return "—"

func _club_nation() -> String:
	for club in session.world.get("clubs", []):
		if String(club.get("id", "")) == session.managed_club_id:
			return _country_name(String(club.get("country_id", "")))
	return ""

func _country_name(country_id: String) -> String:
	for country in session.world.get("countries", []):
		if String(country.get("id", "")) == country_id: return String(country.get("name", country_id))
	return country_id

func _competition_suffix(competition: Dictionary) -> String:
	var parts: Array = []
	if bool(competition.get("continental", false)):
		parts.append("Continental T%d" % int(competition.get("continental_tier", 1)))
	if bool(competition.get("club_world_cup", false)):
		parts.append("CWC")
	if String(competition.get("competition_type", "")) == "knockout" and not bool(competition.get("continental", false)):
		parts.append("Cup")
	if parts.is_empty(): return ""
	return " (%s)" % ", ".join(parts)

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

func add_board(tabs: TabContainer) -> void:
	var box := _tab(tabs, "Board")
	var security: Dictionary = command.job_security_report(session.world, session.managed_club_id)
	var fans: Dictionary = command.supporter_report(session.world, session.managed_club_id)
	_heading(box, tr("Boardroom"), 22)
	_label(box, tr("Job security: %s (risk %.0f%% • board confidence %d)") % [String(security.get("status", "stable")), float(security.get("risk", 0.0)) * 100.0, int(security.get("confidence", 65))])
	_label(box, tr("Supporters: mood %d • loyalty %d • expectation %d • attendance %s") % [int(fans.get("mood", 65)), int(fans.get("loyalty", 60)), int(fans.get("expectation", 50)), String(fans.get("attendance_outlook", "healthy"))])
	_label(box, tr("Season objectives review"))
	_button(box, tr("Run season review"), func():
		var review: Dictionary = command.board_season_review(session.world, session.managed_club_id)
		app.call("_show_error", "Review: %s (%.1f). Objectives: %s" % [String(review.get("status", "")), float(review.get("overall", 0.0)), str(review.get("objectives", []))])
		app.call("_show_career")
	)
	_heading(box, tr("Budget requests"), 18)
	for kind in ["transfer", "wage"]:
		var amount := SpinBox.new()
		amount.min_value = 10000
		amount.max_value = 50000000
		amount.step = 10000
		amount.value = 500000 if kind == "transfer" else 50000
		box.add_child(app.call("_labeled", tr("%s request") % kind.capitalize(), amount))
		_button(box, tr("Request %s budget") % kind, func():
			var result: Dictionary = command.request_board_budget(session.world, session.managed_club_id, kind, int(amount.value), session.seed + int(session.world.get("day_index", 0)))
			app.call("_show_career")
			app.call("_show_error", "Approved: granted %d." % int(result.get("granted", 0)) if bool(result.get("approved", false)) else "Declined (%s)." % String(result.get("reason", "board_declined")))
		)

func _attribute_block(player: Dictionary, block: String) -> Array:
	var attrs: Dictionary = player.get("attributes", {})
	var names: Array = []
	match block:
		"technical":
			names = ["corners", "crossing", "dribbling", "finishing", "first_touch", "free_kicks", "heading", "long_shots", "passing", "tackling", "technique"]
		"mental":
			names = ["aggression", "anticipation", "composure", "concentration", "decisions", "determination", "leadership", "off_the_ball", "positioning", "teamwork", "vision", "work_rate"]
		"physical":
			names = ["acceleration", "agility", "balance", "jumping", "pace", "stamina", "strength", "natural_fitness"]
		"goalkeeping":
			if String(player.get("position", "")) != "GK":
				return []
			names = ["aerial_reach", "command_of_area", "handling", "kicking", "one_on_ones", "reflexes", "rushing_out", "throwing"]
	var rows: Array = []
	for name in names:
		var raw := int(attrs.get(name, 50))
		rows.append({"name": String(name), "display": clampi(int(round(raw / 5.0)), 1, 20), "raw": raw})
	return rows

func _clauses_text(clauses: Dictionary) -> String:
	if clauses.is_empty():
		return "fee only"
	var parts: Array = []
	if int(clauses.get("instalments", 1)) > 1:
		parts.append("%dx" % int(clauses.get("instalments", 1)))
	if float(clauses.get("sell_on_pct", 0.0)) > 0.0:
		parts.append("sell-on %d%%" % int(round(float(clauses.get("sell_on_pct", 0.0)) * 100.0)))
	if int(clauses.get("signing_bonus", 0)) > 0:
		parts.append("bonus %d" % int(clauses.get("signing_bonus", 0)))
	if int(clauses.get("buy_option", 0)) > 0:
		parts.append("buy option %d%s" % [int(clauses.get("buy_option", 0)), " (obligation)" if bool(clauses.get("buy_obligation", false)) else ""])
	if String(clauses.get("squad_status", "")) != "":
		parts.append(String(clauses.get("squad_status", "")))
	return ", ".join(parts) if not parts.is_empty() else "fee only"

func _club_form(club_id: String, competition_id: String) -> String:
	var marks: Array = []
	for fixture in session.world.get("fixtures", []):
		if String(fixture.get("competition_id", "")) != competition_id or not bool(fixture.get("played", false)):
			continue
		var home := String(fixture.get("home_club_id", "")) == club_id
		var away := String(fixture.get("away_club_id", "")) == club_id
		if not home and not away:
			continue
		var gf := int(fixture.get("home_goals", 0)) if home else int(fixture.get("away_goals", 0))
		var ga := int(fixture.get("away_goals", 0)) if home else int(fixture.get("home_goals", 0))
		marks.append("W" if gf > ga else ("D" if gf == ga else "L"))
		if marks.size() >= 5:
			break
	while marks.size() < 5:
		marks.append("-")
	return "".join(marks)

func _competition_qualification_text(competition: Dictionary) -> String:
	if String(competition.get("qualification", "")) != "":
		return String(competition.get("qualification", ""))
	if bool(competition.get("club_world_cup", false)):
		return "Continental champions-tier winners qualify."
	if bool(competition.get("continental", false)):
		return "Tier %d continental qualification via league position." % int(competition.get("continental_tier", 1))
	if String(competition.get("competition_type", "")) == "knockout":
		return "Single-elimination domestic cup."
	return "Double round-robin league with promotion and relegation."
