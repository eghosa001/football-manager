extends SceneTree

const Builder = preload("res://data/launch_world_builder.gd")
const ModernRules = preload("res://simulation/competitions/modern_rules_catalog.gd")
const Continental = preload("res://application/season/continental_competitions.gd")
const ClubWorldCup = preload("res://application/season/club_world_cup.gd")
const Discipline = preload("res://simulation/competitions/discipline_service.gd")
const LeagueTable = preload("res://simulation/competitions/league_table.gd")

var failures := 0
var checks := 0

func _init() -> void:
	_test_domestic_rule_profiles()
	_test_discipline_thresholds()
	_test_head_to_head_tiebreaker()
	_test_club_world_cup_format()
	if failures == 0:
		print("[TEST] COMPETITION DEPTH PASS: tiebreakers, discipline and Club World Cup profile verified")
		quit(0)
		return
	push_error("[TEST] COMPETITION DEPTH FAIL: %d failures across %d checks" % [failures,checks])
	quit(1)

func _test_domestic_rule_profiles() -> void:
	var world: Dictionary = Builder.new().build(99117,0,25,true)
	ModernRules.new().apply_to_world(world)
	for country in ["eng","esp","deu","fra","ita","nld","bra","arg"]:
		var found := false
		for competition in world.get("competitions",[]):
			if String(competition.get("competition_type","")) == "league" and String(competition.get("country_id","")) == country:
				found = true
				_require(not competition.get("tie_breakers",[]).is_empty(),country+" requires explicit tie-breakers")
				_require(competition.get("yellow_thresholds",[]).size() == competition.get("yellow_bans",[]).size(),country+" discipline profile must align")
				break
		_require(found,country+" league must exist")

func _test_discipline_thresholds() -> void:
	var world := {"season_year":2026,"discipline":{}}
	var service = Discipline.new()
	var rules := {"yellow_thresholds":[3,5],"yellow_bans":[1,2],"red_ban_matches":2,"two_yellow_ban_matches":1}
	for i in range(3): service.apply_match(world,"cup","m%d"%i,[{"type":"card","player_id":"p1","card":"yellow","minute":20+i}],rules)
	_require(service.is_suspended(world,"cup","p1"),"third yellow must trigger configured suspension")
	service.serve_fixture(world,"cup",["p1"],"ban-1")
	_require(not service.is_suspended(world,"cup","p1"),"served one-match yellow suspension must clear")
	service.apply_match(world,"cup","red",[{"type":"card","player_id":"p1","card":"red","minute":70}],rules)
	_require(int(world.discipline.cup.players.p1.ban_remaining) == 2,"direct red must use configured ban length")

func _test_head_to_head_tiebreaker() -> void:
	var fixtures := [
		{"played":true,"home_club_id":"A","away_club_id":"B","home_goals":2,"away_goals":0},
		{"played":true,"home_club_id":"B","away_club_id":"A","home_goals":1,"away_goals":0}
	]
	var table := LeagueTable.build(["A","B"],fixtures,3,1,["points","head_to_head_goal_difference"])
	_require(String(table[0].club_id) == "A","head-to-head goal difference must resolve equal points")

func _test_club_world_cup_format() -> void:
	var world: Dictionary = Builder.new().build(66221,0,25,true)
	var continental = Continental.new()
	continental.prepare(world)
	var competition := _competition(world,"global-club-world-cup")
	_require(not competition.is_empty(),"Club World Cup competition must exist")
	if competition.is_empty(): return
	_require(String(competition.get("competition_type","")) == "club_world_cup","Club World Cup must use dedicated format engine")
	_require(competition.get("club_ids",[]).size() == 32,"Club World Cup must have 32 clubs")
	_require(int(competition.get("format",{}).get("groups",0)) == 8,"Club World Cup must have eight groups")
	ClubWorldCup.new().initialize(world,competition,2028)
	var group_fixtures := 0
	for fixture in world.get("fixtures",[]):
		if String(fixture.get("competition_id","")) == "global-club-world-cup" and String(fixture.get("stage","")) == "group_stage": group_fixtures += 1
	_require(group_fixtures == 48,"Club World Cup group stage must contain 48 matches")

func _competition(world: Dictionary,id: String) -> Dictionary:
	for competition in world.get("competitions",[]):
		if String(competition.get("id","")) == id: return competition
	return {}

func _require(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[COMPETITION DEPTH] "+message)
