class_name SpecialAbilityService
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

const SUPER_SUB := "super_sub"
const GAMECHANGER := "gamechanger"
const STAR_STRIKER := "star_striker"
const THE_WALL := "the_wall"
const PRODIGY := "prodigy"
const BIG_GAME_PLAYER := "big_game_player"
const CLUTCH_FINISHER := "clutch_finisher"
const MIDFIELD_ENGINE := "midfield_engine"
const MAESTRO := "maestro"
const STOPPER := "stopper"
const SET_PIECE_SPECIALIST := "set_piece_specialist"
const CAPTAIN_FANTASTIC := "captain_fantastic"
const PRESS_RESISTANT := "press_resistant"
const AERIAL_MONSTER := "aerial_monster"
const SPEED_DEMON := "speed_demon"
const LONG_SHOT_SPECIALIST := "long_shot_specialist"
const PENALTY_EXPERT := "penalty_expert"
const INJURY_PRONE := "injury_prone"
const TEMPERAMENTAL := "temperamental"
const CONSISTENT := "consistent"
const INCONSISTENT := "inconsistent"
const DERBY_SPECIALIST := "derby_specialist"
const COMEBACK_KING := "comeback_king"
const ONE_ON_ONE_SPECIALIST := "one_on_one_specialist"

const LABELS := {
	SUPER_SUB: "Super Sub",
	GAMECHANGER: "Gamechanger",
	STAR_STRIKER: "Star Striker",
	THE_WALL: "The Wall",
	PRODIGY: "Prodigy",
	BIG_GAME_PLAYER: "Big Game Player",
	CLUTCH_FINISHER: "Clutch Finisher",
	MIDFIELD_ENGINE: "Midfield Engine",
	MAESTRO: "Maestro",
	STOPPER: "Stopper",
	SET_PIECE_SPECIALIST: "Set Piece Specialist",
	CAPTAIN_FANTASTIC: "Captain Fantastic",
	PRESS_RESISTANT: "Press Resistant",
	AERIAL_MONSTER: "Aerial Monster",
	SPEED_DEMON: "Speed Demon",
	LONG_SHOT_SPECIALIST: "Long Shot Specialist",
	PENALTY_EXPERT: "Penalty Expert",
	INJURY_PRONE: "Injury Prone",
	TEMPERAMENTAL: "Temperamental",
	CONSISTENT: "Consistent",
	INCONSISTENT: "Inconsistent",
	DERBY_SPECIALIST: "Derby Specialist",
	COMEBACK_KING: "Comeback King",
	ONE_ON_ONE_SPECIALIST: "One-on-One Specialist",
}

const NEGATIVE_TRAITS := [INJURY_PRONE, TEMPERAMENTAL, INCONSISTENT]

func assign_for_player(player: Dictionary, seed: int, key: int) -> Array:
	var existing: Array = player.get("special_abilities", [])
	if not existing.is_empty():
		return existing.duplicate()
	var eligible: Array = _eligible(player)
	if eligible.is_empty():
		return []
	var ca: int = int(player.get("current_ability", 50))
	var pa: int = int(player.get("potential", ca))
	var age: int = int(player.get("age", 25))
	var chance: float = 0.10 + clampf(float(ca - 45) / 235.0, 0.0, 0.20)
	if age <= 21 and pa - ca >= 18:
		chance += 0.05
	var result: Array = []
	if SeededRngClass.unit_for(seed, key + 701) <= chance:
		var first_index: int = int(SeededRngClass.value_for(seed, key + 703) % eligible.size())
		result.append(String(eligible[first_index]))
		var second_chance: float = 0.04 + clampf(float(ca - 70) / 450.0, 0.0, 0.06)
		if eligible.size() > 1 and SeededRngClass.unit_for(seed, key + 709) < second_chance:
			var second_index: int = int(SeededRngClass.value_for(seed, key + 711) % eligible.size())
			if second_index == first_index:
				second_index = (second_index + 1) % eligible.size()
			result.append(String(eligible[second_index]))
	# Weaknesses are independent of elite abilities and remain uncommon.
	var weakness_roll: float = SeededRngClass.unit_for(seed, key + 719)
	if weakness_roll < 0.045:
		var weakness_index: int = int(SeededRngClass.value_for(seed, key + 727) % NEGATIVE_TRAITS.size())
		var weakness: String = String(NEGATIVE_TRAITS[weakness_index])
		if weakness == INCONSISTENT and CONSISTENT in result:
			pass
		elif weakness not in result:
			result.append(weakness)
	return result

