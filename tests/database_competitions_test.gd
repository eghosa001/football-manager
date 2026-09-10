extends SceneTree

const DatabaseLoaderClass = preload("res://data/database_loader.gd")
const KnockoutClass = preload("res://simulation/competitions/knockout_competition.gd")
const CatalogClass = preload("res://simulation/competitions/competition_catalog.gd")
const GroupStageClass = preload("res://simulation/competitions/group_stage.gd")
const ScheduleConstraintsClass = preload("res://simulation/competitions/schedule_constraints.gd")

func _init() -> void:
	var loader = DatabaseLoaderClass.new()
	var data: Dictionary = loader.load_seed()
	assert(not data.is_empty())
	assert(loader.validate_seed(data).is_empty())
	assert(data.countries.size() >= 8)
	assert(not loader.league_system(data, "nga").is_empty())

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
	print("[TEST] DATABASE/COMPETITIONS PASS")
	quit(0)
