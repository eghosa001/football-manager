extends SceneTree

const DatabaseLoaderClass = preload("res://data/database_loader.gd")
const LaunchWorldBuilderClass = preload("res://data/launch_world_builder.gd")
const KnockoutClass = preload("res://simulation/competitions/knockout_competition.gd")
const CatalogClass = preload("res://simulation/competitions/competition_catalog.gd")
const GroupStageClass = preload("res://simulation/competitions/group_stage.gd")
const ScheduleConstraintsClass = preload("res://simulation/competitions/schedule_constraints.gd")
const InternationalClass = preload("res://simulation/competitions/international_football.gd")
const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")

func _init() -> void:
	var loader = DatabaseLoaderClass.new()
	var data: Dictionary = loader.load_seed()
	assert(not data.is_empty())
	assert(loader.validate_seed(data).is_empty())
	assert(data.countries.size() >= 8)
	assert(not loader.league_system(data, "nga").is_empty())

	# Determinism is checked on a representative multi-tier launch slice rather than
	# serializing the entire launch database twice in targeted CI.
	var launch_a: Dictionary = LaunchWorldBuilderClass.new().build(11111, 1, 11)
	var launch_b: Dictionary = LaunchWorldBuilderClass.new().build(11111, 1, 11)
	assert(not launch_a.is_empty())
	assert(launch_a.countries.size() == 1)
	assert(launch_a.competitions.size() >= 2)
	assert(launch_a.clubs.size() >= 20)
	assert(launch_a.players.size() >= launch_a.clubs.size() * 11)
	assert(launch_a.fixtures.size() > 500)
	assert(launch_a.clubs.size() == launch_b.clubs.size())
	assert(launch_a.players.size() == launch_b.players.size())
	assert(launch_a.fixtures.size() == launch_b.fixtures.size())
	assert(String(launch_a.clubs[0].id) == String(launch_b.clubs[0].id))
	assert(String(launch_a.players[0].id) == String(launch_b.players[0].id))
	assert(String(launch_a.fixtures[0].id) == String(launch_b.fixtures[0].id))
	assert(int(launch_a.players[0].current_ability) == int(launch_b.players[0].current_ability))

	var clubs := []
	for i in range(8): clubs.append("club-%d" % i)
	var bracket: Dictionary = KnockoutClass.new().create_bracket(clubs, 123)
	assert(bracket.matches.size() == 4)
	var results := []
	for match in bracket.matches:
		results.append({"home_goals":1,"away_goals":0})
	bracket = KnockoutClass.new().advance_round(bracket, results)
	assert(bracket.entrants.size() == 4)

	var groups: Array = GroupStageClass.new().seed_groups(clubs, 2)
	assert(groups.size() == 2)
	var group_fixtures: Array = GroupStageClass.new().fixtures_for_groups(groups, "continental-test")
	assert(group_fixtures.size() == 24)
	var schedule = ScheduleConstraintsClass.new()
	schedule.assign_dates(group_fixtures, {"year":2026,"month":8,"day":1}, 7, 2)
	assert(schedule.validate_rest(group_fixtures, 2).is_empty())

	var tiers: Array = [[], []]
	for i in range(20): tiers[0].append("nga-a-%02d" % i)
	for i in range(20): tiers[1].append("nga-b-%02d" % i)
	var competitions: Array = CatalogClass.new().build_for_country(data, "nga", tiers)
	assert(competitions.size() == 3)
	assert(int(competitions[0].tier) == 1)
	assert(String(competitions[2].rules.type) == "knockout")

	var world: Dictionary = WorldGeneratorClass.new().create_world(80808)
	var international = InternationalClass.new()
	international.ensure_world(world)
	assert(world.national_teams.size() == world.countries.size())
	var nation_id := String(world.countries[0].id)
	var callup: Dictionary = international.register_callups(world, nation_id, "international-test", 23)
	assert(callup.player_ids.size() <= 23)
	var country_ids: Array = []
	for country in world.countries: country_ids.append(String(country.id))
	var qualifying: Dictionary = international.qualifying_groups(country_ids, 2, "qualifiers")
	assert(qualifying.groups.size() == 2)
	print("[TEST] DATABASE/COMPETITIONS PASS")
	quit(0)
