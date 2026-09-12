extends SceneTree

const SpecialAbilityServiceClass = preload("res://simulation/players/special_ability_service.gd")
const MatchFactorsClass = preload("res://simulation/match/match_factors.gd")
const MedicalSystemClass = preload("res://simulation/players/medical_system.gd")

func _init() -> void:
	var abilities = SpecialAbilityServiceClass.new()
	var super_sub := _player("sub", "home", "ST", 72, [SpecialAbilityServiceClass.SUPER_SUB])
	var starter_bonus: float = abilities.situational_bonus(super_sub, {"minute":70,"score_diff":-1,"came_on":false,"importance":0.5,"phase":"attack"})
	var bench_bonus: float = abilities.situational_bonus(super_sub, {"minute":70,"score_diff":-1,"came_on":true,"importance":0.5,"phase":"attack"})
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

	var derby := _player("derby", "home", "MC", 72, [SpecialAbilityServiceClass.DERBY_SPECIALIST])
	assert(abilities.situational_bonus(derby, {"minute":40,"score_diff":0,"derby":true,"phase":"general"}) >= 4.0, "Derby Specialist must activate in derbies")
	assert(abilities.situational_bonus(derby, {"minute":40,"score_diff":0,"derby":false,"phase":"general"}) == 0.0, "Derby Specialist must remain contextual")

	var comeback := _player("comeback", "home", "AMC", 73, [SpecialAbilityServiceClass.COMEBACK_KING])
	assert(abilities.situational_bonus(comeback, {"minute":65,"score_diff":-1,"phase":"attack"}) >= 4.0, "Comeback King must activate while trailing")
	assert(abilities.situational_bonus(comeback, {"minute":65,"score_diff":1,"phase":"attack"}) == 0.0, "Comeback King must not activate while leading")

	var press_resistant := _player("press", "home", "MC", 73, [SpecialAbilityServiceClass.PRESS_RESISTANT])
	assert(abilities.situational_bonus(press_resistant, {"minute":35,"score_diff":0,"phase":"midfield","under_pressure":true}) >= 4.0, "Press Resistant must improve pressured midfield actions")

	var aerial := _player("aerial", "home", "DC", 73, [SpecialAbilityServiceClass.AERIAL_MONSTER])
	assert(abilities.aerial_multiplier(aerial) >= 1.20, "Aerial Monster must improve aerial contests")

	var penalty := _player("penalty", "home", "ST", 73, [SpecialAbilityServiceClass.PENALTY_EXPERT])
	assert(abilities.shot_multiplier(penalty, {"penalty":true}) > 1.10, "Penalty Expert must improve penalty finishing")

	var one_on_one := _player("one-on-one", "home", "ST", 73, [SpecialAbilityServiceClass.ONE_ON_ONE_SPECIALIST])
	assert(abilities.shot_multiplier(one_on_one, {"one_on_one":true}) > 1.10, "One-on-One Specialist must improve one-on-one finishing")

	var temperamental := _player("temper", "home", "DC", 70, [SpecialAbilityServiceClass.TEMPERAMENTAL])
	assert(abilities.card_probability_multiplier(temperamental) > 1.5, "Temperamental must raise disciplinary risk")

	var injury_prone := _player("fragile", "home", "MC", 70, [SpecialAbilityServiceClass.INJURY_PRONE])
	var normal := _player("normal", "home", "MC", 70, [])
	var medical = MedicalSystemClass.new()
	var fragile_risk: Dictionary = medical.injury_risk(injury_prone, {"base_risk":0.01,"fatigue":60,"match_intensity":1.0})
	var normal_risk: Dictionary = medical.injury_risk(normal, {"base_risk":0.01,"fatigue":60,"match_intensity":1.0})
	assert(float(fragile_risk.probability) > float(normal_risk.probability), "Injury Prone must increase true medical injury probability")

	var consistent := _player("consistent", "home", "MC", 70, [SpecialAbilityServiceClass.CONSISTENT])
	var inconsistent := _player("inconsistent", "home", "MC", 70, [SpecialAbilityServiceClass.INCONSISTENT])
	var consistent_values: Array = []
	var inconsistent_values: Array = []
	for i in range(20):
		consistent_values.append(abilities.match_consistency_multiplier(consistent, 7000 + i, i))
		inconsistent_values.append(abilities.match_consistency_multiplier(inconsistent, 7000 + i, i))
	assert(_range(inconsistent_values) > _range(consistent_values) * 2.0, "Inconsistent must create much wider match-to-match variation")

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
	var weaknesses := 0
	for i in range(500):
		var candidate := _player("generated-%d" % i, "home", "ST", 65 + (i % 15), [])
		candidate["age"] = 18 + (i % 12)
		candidate["potential"] = mini(98, int(candidate.current_ability) + 20)
		var traits: Array = abilities.assign_for_player(candidate, 55555, i * 101 + 7)
		if not traits.is_empty(): assigned += 1
		for trait in traits:
			if String(trait) in SpecialAbilityServiceClass.NEGATIVE_TRAITS: weaknesses += 1
		assert(traits.size() <= 3, "Players must not receive excessive special abilities")
	assert(assigned > 30 and assigned < 210, "Special abilities should remain uncommon but visible")
	assert(weaknesses > 5 and weaknesses < 60, "Negative traits should be uncommon but present")

	print("[TEST] SPECIAL ABILITY PASS: advanced contextual strengths, weaknesses and development traits verified")
	quit(0)

func _range(values: Array) -> float:
	var lo: float = INF
	var hi: float = -INF
	for value in values:
		lo = minf(lo, float(value))
		hi = maxf(hi, float(value))
	return hi - lo

func _player(id: String, club_id: String, position: String, ability: int, traits: Array) -> Dictionary:
	return {
		"id":id,"club_id":club_id,"position":position,"current_ability":ability,"potential":ability + 10,
		"fitness":100,"fatigue":20,"morale":70,"retired":false,"injured_days":0,"age":25,"special_abilities":traits.duplicate(),
		"attributes":{"finishing":ability,"passing":ability,"stamina":ability,"goalkeeping":ability,"pace":ability,"acceleration":ability,"heading":ability,"jumping":ability}
	}
