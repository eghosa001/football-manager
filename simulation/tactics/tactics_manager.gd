class_name TacticsManager
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

const FORMATIONS := {
	"4-3-3": ["GK", "DR", "DC", "DC", "DL", "DM", "MC", "MC", "AMR", "AML", "ST"],
	"4-2-3-1": ["GK", "DR", "DC", "DC", "DL", "DM", "MC", "AMR", "AMC", "AML", "ST"],
	"4-4-2": ["GK", "DR", "DC", "DC", "DL", "MR", "MC", "MC", "ML", "ST", "ST"],
	"4-1-4-1": ["GK", "DR", "DC", "DC", "DL", "DM", "MR", "MC", "MC", "ML", "ST"],
	"4-3-1-2": ["GK", "DR", "DC", "DC", "DL", "MC", "MC", "MC", "AMC", "ST", "ST"],
	"4-2-2-2": ["GK", "DR", "DC", "DC", "DL", "DM", "DM", "AMR", "AML", "ST", "ST"],
	"3-4-3": ["GK", "DC", "DC", "DC", "MR", "MC", "MC", "ML", "AMR", "AML", "ST"],
	"3-5-2": ["GK", "DC", "DC", "DC", "WBR", "DM", "MC", "MC", "WBL", "ST", "ST"],
	"5-3-2": ["GK", "DR", "DC", "DC", "DC", "DL", "MC", "MC", "MC", "ST", "ST"],
}

const ROLES := {
	"GK": ["goalkeeper", "sweeper_keeper"],
	"DR": ["full_back", "wing_back", "inverted_full_back"],
	"DL": ["full_back", "wing_back", "inverted_full_back"],
	"WBR": ["wing_back", "complete_wing_back"],
	"WBL": ["wing_back", "complete_wing_back"],
	"DC": ["central_defender", "ball_playing_defender", "cover_defender", "stopper"],
	"DM": ["anchor", "deep_lying_playmaker", "ball_winner", "half_back"],
	"MC": ["central_midfielder", "box_to_box", "playmaker", "ball_winner", "mezzala"],
	"MR": ["winger", "wide_midfielder", "wide_playmaker"],
	"ML": ["winger", "wide_midfielder", "wide_playmaker"],
	"AMR": ["winger", "inside_forward", "inverted_winger", "wide_playmaker"],
	"AML": ["winger", "inside_forward", "inverted_winger", "wide_playmaker"],
	"AMC": ["attacking_midfielder", "playmaker", "shadow_striker"],
	"ST": ["advanced_forward", "target_forward", "pressing_forward", "deep_lying_forward", "poacher", "complete_forward"],
}

const VALID_MENTALITIES := ["very_cautious", "cautious", "balanced", "positive", "attacking"]
const VALID_TEMPOS := ["very_low", "low", "standard", "high", "very_high"]
const VALID_PRESSING := ["low", "standard", "high", "very_high"]

func ensure_world(world: Dictionary, seed: int) -> void:
	for staff_member in world.get("staff", []):
		if String(staff_member.get("role", "")) != "manager": continue
		if not staff_member.has("manager_profile"):
			var formation_names: Array = FORMATIONS.keys(); formation_names.sort()
			staff_member["manager_profile"] = {
				"preferred_formation":formation_names[_stable_index(seed,String(staff_member.id),formation_names.size())],
				"mentality":["cautious","balanced","positive"][_stable_index(seed+11,String(staff_member.id),3)],
				"tempo":["low","standard","high"][_stable_index(seed+17,String(staff_member.id),3)],
				"pressing":["low","standard","high"][_stable_index(seed+23,String(staff_member.id),3)],
				"adaptability":35 + _stable_index(seed+29,String(staff_member.id),61),
			}
	for club in world.get("clubs", []):
		if not club.has("tactic"):
			var manager: Dictionary = _manager_for_club(world.get("staff", []), String(club.id))
			var profile: Dictionary = manager.get("manager_profile", {})
			club["tactic"] = create_tactic(String(profile.get("preferred_formation","4-3-3")),String(profile.get("mentality","balanced")),String(profile.get("tempo","standard")),String(profile.get("pressing","standard")))
		else:
			ensure_instructions(club.tactic)

