extends SceneTree

const Loader = preload("res://data/database_loader.gd")
const Builder = preload("res://data/launch_world_builder.gd")
const Realism = preload("res://data/realism_profile.gd")

func _init() -> void:
	var loader = Loader.new()
	var data: Dictionary = loader.load_seed()
	if not _check(not data.is_empty(), "launch database did not load"): return
	var errors: Array[String] = loader.validate_seed(data)
	if not _check(errors.is_empty(), "seed validation failed: %s" % str(errors)): return

	for spec in [["eng",0,20],["eng",1,24],["eng",2,24],["esp",0,20],["esp",1,22],["deu",0,18],["deu",1,18],["fra",0,18],["ita",0,20],["bra",0,20],["arg",0,30],["nga",0,20],["gha",0,18],["zaf",0,16],["zaf",1,16]]:
		if not _check_league_size(loader, data, String(spec[0]), int(spec[1]), int(spec[2])): return

	var england: Dictionary = loader.league_system(data, "eng")
	var championship: Dictionary = england.tiers[1]
	if not _check(int(championship.get("automatic_promotion", 0)) == 2, "English Championship automatic promotion must be two"): return
	if not _check(int(championship.get("playoff_promotion", 0)) == 1, "English Championship must have one playoff promotion place"): return
	if not _check(championship.get("playoff_places", []) == [3, 6], "English Championship playoff places must be 3-6"): return
	var germany: Dictionary = loader.league_system(data, "deu")
	if not _check(int(germany.tiers[0].get("relegation_playoff", 0)) == 1, "German top tier needs relegation playoff metadata"): return
	if not _check(int(germany.tiers[1].get("promotion_playoff_vs_upper", 0)) == 1, "German second tier needs promotion playoff metadata"): return

	var world: Dictionary = Builder.new().build(424242, 1, 15, false)
	if not _check(not world.is_empty(), "English realism world failed to build"): return
	var world_errors: Array[String] = loader.validate_world(world)
	if not _check(world_errors.is_empty(), "world validation failed: %s" % str(world_errors)): return
	if not _check(world.has("transfer_windows_by_country"), "world missing country transfer windows"): return
	if not _check((world.transfer_windows_by_country as Dictionary).has("eng"), "world missing England transfer windows"): return

	var club_names: Array[String] = []
	for club in world.clubs:
		club_names.append(String(club.name))
		if not _check(bool(club.get("fictional_identity", false)), "club was not marked fictional: %s" % String(club.name)): return
	for expected in ["Manchester Red", "Manchester Sky", "Merseyside Red", "North London Red"]:
		if not _check(expected in club_names, "missing fictional club analogue: %s" % expected): return
	for prohibited in ["Manchester United", "Manchester City", "Liverpool", "Arsenal", "Chelsea", "Tottenham Hotspur"]:
		if not _check(prohibited not in club_names, "licensed club identity leaked into seed: %s" % prohibited): return

	for pair in [["esp","Madrid White"],["esp","Barcelona Azure"],["deu","Munich Red"],["deu","Dortmund Yellow"],["fra","Paris Blue"],["ita","Milan Black & Blue"]]:
		if not _check_profile_name(data, String(pair[0]), String(pair[1])): return

	var english_second := _competition(world.competitions, "eng-league-2")
	if not _check(not english_second.is_empty(), "English second division missing from world"): return
	if not _check(int(english_second.get("automatic_promotion_places", 0)) == 2, "English second division lost automatic-promotion metadata"): return
	if not _check(int(english_second.get("playoff_promotion_places", 0)) == 1, "English second division lost playoff metadata"): return
	if not _check(english_second.club_ids.size() == 24, "English second division must contain 24 clubs"): return

	var realism = Realism.new()
	var used := {}
	for i in range(750):
		var identity: Dictionary = realism.generated_name(data, "eng", 98765, 1000 + i * 17, used, "test-%04d" % i)
		if not _check(String(identity.get("full_name", "")) != "", "fictional identity generator returned an empty name at %d" % i): return
	if not _check(used.size() == 750, "fictional identity generator produced duplicate names: %d/750 unique" % used.size()): return

	var foreign_seen := false
	for i in range(100):
		if String(realism.nationality("eng", ["eng", "esp", "deu"], 92, 999, i * 19 + 5)) != "eng":
			foreign_seen = true
			break
	if not _check(foreign_seen, "elite-club nationality model did not generate international players"): return

	for player in world.players:
		if not _check(bool(player.get("fictional_identity", false)), "player was not marked fictional: %s" % String(player.get("id", ""))): return

	print("[TEST] REALISM DATABASE PASS: structures, aliases, rules and fictional identities verified")
	quit(0)

func _check_league_size(loader: RefCounted, data: Dictionary, country_id: String, tier_index: int, expected: int) -> bool:
	var system: Dictionary = loader.league_system(data, country_id)
	if not _check(not system.is_empty(), "missing league system: %s" % country_id): return false
	var tiers: Array = system.get("tiers", [])
	if not _check(tier_index < tiers.size(), "missing tier %d for %s" % [tier_index + 1, country_id]): return false
	var tier: Dictionary = tiers[tier_index]
	var template: Dictionary = loader.template_by_id(data, String(tier.template))
	return _check(int(template.get("teams", 0)) == expected, "%s tier %d expected %d teams but has %d" % [country_id, tier_index + 1, expected, int(template.get("teams", 0))])

func _check_profile_name(data: Dictionary, country_id: String, expected: String) -> bool:
	for country in data.get("countries", []):
		if String(country.get("id", "")) != country_id: continue
		for profile in (country.get("club_profiles", {}) as Dictionary).get("1", []):
			if String(profile.get("name", "")) == expected: return true
	return _check(false, "missing fictional club profile: %s" % expected)

func _competition(competitions: Array, id: String) -> Dictionary:
	for competition in competitions:
		if String(competition.get("id", "")) == id: return competition
	return {}

func _check(condition: bool, message: String) -> bool:
	if condition: return true
	push_error("[REALISM TEST] %s" % message)
	print("[REALISM TEST] FAILED: %s" % message)
	quit(1)
	return false
