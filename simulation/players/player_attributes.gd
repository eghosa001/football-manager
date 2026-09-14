class_name PlayerAttributes
extends RefCounted

const SeededRngClass = preload("res://core/seeded_rng.gd")

const TECHNICAL := ["corners","crossing","dribbling","finishing","first_touch","free_kicks","heading","long_shots","long_throws","marking","passing","penalty_taking","tackling","technique"]
const MENTAL := ["aggression","anticipation","bravery","composure","concentration","decisions","determination","flair","leadership","off_the_ball","positioning","teamwork","vision","work_rate"]
const PHYSICAL := ["acceleration","agility","balance","jumping_reach","natural_fitness","pace","stamina","strength"]
const GOALKEEPING := ["aerial_reach","command_of_area","communication","eccentricity","handling","kicking","one_on_ones","reflexes","rushing_out","throwing"]
const HIDDEN := ["consistency","dirtiness","important_matches","injury_proneness","versatility","adaptability","ambition","loyalty","pressure","professionalism","sportsmanship","temperament"]
const PERSONALITIES := [
	{"name":"Model Professional","professionalism":92,"ambition":82,"loyalty":72,"pressure":85,"sportsmanship":80,"temperament":82},
	{"name":"Professional","professionalism":82,"ambition":70,"loyalty":65,"pressure":75,"sportsmanship":72,"temperament":75},
	{"name":"Driven","professionalism":72,"ambition":90,"loyalty":52,"pressure":78,"sportsmanship":60,"temperament":67},
	{"name":"Resolute","professionalism":76,"ambition":77,"loyalty":62,"pressure":82,"sportsmanship":68,"temperament":78},
	{"name":"Balanced","professionalism":60,"ambition":60,"loyalty":60,"pressure":60,"sportsmanship":60,"temperament":60},
	{"name":"Loyal","professionalism":68,"ambition":52,"loyalty":91,"pressure":65,"sportsmanship":75,"temperament":73},
	{"name":"Fairly Professional","professionalism":70,"ambition":62,"loyalty":62,"pressure":65,"sportsmanship":65,"temperament":68},
	{"name":"Temperamental","professionalism":48,"ambition":70,"loyalty":52,"pressure":48,"sportsmanship":42,"temperament":25},
]

func ensure(player: Dictionary, seed: int) -> Dictionary:
	if not player.has("attributes") or not player.get("attributes") is Dictionary:
		player["attributes"] = generate(player, seed)
	else:
		var attrs: Dictionary = player.attributes
		var missing := false
		for name in TECHNICAL + MENTAL + PHYSICAL:
			if not attrs.has(name):
				missing = true
				break
		if missing:
			var generated := generate(player, seed)
			for name in generated:
				if not attrs.has(name): attrs[name] = generated[name]
	ensure_hidden(player, seed)
	ensure_personality(player, seed)
	ensure_traits(player, seed)
	return player.attributes

func generate(player: Dictionary, seed: int) -> Dictionary:
	var attrs := {}
	var ability := int(player.get("current_ability", player.get("ability", 50)))
	var position := String(player.get("position", "CM"))
	var key := _key(player, seed)
	for i in range(TECHNICAL.size()):
		attrs[TECHNICAL[i]] = _ability_around(ability, 14, seed, key + i * 97)
	for i in range(MENTAL.size()):
		attrs[MENTAL[i]] = _ability_around(ability, 13, seed, key + 1500 + i * 101)
	for i in range(PHYSICAL.size()):
		attrs[PHYSICAL[i]] = _ability_around(ability, 12, seed, key + 3000 + i * 103)
	_apply_position_shaping(attrs, position, seed, key)
	if position == "GK":
		for name in GOALKEEPING:
			attrs[name] = _ability_around(ability + 4, 12, seed, key + _name_key(name))
		attrs["finishing"] = _ability_around(maxi(5, ability - 30), 10, seed, key + 977)
		attrs["long_shots"] = _ability_around(maxi(5, ability - 25), 10, seed, key + 978)
	else:
		for name in GOALKEEPING:
			attrs[name] = _ability_around(12, 8, seed, key + _name_key(name))
	return attrs

