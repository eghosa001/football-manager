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
	var max_foreign := int(rules.get("max_foreign", 99))
	var accepted: Array = []
	var rejected: Array = []
	var homegrown_count := 0
	var foreign_count := 0
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
	var valid := homegrown_count >= mini(min_homegrown, accepted.size())
	var key := "%s:%s:%d" % [club_id, String(competition.get("id", "competition")), season_year]
	world.registrations[key] = {"club_id":club_id,"competition_id":String(competition.get("id", "")),"season_year":season_year,"player_ids":accepted.duplicate(),"homegrown":homegrown_count,"foreign":foreign_count,"valid":valid}
	return {"valid":valid,"registered":accepted,"rejected":rejected,"homegrown":homegrown_count,"foreign":foreign_count}

func is_registered(world: Dictionary, club_id: String, competition_id: String, season_year: int, player_id: String) -> bool:
	ensure_world(world)
	var key := "%s:%s:%d" % [club_id, competition_id, season_year]
	return player_id in world.registrations.get(key, {}).get("player_ids", [])

func _player(world: Dictionary, player_id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == player_id: return player
	return {}
