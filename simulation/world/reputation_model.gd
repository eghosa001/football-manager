class_name ReputationModel
extends RefCounted

func ensure_world(world: Dictionary) -> void:
	for club in world.get("clubs", []):
		var base := float(club.get("reputation", 50))
		club["domestic_reputation"] = clampf(float(club.get("domestic_reputation", base)), 1.0, 100.0)
		club["continental_reputation"] = clampf(float(club.get("continental_reputation", base * 0.82)), 1.0, 100.0)
		club["global_reputation"] = clampf(float(club.get("global_reputation", base)), 1.0, 100.0)
	for competition in world.get("competitions", []):
		if String(competition.get("competition_type", "league")) == "league":
			competition["league_reputation"] = clampf(float(competition.get("league_reputation", _average_club_reputation(world, competition.get("club_ids", [])))), 1.0, 100.0)
	for country in world.get("countries", []):
		var youth := float(country.get("youth_rating", 50))
		country["football_popularity"] = clampf(float(country.get("football_popularity", youth)), 1.0, 100.0)
		country["infrastructure"] = clampf(float(country.get("infrastructure", youth * 0.85)), 1.0, 100.0)
		country["coaching_quality"] = clampf(float(country.get("coaching_quality", youth * 0.82)), 1.0, 100.0)
		country["economic_strength"] = clampf(float(country.get("economic_strength", 55.0)), 1.0, 100.0)
		country["league_reputation"] = clampf(float(country.get("league_reputation", _country_league_reputation(world, String(country.get("id", ""))))), 1.0, 100.0)

func advance_year(world: Dictionary, records: Array) -> Dictionary:
	ensure_world(world)
	var record_by_id := {}
	for record in records:
		record_by_id[String(record.get("competition_id", ""))] = record
	var continental_scores := {}
	for competition in world.get("competitions", []):
		if not bool(competition.get("continental", false)):
			continue
		var record: Dictionary = record_by_id.get(String(competition.get("id", "")), {})
		if record.is_empty():
			continue
		var champion := String(record.get("champion_club_id", ""))
		for club_id in competition.get("club_ids", []):
			continental_scores[String(club_id)] = float(continental_scores.get(String(club_id), 0.0)) + 1.0
		if champion != "":
			continental_scores[champion] = float(continental_scores.get(champion, 0.0)) + 5.0

	var club_changes := 0
	for club in world.get("clubs", []):
		var before := float(club.global_reputation)
		var domestic_target := float(club.domestic_reputation)
		var competition := _domestic_league_for_club(world, String(club.id))
		if not competition.is_empty():
			var record: Dictionary = record_by_id.get(String(competition.id), {})
			var table: Array = record.get("table", [])
			for i in range(table.size()):
				if String(table[i].get("club_id", "")) != String(club.id):
					continue
				var percentile := float(i) / maxf(1.0, float(table.size() - 1))
				var result_delta := lerpf(2.2, -2.0, percentile)
				domestic_target = clampf(float(club.domestic_reputation) + result_delta, 5.0, 98.0)
				break
		club.domestic_reputation = _move(float(club.domestic_reputation), domestic_target, 2.5)
		var continental_delta := float(continental_scores.get(String(club.id), 0.0))
		var continental_target := float(club.continental_reputation) + continental_delta
		if continental_delta <= 0.0:
			continental_target -= 0.35
		club.continental_reputation = _move(float(club.continental_reputation), clampf(continental_target, 3.0, 99.0), 3.0)
		var global_target := float(club.domestic_reputation) * 0.62 + float(club.continental_reputation) * 0.38
		club.global_reputation = _move(float(club.global_reputation), global_target, 1.8)
		club.reputation = clampi(int(round(float(club.global_reputation))), 10, 95)
		if absf(float(club.global_reputation) - before) >= 0.1:
			club_changes += 1

	var league_changes := 0
	for competition in world.get("competitions", []):
		if String(competition.get("competition_type", "league")) != "league":
			continue
		var before_league := float(competition.get("league_reputation", 50.0))
		var club_average := _average_club_reputation(world, competition.get("club_ids", []))
		var continental_bonus := 0.0
		for club_id in competition.get("club_ids", []):
			continental_bonus += float(continental_scores.get(String(club_id), 0.0))
		continental_bonus /= maxf(1.0, float(competition.get("club_ids", []).size()))
		var target := clampf(club_average * 0.85 + (50.0 + continental_bonus * 3.0) * 0.15, 8.0, 96.0)
		competition.league_reputation = _move(before_league, target, 1.25)
		if absf(float(competition.league_reputation) - before_league) >= 0.1:
			league_changes += 1

	var country_changes := 0
	for country in world.get("countries", []):
		var country_id := String(country.get("id", ""))
		var league_rep := _country_league_reputation(world, country_id)
		var old_strength := _country_strength(country)
		country.league_reputation = _move(float(country.league_reputation), league_rep, 0.8)
		country.football_popularity = _move(float(country.football_popularity), float(country.league_reputation) * 0.72 + float(country.get("youth_rating", 50)) * 0.28, 0.45)
		country.infrastructure = _move(float(country.infrastructure), float(country.league_reputation) * 0.62 + float(country.economic_strength) * 0.38, 0.35)
		country.coaching_quality = _move(float(country.coaching_quality), float(country.get("youth_rating", 50)) * 0.58 + float(country.infrastructure) * 0.42, 0.35)
		var new_strength := _country_strength(country)
		country["football_strength"] = snappedf(new_strength, 0.1)
		if absf(new_strength - old_strength) >= 0.1:
			country_changes += 1
	return {"club_changes":club_changes,"league_changes":league_changes,"country_changes":country_changes}

func _move(current: float, target: float, maximum_step: float) -> float:
	return snappedf(clampf(current + clampf(target - current, -maximum_step, maximum_step), 1.0, 100.0), 0.1)

func _country_strength(country: Dictionary) -> float:
	return float(country.get("football_popularity",50.0))*0.16 + float(country.get("youth_rating",50.0))*0.22 + float(country.get("infrastructure",50.0))*0.16 + float(country.get("coaching_quality",50.0))*0.16 + float(country.get("economic_strength",50.0))*0.10 + float(country.get("league_reputation",50.0))*0.20

func _average_club_reputation(world: Dictionary, club_ids: Array) -> float:
	if club_ids.is_empty():
		return 50.0
	var total := 0.0
	var count := 0
	for club_id in club_ids:
		var club := _club(world, String(club_id))
		if club.is_empty():
			continue
		total += float(club.get("global_reputation", club.get("reputation", 50)))
		count += 1
	return total / maxf(1.0, float(count))

func _country_league_reputation(world: Dictionary, country_id: String) -> float:
	var total := 0.0
	var count := 0
	for competition in world.get("competitions", []):
		if String(competition.get("country_id", "")) == country_id and String(competition.get("competition_type", "league")) == "league":
			total += float(competition.get("league_reputation", _average_club_reputation(world, competition.get("club_ids", []))))
			count += 1
	return total / maxf(1.0, float(count))

func _domestic_league_for_club(world: Dictionary, club_id: String) -> Dictionary:
	for competition in world.get("competitions", []):
		if String(competition.get("competition_type", "league")) == "league" and club_id in competition.get("club_ids", []):
			return competition
	return {}

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return club
	return {}