func create_tactic(formation: String, mentality: String = "balanced", tempo: String = "standard", pressing: String = "standard") -> Dictionary:
	if not FORMATIONS.has(formation): formation = "4-3-3"
	if mentality not in VALID_MENTALITIES: mentality = "balanced"
	if tempo not in VALID_TEMPOS: tempo = "standard"
	if pressing not in VALID_PRESSING: pressing = "standard"
	var roles := {}; var duties := {}; var role_counts := {}
	for position in FORMATIONS[formation]:
		role_counts[position] = int(role_counts.get(position, 0)) + 1
		var key := position if int(role_counts[position]) == 1 else "%s_%d" % [position, int(role_counts[position])]
		roles[key] = String(ROLES.get(position,["support"])[0])
		duties[key] = _default_duty(position)
	var tactic := {"formation":formation,"mentality":mentality,"tempo":tempo,"pressing":pressing,"roles":roles,"duties":duties,"familiarity":50.0,"instructions":default_instructions(mentality,tempo,pressing)}
	return tactic

func default_instructions(mentality: String = "balanced", tempo: String = "standard", pressing: String = "standard") -> Dictionary:
	return {
		"in_possession":{
			"width":"standard","passing_directness":"standard","build_up":"balanced","overlap_left":false,"overlap_right":false,
			"underlap_left":false,"underlap_right":false,"crossing":"mixed","creative_freedom":"balanced","time_wasting":"low",
			"work_ball_into_box":mentality in ["very_cautious","cautious"],"shoot_on_sight":mentality == "attacking",
		},
		"transition":{
			"counter":mentality in ["positive","attacking"],"regroup":mentality in ["very_cautious","cautious"],
			"counter_press":pressing in ["high","very_high"],"gk_distribution":"mixed","distribute_quickly":tempo in ["high","very_high"],
		},
		"out_of_possession":{
			"defensive_line":"standard","line_of_engagement":"standard","defensive_width":"standard","offside_trap":false,
			"tackling":"standard","pressing_triggers":pressing,"marking":"zonal","prevent_short_gk":pressing in ["high","very_high"],
		},
	}

func ensure_instructions(tactic: Dictionary) -> void:
	if not tactic.has("instructions"):
		tactic["instructions"] = default_instructions(String(tactic.get("mentality","balanced")),String(tactic.get("tempo","standard")),String(tactic.get("pressing","standard")))
	var defaults := default_instructions(String(tactic.get("mentality","balanced")),String(tactic.get("tempo","standard")),String(tactic.get("pressing","standard")))
	for phase in defaults.keys():
		if not tactic.instructions.has(phase): tactic.instructions[phase] = {}
		for key in defaults[phase].keys():
			if not tactic.instructions[phase].has(key): tactic.instructions[phase][key] = defaults[phase][key]

func set_instruction(tactic: Dictionary, phase: String, key: String, value) -> Error:
	ensure_instructions(tactic)
	if phase not in ["in_possession","transition","out_of_possession"]: return ERR_INVALID_PARAMETER
	if not tactic.instructions[phase].has(key): return ERR_INVALID_PARAMETER
	tactic.instructions[phase][key] = value
	tactic.familiarity = maxf(0.0, float(tactic.get("familiarity",50.0)) - 2.0)
	return OK

func train_tactic(club: Dictionary, sessions: int = 1) -> void:
	if not club.has("tactic"): club["tactic"] = create_tactic("4-3-3")
	ensure_instructions(club.tactic)
	club.tactic.familiarity = clampf(float(club.tactic.get("familiarity",50.0)) + sessions * 1.5,0.0,100.0)

