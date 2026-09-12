extends SceneTree

const Loader = preload("res://data/database_loader.gd")
const Builder = preload("res://data/launch_world_builder.gd")

func _init() -> void:
	var loader = Loader.new()
	var data: Dictionary = loader.load_seed()
	assert(not data.is_empty())
	var errors: Array[String] = loader.validate_seed(data)
	assert(errors.is_empty(), "Seed validation failed: %s" % str(errors))

	_assert_league_size(loader, data, "eng", 0, 20)
	_assert_league_size(loader, data, "eng", 1, 24)
	_assert_league_size(loader, data, "eng", 2, 24)
	_assert_league_size(loader, data, "esp", 0, 20)
	_assert_league_size(loader, data, "esp", 1, 22)
	_assert_league_size(loader, data, "deu", 0, 18)
	_assert_league_size(loader, data, "deu", 1, 18)
	_assert_league_size(loader, data, "zaf", 0, 16)
	_assert_league_size(loader, data, "zaf", 1, 16)

	var england: Dictionary = loader.league_system(data, "eng")
	var championship: Dictionary = england.tiers[1]
	assert(int(championship.get("automatic_promotion", 0)) == 2)
	assert(int(championship.get("playoff_promotion", 0)) == 1)
	assert(championship.get("playoff_places", []) == [3, 6])
	var germany: Dictionary = loader.league_system(data, "deu")
	assert(int(germany.tiers[0].get("relegation_playoff", 0)) == 1)
	assert(int(germany.tiers[1].get("promotion_playoff_vs_upper", 0)) == 1)

	var world: Dictionary = Builder.new().build(424242, 3, 25, false)
	assert(not world.is_empty())
	assert(loader.validate_world(world).is_empty())
	assert(world.has("transfer_windows_by_country"))
	assert((world.transfer_windows_by_country as Dictionary).has("eng"))
	assert((world.transfer_windows_by_country as Dictionary).has("esp"))

	var club_names: Array[String] = []
	for club in world.clubs:
		club_names.append(String(club.name))
		assert(bool(club.get("fictional_identity", false)))
	for expected in ["Manchester Red", "Manchester Sky", "Merseyside Red", "North London Red", "Madrid White", "Barcelona Azure", "Munich Red", "Dortmund Yellow"]:
		assert(expected in club_names, "Missing fictional analogue: %s" % expected)
	for prohibited in ["Manchester United", "Manchester City", "Liverpool", "Arsenal", "Chelsea", "Tottenham Hotspur", "Real Madrid", "FC Barcelona", "Bayern Munich", "Borussia Dortmund"]:
		assert(prohibited not in club_names, "Licensed club identity leaked into seed: %s" % prohibited)

	var names := {}
	var foreign_players := 0
	for player in world.players:
		assert(bool(player.get("fictional_identity", false)))
		var full_name := "%s %s" % [String(player.get("first_name", "")), String(player.get("last_name", ""))]
		assert(not names.has(full_name), "Duplicate generated player identity: %s" % full_name)
		names[full_name] = true
		var club := _club(world.clubs, String(player.club_id))
		if not club.is_empty() and String(player.get("country_id", "")) != String(club.get("country_id", "")):
			foreign_players += 1
	assert(foreign_players > 0, "Top-flight squads should include international players")

	var english_second := _competition(world.competitions, "eng-league-2")
	assert(int(english_second.get("automatic_promotion_places", 0)) == 2)
	assert(int(english_second.get("playoff_promotion_places", 0)) == 1)
	assert(english_second.club_ids.size() == 24)
	var spanish_second := _competition(world.competitions, "esp-league-2")
	assert(spanish_second.club_ids.size() == 22)

	print("[TEST] REALISM DATABASE PASS: structures, fictional clubs and fictional player identities verified")
	quit(0)

func _assert_league_size(loader: RefCounted, data: Dictionary, country_id: String, tier_index: int, expected: int) -> void:
	var system: Dictionary = loader.league_system(data, country_id)
	var tier: Dictionary = system.tiers[tier_index]
	var template: Dictionary = loader.template_by_id(data, String(tier.template))
	assert(int(template.get("teams", 0)) == expected, "%s tier %d expected %d teams" % [country_id, tier_index + 1, expected])

func _club(clubs: Array, id: String) -> Dictionary:
	for club in clubs:
		if String(club.get("id", "")) == id: return club
	return {}

func _competition(competitions: Array, id: String) -> Dictionary:
	for competition in competitions:
		if String(competition.get("id", "")) == id: return competition
	return {}