func ensure_hidden(player: Dictionary, seed: int) -> void:
	if not player.has("hidden_attributes") or not player.get("hidden_attributes") is Dictionary:
		player["hidden_attributes"] = {}
	var hidden: Dictionary = player.hidden_attributes
	var key := _key(player, seed)
	for i in range(HIDDEN.size()):
		var name: String = HIDDEN[i]
		if hidden.has(name):
			continue
		hidden[name] = 20 + int(SeededRngClass.value_for(seed, key + 5000 + i * 131) % 71)

func ensure_personality(player: Dictionary, seed: int) -> void:
	# Older/migrated saves can contain null/boolean/non-string personality values.
	# Godot 4.7 no longer accepts String(bool), so only preserve a real non-empty
	# string and regenerate every other legacy representation deterministically.
	var existing: Variant = player.get("personality", "")
	if typeof(existing) == TYPE_STRING and not (existing as String).strip_edges().is_empty():
		return
	if typeof(existing) == TYPE_STRING_NAME and not StringName(existing).is_empty():
		player["personality"] = str(existing)
		return
	var hidden: Dictionary = player.get("hidden_attributes", {})
	var best := PERSONALITIES[6]
	var best_score := -999999.0
	for candidate in PERSONALITIES:
		var score := 0.0
		for ptrait in ["professionalism", "ambition", "loyalty", "pressure", "sportsmanship", "temperament"]:
			score -= absf(float(hidden.get(ptrait, 50)) - float(candidate.get(ptrait, 55)))
		score += float(SeededRngClass.value_for(seed, _key(player, seed) + 9000 + PERSONALITIES.find(candidate)) % 7)
		if score > best_score:
			best_score = score
			best = candidate
	player["personality"] = str(best.get("name", "Balanced"))

func ensure_traits(player: Dictionary, seed: int) -> void:
	if player.has("traits") and player.get("traits") is Array:
		return
	var traits: Array = []
	var attrs: Dictionary = player.get("attributes", {})
	if int(attrs.get("pace", 0)) >= 80: traits.append("knocks_ball_past_opponent")
	if int(attrs.get("finishing", 0)) >= 80: traits.append("places_shots")
	if int(attrs.get("vision", 0)) >= 80 and int(attrs.get("passing", 0)) >= 75: traits.append("tries_killer_balls")
	if int(attrs.get("dribbling", 0)) >= 82: traits.append("runs_with_ball_often")
	if int(attrs.get("long_shots", 0)) >= 78: traits.append("shoots_from_distance")
	if int(attrs.get("heading", 0)) >= 78 and int(attrs.get("jumping_reach", 0)) >= 75: traits.append("aerial_threat")
	if traits.is_empty() and int(SeededRngClass.value_for(seed, _key(player, seed) + 9901) % 100) < 18:
		traits.append("simple_passes")
	player["traits"] = traits.slice(0, 3)

func _apply_position_shaping(attrs: Dictionary, position: String, seed: int, key: int) -> void:
	var boosts := {}
	match position:
		"ST": boosts = {"finishing":10,"off_the_ball":8,"composure":6,"heading":4,"pace":4}
		"LW", "RW": boosts = {"dribbling":9,"pace":9,"acceleration":8,"crossing":6,"flair":5}
		"AM": boosts = {"passing":8,"vision":9,"technique":8,"first_touch":7,"flair":6}
		"CM": boosts = {"passing":8,"vision":7,"decisions":6,"teamwork":6,"stamina":5}
		"DM": boosts = {"positioning":8,"tackling":8,"decisions":6,"strength":4,"teamwork":5}
		"LB", "RB", "LWB", "RWB": boosts = {"crossing":7,"pace":6,"stamina":7,"tackling":5,"positioning":5}
		"CB": boosts = {"marking":9,"tackling":9,"positioning":8,"heading":7,"strength":7,"jumping_reach":6}
	for name in boosts:
		attrs[name] = clampi(int(attrs.get(name, 50)) + int(boosts[name]), 1, 100)

func _ability_around(base: int, spread: int, seed: int, key: int) -> int:
	var roll := int(SeededRngClass.value_for(seed, key) % (spread * 2 + 1)) - spread
	return clampi(base + roll, 1, 100)

func _key(player: Dictionary, seed: int) -> int:
	var id := String(player.get("id", player.get("name", "player")))
	return _name_key(id) + seed * 31

func _name_key(text: String) -> int:
	var value := 17
	for i in range(text.length()):
		value = int((value * 131 + text.unicode_at(i)) & 0x7fffffff)
	return value
