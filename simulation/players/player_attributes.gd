class_name PlayerAttributes
extends RefCounted

# Full Football-Manager-style attribute model: technical / mental / physical /
# goalkeeping blocks, hidden attributes, personality, preferred traits (PPMs),
# footedness and positional familiarity. All generation is deterministic from
# (player id, seed); ensure_* functions only ADD missing keys so legacy saves
# and existing regression worlds are never rewritten.

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

const TECHNICAL := ["corners", "crossing", "dribbling", "finishing", "first_touch", "free_kicks", "heading", "long_shots", "long_throws", "marking", "passing", "penalties", "tackling", "technique"]
const MENTAL := ["aggression", "anticipation", "bravery", "composure", "concentration", "decisions", "determination", "flair", "leadership", "off_the_ball", "positioning", "teamwork", "vision", "work_rate"]
const PHYSICAL := ["acceleration", "agility", "balance", "jumping", "natural_fitness", "pace", "stamina", "strength"]
const GOALKEEPING := ["aerial_reach", "command_of_area", "communication", "eccentricity", "handling", "kicking", "one_on_ones", "reflexes", "rushing_out", "throwing"]
const HIDDEN := ["consistency", "big_matches", "injury_proneness", "versatility", "professionalism", "ambition", "loyalty", "pressure", "sportsmanship", "temperament", "controversy", "adaptability", "greed"]

const PERSONALITIES := [
	{"name": "Model Professional", "professionalism": 85, "ambition": 75, "loyalty": 75, "pressure": 75, "sportsmanship": 80, "temperament": 80},
	{"name": "Professional", "professionalism": 72, "ambition": 65, "loyalty": 60, "pressure": 65, "sportsmanship": 65, "temperament": 65},
	{"name": "Resolute", "professionalism": 60, "ambition": 70, "loyalty": 55, "pressure": 55, "sportsmanship": 55, "temperament": 45, "determination": 80},
	{"name": "Driven", "professionalism": 55, "ambition": 85, "loyalty": 40, "pressure": 60, "sportsmanship": 55, "temperament": 55},
	{"name": "Ambitious", "professionalism": 50, "ambition": 80, "loyalty": 35, "pressure": 55, "sportsmanship": 50, "temperament": 55},
	{"name": "Loyal", "professionalism": 60, "ambition": 45, "loyalty": 85, "pressure": 60, "sportsmanship": 65, "temperament": 65},
	{"name": "Balanced", "professionalism": 55, "ambition": 55, "loyalty": 55, "pressure": 55, "sportsmanship": 55, "temperament": 55},
	{"name": "Spirited", "professionalism": 50, "ambition": 60, "loyalty": 50, "pressure": 45, "sportsmanship": 60, "temperament": 40},
	{"name": "Volatile", "professionalism": 35, "ambition": 65, "loyalty": 35, "pressure": 30, "sportsmanship": 35, "temperament": 25},
	{"name": "Casual", "professionalism": 30, "ambition": 40, "loyalty": 55, "pressure": 45, "sportsmanship": 60, "temperament": 60},
]

const TRAITS_BY_POSITION := {
	"GK": ["commands_area", "distributes_quickly", "sweeper_keeper"],
	"DC": ["marks_tightly", "plays_out_from_back", "powerful_header"],
	"DR": ["overlaps", "whips_crosses", "cuts_inside"],
	"DL": ["overlaps", "whips_crosses", "cuts_inside"],
	"DM": ["dictates_tempo", "breaks_up_play", "sprays_passes"],
	"MC": ["arrives_late_in_box", "dictates_tempo", "tries_killer_balls"],
	"AMR": ["cuts_inside", "hugs_touchline", "shoots_from_distance"],
	"AML": ["cuts_inside", "hugs_touchline", "shoots_from_distance"],
	"AMC": ["plays_through_balls", "shoots_from_distance", "finds_pockets"],
	"ST": ["poacher", "holds_up_ball", "beats_offside_trap", "places_shots"],
}

const POSITION_GROUPS := {
	"GK": ["GK"],
	"DEF": ["DR", "DC", "DL", "WBR", "WBL"],
	"MID": ["DM", "MC", "MR", "ML", "AMC", "AMR", "AML", "DMC"],
	"FWD": ["ST"],
}

func ensure(player: Dictionary, seed: int) -> void:
	if player.has("attributes") and player.get("attributes") is Dictionary:
		_top_up_attributes(player, seed)
	else:
		player["attributes"] = generate_attributes(String(player.get("position", "MC")), int(player.get("current_ability", 50)), _key(player, seed), seed)
	ensure_hidden(player, seed)
	ensure_personality(player, seed)
	ensure_traits(player, seed)
	ensure_feet(player, seed)
	ensure_position_familiarity(player, seed)
	if not player.has("market_value") or int(player.get("market_value", 0)) <= 0:
		player["market_value"] = estimate_value(player)

func generate_attributes(position: String, ability: int, key: int, seed: int) -> Dictionary:
	var attrs := {}
	var spread := 14
	for name in TECHNICAL + MENTAL + PHYSICAL:
		attrs[name] = _ability_around(ability, spread, seed, key + _name_key(name))
	# Position shaping: strikers finish, defenders mark/tackle, wingers pace.
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
	if String(player.get("personality", "")) != "":
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
	player["personality"] = String(best.name)

