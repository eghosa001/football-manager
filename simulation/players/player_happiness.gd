class_name PlayerHappiness
extends RefCounted

const CATEGORIES := ["playing_time","contract","training","manager","club_performance","squad_harmony","transfer_status"]

func ensure_player(player: Dictionary) -> void:
	var categories: Dictionary = player.get("happiness_categories", {})
	var baseline := float(player.get("happiness", player.get("morale", 65)))
	for category in CATEGORIES:
		if not categories.has(category):
			categories[category] = clampf(baseline, 0.0, 100.0)
	player["happiness_categories"] = categories
	player["happiness"] = _average(categories)

func update_week(world: Dictionary) -> Dictionary:
	var changed := 0
	var unhappy := 0
	# Weekly happiness touches every active player. Build the world-wide lookup
	# data once instead of rescanning contracts/clubs/fixtures/relationships and
	# transfer offers for every player. This keeps the result identical while
	# making the operation scale linearly with the launch database.
	var context := _build_week_context(world)
	for player in world.get("players", []):
		if bool(player.get("retired", false)):
			continue
		ensure_player(player)
		var targets := _targets(world, player, context)
		var categories: Dictionary = player.happiness_categories
		var before := float(player.happiness)
		for category in CATEGORIES:
			var current := float(categories.get(category, 65.0))
			var target := float(targets.get(category, current))
			# Happiness moves slowly. A single week cannot turn a content player into
			# a mutinous one unless another system explicitly applies a stronger event.
			categories[category] = clampf(current + clampf((target - current) * 0.20, -4.0, 4.0), 0.0, 100.0)
		player.happiness = snappedf(_average(categories), 0.1)
		if absf(float(player.happiness) - before) >= 0.1:
			changed += 1
		if float(player.happiness) < 40.0:
			unhappy += 1
	return {"players_changed":changed,"unhappy_players":unhappy}

func apply_event(player: Dictionary, category: String, delta: float) -> Error:
	ensure_player(player)
	if category not in CATEGORIES:
		return ERR_INVALID_PARAMETER
	player.happiness_categories[category] = clampf(float(player.happiness_categories.get(category, 65.0)) + delta, 0.0, 100.0)
	player.happiness = snappedf(_average(player.happiness_categories), 0.1)
	return OK

func concerns(player: Dictionary, threshold: float = 50.0) -> Array:
	ensure_player(player)
	var rows: Array = []
	for category in CATEGORIES:
		var value := float(player.happiness_categories.get(category, 65.0))
		if value < threshold:
			rows.append({"category":category,"value":snappedf(value,0.1)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.value) < float(b.value))
	return rows