func labels_for(player: Dictionary) -> Array:
	var result: Array = []
	for ability in player.get("special_abilities", []):
		result.append(String(LABELS.get(String(ability), String(ability).replace("_", " ").capitalize())))
	return result

func has(player: Dictionary, ability: String) -> bool:
	return ability in player.get("special_abilities", [])

func development_multiplier(player: Dictionary) -> float:
	if not has(player, PRODIGY):
		return 1.0
	var age: int = int(player.get("age", 25))
	if age <= 19:
		return 1.40
	if age <= 21:
		return 1.32
	if age <= 23:
		return 1.16
	return 1.0

func match_consistency_multiplier(player: Dictionary, seed: int, match_key: int = 0) -> float:
	if has(player, CONSISTENT):
		return 0.99 + SeededRngClass.unit_for(seed, match_key + _stable_key(String(player.get("id", ""))) + 801) * 0.04
	if has(player, INCONSISTENT):
		return 0.84 + SeededRngClass.unit_for(seed, match_key + _stable_key(String(player.get("id", ""))) + 809) * 0.28
	return 0.96 + SeededRngClass.unit_for(seed, match_key + _stable_key(String(player.get("id", ""))) + 811) * 0.08

func situational_bonus(player: Dictionary, context: Dictionary = {}) -> float:
	var minute: int = int(context.get("minute", 0))
	var importance: float = float(context.get("importance", 0.5))
	var score_diff: int = int(context.get("score_diff", 0))
	var came_on: bool = bool(context.get("came_on", false))
	var phase: String = String(context.get("phase", "general"))
	var derby: bool = bool(context.get("derby", false))
	var under_pressure: bool = bool(context.get("under_pressure", false))
	var bonus: float = 0.0
	if has(player, SUPER_SUB) and came_on and minute >= 55:
		bonus += 8.0 if minute <= 80 else 6.0
	if has(player, GAMECHANGER) and minute >= 55 and score_diff <= 0:
		bonus += 4.0
	if has(player, BIG_GAME_PLAYER) and importance >= 0.80:
		bonus += 4.0 * importance
	if has(player, CLUTCH_FINISHER) and minute >= 75 and score_diff <= 0 and phase in ["attack", "shot", "general", "one_on_one"]:
		bonus += 5.0
	if has(player, STAR_STRIKER) and phase in ["attack", "shot", "one_on_one"]:
		bonus += 3.5
	if has(player, THE_WALL) and phase in ["goalkeeping", "defending", "one_on_one"]:
		bonus += 5.0
	if has(player, MIDFIELD_ENGINE) and minute >= 60 and phase in ["general", "midfield", "defending"]:
		bonus += 2.5
	if has(player, MAESTRO) and phase in ["general", "midfield", "attack"]:
		bonus += 2.5
	if has(player, STOPPER) and phase in ["defending", "goalkeeping", "aerial"]:
		bonus += 3.0
	if has(player, SET_PIECE_SPECIALIST) and phase in ["set_piece", "penalty"]:
		bonus += 7.0
	if has(player, CAPTAIN_FANTASTIC) and (importance >= 0.65 or score_diff < 0):
		bonus += 2.5
	if has(player, PRESS_RESISTANT) and phase in ["midfield", "general"]:
		bonus += 4.0 if under_pressure else 1.5
	if has(player, AERIAL_MONSTER) and phase in ["aerial", "set_piece"]:
		bonus += 5.0
	if has(player, SPEED_DEMON) and phase in ["attack", "general", "one_on_one"]:
		bonus += 2.5
	if has(player, LONG_SHOT_SPECIALIST) and phase == "shot" and bool(context.get("long_shot", false)):
		bonus += 4.0
	if has(player, PENALTY_EXPERT) and phase == "penalty":
		bonus += 8.0
	if has(player, DERBY_SPECIALIST) and derby:
		bonus += 4.0
	if has(player, COMEBACK_KING) and score_diff < 0 and minute >= 50:
		bonus += 4.5
	if has(player, ONE_ON_ONE_SPECIALIST) and phase == "one_on_one":
		bonus += 6.0
	if has(player, CONSISTENT):
		bonus += 1.0
	if has(player, INCONSISTENT):
		bonus -= 1.5
	return clampf(bonus, -5.0, 14.0)

