extends SceneTree

const DatabaseLoaderClass = preload("res://data/database_loader.gd")
const LaunchWorldBuilderClass = preload("res://data/launch_world_builder.gd")
const KnockoutClass = preload("res://simulation/competitions/knockout_competition.gd")
const CatalogClass = preload("res://simulation/competitions/competition_catalog.gd")
const GroupStageClass = preload("res://simulation/competitions/group_stage.gd")
const ScheduleConstraintsClass = preload("res://simulation/competitions/schedule_constraints.gd")
const InternationalClass = preload("res://simulation/competitions/international_football.gd")
const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")

var failed := false

func _init() -> void:
	print("[TEST] database seed")
	var loader = DatabaseLoaderClass.new()
	var data: Dictionary = loader.load_seed()
	if not _must(not data.is_empty(), "seed should load"): return
	if not _must(loader.validate_seed(data).is_empty(), "seed should validate"): return
	if not _must(data.countries.size() >= 8, "launch seed should contain at least 8 countries"): return
	if not _must(not loader.league_system(data, "nga").is_empty(), "Nigeria league system should exist"): return

	print("[TEST] launch world")
	var launch_a: Dictionary = LaunchWorldBuilderClass.new().build(11111, 1, 11)
	var launch_b: Dictionary = LaunchWorldBuilderClass.new().build(11111, 1, 11)
	if not _must(not launch_a.is_empty(), "launch world should build"): return
	if not _must(launch_a.countries.size() == 1, "launch slice should contain one country"): return
	if not _must(launch_a.competitions.size() >= 2, "launch country should contain multiple tiers"): return
	if not _must(launch_a.clubs.size() >= 20, "launch country should contain clubs"): return
	if not _must(launch_a.players.size() >= launch_a.clubs.size() * 11, "launch clubs should contain playable squads"): return
	if not _must(launch_a.fixtures.size() > 500, "launch country should generate a full league calendar"): return
	if not _must(launch_a.clubs.size() == launch_b.clubs.size(), "club counts should be deterministic"): return
	if not _must(launch_a.players.size() == launch_b.players.size(), "player counts should be deterministic"): return
	if not _must(launch_a.fixtures.size() == launch_b.fixtures.size(), "fixture counts should be deterministic"): return
	if not _must(String(launch_a.clubs[0].id) == String(launch_b.clubs[0].id), "club IDs should be deterministic"): return
	if not _must(String(launch_a.players[0].id) == String(launch_b.players[0].id), "player IDs should be deterministic"): return
	if not _must(String(launch_a.fixtures[0].id) == String(launch_b.fixtures[0].id), "fixture IDs should be deterministic"): return
	if not _must(int(launch_a.players[0].current_ability) == int(launch_b.players[0].current_ability), "player generation should be deterministic"): return

	print("[TEST] knockout")
	var clubs := []
	for i in range(8): clubs.append("club-%d" % i)
	var bracket: Dictionary = KnockoutClass.new().create_bracket(clubs, 123)
	if not _must(bracket.matches.size() == 4, "8-team bracket should start with four matches"): return
	var results := []
	for match in bracket.matches:
		results.append({"home_goals":1,"away_goals":0})
	bracket = KnockoutClass.new().advance_round(bracket, results)
	if not _must(bracket.entrants.size() == 4, "knockout should halve entrants"): return

	print("[TEST] group scheduling")
	var groups: Array = GroupStageClass.new().seed_groups(clubs, 2)
	if not _must(groups.size() == 2, "group stage should create two groups"): return
	var group_fixtures: Array = GroupStageClass.new().fixtures_for_groups(groups, "continental-test")
	if not _must(group_fixtures.size() == 24, "two four-team groups should create 24 home/away fixtures"): return
	var schedule = ScheduleConstraintsClass.new()
	schedule.assign_dates(group_fixtures, {"year":2026,"month":8,"day":1}, 7, 2)
	if not _must(schedule.validate_rest(group_fixtures, 2).is_empty(), "scheduled group stage should respect minimum rest"): return

	print("[TEST] competition catalog")
	var tiers: Array = [[], []]
	for i in range(20): tiers[0].append("nga-a-%02d" % i)
	for i in range(20): tiers[1].append("nga-b-%02d" % i)
	var competitions: Array = CatalogClass.new().build_for_country(data, "nga", tiers)
	if not _must(competitions.size() == 3, "Nigeria catalog should contain two leagues and a cup"): return
	if not _must(int(competitions[0].tier) == 1, "top league should be tier 1"): return
	if not _must(String(competitions[2].rules.type) == "knockout", "domestic cup should use knockout rules"): return

	print("[TEST] international")
	var world: Dictionary = WorldGeneratorClass.new().create_world(80808)
	var international = InternationalClass.new()
	international.ensure_world(world)
	if not _must(world.national_teams.size() == world.countries.size(), "each active country should have a national team"): return
	var nation_id := String(world.countries[0].id)
	var callup: Dictionary = international.register_callups(world, nation_id, "international-test", 23)
	if not _must(callup.player_ids.size() <= 23, "call-up should respect squad limit"): return
	var country_ids: Array = []
	for country in world.countries: country_ids.append(String(country.id))
	var qualifying: Dictionary = international.qualifying_groups(country_ids, 2, "qualifiers")
	if not _must(qualifying.groups.size() == 2, "qualifying should create requested groups"): return

	print("[TEST] DATABASE/COMPETITIONS PASS")
	quit(0)

func _must(condition: bool, message: String) -> bool:
	if condition:
		return true
	failed = true
	push_error("[TEST] DATABASE/COMPETITIONS FAIL: %s" % message)
	quit(1)
	return false
