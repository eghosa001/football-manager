extends SceneTree

const SpecialAbilityServiceClass = preload("res://simulation/players/special_ability_service.gd")
const MatchFactorsClass = preload("res://simulation/match/match_factors.gd")

func _init() -> void:
	var abilities = SpecialAbilityServiceClass.new()
	var super_sub := _player("sub", "home", "ST", 72, [SpecialAbilityServiceClass.SUPER_SUB])
	var starter_bonus := abilities.situational_bonus(super_sub, {"minute":70,"score_diff":-1,"came_on":false,"importance":0.5,"phase":"attack"})
	var bench_bonus := abilities.situational_bonus(super_sub, {"minute":70,"score_diff":-1,"came_on":true,"importance":0.5,"phase":"attack"})
	assert(starter_bonus == 0.0, "Super Sub must not activate for a starter")
	assert(bench_bonus >= 6.0, "Super Sub must activate after entering from the bench")

	var keeper := _player("keeper", "home", "GK", 74, [SpecialAbilityServiceClass.THE_WALL])
	assert(abilities.goalkeeper_goal_reduction(keeper, {"importance":0.5}) >= 0.14, "The Wall must reduce goal probability")

	var prodigy := _player("prodigy", "home", "AMC", 58, [SpecialAbilityServiceClass.PRODIGY])
	prodigy["age"] = 18
	prodigy["potential"] = 88
	assert(abilities.development_multiplier(prodigy) > 1.30, "Prodigy must accelerate young-player development")

	var clutch := _player("clutch", "home", "ST", 78, [SpecialAbilityServiceClass.CLUTCH_FINISHER])
	assert(abilities.shot_multiplier(clutch, {"minute":82,"score_diff":0}) > 1.10, "Clutch Finisher must improve late shooting in close matches")
	assert(abilities.shot_multiplier(clutch, {"minute":30,"score_diff":1}) == 1.0, "Clutch Finisher must remain situational")

	var players: Array = []
	for i in range(11):
		players.append(_player("h%02d" % i, "home", "ST" if i == 10 else "MC", 70, [SpecialAbilityServiceClass.BIG_GAME_PLAYER] if i == 10 else []))
		players.append(_player("a%02d" % i, "away", "ST" if i == 10 else "MC", 70, []))
	var home := {"id":"home","reputation":70,"stadium_capacity":30000,"manager_ability":65,"tactic":{"formation":"4-3-3","familiarity":70,"mentality":"balanced"}}
	var away := {"id":"away","reputation":70,"stadium_capacity":30000,"manager_ability":65,"tactic":{"formation":"4-3-3","familiarity":70,"mentality":"balanced"}}
	var factors: Dictionary = MatchFactorsClass.new().breakdown(home, away, players, {"importance":1.0,"stage":"final"})
	assert(float(factors.get("special_abilities", 0.0)) > 0.0, "Special abilities must contribute to match factors")
	assert(factors.get("weights", {}).has("special_abilities"), "Match factor weighting must expose special abilities")

	var assigned := 0
	for i in range(500):
		var candidate := _player("generated-%d" % i, "home", "ST", 65 + (i % 15), [])
		candidate["age"] = 18 + (i % 12)
		candidate["potential"] = mini(98, int(candidate.current_ability) + 20)
		var traits: Array = abilities.assign_for_player(candidate, 55555, i * 101 + 7)
		if not traits.is_empty(): assigned += 1
		assert(traits.size() <= 2, "Players must not receive excessive special abilities")
	assert(assigned > 25 and assigned < 180, "Special abilities should remain uncommon but visible")

	print("[TEST] SPECIAL ABILITY PASS: situational match traits and development traits verified")
	quit(0)

func _player(id: String, club_id: String, position: String, ability: int, traits: Array) -> Dictionary:
	return {
		"id":id,"club_id":club_id,"position":position,"current_ability":ability,"potential":ability + 10,
		"fitness":100,"morale":70,"retired":false,"injured_days":0,"age":25,"special_abilities":traits.duplicate(),
		"attributes":{"finishing":ability,"passing":ability,"stamina":ability,"goalkeeping":ability}
	}
