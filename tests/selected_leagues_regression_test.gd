extends SceneTree

const Builder = preload("res://data/launch_world_builder.gd")

func _init() -> void:
	var world: Dictionary = Builder.new().build(20260913, 0, 15, false, ["esp"])
	assert(not world.is_empty())
	assert(world.get("countries", []).size() == 1)
	assert(String(world.countries[0].get("id", "")) == "esp")
	assert(not world.get("clubs", []).is_empty())
	assert(not world.get("players", []).is_empty())
	for club in world.get("clubs", []):
		assert(String(club.get("country_id", "")) == "esp")
	for competition in world.get("competitions", []):
		assert(String(competition.get("country_id", "")) == "esp")
	assert(world.get("active_country_ids", []) == ["esp"])
	print("[SELECTED LEAGUES] countries=%d clubs=%d players=%d fixtures=%d" % [world.countries.size(),world.clubs.size(),world.players.size(),world.fixtures.size()])
	print("[TEST] SELECTED LEAGUES REGRESSION PASS")
	quit(0)
