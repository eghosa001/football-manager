extends Node

const CommandClass = preload("res://application/career/career_command_service.gd")
const ScoutingServiceClass = preload("res://simulation/scouting/scouting_service.gd")

var _next_scan_ms := 0

func _ready() -> void:
	set_process(true)
	call_deferred("_scan")
	if has_node("/root/Monetization"):
		var monetization := get_node("/root/Monetization")
		monetization.analyst_credits_changed.connect(func(_credits): _refresh_buttons())
		monetization.premium_changed.connect(func(_active): _refresh_buttons())

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_scan_ms:
		return
	_next_scan_ms = now + 500
	_scan()

func _scan() -> void:
	var root := get_tree().root
	if root == null:
		return
	_scan_node(root)

func _scan_node(node: Node) -> void:
	if node is TabContainer:
		_install_on_scouting_tab(node as TabContainer)
	for child in node.get_children():
		_scan_node(child)

func _install_on_scouting_tab(tabs: TabContainer) -> void:
	for i in range(tabs.get_tab_count()):
		var tab := tabs.get_tab_control(i)
		if String(tab.name) != "Scouting" or not tab is Container:
			continue
		if tab.has_node("MonetizationAnalystPanel"):
			continue
		var panel := VBoxContainer.new()
		panel.name = "MonetizationAnalystPanel"
		panel.add_theme_constant_override("separation", 5)
		var rule := HSeparator.new()
		panel.add_child(rule)
		var label := Label.new()
		label.name = "AnalystCreditStatus"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(label)
		var button := Button.new()
		button.name = "InstantAnalystReportButton"
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(300, 44)
		button.pressed.connect(_use_analyst_report.bind(tabs))
		panel.add_child(button)
		(tab as Container).add_child(panel)
		_update_panel(panel)

func _refresh_buttons() -> void:
	for node in get_tree().get_nodes_in_group("__never_used_monetization_group"):
		pass
	_refresh_node(get_tree().root)

func _refresh_node(node: Node) -> void:
	if node.name == "MonetizationAnalystPanel" and node is VBoxContainer:
		_update_panel(node as VBoxContainer)
	for child in node.get_children():
		_refresh_node(child)

func _update_panel(panel: VBoxContainer) -> void:
	if not has_node("/root/Monetization"):
		return
	var monetization := get_node("/root/Monetization")
	var label := panel.get_node_or_null("AnalystCreditStatus") as Label
	var button := panel.get_node_or_null("InstantAnalystReportButton") as Button
	if label != null:
		if monetization.is_premium:
			label.text = "Premium Analyst Desk: unlimited instant dossiers on your current top recruitment target. Reports provide information only and never alter match or transfer outcomes."
		else:
			label.text = "Analyst Report credits: %d/%d. Earn credits voluntarily from the Premium menu by completing a rewarded ad." % [monetization.analyst_credits, monetization.MAX_ANALYST_CREDITS]
	if button != null:
		button.text = "GENERATE INSTANT ANALYST DOSSIER" if monetization.is_premium else "USE ANALYST REPORT CREDIT"
		button.disabled = not monetization.can_use_analyst_report()

func _use_analyst_report(tabs: TabContainer) -> void:
	if not has_node("/root/Monetization"):
		return
	var app := _career_app_from(tabs)
	if app == null:
		return
	var session = app.get("session")
	if session == null or session.world.is_empty():
		_show(app, "Start or load a career before requesting an analyst dossier.")
		return
	var command = CommandClass.new()
	var candidates: Array = command.shortlist(session.world, session.managed_club_id, 12)
	if candidates.is_empty():
		_show(app, "No recruitment target is currently available for an analyst dossier.")
		return
	var target: Dictionary = candidates[0]
	var monetization := get_node("/root/Monetization")
	if not monetization.consume_analyst_report():
		_show(app, "No Analyst Report credit available. Use the Premium menu to earn one from an optional rewarded ad, or activate Premium.")
		return

	var quality := _best_scout_quality(session.world, session.managed_club_id)
	var report: Dictionary = ScoutingServiceClass.new().analyst_report(
		session.world,
		target,
		maxi(65, quality),
		int(session.seed) + int(session.world.get("day_index", 0)) + String(target.get("id", "")).hash()
	)
	_show(app, _format_report(target, report))
	_refresh_buttons()

func _best_scout_quality(world: Dictionary, club_id: String) -> int:
	var best := 55
	for member in world.get("staff", []):
		if String(member.get("club_id", "")) != club_id or String(member.get("role", "")) != "scout":
			continue
		best = maxi(best, int(member.get("ability", member.get("scouting", 55))))
	return best

func _format_report(player: Dictionary, report: Dictionary) -> String:
	var name := String(player.get("name", "Target"))
	if name == "Target":
		name = "%s %s" % [String(player.get("first_name", "")), String(player.get("last_name", ""))]
		name = name.strip_edges()
	var ability: Dictionary = report.get("ability_estimate", {})
	var potential: Dictionary = report.get("potential_estimate", {})
	var strengths := _attribute_names(report.get("strengths", []))
	var weaknesses := _attribute_names(report.get("weaknesses", []))
	var role_fit: Dictionary = report.get("role_fit", {})
	var best_role := ""
	var best_role_score := -1.0
	for role in role_fit.keys():
		var score := float(role_fit[role])
		if score > best_role_score:
			best_role_score = score
			best_role = String(role).replace("_", " ").capitalize()
	return "ANALYST DOSSIER — %s\nVerdict: %s\nAbility estimate: %d–%d | Potential: %d–%d\nStrengths: %s\nWeaknesses: %s\nBest role profile: %s (%.0f)\n\nThis report improves decision information only; it does not change the player or any match outcome." % [
		name,
		String(report.get("verdict", "Assessment unavailable")),
		int(ability.get("min", 0)), int(ability.get("max", 0)),
		int(potential.get("min", 0)), int(potential.get("max", 0)),
		strengths, weaknesses, best_role, best_role_score
	]

func _attribute_names(rows: Array) -> String:
	if rows.is_empty():
		return "None identified"
	var names: Array[String] = []
	for row in rows:
		if row is Dictionary:
			names.append(String(row.get("attribute", "")).replace("_", " ").capitalize())
	return ", ".join(names)

func _career_app_from(node: Node) -> Node:
	var cursor: Node = node
	while cursor != null and not cursor is Viewport:
		var script = cursor.get_script()
		if script != null and String(script.resource_path).ends_with("game/career/career_app.gd"):
			return cursor
		cursor = cursor.get_parent()
	return null

func _show(app: Node, text: String) -> void:
	if app.has_method("_show_error"):
		app.call("_show_error", text)
	else:
		print(text)
