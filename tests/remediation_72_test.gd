extends SceneTree

const LawsClass = preload("res://simulation/match/football_laws_engine.gd")
const DisciplineClass = preload("res://simulation/competitions/discipline_service.gd")
const FixtureSolverClass = preload("res://simulation/competitions/fixture_constraint_solver.gd")
const ManagerCareerClass = preload("res://simulation/staff/manager_career_service.gd")
const TransferNegotiationClass = preload("res://simulation/transfers/transfer_negotiation.gd")
const SaveStoreClass = preload("res://persistence/save_store.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_laws_and_discipline()
	_test_transfer_clauses()
	_test_manager_career()
	_test_fixture_constraints()
	_test_save_migration()
	print("[TEST] 72-GAP REMEDIATION PASS")
	quit(0)

func _test_laws_and_discipline() -> void:
	var laws = LawsClass.new()
	var weather: Dictionary = laws.weather_profile(1234)
	assert(String(weather.get("kind", "")) in ["clear","rain","heavy_rain","hot"])
	assert(float(weather.get("pass_factor", 0.0)) > 0.0)
	var cards := [
		{"type":"card","player_id":"p1","card":"yellow","minute":12},
		{"type":"card","player_id":"p1","card":"yellow","minute":55},
		{"type":"card","player_id":"p2","card":"red","minute":70}
	]
	var suspension: Dictionary = laws.suspension_state(cards, {"yellow_limit":2,"red_games":2})
	assert(int(suspension.bans.get("p1",0)) == 1)
	assert(int(suspension.bans.get("p2",0)) == 2)
	var world := {}
	var discipline = DisciplineClass.new()
	discipline.apply_match(world,"league-1","m1",cards,{"yellow_limit":2,"red_ban_matches":2})
	assert(discipline.is_suspended(world,"league-1","p1"))
	assert(discipline.is_suspended(world,"league-1","p2"))
	var served := discipline.serve_fixture(world,"league-1",["p1","p2"])
	assert(served.size() == 2)

func _test_transfer_clauses() -> void:
	var negotiation = TransferNegotiationClass.new()
	var world := {
		"season_year":2026,
		"current_date":"2026-08-20",
		"players":[{"id":"p1","club_id":"s1","current_ability":150,"potential":165,"age":24,"happiness":65,"market_value":20_000_000}],
		"clubs":[{"id":"s1","cash":5_000_000,"reputation":65},{"id":"b1","cash":80_000_000,"reputation":80}],
		"transfer_offers":[]
	}
	var player: Dictionary = world.players[0]
	var buyer: Dictionary = world.clubs[1]
	var offer := negotiation.create_offer(world,player,buyer,18_000_000,{"instalments":3,"sell_on_pct":0.15,"appearance_bonus":15_000,"release_clause":60_000_000})
	var status := negotiation.evaluate_offer(world,offer,77)
	assert(status in ["accepted","rejected"])
	assert(offer.has("valuation"))
	assert(int(offer.clauses.instalments) == 3)
	assert(float(offer.clauses.sell_on_pct) == 0.15)
	assert(int(offer.clauses.release_clause) == 60_000_000)
	assert(not (offer.reason_codes as Array).is_empty())

func _test_manager_career() -> void:
	var service = ManagerCareerClass.new()
	var world := {"season_year":2026}
	var manager := service.create_manager(world,"mgr-human","Test Manager",true,"")
	var job := service.advertise_job(world,"club-1","club",60.0)
	assert(String(service.apply_for_job(world,manager,job).status) == "applied")
	var interview := service.interview(manager,job,{"philosophy_fit":0.9,"wage_fit":0.8,"confidence":0.9},123)
	assert(interview.has("score"))
	var contract := service.offer_contract(world,manager,job,50_000,3)
	var accepted := service.accept_job(manager,job,contract)
	assert(String(accepted.status) == "accepted")
	assert(String(manager.club_id) == "club-1")
	var sacked := service.sack(manager,"club-1",["results_below_target"])
	assert(String(sacked.status) == "sacked")
	assert(String(manager.employment) == "unemployed")

func _test_fixture_constraints() -> void:
	var solver = FixtureSolverClass.new()
	var fixtures := [
		{"id":"f1","date":"2026-09-01","home_id":"a","away_id":"b","venue_id":"v1"},
		{"id":"f2","date":"2026-09-02","home_id":"a","away_id":"c","venue_id":"v1"},
		{"id":"f3","date":"2026-09-02","home_id":"d","away_id":"e","venue_id":"v2"}
	]
	var solved: Dictionary = solver.solve(fixtures,{"min_rest_days":3,"blocked_dates":{"2026-09-03":true},"shared_venues":{"v1":"complex-a","v2":"complex-a"}})
	assert(bool(solved.valid))
	assert((solved.changes as Array).size() >= 1)
	var resolved: Array = solved.fixtures
	assert(String(resolved[1].date) != "2026-09-02")

func _test_save_migration() -> void:
	var store = SaveStoreClass.new()
	var migrated: Dictionary = store._migrate({"schema_version":2,"world":{},"history":[]})
	assert(not migrated.is_empty())
	assert(int(migrated.schema_version) == 3)
	assert((migrated.world as Dictionary).has("discipline"))
	assert((migrated.world as Dictionary).has("regions"))
	assert(store._migrate({"schema_version":999,"world":{},"history":[]}).is_empty())
