extends SceneTree

const Builder = preload("res://data/launch_world_builder.gd")

func _init() -> void:
	var country_world: Dictionary = Builder.new().build(20260913, 0, 15, false, ["esp"])
	assert(not country_world.is_empty())
	assert(country_world.get("countries", []).size() == 1)
	assert(String(country_world.countries[0].get("id", "")) == "esp")
	assert(not country_world.get("clubs", []).is_empty())
	assert(not country_world.get("players", []).is_empty())
	for club in country_world.get("clubs", []):
		assert(String(club.get("country_id", "")) == "esp")
	for competition in country_world.get("competitions", []):
		assert(String(competition.get("country_id", "")) == "esp")
	assert(country_world.get("active_country_ids", []) == ["esp"])

	var tier_world: Dictionary = Builder.new().build(20260913, 0, 15, false, ["eng"], ["eng:1"])
	assert(not tier_world.is_empty())
	assert(tier_world.get("active_league_ids", []) == ["eng:1"])
	assert(tier_world.get("countries", []).size() == 1)
	for club in tier_world.get("clubs", []):
		assert(String(club.get("country_id", "")) == "eng")
		assert(int(club.get("tier", 0)) == 1)
	for competition in tier_world.get("competitions", []):
		if String(competition.get("competition_type", "league")) == "league":
			assert(int(competition.get("tier", 0)) == 1)
	assert(tier_world.get("clubs", []).size() < country_world.get("clubs", []).size() or country_world.get("active_league_ids", []).size() > 1)
	print("[SELECTED LEAGUES] exact=%s clubs=%d players=%d fixtures=%d" % [str(tier_world.active_league_ids),tier_world.clubs.size(),tier_world.players.size(),tier_world.fixtures.size()])
	print("[TEST] SELECTED LEAGUES REGRESSION PASS")
	quit(0)
