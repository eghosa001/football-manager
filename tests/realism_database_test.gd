extends SceneTree

const Loader = preload("res://data/database_loader.gd")
const Builder = preload("res://data/launch_world_builder.gd")
const Realism = preload("res://data/realism_profile.gd")

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
	_assert_league_size(loader, data, "fra", 0, 18)
	_assert_league_size(loader, data, "ita", 0, 20)
	_assert_league_size(loader, data, "bra", 0, 20)
	_assert_league_size(loader, data, "arg", 0, 30)
	_assert_league_size(loader, data, "nga", 0, 20)
	_assert_league_size(loader, data, "gha", 0, 18)
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

	# Build one complete three-tier English pyramid; all other country sizes and
	# rules are validated directly from the launch database above.
	var world: Dictionary = Builder.new().build(424242, 1, 15, false)
	assert(not world.is_empty())
	assert(loader.validate_world(world).is_empty())
	assert(world.has("transfer_windows_by_country"))
	assert((world.transfer_windows_by_country as Dictionary).has("eng"))

	var club_names: Array[String] = []
	for club in world.clubs:
		club_names.append(String(club.name))
		assert(bool(club.get("fictional_identity", false)))
	for expected in ["Manchester Red", "Manchester Sky", "Merseyside Red", "North London Red"]:
		assert(expected in club_names, "Missing fictional analogue: %s" % expected)
	for prohibited in ["Manchester United", "Manchester City", "Liverpool", "Arsenal", "Chelsea", "Tottenham Hotspur"]:
		assert(prohibited not in club_names, "Licensed club identity leaked into seed: %s" % prohibited)

	# Major non-English analogues are present in the data even though this fast
	# contract does not build every national pyramid.
	_assert_profile_name(data, "esp", "Madrid White")
	_assert_profile_name(data, "esp", "Barcelona Azure")
	_assert_profile_name(data, "deu", "Munich Red")
	_assert_profile_name(data, "deu", "Dortmund Yellow")
	_assert_profile_name(data, "fra", "Paris Blue")
	_assert_profile_name(data, "ita", "Milan Black & Blue")

	var english_second := _competition(world.competitions, "eng-league-2")
	assert(int(english_second.get("automatic_promotion_places", 0)) == 2)
	assert(int(english_second.get("playoff_promotion_places", 0)) == 1)
	assert(english_second.club_ids.size() == 24)

	# Stress the fictional-name generator directly without constructing another
	# multi-thousand-player world.
	var realism = Realism.new()
	var used := {}
	for i in range(750):
		var identity: Dictionary = realism.generated_name(data, "eng", 98765, 1000 + i * 17, used, "test-%04d" % i)
		assert(String(identity.get("full_name", "")) != "")
	assert(used.size() == 750, "Fictional identity generator must remain unique at scale")

	var foreign_seen := false
	for i in range(100):
		if String(realism.nationality("eng", ["eng", "esp", "deu"], 92, 999, i * 19 + 5)) != "eng":
			foreign_seen = true
			break
	assert(foreign_seen, "Elite-club nationality model should generate international players")

	for player in world.players:
		assert(bool(player.get("fictional_identity", false)))

	print("[TEST] REALISM DATABASE PASS: structures, aliases, rules and fictional identities verified")
	quit(0)

func _assert_league_size(loader: RefCounted, data: Dictionary, country_id: String, tier_index: int, expected: int) -> void:
	var system: Dictionary = loader.league_system(data, country_id)
	var tier: Dictionary = system.tiers[tier_index]
	var template: Dictionary = loader.template_by_id(data, String(tier.template))
	assert(int(template.get("teams", 0)) == expected, "%s tier %d expected %d teams" % [country_id, tier_index + 1, expected])

func _assert_profile_name(data: Dictionary, country_id: String, expected: String) -> void:
	for country in data.get("countries", []):
		if String(country.get("id", "")) != country_id:
			continue
		for profile in (country.get("club_profiles", {}) as Dictionary).get("1", []):
			if String(profile.get("name", "")) == expected:
				return
	assert(false, "Missing fictional club profile: %s" % expected)

func _competition(competitions: Array, id: String) -> Dictionary:
	for competition in competitions:
		if String(competition.get("id", "")) == id: return competition
	return {}