func _build_week_context(world: Dictionary) -> Dictionary:
	var contracts_by_player := {}
	for contract in world.get("contracts", []):
		var player_id := String(contract.get("player_id", ""))
		if player_id != "" and not contracts_by_player.has(player_id):
			contracts_by_player[player_id] = contract

	var clubs_by_id := {}
	for club in world.get("clubs", []):
		var club_id := String(club.get("id", ""))
		if club_id != "":
			clubs_by_id[club_id] = club

	var manager_relationship_by_player := {}
	for relation in world.get("relationships", []):
		if String(relation.get("relationship_type", "")) != "manager_relationship":
			continue
		var source_id := String(relation.get("source_person_id", ""))
		if source_id != "" and not manager_relationship_by_player.has(source_id):
			manager_relationship_by_player[source_id] = float(relation.get("strength", 0))

	var transfer_target_by_player := {}
	for offer in world.get("transfer_offers", []):
		var status := String(offer.get("status", ""))
		if status not in ["pending", "accepted"]:
			continue
		var player_id := String(offer.get("player_id", ""))
		if player_id == "" or transfer_target_by_player.has(player_id):
			continue
		var player_club_id := ""
		# Player ownership is indexed below; defer buyer comparison until after
		# that index exists by retaining the buyer id here.
		transfer_target_by_player[player_id] = String(offer.get("buyer_id", ""))

	var player_club_by_id := {}
	var morale_by_club := {}
	for player in world.get("players", []):
		if bool(player.get("retired", false)):
			continue
		var player_id := String(player.get("id", ""))
		var club_id := String(player.get("club_id", ""))
		if player_id != "":
			player_club_by_id[player_id] = club_id
		if club_id == "":
			continue
		if not morale_by_club.has(club_id):
			morale_by_club[club_id] = {"total":0.0,"count":0}
		morale_by_club[club_id].total = float(morale_by_club[club_id].total) + float(player.get("morale", 65))
		morale_by_club[club_id].count = int(morale_by_club[club_id].count) + 1

	var harmony_by_club := {}
	var rooms: Dictionary = world.get("dressing_rooms", {})
	for club_id in clubs_by_id.keys():
		var room: Dictionary = rooms.get(club_id, {})
		if not room.is_empty():
			harmony_by_club[club_id] = float(room.get("atmosphere", 65.0))
		else:
			var morale: Dictionary = morale_by_club.get(club_id, {})
			harmony_by_club[club_id] = float(morale.get("total", 0.0)) / maxf(1.0, float(morale.get("count", 0)))

	var fixtures_by_club := {}
	for fixture in world.get("fixtures", []):
		if not bool(fixture.get("played", false)):
			continue
		var home_id := String(fixture.get("home_club_id", ""))
		var away_id := String(fixture.get("away_club_id", ""))
		if home_id != "":
			if not fixtures_by_club.has(home_id): fixtures_by_club[home_id] = []
			fixtures_by_club[home_id].append(fixture)
		if away_id != "":
			if not fixtures_by_club.has(away_id): fixtures_by_club[away_id] = []
			fixtures_by_club[away_id].append(fixture)

	var recent_points_by_club := {}
	for club_id in fixtures_by_club.keys():
		var fixtures: Array = fixtures_by_club[club_id]
		fixtures.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.get("date", "")) > String(b.get("date", "")))
		var points := 0
		for fixture in fixtures.slice(0, mini(5, fixtures.size())):
			var home := String(fixture.get("home_club_id", "")) == String(club_id)
			var gf := int(fixture.get("home_goals", 0)) if home else int(fixture.get("away_goals", 0))
			var ga := int(fixture.get("away_goals", 0)) if home else int(fixture.get("home_goals", 0))
			points += 3 if gf > ga else (1 if gf == ga else 0)
		recent_points_by_club[club_id] = points

	return {
		"contracts_by_player":contracts_by_player,
		"clubs_by_id":clubs_by_id,
		"manager_relationship_by_player":manager_relationship_by_player,
		"transfer_buyer_by_player":transfer_target_by_player,
		"player_club_by_id":player_club_by_id,
		"harmony_by_club":harmony_by_club,
		"recent_points_by_club":recent_points_by_club,
	}

