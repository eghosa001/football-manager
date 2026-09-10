class_name RecruitmentFocus
extends RefCounted

func shortlist(world: Dictionary, club_id: String, position: String, min_ability: int = 0, max_age: int = 40, limit: int = 25) -> Array:
	var scored: Array = []
	var knowledge: Dictionary = world.get("scouting_knowledge", {})
	for player in world.get("players", []):
		if bool(player.get("retired", false)):
			continue
		if String(player.get("club_id", "")) == club_id:
			continue
		if position != "" and String(player.get("position", "")) != position:
			continue
		if int(player.get("age", 99)) > max_age or int(player.get("current_ability", 0)) < min_ability:
			continue
		var seen: float = float(knowledge.get(String(player.id), 0.0))
		var score: float = float(player.get("current_ability", 0)) * 0.65 + float(player.get("potential", 0)) * 0.25 + seen * 10.0
		scored.append({"player_id":String(player.id),"score":score,"knowledge":seen})
	scored.sort_custom(func(a: Dictionary, b: Dictionary):
		if is_equal_approx(float(a.score), float(b.score)):
			return String(a.player_id) < String(b.player_id)
		return float(a.score) > float(b.score)
	)
	if scored.size() > limit:
		scored.resize(limit)
	return scored

func squad_needs(players: Array, club_id: String) -> Array[String]:
	var counts := {"GK":0,"DC":0,"FB":0,"MID":0,"WIDE":0,"ST":0}
	for player in players:
		if String(player.get("club_id", "")) != club_id or bool(player.get("retired", false)):
			continue
		match String(player.get("position", "")):
			"GK": counts.GK += 1
			"DC": counts.DC += 1
			"DR", "DL": counts.FB += 1
			"DM", "MC", "AMC": counts.MID += 1
			"MR", "ML", "AMR", "AML": counts.WIDE += 1
			"ST": counts.ST += 1
	var needs: Array[String] = []
	if int(counts.GK) < 2: needs.append("GK")
	if int(counts.DC) < 4: needs.append("DC")
	if int(counts.FB) < 4: needs.append("FB")
	if int(counts.MID) < 5: needs.append("MID")
	if int(counts.WIDE) < 4: needs.append("WIDE")
	if int(counts.ST) < 3: needs.append("ST")
	return needs
