class_name YouthAcademy
extends RefCounted

const SeededRngClass = preload("res://core/rng/seeded_rng.gd")

func ensure_club(club: Dictionary) -> void:
	club["academy"] = club.get("academy", {"prospects":[],"recruitment":50,"coaching":50,"reputation":40})

func intake_preview(world: Dictionary, club_id: String, seed: int, count: int = 8) -> Array:
	var club := _club(world, club_id)
	if club.is_empty(): return []
	ensure_club(club)
	var result: Array = []
	var base := int(club.academy.recruitment) + int(club.academy.coaching) + int(club.get("reputation", 50))
	for i in range(count):
		var key := _stable_key("%s:%d:%d" % [club_id, int(world.get("season_year", 2026)), i])
		var quality := clampi(int(float(base) / 3.0) + int(SeededRngClass.value_for(seed, key) % 31) - 15, 20, 90)
		var potential := clampi(quality + 10 + int(SeededRngClass.value_for(seed, key + 1) % 26), quality, 99)
		result.append({"id":"academy-preview-%s-%d" % [club_id, i],"position":["GK","DR","DC","DL","DM","MC","AMR","AML","ST"][int(SeededRngClass.value_for(seed,key+2)%9)],"ability":quality,"potential":potential})
	return result

func add_prospect(club: Dictionary, player_id: String) -> void:
	ensure_club(club)
	if player_id not in club.academy.prospects: club.academy.prospects.append(player_id)

func promote(world: Dictionary, club_id: String, player_id: String) -> Error:
	var club := _club(world, club_id); var player := _player(world, player_id)
	if club.is_empty() or player.is_empty(): return ERR_DOES_NOT_EXIST
	ensure_club(club)
	if player_id not in club.academy.prospects: return ERR_INVALID_PARAMETER
	player.club_id = club_id
	player["squad_status"] = "first_team"
	club.academy.prospects.erase(player_id)
	return OK

func release(world: Dictionary, club_id: String, player_id: String) -> Error:
	var club := _club(world, club_id); var player := _player(world, player_id)
	if club.is_empty() or player.is_empty(): return ERR_DOES_NOT_EXIST
	ensure_club(club)
	club.academy.prospects.erase(player_id)
	player.club_id = ""
	player["squad_status"] = "free_agent"
	return OK

func develop_academy(world: Dictionary, club_id: String) -> Dictionary:
	var club := _club(world, club_id)
	if club.is_empty(): return {"error":ERR_DOES_NOT_EXIST}
	ensure_club(club)
	var improved := 0
	for player_id in club.academy.prospects:
		var player := _player(world, String(player_id))
		if player.is_empty(): continue
		var room := maxi(0, int(player.get("potential", 50)) - int(player.get("current_ability", 50)))
		var gain := mini(room, 1 + int(club.academy.coaching) / 45)
		if gain > 0:
			player.current_ability = mini(int(player.potential), int(player.current_ability) + gain)
			improved += 1
	return {"improved":improved,"prospects":club.academy.prospects.size()}

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id: return club
	return {}

func _player(world: Dictionary, player_id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == player_id: return player
	return {}

func _stable_key(text: String) -> int:
	var value := 97
	for c in text.to_utf8_buffer(): value = posmod(value * 193 + int(c), 2_147_483_647)
	return value
