class_name PlayerProfileDialog
extends AcceptDialog

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
	min_size = Vector2i(900, 650)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(860, 560)
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
	_heading(box, _name(player))
	_label(box, "Age %d   Nationality %s   Position %s   Foot %s   Weak foot %d" % [int(player.get("age",0)),String(player.get("country_id",player.get("nationality_id",""))),String(player.get("position","")),String(player.get("preferred_foot","")),int(player.get("weak_foot",0))])
	_label(box, "Value %s   Wage %s   Morale %d   Condition %d   Sharpness %d" % [_money(_estimated_value(player)),_money(_weekly_wage()),int(player.get("morale",0)),int(player.get("fitness",0)),int(player.get("match_sharpness",0))])
	_label(box, "Current ability %d   Potential %d   Reputation %d" % [int(player.get("current_ability",0)),int(player.get("potential",0)),int(player.get("reputation",0))])
	var traits: Array = player.get("traits", [])
	_label(box, "Traits: %s" % (", ".join(traits) if not traits.is_empty() else "None"))

func _add_attributes(tabs: TabContainer, player: Dictionary) -> void:
	var box := _tab(tabs, "Attributes")
	var attrs: Dictionary = player.get("attributes", {})
	var keys: Array = attrs.keys(); keys.sort()
	for key in keys:
		_label(box, "%s: %d" % [String(key).replace("_"," ").capitalize(), int(attrs[key])])

func _add_performance(tabs: TabContainer, player: Dictionary) -> void:
	var box := _tab(tabs, "Performance")
	var totals := PlayerStats.new().season_totals(world, player_id)
	_label(box, "Appearances %d   Goals %d   Shots %d   xG %.2f" % [int(totals.appearances),int(totals.goals),int(totals.shots),float(totals.xg)])
	_label(box, "Passing %d/%d   Dribbles %d/%d" % [int(totals.passes_completed),int(totals.passes),int(totals.dribbles_completed),int(totals.dribbles)])
	_heading(box, "Recent matches")
	var rows: Array = []
	for row in world.get("player_match_stats", []):
		if String(row.get("player_id","")) == player_id: rows.append(row)
	for row in rows.slice(maxi(0, rows.size()-10)):
		_label(box, "%s — %d goal(s), %d shots, %.2f xG, passes %d/%d" % [String(row.get("fixture_id","Match")),int(row.get("goals",0)),int(row.get("shots",0)),float(row.get("xg",0.0)),int(row.get("passes_completed",0)),int(row.get("passes",0))])

func _add_development(tabs: TabContainer, player: Dictionary) -> void:
	var box := _tab(tabs, "Development")
	_label(box, "Training focus: %s" % String(player.get("training_focus","balanced")).capitalize())
	_heading(box, "Development history")
	var history: Array = player.get("development_history", [])
	if history.is_empty(): _label(box, "No annual development record yet.")
	for row in history.slice(maxi(0, history.size()-12)):
		_label(box, "%s: CA %d → %d (%+d), appearances %d" % [String(row.get("season_year","")),int(row.get("before",0)),int(row.get("after",0)),int(row.get("delta",0)),int(row.get("appearances",0))])

func _add_contract(tabs: TabContainer, _player_data: Dictionary) -> void:
	var box := _tab(tabs, "Contract")
	var contract := _contract()
	if contract.is_empty():
		_label(box, "No active contract.")
		return
	_label(box, "Club: %s" % _club_name(String(contract.get("club_id",""))))
	_label(box, "Start %s   End %s   Weekly wage %s" % [str(contract.get("start_year","")),str(contract.get("end_year","")),_money(int(contract.get("weekly_wage",0)))])
	for key in ["signing_bonus","release_clause","appearance_fee","goal_bonus"]:
		if contract.has(key): _label(box, "%s: %s" % [key.replace("_"," ").capitalize(),_money(int(contract[key]))])

func _add_medical(tabs: TabContainer, player: Dictionary) -> void:
	var box := _tab(tabs, "Medical")
	var report: Dictionary = Medical.new().report(player)
	for key in report.keys(): _label(box, "%s: %s" % [String(key).replace("_"," ").capitalize(),str(report[key])])
	_heading(box, "Injury history")
	var history: Array = player.get("injury_history", [])
	if history.is_empty(): _label(box, "No recorded injuries.")
	for injury in history:
		_label(box, "%s — %d days — %s" % [String(injury.get("season_year",injury.get("date",""))),int(injury.get("days",0)),String(injury.get("source","injury"))])