func ai_choose_tactic(world: Dictionary, club_id: String, opponent_id: String, seed: int) -> Dictionary:
	ensure_world(world, seed)
	var club := _find_club(world.get("clubs", []), club_id); var opponent := _find_club(world.get("clubs", []), opponent_id)
	if club.is_empty(): return create_tactic("4-3-3")
	var base: Dictionary = club.tactic.duplicate(true); ensure_instructions(base)
	var own_strength := _squad_strength(world.get("players", []),club_id); var opponent_strength := _squad_strength(world.get("players", []),opponent_id)
	if own_strength > opponent_strength + 7.0:
		base.mentality="positive"; base.tempo="high"; base.instructions.transition.counter=true
	elif own_strength + 7.0 < opponent_strength:
		base.mentality="cautious"; base.tempo="low"; base.instructions.transition.regroup=true; base.instructions.out_of_possession.defensive_line="lower"
	else:
		base.mentality="balanced"
	if not opponent.is_empty() and int(opponent.get("reputation",50)) > int(club.get("reputation",50))+10: base.pressing="standard"
	return base

func select_lineup(players: Array, club_id: String, tactic: Dictionary) -> Array:
	var squad: Array = []
	for player in players:
		if String(player.get("club_id","")) == club_id and not bool(player.get("retired",false)) and int(player.get("injured_days",0)) <= 0: squad.append(player)
	if squad.size() < 11:
		for player in players:
			if String(player.get("club_id","")) == club_id and not bool(player.get("retired",false)) and not squad.has(player): squad.append(player)
	var slots: Array = FORMATIONS.get(String(tactic.get("formation","4-3-3")),FORMATIONS["4-3-3"])
	var selected: Array = []; var remaining: Array = squad.duplicate()
	for slot in slots:
		if remaining.is_empty(): break
		var best_index := 0; var best_score := -999999.0
		for i in range(remaining.size()):
			var score := _slot_score(remaining[i],String(slot),tactic)
			if score > best_score or (is_equal_approx(score,best_score) and String(remaining[i].id) < String(remaining[best_index].id)):
				best_index=i; best_score=score
		selected.append(remaining[best_index]); remaining.remove_at(best_index)
	return selected

func role_rating(player: Dictionary, tactic: Dictionary) -> float:
	var position := String(player.get("position","MC")); var role := _role_for_position(tactic, position)
	var a: Dictionary = player.get("attributes", {}); var ca := float(player.get("current_ability",50))
	var technical := float(a.get("technique",ca)); var passing := float(a.get("passing",ca)); var pace := float(a.get("pace",ca)); var strength := float(a.get("strength",ca)); var finishing := float(a.get("finishing",ca)); var tackling := float(a.get("tackling",ca)); var vision := float(a.get("vision",ca)); var decisions := float(a.get("decisions",ca)); var crossing := float(a.get("crossing",ca)); var marking := float(a.get("marking",ca)); var off_ball := float(a.get("off_the_ball",ca))
	var score := ca
	if role in ["playmaker","deep_lying_playmaker","wide_playmaker","ball_playing_defender"]: score=ca*0.45+passing*0.23+technical*0.14+vision*0.10+decisions*0.08
	elif role in ["winger","wing_back","complete_wing_back","inverted_winger","inside_forward"]: score=ca*0.45+pace*0.22+technical*0.13+crossing*0.10+off_ball*0.10
	elif role in ["advanced_forward","pressing_forward","poacher","complete_forward","shadow_striker"]: score=ca*0.45+finishing*0.25+pace*0.12+off_ball*0.10+decisions*0.08
	elif role in ["target_forward","central_defender","anchor","stopper","cover_defender","half_back"]: score=ca*0.48+strength*0.18+tackling*0.14+marking*0.12+decisions*0.08
	return clampf(score,1.0,100.0)

