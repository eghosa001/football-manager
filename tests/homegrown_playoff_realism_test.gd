extends SceneTree

const HomegrownTrainingServiceClass = preload("res://simulation/players/homegrown_training_service.gd")
const RegistrationServiceClass = preload("res://simulation/competitions/registration_service.gd")
const LeagueSystemClass = preload("res://application/season/league_system.gd")

var checks := 0
var failures := 0

func _init() -> void:
	_test_homegrown_is_training_not_nationality()
	_test_homegrown_accrues_across_seasons()
	_test_playoff_is_resolved_by_match()
	if failures == 0:
		print("[TEST] HOMEGROWN + PLAYOFF REALISM PASS: %d checks" % checks)
		quit(0)
		return
	push_error("[TEST] HOMEGROWN + PLAYOFF REALISM FAIL: %d failures across %d checks" % [failures, checks])
	quit(1)

func _test_homegrown_is_training_not_nationality() -> void:
	var registration = RegistrationServiceClass.new()
	var competition := {"id":"eng-1","country_id":"eng","registration_rules":{"max_squad":25,"min_homegrown":1}}
	var same_nationality := {"id":"p1","club_id":"club","country_id":"eng","age":22,"retired":false,"injured_days":0,"training_history_version":1,"training_years_15_21_by_country":{},"training_years_15_21_by_club":{}}
	var trained_foreign_national := {"id":"p2","club_id":"club","country_id":"fra","age":22,"retired":false,"injured_days":0,"training_history_version":1,"training_years_15_21_by_country":{"eng":3.0},"training_years_15_21_by_club":{"club":3.0}}
	var first: Dictionary = registration.eligibility(same_nationality, competition, 2026)
	var second: Dictionary = registration.eligibility(trained_foreign_national, competition, 2026)
	_require(not bool(first.homegrown), "matching nationality must not automatically confer homegrown status")
	_require(bool(second.homegrown), "three qualifying training years must confer association-homegrown status regardless of nationality")
	_require(registration.club_trained(trained_foreign_national, "club"), "three qualifying years at the same club must confer club-trained status")

func _test_homegrown_accrues_across_seasons() -> void:
	var player := {"id":"academy","club_id":"club","country_id":"fra","age":16,"retired":false,"homegrown":false}
	var world := {"clubs":[{"id":"club","country_id":"eng"}],"players":[player]}
	var service = HomegrownTrainingServiceClass.new()
	service.accrue_season(world)
	player.age = 17
	service.accrue_season(world)
	_require(not service.association_homegrown(player, "eng"), "two academy seasons must not yet qualify as homegrown")
	player.age = 18
	service.accrue_season(world)
	_require(service.association_homegrown(player, "eng"), "three academy seasons between ages 15-21 must qualify as homegrown")
	_require(service.club_trained(player, "club"), "three seasons at the same academy must qualify as club-trained")
	player.club_id = "other"
	world.clubs.append({"id":"other","country_id":"esp"})
	player.age = 19
	service.accrue_season(world)
	_require(service.association_homegrown(player, "eng"), "homegrown qualification must persist after a transfer abroad")
	_require(not service.association_homegrown(player, "esp"), "one season after transfer must not create a new association-homegrown qualification")

func _test_playoff_is_resolved_by_match() -> void:
	var clubs: Array = []
	var players: Array = []
	for i in range(8):
		var club_id := "c%d" % i
		clubs.append({"id":club_id,"country_id":"eng","reputation":55+i})
		for p in range(11):
			players.append({"id":"%s-p%d" % [club_id,p],"club_id":club_id,"position":"GK" if p == 0 else "MC","current_ability":50+i,"fitness":100,"morale":70,"retired":false,"injured_days":0})
	var world := {"season_year":2026,"clubs":clubs,"players":players}
	var league = LeagueSystemClass.new()
	var result: Dictionary = league._domestic_playoff(world,["c0","c1","c2","c3"],"eng-league-2",0)
	_require(String(result.get("winner","")) in ["c0","c1","c2","c3"], "playoff bracket must produce a participating winner")
	var matches: Array = result.get("matches",[])
	_require(matches.size() == 3, "four-team playoff must be resolved through two semifinals and a final")
	for match in matches:
		_require(bool(match.get("played",false)), "playoff fixture must be marked played")
		_require(match.has("home_goals") and match.has("away_goals"), "playoff fixture must contain a football score")
		_require(String(match.get("winner","")) in [String(match.home_club_id),String(match.away_club_id)], "playoff fixture must resolve a winner, including level matches")

func _require(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		return
	failures += 1
	push_error("[REALISM] " + message)