func _add_history(tabs: TabContainer, player: Dictionary) -> void:
	var box := _tab(tabs, "History")
	_label(box, "Career appearances: %d" % int(player.get("career_appearances",0)))
	for row in world.get("player_history", []):
		if String(row.get("player_id","")) != player_id: continue
		_label(box, "%s — %s — %s: %d apps, %d goals, %.2f xG" % [String(row.get("season_year","")),_club_name(String(row.get("club_id",""))),_competition_name(String(row.get("competition_id",""))),int(row.get("appearances",0)),int(row.get("goals",0)),float(row.get("xg",0.0))])

func _add_relationships(tabs: TabContainer, _player_data: Dictionary) -> void:
	var box := _tab(tabs, "Relationships")
	var count := 0
	for rel in world.get("relationships", []):
		var source := String(rel.get("source_person_id",rel.get("source_id","")))
		var target := String(rel.get("target_person_id",rel.get("target_id","")))
		if source != player_id and target != player_id: continue
		var other := target if source == player_id else source
		_label(box, "%s — %s (%d)" % [_person_name(other),String(rel.get("relationship_type",rel.get("type","relationship"))).replace("_"," ").capitalize(),int(rel.get("strength",0))])
		count += 1
	if count == 0: _label(box, "No notable relationships recorded.")

func _add_reports(tabs: TabContainer, player: Dictionary) -> void:
	var box := _tab(tabs, "Reports")
	var knowledge: Dictionary = world.get("scouting_knowledge", {}).get(managed_club_id, {})
	var report = knowledge.get(player_id, {})
	if typeof(report) == TYPE_DICTIONARY and not report.is_empty():
		for key in report.keys(): _label(box, "%s: %s" % [String(key).replace("_"," ").capitalize(),str(report[key])])
	else:
		_label(box, "No current scouting report from your club.")
	var hidden: Dictionary = player.get("hidden_attributes", {})
	var descriptions: Array[String] = []
	if int(hidden.get("professionalism",50)) >= 75: descriptions.append("Highly professional")
	if int(hidden.get("consistency",50)) >= 75: descriptions.append("Consistent performer")
	if int(hidden.get("important_matches",50)) >= 75: descriptions.append("Enjoys important matches")
	if int(hidden.get("injury_proneness",50)) >= 70: descriptions.append("May be susceptible to injuries")
	if int(hidden.get("adaptability",50)) <= 30: descriptions.append("May need time to adapt")
	if not descriptions.is_empty(): _label(box, "Scout observations: %s" % "; ".join(descriptions))

func _tab(tabs: TabContainer, name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new(); scroll.name = name; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new(); box.custom_minimum_size = Vector2(820, 500); scroll.add_child(box); tabs.add_child(scroll); tabs.set_tab_title(tabs.get_tab_count()-1, name); return box
func _heading(parent: Control, text: String) -> void:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size",18); parent.add_child(label)
func _label(parent: Control, text: String) -> void:
	var label := Label.new(); label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; parent.add_child(label)
func _player() -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id","")) == player_id: return player
	return {}
func _contract() -> Dictionary:
	for contract in world.get("contracts", []):
		if String(contract.get("player_id","")) == player_id and not bool(contract.get("expired",false)): return contract
	return {}
func _weekly_wage() -> int:
	return int(_contract().get("weekly_wage",0))
func _club_name(id: String) -> String:
	for club in world.get("clubs", []):
		if String(club.get("id","")) == id: return String(club.get("name",id))
	return id
func _competition_name(id: String) -> String:
	for competition in world.get("competitions", []):
		if String(competition.get("id","")) == id: return String(competition.get("name",id))
	return id
func _person_name(id: String) -> String:
	for p in world.get("players", []):
		if String(p.get("id","")) == id: return _name(p)
	for s in world.get("staff", []):
		if String(s.get("id","")) == id: return String(s.get("name",id))
	return id
func _name(player: Dictionary) -> String:
	var name := String(player.get("name","")).strip_edges()
	if name != "": return name
	return (String(player.get("first_name",""))+" "+String(player.get("last_name",""))).strip_edges()
func _estimated_value(player: Dictionary) -> int:
	var ability := int(player.get("current_ability",50)); var potential := int(player.get("potential",ability)); var age := int(player.get("age",25))
	var age_factor := 1.25 if age <= 23 else (1.0 if age <= 28 else maxf(0.35,1.0-float(age-28)*0.09))
	return int((ability*ability*900 + maxi(0,potential-ability)*ability*450) * age_factor)
func _money(value: int) -> String:
	if value >= 1000000: return "£%.1fm" % (float(value)/1000000.0)
	if value >= 1000: return "£%.0fk" % (float(value)/1000.0)
	return "£%d" % value
