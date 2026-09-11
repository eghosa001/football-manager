class_name YouthQualityService
extends RefCounted

const SeededRng = preload("res://core/rng/seeded_rng.gd")

func apply_to_intake(world: Dictionary, player_ids: Array, seed: int) -> Dictionary:
	var adjusted := 0
	var elite := 0
	for player_id in player_ids:
		var player := _player(world, String(player_id))
		if player.is_empty():
			continue
		var club := _club(world, String(player.get("club_id", "")))
		var country := _country(world, String(club.get("country_id", player.get("country_id", ""))))
		if club.is_empty() or country.is_empty():
			continue
		var country_youth := float(country.get("youth_rating", 50)) / 100.0
		var recruitment := float(club.get("youth_recruitment", 50)) / 100.0
		var academy := float(club.get("youth_facilities", club.get("training_facilities", 50))) / 100.0
		var popularity := float(country.get("football_popularity", country.get("youth_rating", 50))) / 100.0
		var population := clampf(float(country.get("population_factor", 1.0)), 0.45, 1.75)
		# Geometric blending prevents one exceptional input from completely masking
		# weak infrastructure while still allowing football nations to emerge.
		var quality := pow(maxf(0.05, country_youth * recruitment * academy * popularity), 0.25) * sqrt(population)
		quality = clampf(quality, 0.30, 1.25)
		var key := _stable_key(String(player.id))
		var variation := (SeededRng.unit_for(seed, key + 11) - 0.5) * 10.0
		var original_ca := int(player.get("current_ability", 35))
		var original_pa := int(player.get("potential", original_ca + 15))
		var ca_target := clampi(int(round(18.0 + quality * 35.0 + variation * 0.35)), 20, 65)
		var pa_target := clampi(int(round(38.0 + quality * 46.0 + variation)), ca_target, 99)
		# Blend rather than replace so club-specific academy logic from the base
		# lifecycle remains meaningful.
		player.current_ability = clampi(int(round(original_ca * 0.55 + ca_target * 0.45)), 20, 70)
		player.potential = clampi(maxi(int(player.current_ability), int(round(original_pa * 0.45 + pa_target * 0.55))), int(player.current_ability), 99)
		player["youth_quality"] = snappedf(quality * 100.0, 0.1)
		player["country_id"] = String(country.get("id", ""))
		adjusted += 1
		if int(player.potential) >= 88:
			elite += 1
	return {"adjusted":adjusted,"elite_prospects":elite}

func _player(world: Dictionary, id: String) -> Dictionary:
	for player in world.get("players", []):
		if String(player.get("id", "")) == id:
			return player
	return {}

func _club(world: Dictionary, id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == id:
			return club
	return {}

func _country(world: Dictionary, id: String) -> Dictionary:
	for country in world.get("countries", []):
		if String(country.get("id", "")) == id:
			return country
	return {}

func _stable_key(text: String) -> int:
	var value := 137
	for character in text.to_utf8_buffer():
		value = posmod(value * 211 + int(character), 2_147_483_647)
	return value