func shot_multiplier(player: Dictionary, context: Dictionary = {}) -> float:
	var multiplier: float = 1.0
	var minute: int = int(context.get("minute", 0))
	var score_diff: int = int(context.get("score_diff", 0))
	if has(player, STAR_STRIKER): multiplier *= 1.14
	if has(player, GAMECHANGER) and minute >= 60 and score_diff <= 0: multiplier *= 1.08
	if has(player, CLUTCH_FINISHER) and minute >= 75 and score_diff <= 0: multiplier *= 1.15
	if has(player, SET_PIECE_SPECIALIST) and bool(context.get("set_piece", false)): multiplier *= 1.16
	if has(player, LONG_SHOT_SPECIALIST) and bool(context.get("long_shot", false)): multiplier *= 1.18
	if has(player, PENALTY_EXPERT) and bool(context.get("penalty", false)): multiplier *= 1.12
	if has(player, ONE_ON_ONE_SPECIALIST) and bool(context.get("one_on_one", false)): multiplier *= 1.16
	if has(player, DERBY_SPECIALIST) and bool(context.get("derby", false)): multiplier *= 1.05
	if has(player, COMEBACK_KING) and score_diff < 0 and minute >= 50: multiplier *= 1.08
	return clampf(multiplier, 0.82, 1.48)

func goalkeeper_goal_reduction(player: Dictionary, context: Dictionary = {}) -> float:
	var reduction: float = 0.0
	if has(player, THE_WALL): reduction += 0.14
	if has(player, BIG_GAME_PLAYER) and float(context.get("importance", 0.5)) >= 0.8: reduction += 0.03
	if has(player, DERBY_SPECIALIST) and bool(context.get("derby", false)): reduction += 0.02
	return clampf(reduction, 0.0, 0.22)

func stamina_retention(player: Dictionary) -> float:
	var retention: float = 0.0
	if has(player, MIDFIELD_ENGINE): retention += 0.18
	if has(player, SPEED_DEMON): retention -= 0.04
	return clampf(retention, -0.08, 0.22)

func aerial_multiplier(player: Dictionary) -> float:
	return 1.20 if has(player, AERIAL_MONSTER) else 1.0

func pace_multiplier(player: Dictionary) -> float:
	return 1.10 if has(player, SPEED_DEMON) else 1.0

func card_probability_multiplier(player: Dictionary) -> float:
	var multiplier: float = 1.0
	if has(player, TEMPERAMENTAL): multiplier *= 1.65
	if has(player, CONSISTENT): multiplier *= 0.92
	return clampf(multiplier, 0.75, 1.80)

func injury_risk_multiplier(player: Dictionary) -> float:
	return 1.55 if has(player, INJURY_PRONE) else 1.0

