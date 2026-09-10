class_name TacticsManager
extends RefCounted

const FORMATIONS := {
	"4-3-3": ["GK", "DR", "DC", "DC", "DL", "DM", "MC", "MC", "AMR", "AML", "ST"],
	"4-2-3-1": ["GK", "DR", "DC", "DC", "DL", "DM", "MC", "AMR", "AMC", "AML", "ST"],
	"4-4-2": ["GK", "DR", "DC", "DC", "DL", "MR", "MC", "MC", "ML", "ST", "ST"],
}

const ROLES := {
	"GK": ["goalkeeper", "sweeper_keeper"],
	"DR": ["full_back", "wing_back"],
	"DL": ["full_back", "wing_back"],
	"DC": ["central_defender", "ball_playing_defender"],
	"DM": ["anchor", "deep_lying_playmaker"],
	"MC": ["central_midfielder", "box_to_box", "playmaker"],
	"MR": ["winger", "wide_midfielder"],
	"ML": ["winger", "wide_midfielder"],
	"AMR": ["winger", "inside_forward"],
	"AML": ["winger", "inside_forward"],
	"AMC": ["attacking_midfielder", "playmaker"],
	"ST": ["advanced_forward", "target_forward", "pressing_forward"],
}

func ensure_world(world: Dictionary, seed: int) -> void:
	for staff_member in world.staff:
		if String(staff_member.role) != "manager":
			continue
		if not staff_member.has("manager_profile"):
			var index: int = _stable_index(seed, String(staff_member.id), FORMATIONS.size())
			var formation_names: Array = FORMATIONS.keys()
			formation_names.sort()
			staff_member["manager_profile"] = {
				"preferred_formation": formation_names[index],
				"mentality": ["cautious", "balanced", "positive"][_stable_index(seed + 11, String(staff_member.id), 3)],
				"tempo": ["low", "standard", "high"][_stable_index(seed + 17, String(staff_member.id), 3)],
				"pressing": ["low", "standard", "high"][_stable_index(seed + 23, String(staff_member.id), 3)],
			}
	for club in world.clubs:
		if not club.has("tactic"):
			var manager: Dictionary = _manager_for_club(world.staff, String(club.id))
			var profile: Dictionary = manager.get("manager_profile", {})
			club["tactic"] = create_tactic(
				String(profile.get("preferred_formation", "4-3-3")),
				String(profile.get("mentality", "balanced")),
				String(profile.get("tempo", "standard")),
				String(profile.get("pressing", "standard"))
			)

func create_tactic(formation: String, mentality: String = "balanced", tempo: String = "standard", pressing: String = "standard") -> Dictionary:
	if not FORMATIONS.has(formation):
		formation = "4-3-3"
	var roles := {}
	var duties := {}
	for position in FORMATIONS[formation]:
		if not roles.has(position):
			roles[position] = String(ROLES.get(position, ["support"])[0])
			duties[position] = "support"
	return {
		"formation": formation,
		"mentality": mentality,
		"tempo": tempo,
		"pressing": pressing,
		"roles": roles,
		"duties": duties,
		"familiarity": 50.0,
	}

func train_tactic(club: Dictionary, sessions: int = 1) -> void:
	if not club.has("tactic"):
		club["tactic"] = create_tactic("4-3-3")
	club.tactic.familiarity = clampf(float(club.tactic.get("familiarity", 50.0)) + sessions * 1.5, 0.0, 100.0)

func ai_choose_tactic(world: Dictionary, club_id: String, opponent_id: String, seed: int) -> Dictionary:
	ensure_world(world, seed)
	var club: Dictionary = _find_club(world.clubs, club_id)
	var opponent: Dictionary = _find_club(world.clubs, opponent_id)
	if club.is_empty():
		return create_tactic("4-3-3")
	var base: Dictionary = club.tactic.duplicate(true)
	var own_strength: float = _squad_strength(world.players, club_id)
	var opponent_strength: float = _squad_strength(world.players, opponent_id)
	if own_strength > opponent_strength + 5.0:
		base.mentality = "positive"
		base.tempo = "high"
	elif own_strength + 5.0 < opponent_strength:
		base.mentality = "cautious"
		base.tempo = "low"
	else:
		base.mentality = "balanced"
	if not opponent.is_empty() and int(opponent.get("reputation", 50)) > int(club.get("reputation", 50)) + 10:
		base.pressing = "standard"
	return base

