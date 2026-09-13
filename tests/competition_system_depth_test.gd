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
	_test_modern_regional_formats()
	_test_club_world_cup_format()
	if failures == 0:
		print("[TEST] COMPETITION DEPTH PASS: tiebreakers, discipline, regional continental formats and Club World Cup verified")
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

func _test_modern_regional_formats() -> void:
	var world: Dictionary = Builder.new().build(225577,0,25,true)
	var continental = Continental.new(); continental.prepare(world); continental.initialize_formats(world,2026,true)
	var south := _competition(world,"continental-south_america-champions")
	if not south.is_empty() and south.get("club_ids",[]).size() >= 32:
		_require(String(south.get("competition_type","")) == "regional_continental","South America top competition must use modern regional engine")
		_require(int(south.get("format",{}).get("groups",0)) == 8,"South America top competition must have eight groups")
		_require(int(south.get("format",{}).get("group_matches_per_club",0)) == 6,"South America group clubs must play six matches")
		_require(_fixture_count(world,String(south.id),"group_stage") == 96,"South America group stage must create 96 matches")
	var africa := _competition(world,"continental-africa-champions")
	if not africa.is_empty() and africa.get("club_ids",[]).size() >= 16:
		_require(String(africa.get("competition_type","")) == "regional_continental","Africa top competition must use modern regional engine")
		_require(int(africa.get("format",{}).get("groups",0)) == 4,"Africa top competition must have four groups")
		_require(bool(africa.get("format",{}).get("final_two_leg",false)),"Africa final must be two-legged")
		_require(_fixture_count(world,String(africa.id),"group_stage") == 48,"Africa group stage must create 48 matches")
	var north := _competition(world,"continental-north_america-champions")
	if not north.is_empty() and north.get("club_ids",[]).size() >= 27:
		_require(String(north.get("format_kind","")) == "concacaf_27","North America top competition must use 27-club format")
		_require(int(north.get("format",{}).get("round_one_clubs",0)) == 22,"Concacaf-style Round One must contain 22 clubs")
		_require(int(north.get("format",{}).get("round_of_16_byes",0)) == 5,"Concacaf-style format must award five R16 byes")
		_require(_fixture_count(world,String(north.id),"round_one") == 22,"Concacaf-style Round One must create 11 two-legged ties")

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
	_require(_fixture_count(world,"global-club-world-cup","group_stage") == 48,"Club World Cup group stage must contain 48 matches")

func _fixture_count(world: Dictionary,competition_id: String,stage: String) -> int:
	var count := 0
	for fixture in world.get("fixtures",[]):
		if String(fixture.get("competition_id","")) == competition_id and String(fixture.get("stage","")) == stage: count += 1
	return count

func _competition(world: Dictionary,id: String) -> Dictionary:
	for competition in world.get("competitions",[]):
		if String(competition.get("id","")) == id: return competition
	return {}

func _require(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[COMPETITION DEPTH] "+message)