func leadership_edge(player: Dictionary, context: Dictionary = {}) -> float:
	if not has(player, CAPTAIN_FANTASTIC): return 0.0
	var edge: float = 0.35
	if float(context.get("importance", 0.5)) >= 0.8: edge += 0.20
	if int(context.get("score_diff", 0)) < 0: edge += 0.20
	return edge

func pregame_team_edge(players: Array, club_id: String, context: Dictionary = {}) -> float:
	var candidates: Array = []
	for player in players:
		if String(player.get("club_id", "")) != club_id: continue
		if bool(player.get("retired", false)) or int(player.get("injured_days", 0)) > 0: continue
		candidates.append(player)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("current_ability", 0)) > int(b.get("current_ability", 0)))
	var starters: Array = candidates.slice(0, mini(11, candidates.size()))
	var edge: float = 0.0
	for player in starters:
		if has(player, BIG_GAME_PLAYER) and float(context.get("importance", 0.5)) >= 0.8: edge += 0.35
		if has(player, STAR_STRIKER): edge += 0.18
		if has(player, THE_WALL): edge += 0.22
		if has(player, MAESTRO): edge += 0.15
		if has(player, STOPPER): edge += 0.12
		if has(player, CAPTAIN_FANTASTIC): edge += 0.20
		if has(player, DERBY_SPECIALIST) and bool(context.get("derby", false)): edge += 0.22
		if has(player, CONSISTENT): edge += 0.08
		if has(player, INCONSISTENT): edge -= 0.10
	for player in candidates.slice(mini(11, candidates.size()), mini(18, candidates.size())):
		if has(player, SUPER_SUB): edge += 0.20
		if has(player, GAMECHANGER): edge += 0.10
	return clampf(edge, -1.0, 3.4)

func _eligible(player: Dictionary) -> Array:
	var position: String = String(player.get("position", "MC"))
	var age: int = int(player.get("age", 25))
	var ca: int = int(player.get("current_ability", 50))
	var pa: int = int(player.get("potential", ca))
	var result: Array = []
	if position == "GK":
		result.append(THE_WALL)
		if ca >= 65: result.append(BIG_GAME_PLAYER)
		if ca >= 62: result.append(CONSISTENT)
		return result
	if position in ["ST", "AML", "AMR", "AMC"]:
		result.append(GAMECHANGER)
		result.append(SUPER_SUB)
		result.append(SPEED_DEMON)
		result.append(ONE_ON_ONE_SPECIALIST)
	if position == "ST":
		result.append(STAR_STRIKER)
		result.append(CLUTCH_FINISHER)
	if position in ["MC", "DM", "AMC"]:
		result.append(PRESS_RESISTANT)
		result.append(MAESTRO)
	if position in ["MC", "DM"]:
		result.append(MIDFIELD_ENGINE)
	if position in ["DC", "DM"]:
		result.append(STOPPER)
		result.append(AERIAL_MONSTER)
	if position in ["DC", "DR", "DL", "ST"]:
		result.append(AERIAL_MONSTER)
	if position in ["MC", "AMC", "AML", "AMR", "ST", "DR", "DL"]:
		result.append(SET_PIECE_SPECIALIST)
		result.append(LONG_SHOT_SPECIALIST)
	if position in ["ST", "AMC", "AML", "AMR", "MC"]:
		result.append(PENALTY_EXPERT)
	if age <= 21 and pa - ca >= 15: result.append(PRODIGY)
	if ca >= 68 and age >= 21: result.append(BIG_GAME_PLAYER)
	if ca >= 66 and age >= 24: result.append(CAPTAIN_FANTASTIC)
	if ca >= 62: result.append(CONSISTENT)
	if ca >= 58: result.append(DERBY_SPECIALIST)
	if ca >= 60: result.append(COMEBACK_KING)
	return result

func _stable_key(text: String) -> int:
	var value: int = 97
	for character in text.to_utf8_buffer():
		value = posmod(value * 167 + int(character), 2_147_483_647)
	return value