func select_lineup(players: Array, club_id: String, tactic: Dictionary) -> Array:
	var squad: Array = []
	for player in players:
		if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)) and int(player.get("injured_days", 0)) <= 0:
			squad.append(player)
	if squad.size() < 11:
		for player in players:
			if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)) and not squad.has(player):
				squad.append(player)
	var slots: Array = FORMATIONS.get(String(tactic.get("formation", "4-3-3")), FORMATIONS["4-3-3"])
	var selected: Array = []
	var remaining: Array = squad.duplicate()
	for slot in slots:
		if remaining.is_empty():
			break
		var best_index := 0
		var best_score := -999999.0
		for i in range(remaining.size()):
			var score: float = _slot_score(remaining[i], String(slot), tactic)
			if score > best_score or (is_equal_approx(score, best_score) and String(remaining[i].id) < String(remaining[best_index].id)):
				best_index = i
				best_score = score
		selected.append(remaining[best_index])
		remaining.remove_at(best_index)
	return selected

func role_rating(player: Dictionary, tactic: Dictionary) -> float:
	var position: String = String(player.get("position", "MC"))
	var role: String = String(tactic.get("roles", {}).get(position, "support"))
	var attributes: Dictionary = player.get("attributes", {})
	var technical: float = float(attributes.get("technique", player.get("current_ability", 50)))
	var passing: float = float(attributes.get("passing", player.get("current_ability", 50)))
	var pace: float = float(attributes.get("pace", player.get("current_ability", 50)))
	var strength: float = float(attributes.get("strength", player.get("current_ability", 50)))
	var finishing: float = float(attributes.get("finishing", player.get("current_ability", 50)))
	var score: float = float(player.get("current_ability", 50))
	if role in ["playmaker", "deep_lying_playmaker", "ball_playing_defender"]:
		score = score * 0.55 + passing * 0.3 + technical * 0.15
	elif role in ["winger", "wing_back", "inside_forward"]:
		score = score * 0.55 + pace * 0.3 + technical * 0.15
	elif role in ["advanced_forward", "pressing_forward"]:
		score = score * 0.55 + finishing * 0.3 + pace * 0.15
	elif role in ["target_forward", "central_defender", "anchor"]:
		score = score * 0.6 + strength * 0.4
	return clampf(score, 1.0, 100.0)

func style_modifiers(tactic: Dictionary) -> Dictionary:
	var mentality: String = String(tactic.get("mentality", "balanced"))
	var tempo: String = String(tactic.get("tempo", "standard"))
	var pressing: String = String(tactic.get("pressing", "standard"))
	var familiarity: float = float(tactic.get("familiarity", 50.0))
	var possession := 0.0
	var shot := 0.0
	var pass := 0.0
	var card := 0.0
	var sequence_multiplier := 1.0
	if mentality == "positive":
		shot += 0.055
		possession += 0.015
		card += 0.001
	elif mentality == "cautious":
		shot -= 0.045
		pass += 0.025
		possession -= 0.01
	if tempo == "high":
		sequence_multiplier += 0.10
		pass -= 0.025
		shot += 0.018
	elif tempo == "low":
		sequence_multiplier -= 0.10
		pass += 0.035
		shot -= 0.012
	if pressing == "high":
		possession += 0.018
		card += 0.006
	elif pressing == "low":
		possession -= 0.012
		card -= 0.003
	var familiarity_bonus: float = (familiarity - 50.0) / 1000.0
	pass += familiarity_bonus
	return {
		"possession": possession,
		"shot": shot,
		"pass": pass,
		"card": card,
		"sequence_multiplier": clampf(sequence_multiplier, 0.82, 1.18),
	}

func _slot_score(player: Dictionary, slot: String, tactic: Dictionary) -> float:
	var score: float = role_rating(player, tactic)
	var position: String = String(player.get("position", ""))
	if position == slot:
		score += 40.0
	elif _compatible(position, slot):
		score += 18.0
	return score * (0.75 + float(player.get("fitness", 100)) / 400.0)

func _compatible(position: String, slot: String) -> bool:
	if position == slot:
		return true
	var wide := [["DR", "DL"], ["MR", "ML", "AMR", "AML"], ["DM", "MC", "AMC"], ["ST", "AMC"]]
	for group in wide:
		if position in group and slot in group:
			return true
	return false

func _squad_strength(players: Array, club_id: String) -> float:
	var total := 0.0
	var count := 0
	for player in players:
		if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)):
			total += float(player.get("current_ability", 50))
			count += 1
	return total / maxf(float(count), 1.0)

func _manager_for_club(staff: Array, club_id: String) -> Dictionary:
	for staff_member in staff:
		if String(staff_member.club_id) == club_id and String(staff_member.role) == "manager":
			return staff_member
	return {}

func _find_club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if String(club.id) == club_id:
			return club
	return {}

func _stable_index(seed: int, text: String, size: int) -> int:
	var key := seed
	for character in text.to_utf8_buffer():
		key = posmod(key * 131 + int(character), 2_147_483_647)
	return SeededRngClass.value_for(seed, key) % size
