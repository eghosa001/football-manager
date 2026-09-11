class_name TacticsActions
extends RefCounted

const TacticsManagerClass = preload("res://simulation/tactics/tactics_manager.gd")
const VALID_DUTIES := ["defend", "support", "attack"]

func set_role(world: Dictionary, club_id: String, slot_key: String, role: String) -> Error:
	var club := _club(world, club_id)
	if club.is_empty(): return ERR_DOES_NOT_EXIST
	_ensure_tactic(club)
	var position := _position_for_slot(club.tactic, slot_key)
	if position == "": return ERR_INVALID_PARAMETER
	if role not in TacticsManagerClass.ROLES.get(position, []): return ERR_INVALID_PARAMETER
	club.tactic.roles[slot_key] = role
	club.tactic.familiarity = maxf(0.0, float(club.tactic.get("familiarity",50.0)) - 1.5)
	return OK

func set_duty(world: Dictionary, club_id: String, slot_key: String, duty: String) -> Error:
	var club := _club(world, club_id)
	if club.is_empty(): return ERR_DOES_NOT_EXIST
	_ensure_tactic(club)
	if not club.tactic.get("duties", {}).has(slot_key) or duty not in VALID_DUTIES: return ERR_INVALID_PARAMETER
	var position := _position_for_slot(club.tactic, slot_key)
	if position == "GK" and duty == "attack": return ERR_INVALID_PARAMETER
	club.tactic.duties[slot_key] = duty
	club.tactic.familiarity = maxf(0.0, float(club.tactic.get("familiarity",50.0)) - 1.0)
	return OK

func issues(world: Dictionary, club_id: String) -> Array[String]:
	var club := _club(world, club_id)
	if club.is_empty(): return ["Club not found."]
	_ensure_tactic(club)
	var tactic: Dictionary = club.tactic
	var slots := _slot_positions(tactic)
	var issues: Array[String] = []
	var attacking_duties := 0; var defending_duties := 0; var central_defenders := 0; var wide_defenders := 0
	for key in slots.keys():
		var position := String(slots[key]); var duty := String(tactic.duties.get(key,"support")); var role := String(tactic.roles.get(key,""))
		if duty == "attack": attacking_duties += 1
		if duty == "defend": defending_duties += 1
		if position == "DC": central_defenders += 1
		if position in ["DL","DR","WBL","WBR"]: wide_defenders += 1
		if position in ["DL","DR","WBL","WBR"] and duty == "attack" and role in ["wing_back","complete_wing_back"]:
			issues.append("%s is very aggressive; the flank may be exposed in transition." % key)
	if central_defenders < 2: issues.append("The shape has fewer than two central defenders and may be vulnerable centrally.")
	if wide_defenders == 0: issues.append("No natural wide defender is selected; wide areas may be vulnerable.")
	if attacking_duties >= 5: issues.append("Five or more attacking duties can leave insufficient rest defence.")
	if defending_duties >= 7: issues.append("The setup is very conservative and may isolate the forward line.")
	var instructions: Dictionary = tactic.get("instructions", {})
	var oop: Dictionary = instructions.get("out_of_possession", {})
	var transition: Dictionary = instructions.get("transition", {})
	if String(oop.get("defensive_line","standard")) == "higher" and String(tactic.get("pressing","standard")) == "low": issues.append("A high defensive line with low pressure can leave space in behind.")
	if bool(transition.get("counter_press",false)) and String(tactic.get("pressing","standard")) == "low": issues.append("Counter-press is selected but overall pressing intensity is low.")
	if float(tactic.get("familiarity",50.0)) < 35.0: issues.append("Tactical familiarity is low; coordination may suffer until the system is trained.")
	if issues.is_empty(): issues.append("No major structural tactical issue detected.")
	return issues

func slot_keys(tactic: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in _slot_positions(tactic).keys(): out.append(String(key))
	return out

func position_for_slot(tactic: Dictionary, slot_key: String) -> String:
	return _position_for_slot(tactic, slot_key)

func _ensure_tactic(club: Dictionary) -> void:
	if not club.has("tactic"): club["tactic"] = TacticsManagerClass.new().create_tactic("4-3-3")
	TacticsManagerClass.new().ensure_instructions(club.tactic)

func _slot_positions(tactic: Dictionary) -> Dictionary:
	var formation := String(tactic.get("formation","4-3-3"))
	var positions: Array = TacticsManagerClass.FORMATIONS.get(formation,TacticsManagerClass.FORMATIONS["4-3-3"])
	var counts := {}; var result := {}
	for position in positions:
		var p := String(position); counts[p] = int(counts.get(p,0))+1
		var key := p if int(counts[p])==1 else "%s_%d" % [p,int(counts[p])]
		result[key] = p
	return result

func _position_for_slot(tactic: Dictionary, slot_key: String) -> String:
	return String(_slot_positions(tactic).get(slot_key,""))

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id","")) == club_id: return club
	return {}