func ensure_traits(player: Dictionary, seed: int) -> void:
	if player.has("traits") and player.get("traits") is Array:
		return
	var pool: Array = TRAITS_BY_POSITION.get(String(player.get("position", "MC")), ["tries_killer_balls", "works_channels"])
	var key := _key(player, seed)
	var count := int(SeededRngClass.value_for(seed, key + 9600) % 3)
	var traits: Array = []
	for i in range(count):
		var ptrait: String = pool[int(SeededRngClass.value_for(seed, key + 9601 + i * 37) % pool.size())]
		if ptrait not in traits:
			traits.append(ptrait)
	player["traits"] = traits

func ensure_feet(player: Dictionary, seed: int) -> void:
	if player.has("preferred_foot"):
		return
	var key := _key(player, seed)
	var roll := int(SeededRngClass.value_for(seed, key + 9700) % 100)
	var foot := "right"
	if roll < 22:
		foot = "left"
	elif roll < 34:
		foot = "both"
	player["preferred_foot"] = foot
	player["weak_foot"] = 1 + int(SeededRngClass.value_for(seed, key + 9701) % 20) if foot != "both" else 14 + int(SeededRngClass.value_for(seed, key + 9702) % 7)

func ensure_position_familiarity(player: Dictionary, seed: int) -> void:
	if player.has("position_familiarity") and player.get("position_familiarity") is Dictionary:
		return
	var main := String(player.get("position", "MC"))
	var fam := {main: 20}
	var group := _group_of(main)
	var key := _key(player, seed)
	for position in TRAITS_BY_POSITION.keys():
		if position == main:
			continue
		var value := 4 + int(SeededRngClass.value_for(seed, key + 9800 + _name_key(position)) % 9)
		if _group_of(position) == group:
			value += 4
		fam[position] = mini(20, value)
	player["position_familiarity"] = fam

func estimate_value(player: Dictionary) -> int:
	var ca := int(player.get("current_ability", 50))
	var pa := int(player.get("potential", ca))
	var age := int(player.get("age", 24))
	var upside := maxi(0, pa - ca)
	var peak := 1.0 if age <= 28 else maxf(0.30, 1.0 - float(age - 28) * 0.09)
	var trait_premium := 1.0 + float(player.get("traits", []).size()) * 0.02
	return maxi(5000, int((ca * ca * 720.0 + upside * 46000.0) * peak * trait_premium))

func attribute_display(player: Dictionary) -> Dictionary:
	var attrs: Dictionary = player.get("attributes", {})
	return {
		"technical": _block_display(attrs, TECHNICAL),
		"mental": _block_display(attrs, MENTAL),
		"physical": _block_display(attrs, PHYSICAL),
		"goalkeeping": _block_display(attrs, GOALKEEPING) if String(player.get("position", "")) == "GK" else [],
	}

func _block_display(attrs: Dictionary, names: Array) -> Array:
	var rows: Array = []
	for name in names:
		rows.append({"name": String(name), "value": clampi(int(attrs.get(name, 50)), 1, 20) if int(attrs.get(name, 50)) <= 20 else clampi(int(attrs.get(name, 50)) / 5, 1, 20), "raw": int(attrs.get(name, 50))})
	return rows

func _top_up_attributes(player: Dictionary, seed: int) -> void:
	var attrs: Dictionary = player.attributes
	var ability := int(player.get("current_ability", 50))
	var key := _key(player, seed)
	for name in TECHNICAL + MENTAL + PHYSICAL:
		if not attrs.has(name):
			attrs[name] = _ability_around(ability, 14, seed, key + _name_key(name))
	if String(player.get("position", "")) == "GK":
		for name in GOALKEEPING:
			if not attrs.has(name):
				attrs[name] = _ability_around(ability + 4, 12, seed, key + _name_key(name))

func _apply_position_shaping(attrs: Dictionary, position: String, seed: int, key: int) -> void:
	var boosts := {}
	match position:
		"ST":
			boosts = {"finishing": 8, "off_the_ball": 6, "composure": 5, "heading": 4, "pace": 3}
		"AMR", "AML":
			boosts = {"dribbling": 7, "crossing": 6, "pace": 6, "technique": 4, "flair": 4}
		"AMC":
			boosts = {"vision": 8, "passing": 6, "technique": 6, "decisions": 5, "first_touch": 4}
		"MC", "DM":
			boosts = {"passing": 6, "vision": 4, "tackling": 5, "positioning": 5, "work_rate": 4, "stamina": 4}
		"DR", "DL":
			boosts = {"crossing": 6, "pace": 5, "stamina": 5, "tackling": 5, "marking": 4}
		"DC":
			boosts = {"marking": 8, "tackling": 7, "heading": 7, "strength": 6, "jumping": 6, "positioning": 5}
		"GK":
			boosts = {"reflexes": 8, "handling": 7, "positioning": 6, "concentration": 5}
	for name in boosts.keys():
		var current := int(attrs.get(name, 50))
		var jitter := int(SeededRngClass.value_for(seed, key + _name_key(String(name)) + 31) % 5) - 2
		attrs[name] = clampi(current + int(boosts[name]) + jitter, 1, 99)

func _ability_around(center: int, spread: int, seed: int, key: int) -> int:
	var span := spread * 2 + 1
	return clampi(center + int(SeededRngClass.value_for(seed, key) % span) - spread, 1, 99)

func _group_of(position: String) -> String:
	for group in POSITION_GROUPS:
		if position in POSITION_GROUPS[group]:
			return String(group)
	return "MID"

func _name_key(text: String) -> int:
	var value := 17
	for c in text.to_utf8_buffer():
		value = posmod(value * 139 + int(c), 2_147_483_647)
	return value

func _key(player: Dictionary, seed: int) -> int:
	var value := 101 + seed
	for c in String(player.get("id", "player")).to_utf8_buffer():
		value = posmod(value * 173 + int(c), 2_147_483_647)
	return value
