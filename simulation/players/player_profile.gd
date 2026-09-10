class_name PlayerProfile
extends RefCounted

const TECHNICAL := ["finishing","first_touch","passing","technique","dribbling","crossing","tackling","marking","heading","long_shots","set_pieces","penalties"]
const MENTAL := ["anticipation","composure","concentration","decisions","determination","flair","leadership","off_the_ball","positioning","teamwork","vision","work_rate","aggression","bravery"]
const PHYSICAL := ["acceleration","pace","agility","balance","jumping","strength","stamina","natural_fitness"]
const GOALKEEPING := ["handling","reflexes","aerial_reach","one_on_ones","command","kicking","throwing","gk_positioning","communication"]
const HIDDEN := ["consistency","important_matches","professionalism","ambition","loyalty","pressure","temperament","adaptability","injury_proneness","versatility","dirtiness","sportsmanship"]

func ensure(player: Dictionary) -> void:
	var base := clampi(int(player.get("current_ability", 50)), 1, 100)
	var attributes: Dictionary = player.get("attributes", {})
	for name in TECHNICAL + MENTAL + PHYSICAL + GOALKEEPING:
		if not attributes.has(name):
			attributes[name] = base
	player["attributes"] = attributes
	var hidden: Dictionary = player.get("hidden_attributes", {})
	for name in HIDDEN:
		if not hidden.has(name):
			hidden[name] = 50
	player["hidden_attributes"] = hidden
	player["preferred_foot"] = String(player.get("preferred_foot", "right"))
	player["weak_foot"] = clampi(int(player.get("weak_foot", 45)), 1, 100)
	player["height_cm"] = clampi(int(player.get("height_cm", 180)), 150, 210)
	player["weight_kg"] = clampi(int(player.get("weight_kg", 75)), 50, 120)
	player["traits"] = player.get("traits", [])
	player["position_familiarity"] = player.get("position_familiarity", {String(player.get("position", "MC")): 100})

func personality(player: Dictionary) -> String:
	ensure(player)
	var h: Dictionary = player.hidden_attributes
	if int(h.professionalism) >= 75 and int(h.determination) >= 70:
		return "Driven Professional"
	if int(h.ambition) >= 80 and int(h.loyalty) <= 35:
		return "Ambitious Mercenary"
	if int(h.temperament) <= 30:
		return "Temperamental"
	return "Balanced"
