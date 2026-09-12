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
}

func assign_for_player(player: Dictionary, seed: int, key: int) -> Array:
	var existing: Array = player.get("special_abilities", [])
	if not existing.is_empty():
		return existing.duplicate()
	var eligible := _eligible(player)
	if eligible.is_empty():
		return []
	var ca := int(player.get("current_ability", 50))
	var pa := int(player.get("potential", ca))
	var age := int(player.get("age", 25))
	var chance := 0.08 + clampf(float(ca - 45) / 240.0, 0.0, 0.18)
	if age <= 21 and pa - ca >= 18:
		chance += 0.05
	if SeededRngClass.unit_for(seed, key + 701) > chance:
		return []
	var first_index := int(SeededRngClass.value_for(seed, key + 703) % eligible.size())
	var result: Array = [String(eligible[first_index])]
	var second_chance := 0.035 + clampf(float(ca - 70) / 500.0, 0.0, 0.05)
	if eligible.size() > 1 and SeededRngClass.unit_for(seed, key + 709) < second_chance:
		var second_index := int(SeededRngClass.value_for(seed, key + 711) % eligible.size())
		if second_index == first_index:
			second_index = (second_index + 1) % eligible.size()
		result.append(String(eligible[second_index]))
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
	var age := int(player.get("age", 25))
	if age <= 19:
		return 1.40
	if age <= 21:
		return 1.32
	if age <= 23:
		return 1.16
	return 1.0

func situational_bonus(player: Dictionary, context: Dictionary = {}) -> float:
	var minute := int(context.get("minute", 0))
	var importance := float(context.get("importance", 0.5))
	var score_diff := int(context.get("score_diff", 0))
	var came_on := bool(context.get("came_on", false))
	var phase := String(context.get("phase", "general"))
	var bonus := 0.0
	if has(player, SUPER_SUB) and came_on and minute >= 55:
		bonus += 8.0 if minute <= 80 else 6.0
	if has(player, GAMECHANGER) and minute >= 55 and score_diff <= 0:
		bonus += 4.0
	if has(player, BIG_GAME_PLAYER) and importance >= 0.80:
		bonus += 4.0 * importance
	if has(player, CLUTCH_FINISHER) and minute >= 75 and score_diff <= 0 and phase in ["attack", "shot", "general"]:
		bonus += 5.0
	if has(player, STAR_STRIKER) and phase in ["attack", "shot"]:
		bonus += 3.5
	if has(player, THE_WALL) and phase in ["goalkeeping", "defending"]:
		bonus += 5.0
	if has(player, MIDFIELD_ENGINE) and minute >= 60 and phase in ["general", "midfield", "defending"]:
		bonus += 2.5
	if has(player, MAESTRO) and phase in ["general", "midfield", "attack"]:
		bonus += 2.5
	if has(player, STOPPER) and phase in ["defending", "goalkeeping"]:
		bonus += 3.0
	if has(player, SET_PIECE_SPECIALIST) and phase == "set_piece":
		bonus += 7.0
	return clampf(bonus, 0.0, 12.0)

func shot_multiplier(player: Dictionary, context: Dictionary = {}) -> float:
	var multiplier := 1.0
	if has(player, STAR_STRIKER):
		multiplier *= 1.14
	if has(player, GAMECHANGER) and int(context.get("minute", 0)) >= 60 and int(context.get("score_diff", 0)) <= 0:
		multiplier *= 1.08
	if has(player, CLUTCH_FINISHER) and int(context.get("minute", 0)) >= 75 and int(context.get("score_diff", 0)) <= 0:
		multiplier *= 1.15
	if has(player, SET_PIECE_SPECIALIST) and bool(context.get("set_piece", false)):
		multiplier *= 1.16
	return clampf(multiplier, 1.0, 1.36)

func goalkeeper_goal_reduction(player: Dictionary, context: Dictionary = {}) -> float:
	var reduction := 0.0
	if has(player, THE_WALL):
		reduction += 0.14
	if has(player, BIG_GAME_PLAYER) and float(context.get("importance", 0.5)) >= 0.8:
		reduction += 0.03
	return clampf(reduction, 0.0, 0.20)

func stamina_retention(player: Dictionary) -> float:
	return 0.18 if has(player, MIDFIELD_ENGINE) else 0.0

func pregame_team_edge(players: Array, club_id: String, context: Dictionary = {}) -> float:
	var candidates: Array = []
	for player in players:
		if String(player.get("club_id", "")) != club_id:
			continue
		if bool(player.get("retired", false)) or int(player.get("injured_days", 0)) > 0:
			continue
		candidates.append(player)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("current_ability", 0)) > int(b.get("current_ability", 0)))
	var starters: Array = candidates.slice(0, mini(11, candidates.size()))
	var edge := 0.0
	for player in starters:
		if has(player, BIG_GAME_PLAYER) and float(context.get("importance", 0.5)) >= 0.8:
			edge += 0.35
		if has(player, STAR_STRIKER): edge += 0.18
		if has(player, THE_WALL): edge += 0.22
		if has(player, MAESTRO): edge += 0.15
		if has(player, STOPPER): edge += 0.12
	# A dangerous bench matters, but far less than the starting XI.
	for player in candidates.slice(mini(11, candidates.size()), mini(18, candidates.size())):
		if has(player, SUPER_SUB): edge += 0.20
		if has(player, GAMECHANGER): edge += 0.10
	return clampf(edge, 0.0, 2.8)

func _eligible(player: Dictionary) -> Array:
	var position := String(player.get("position", "MC"))
	var age := int(player.get("age", 25))
	var ca := int(player.get("current_ability", 50))
	var pa := int(player.get("potential", ca))
	var result: Array = []
	if position == "GK":
		result.append(THE_WALL)
		if ca >= 65: result.append(BIG_GAME_PLAYER)
		return result
	if position in ["ST", "AML", "AMR", "AMC"]:
		result.append(GAMECHANGER)
		result.append(SUPER_SUB)
	if position == "ST":
		result.append(STAR_STRIKER)
		result.append(CLUTCH_FINISHER)
	if position in ["MC", "DM"]:
		result.append(MIDFIELD_ENGINE)
		result.append(MAESTRO)
	if position in ["DC", "DM"]:
		result.append(STOPPER)
	if position in ["MC", "AMC", "AML", "AMR", "ST", "DR", "DL"]:
		result.append(SET_PIECE_SPECIALIST)
	if age <= 21 and pa - ca >= 15:
		result.append(PRODIGY)
	if ca >= 68 and age >= 21:
		result.append(BIG_GAME_PLAYER)
	return result