func style_modifiers(tactic: Dictionary) -> Dictionary:
	ensure_instructions(tactic)
	var mentality := String(tactic.get("mentality","balanced")); var tempo := String(tactic.get("tempo","standard")); var pressing := String(tactic.get("pressing","standard")); var familiarity := float(tactic.get("familiarity",50.0))
	var ip: Dictionary = tactic.instructions.in_possession; var tr: Dictionary = tactic.instructions.transition; var oop: Dictionary = tactic.instructions.out_of_possession
	var possession := 0.0; var shot := 0.0; var pass_mod := 0.0; var card := 0.0; var sequence := 1.0
	match mentality:
		"very_cautious": shot-=0.07; pass_mod+=0.04; possession-=0.02
		"cautious": shot-=0.045; pass_mod+=0.025; possession-=0.01
		"positive": shot+=0.055; possession+=0.015; card+=0.001
		"attacking": shot+=0.085; possession+=0.02; sequence+=0.06; card+=0.003
	match tempo:
		"very_low": sequence-=0.16; pass_mod+=0.05; shot-=0.018
		"low": sequence-=0.10; pass_mod+=0.035; shot-=0.012
		"high": sequence+=0.10; pass_mod-=0.025; shot+=0.018
		"very_high": sequence+=0.16; pass_mod-=0.045; shot+=0.028; card+=0.002
	match pressing:
		"low": possession-=0.012; card-=0.003
		"high": possession+=0.018; card+=0.006
		"very_high": possession+=0.028; card+=0.010; sequence+=0.03
	match String(ip.get("passing_directness","standard")):
		"shorter": pass_mod+=0.035; possession+=0.012; shot-=0.008
		"more_direct": pass_mod-=0.025; possession-=0.008; shot+=0.018; sequence+=0.035
	match String(ip.get("width","standard")):
		"wide": shot+=0.008; pass_mod-=0.005
		"narrow": possession+=0.008; pass_mod+=0.008
	if bool(ip.get("work_ball_into_box",false)): shot-=0.01; pass_mod+=0.015
	if bool(ip.get("shoot_on_sight",false)): shot+=0.03
	if bool(tr.get("counter",false)): shot+=0.018; sequence+=0.025
	if bool(tr.get("counter_press",false)): possession+=0.012; card+=0.003
	if bool(tr.get("regroup",false)): shot-=0.008; card-=0.002
	match String(oop.get("defensive_line","standard")):
		"higher": possession+=0.008; card+=0.002
		"lower": possession-=0.006; shot-=0.004
	if String(oop.get("tackling","standard")) == "harder": card+=0.008
	pass_mod += (familiarity-50.0)/1000.0
	return {"possession":possession,"shot":shot,"pass":pass_mod,"card":card,"sequence_multiplier":clampf(sequence,0.78,1.24)}

func _slot_score(player: Dictionary, slot: String, tactic: Dictionary) -> float:
	var score := role_rating(player,tactic); var position := String(player.get("position",""))
	if position == slot: score += 40.0
	elif _compatible(position,slot): score += 18.0
	var familiarity: Dictionary = player.get("position_familiarity", {})
	if familiarity.has(slot): score += float(familiarity[slot]) * 0.12
	return score * (0.75 + float(player.get("fitness",100))/400.0)

func _compatible(position: String, slot: String) -> bool:
	if position == slot: return true
	var groups := [["DR","DL","WBR","WBL"],["MR","ML","AMR","AML"],["DM","MC","AMC"],["ST","AMC"]]
	for group in groups:
		if position in group and slot in group: return true
	return false

func _role_for_position(tactic: Dictionary, position: String) -> String:
	var roles: Dictionary = tactic.get("roles", {})
	if roles.has(position): return String(roles[position])
	for key in roles.keys():
		if String(key).begins_with(position + "_"): return String(roles[key])
	return "support"

func _default_duty(position: String) -> String:
	if position in ["ST","AMR","AML","AMC"]: return "attack"
	if position in ["GK","DC","DM"]: return "defend"
	return "support"

func _squad_strength(players: Array, club_id: String) -> float:
	var total := 0.0; var count := 0
	for player in players:
		if String(player.get("club_id","")) == club_id and not bool(player.get("retired",false)): total += float(player.get("current_ability",50)); count += 1
	return total/maxf(float(count),1.0)

func _manager_for_club(staff: Array, club_id: String) -> Dictionary:
	for staff_member in staff:
		if String(staff_member.get("club_id","")) == club_id and String(staff_member.get("role","")) == "manager": return staff_member
	return {}

func _find_club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if String(club.get("id","")) == club_id: return club
	return {}

func _stable_index(seed: int, text: String, size: int) -> int:
	var key := seed
	for character in text.to_utf8_buffer(): key = posmod(key*131+int(character),2_147_483_647)
	return SeededRngClass.value_for(seed,key)%maxi(1,size)