func _targets(world: Dictionary, player: Dictionary, context: Dictionary = {}) -> Dictionary:
	var club_id := String(player.get("club_id", ""))
	var player_id := String(player.get("id", ""))
	var appearances := int(player.get("season_appearances", 0))
	var age := int(player.get("age", 24))
	var ability := int(player.get("current_ability", 50))
	var desired_appearances := 14
	if ability >= 75: desired_appearances = 24
	elif ability >= 60: desired_appearances = 19
	if age <= 20: desired_appearances = maxi(8, desired_appearances - 5)
	var playing_target := clampf(45.0 + float(appearances - desired_appearances) * 2.5, 20.0, 90.0)

	var contract: Dictionary
	if context.is_empty():
		contract = _contract(world, player_id)
	else:
		contract = context.get("contracts_by_player", {}).get(player_id, {})
	var years_left := int(contract.get("end_year", int(world.get("season_year", 2026)))) - int(world.get("season_year", 2026))
	var wage := int(contract.get("weekly_wage", 0))
	var contract_target := 68.0 + clampf(float(years_left - 1) * 5.0, -18.0, 12.0)
	if wage <= 0: contract_target -= 12.0

	var club: Dictionary = _club(world, club_id) if context.is_empty() else context.get("clubs_by_id", {}).get(club_id, {})
	var intensity := float(club.get("training_intensity", 0.65))
	var fitness := float(player.get("fitness", 90))
	var training_target := clampf(72.0 - absf(intensity - 0.65) * 35.0 + (fitness - 80.0) * 0.25, 35.0, 88.0)

	var manager_target := 65.0
	if context.is_empty():
		for relation in world.get("relationships", []):
			if String(relation.get("source_person_id", "")) == player_id and String(relation.get("relationship_type", "")) == "manager_relationship":
				manager_target = clampf(65.0 + float(relation.get("strength", 0)) * 0.25, 25.0, 95.0)
				break
	else:
		var relation_strengths: Dictionary = context.get("manager_relationship_by_player", {})
		if relation_strengths.has(player_id):
			manager_target = clampf(65.0 + float(relation_strengths[player_id]) * 0.25, 25.0, 95.0)

	var club_points := _recent_points(world, club_id, 5) if context.is_empty() else int(context.get("recent_points_by_club", {}).get(club_id, 0))
	var club_target := clampf(48.0 + club_points * 3.1, 35.0, 88.0)
	var harmony_target := _squad_harmony(world, club_id) if context.is_empty() else float(context.get("harmony_by_club", {}).get(club_id, 65.0))
	var transfer_target := 68.0
	if context.is_empty():
		for offer in world.get("transfer_offers", []):
			if String(offer.get("player_id", "")) != player_id:
				continue
			var status := String(offer.get("status", ""))
			if status in ["pending","accepted"]:
				transfer_target = 52.0 if String(offer.get("buyer_id", "")) != club_id else 74.0
				break
	else:
		var buyers: Dictionary = context.get("transfer_buyer_by_player", {})
		if buyers.has(player_id):
			transfer_target = 52.0 if String(buyers[player_id]) != club_id else 74.0
	return {
		"playing_time":playing_target,
		"contract":contract_target,
		"training":training_target,
		"manager":manager_target,
		"club_performance":club_target,
		"squad_harmony":harmony_target,
		"transfer_status":transfer_target,
	}

func _average(categories: Dictionary) -> float:
	var total := 0.0
	for category in CATEGORIES:
		total += float(categories.get(category, 65.0))
	return total / float(CATEGORIES.size())

func _recent_points(world: Dictionary, club_id: String, limit: int) -> int:
	var played: Array = []
	for fixture in world.get("fixtures", []):
		if not bool(fixture.get("played", false)):
			continue
		if String(fixture.get("home_club_id", "")) == club_id or String(fixture.get("away_club_id", "")) == club_id:
			played.append(fixture)
	played.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.get("date", "")) > String(b.get("date", "")))
	var points := 0
	for fixture in played.slice(0, mini(limit, played.size())):
		var home := String(fixture.get("home_club_id", "")) == club_id
		var gf := int(fixture.get("home_goals", 0)) if home else int(fixture.get("away_goals", 0))
		var ga := int(fixture.get("away_goals", 0)) if home else int(fixture.get("home_goals", 0))
		points += 3 if gf > ga else (1 if gf == ga else 0)
	return points

func _squad_harmony(world: Dictionary, club_id: String) -> float:
	var room: Dictionary = world.get("dressing_rooms", {}).get(club_id, {})
	if not room.is_empty():
		return float(room.get("atmosphere", 65.0))
	var total := 0.0
	var count := 0
	for player in world.get("players", []):
		if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)):
			total += float(player.get("morale", 65))
			count += 1
	return total / maxf(1.0, float(count))

func _contract(world: Dictionary, player_id: String) -> Dictionary:
	for contract in world.get("contracts", []):
		if String(contract.get("player_id", "")) == player_id:
			return contract
	return {}

func _club(world: Dictionary, club_id: String) -> Dictionary:
	for club in world.get("clubs", []):
		if String(club.get("id", "")) == club_id:
			return club
	return {}
