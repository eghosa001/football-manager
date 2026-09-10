class_name WorldInspector
extends RefCounted

func summarize(world: Dictionary) -> Dictionary:
	var active_players := 0
	var retired_players := 0
	var free_agents := 0
	var total_cash := 0
	for player in world.get("players", []):
		if bool(player.get("retired", false)):
			retired_players += 1
		else:
			active_players += 1
			if String(player.get("club_id", "")) == "":
				free_agents += 1
	for club in world.get("clubs", []):
		total_cash += int(club.get("cash", 0))
	return {
		"season_year": int(world.get("season_year", 0)),
		"countries": world.get("countries", []).size(),
		"clubs": world.get("clubs", []).size(),
		"competitions": world.get("competitions", []).size(),
		"players_active": active_players,
		"players_retired": retired_players,
		"free_agents": free_agents,
		"staff": world.get("staff", []).size(),
		"contracts": world.get("contracts", []).size(),
		"total_club_cash": total_cash,
		"relationships": world.get("relationships", []).size(),
		"news": world.get("news", []).size()
	}

func validate(world: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var club_ids := {}
	for club in world.get("clubs", []):
		var id := String(club.get("id", ""))
		if id == "" or club_ids.has(id):
			errors.append("duplicate/empty club id: %s" % id)
		club_ids[id] = true
	for player in world.get("players", []):
		var club_id := String(player.get("club_id", ""))
		if club_id != "" and not club_ids.has(club_id):
			errors.append("player %s references missing club %s" % [player.get("id", "?"), club_id])
	for fixture in world.get("fixtures", []):
		if not club_ids.has(String(fixture.get("home_club_id", ""))) or not club_ids.has(String(fixture.get("away_club_id", ""))):
			errors.append("fixture %s has broken club reference" % fixture.get("id", "?"))
	return errors
