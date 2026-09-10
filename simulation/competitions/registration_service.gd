class_name RegistrationService
extends RefCounted

func ensure_world(world: Dictionary) -> void:
	world["registrations"] = world.get("registrations", {})

func eligibility(player: Dictionary, competition: Dictionary, season_year: int) -> Dictionary:
	var rules: Dictionary = competition.get("registration_rules", {})
	var age := int(player.get("age", 0))
	var nationality := String(player.get("country_id", ""))
	var home_country := String(competition.get("country_id", ""))
	var homegrown := bool(player.get("homegrown", false)) or nationality == home_country
	var reasons: Array[String] = []
	if bool(player.get("retired", false)):
		reasons.append("retired")
	if int(player.get("suspended_until_year", 0)) > season_year:
		reasons.append("suspended")
	var min_age := int(rules.get("min_age", 15))
	if age < min_age:
		reasons.append("too_young")
	return {"eligible":reasons.is_empty(),"reasons":reasons,"homegrown":homegrown,"foreign":home_country != "" and nationality != "" and nationality != home_country,"u21":age <= 21}

func register_squad(world: Dictionary, club_id: String, competition: Dictionary, player_ids: Array, season_year: int) -> Dictionary:
	ensure_world(world)
	var rules: Dictionary = competition.get("registration_rules", {})
	var max_squad := int(rules.get("max_squad", 25))
	var min_homegrown := int(rules.get("min_homegrown", 0))
	var min_goalkeepers := int(rules.get("min_goalkeepers", 0))
	var max_foreign := int(rules.get("max_foreign", 99))
	var accepted: Array = []
	var rejected: Array = []
	var homegrown_count := 0
	var foreign_count := 0
	var goalkeeper_count := 0
	for player_id in player_ids:
		var player := _player(world, String(player_id))
		if player.is_empty() or String(player.get("club_id", "")) != club_id:
			rejected.append({"player_id":String(player_id),"reason":"not_at_club"})
			continue
		var check: Dictionary = eligibility(player, competition, season_year)
		if not bool(check.eligible):
			rejected.append({"player_id":String(player_id),"reason":String(check.reasons[0])})
			continue
		if accepted.size() >= max_squad and not bool(check.u21):
			rejected.append({"player_id":String(player_id),"reason":"squad_full"})
			continue
		if bool(check.foreign) and foreign_count >= max_foreign:
			rejected.append({"player_id":String(player_id),"reason":"foreign_limit"})
			continue
		accepted.append(String(player_id))
		if bool(check.homegrown): homegrown_count += 1
		if bool(check.foreign): foreign_count += 1
		if String(player.get("position", "")) == "GK": goalkeeper_count += 1
	var valid := homegrown_count >= mini(min_homegrown, accepted.size()) and goalkeeper_count >= mini(min_goalkeepers, accepted.size())
	var key := _key(club_id, String(competition.get("id", "competition")), season_year)
	world.registrations[key] = {"club_id":club_id,"competition_id":String(competition.get("id", "")),"season_year":season_year,"player_ids":accepted.duplicate(),"homegrown":homegrown_count,"foreign":foreign_count,"goalkeepers":goalkeeper_count,"valid":valid}
	return {"valid":valid,"registered":accepted,"rejected":rejected,"homegrown":homegrown_count,"foreign":foreign_count,"goalkeepers":goalkeeper_count}

func auto_register_world(world: Dictionary, season_year: int) -> Dictionary:
	ensure_world(world)
	var registered := 0
	var invalid := 0
	for competition in world.get("competitions", []):
		for club_id in competition.get("club_ids", []):
			var candidates: Array = []
			for player in world.get("players", []):
				if String(player.get("club_id", "")) == String(club_id) and not bool(player.get("retired", false)):
					candidates.append(player)
			candidates.sort_custom(func(a: Dictionary, b: Dictionary):
				var a_gk := 1 if String(a.get("position", "")) == "GK" else 0
				var b_gk := 1 if String(b.get("position", "")) == "GK" else 0
				if a_gk != b_gk: return a_gk > b_gk
				var aa := int(a.get("current_ability", 0)); var bb := int(b.get("current_ability", 0))
				if aa == bb: return String(a.get("id", "")) < String(b.get("id", ""))
				return aa > bb
			)
			var ids: Array = []
			for player in candidates: ids.append(String(player.get("id", "")))
			var result: Dictionary = register_squad(world, String(club_id), competition, ids, season_year)
			registered += 1
			if not bool(result.get("valid", false)): invalid += 1
	return {"registered":registered,"invalid":invalid}

func registered_players(world: Dictionary, club_id: String, competition_id: String, season_year: int) -> Array:
	ensure_world(world)
	var key := _key(club_id, competition_id, season_year)
	if not world.registrations.has(key): return []
	var ids: Array = world.registrations[key].get("player_ids", [])
	var players: Array = []
	for player in world.get("players", []):
		if String(player.get("id", "")) in ids: players.append(player)
	return players

func is_registered(world: Dictionary, club_id: String, competition_id: String, season_year: int, player_id: String) -> bool:
	ensure_world(world)
	var key := _key(club_id, competition_id, season_year)
	return player_id in world.registrations.get(key, {}).get("player_ids", [])

func _key(club_id: String, competition_id: String, season_year: int) -> String:
	return "%s:%s:%d" % [club_id, competition_id, season_year]

func _player(world: Dictionary, player_id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == player_id: return player
	return {}
