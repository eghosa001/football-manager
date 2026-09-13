class_name HomegrownTrainingService
extends RefCounted

const TRAINING_HISTORY_VERSION := 1
const QUALIFYING_YEARS := 3.0

func ensure_world(world: Dictionary) -> void:
	var club_country := _club_country_index(world.get("clubs", []))
	for player in world.get("players", []):
		ensure_player(player, club_country)

func ensure_player(player: Dictionary, club_country: Dictionary = {}) -> void:
	var countries: Variant = player.get("training_years_15_21_by_country", {})
	var clubs: Variant = player.get("training_years_15_21_by_club", {})
	if not (countries is Dictionary):
		countries = {}
	if not (clubs is Dictionary):
		clubs = {}
	var country_years: Dictionary = countries
	var club_years: Dictionary = clubs
	var had_modern_history := player.has("training_history_version")
	if not had_modern_history:
		# Migrate only explicit legacy qualification; nationality by itself is not
		# training history. A legacy association-homegrown flag is carried across
		# conservatively once the player is old enough to have completed 3 years.
		var current_club := String(player.get("club_id", ""))
		var current_country := String(club_country.get(current_club, ""))
		if bool(player.get("homegrown", false)) and int(player.get("age", 0)) >= 18 and current_country != "":
			country_years[current_country] = maxf(float(country_years.get(current_country, 0.0)), QUALIFYING_YEARS)
		if bool(player.get("club_trained", false)) and int(player.get("age", 0)) >= 18 and current_club != "":
			club_years[current_club] = maxf(float(club_years.get(current_club, 0.0)), QUALIFYING_YEARS)
	player["training_years_15_21_by_country"] = country_years
	player["training_years_15_21_by_club"] = club_years
	player["training_history_version"] = TRAINING_HISTORY_VERSION

func accrue_season(world: Dictionary) -> Dictionary:
	var club_country := _club_country_index(world.get("clubs", []))
	var accrued := 0
	var qualified_association := 0
	var qualified_club := 0
	for player in world.get("players", []):
		ensure_player(player, club_country)
		if bool(player.get("retired", false)):
			continue
		var age := int(player.get("age", 0))
		if age < 15 or age > 21:
			continue
		var club_id := String(player.get("club_id", ""))
		var country_id := String(club_country.get(club_id, ""))
		if club_id == "" or country_id == "":
			continue
		var country_years: Dictionary = player.training_years_15_21_by_country
		var club_years: Dictionary = player.training_years_15_21_by_club
		var before_country := float(country_years.get(country_id, 0.0))
		var before_club := float(club_years.get(club_id, 0.0))
		country_years[country_id] = minf(7.0, before_country + 1.0)
		club_years[club_id] = minf(7.0, before_club + 1.0)
		if before_country < QUALIFYING_YEARS and float(country_years[country_id]) >= QUALIFYING_YEARS:
			qualified_association += 1
		if before_club < QUALIFYING_YEARS and float(club_years[club_id]) >= QUALIFYING_YEARS:
			qualified_club += 1
		accrued += 1
	return {"accrued": accrued, "new_association_homegrown": qualified_association, "new_club_trained": qualified_club}

func association_homegrown(player: Dictionary, country_id: String) -> bool:
	if country_id == "":
		return false
	var years: Variant = player.get("training_years_15_21_by_country", {})
	return years is Dictionary and float((years as Dictionary).get(country_id, 0.0)) >= QUALIFYING_YEARS

func club_trained(player: Dictionary, club_id: String) -> bool:
	if club_id == "":
		return false
	var years: Variant = player.get("training_years_15_21_by_club", {})
	return years is Dictionary and float((years as Dictionary).get(club_id, 0.0)) >= QUALIFYING_YEARS

func _club_country_index(clubs: Array) -> Dictionary:
	var result := {}
	for club in clubs:
		var club_id := String(club.get("id", ""))
		if club_id != "":
			result[club_id] = String(club.get("country_id", ""))
	return result
