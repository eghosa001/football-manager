extends SceneTree

const LawsClass = preload("res://simulation/match/football_laws_engine.gd")
const DisciplineClass = preload("res://simulation/competitions/discipline_service.gd")
const FixtureSolverClass = preload("res://simulation/competitions/fixture_constraint_solver.gd")
const CompetitionRulesClass = preload("res://simulation/competitions/competition_rule_engine.gd")
const ManagerCareerClass = preload("res://simulation/staff/manager_career_service.gd")
const TransferNegotiationClass = preload("res://simulation/transfers/transfer_negotiation.gd")
const AgentRegistryClass = preload("res://simulation/transfers/agent_registry.gd")
const EconomyClass = preload("res://simulation/finance/economy_stability_service.gd")
const ScoutingClass = preload("res://simulation/scouting/scouting_service.gd")
const ModManifestClass = preload("res://mods/mod_manifest_service.gd")
const DomainValidatorClass = preload("res://core/schema/domain_validator.gd")
const GeographyClass = preload("res://simulation/world/geography_service.gd")
const SaveStoreClass = preload("res://persistence/save_store.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_laws_and_discipline()
	_test_transfer_clauses()
	_test_manager_career()
	_test_fixture_constraints()
	_test_competition_rules()
	_test_agents_economy_and_scouting()
	_test_mod_and_schema_safety()
	_test_geography()
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
		"clubs":[{"id":"s1","name":"Seller","cash":5_000_000,"reputation":65},{"id":"b1","name":"Buyer","cash":80_000_000,"reputation":80}],
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

func _test_competition_rules() -> void:
	var rules = CompetitionRulesClass.new()
	var table := [
		{"club_id":"a","points":20,"goals_for":20,"goals_against":10},
		{"club_id":"b","points":20,"goals_for":19,"goals_against":12}
	]
	assert(String(rules.rank_table(table,{} )[0].club_id) == "a")
	var knockout := rules.resolve_knockout(1,1,{},1,0,0,0)
	assert(String(knockout.method) == "extra_time")

func _test_agents_economy_and_scouting() -> void:
	var world := {
		"season_year":2026,
		"day_index":1,
		"countries":[{"id":"ng","name":"Nigeria","language":"English"}],
		"clubs":[{"id":"c1","name":"Club","country_id":"ng","cash":-1_000_000,"reputation":60,"annual_revenue":10_000_000,"annual_wages":9_000_000}],
		"players":[{"id":"p1","club_id":"c1","country_id":"ng","age":20,"position":"MC","current_ability":60,"potential":80,"attributes":{"passing":70,"vision":68},"hidden_attributes":{"professionalism":70}}],
		"staff":[{"id":"s1","club_id":"c1","role":"scout","ability":70,"country_id":"ng","languages":["English"]}]
	}
	var agents = AgentRegistryClass.new()
	var agent := agents.create_agent(world,"a1","Agent One",42)
	assert(bool(agents.sign_client(world,"a1",world.players[0]).ok))
	assert(String(world.players[0].agent_id) == "a1")
	assert(String(agent.id) == "a1")
	var economy = EconomyClass.new()
	var finance := economy.advance_season(world)
	assert(finance.has("indices"))
	var scouting = ScoutingClass.new()
	scouting.configure_network(world,"c1",[],["ng"],100000)
	var assignment := scouting.assign_scout(world,"s1","player","p1",1)
	scouting.advance_assignment(world,assignment,60,70,10)
	var report := scouting.analyst_report(world,world.players[0],70,10)
	assert(report.has("role_fit"))

func _test_mod_and_schema_safety() -> void:
	var mods = ModManifestClass.new()
	var validation := mods.validate_manifests([
		{"id":"base","version":"1.0.0","safe_remove":true},
		{"id":"addon","dependencies":["base"],"safe_remove":true}
	])
	assert(bool(validation.ok))
	assert((validation.load_order as Array).size() == 2)
	assert(not bool(mods.can_remove_from_career(validation.manifests,"base").ok))
	var schema = DomainValidatorClass.new()
	var world := {
		"clubs":[{"id":"c1","name":"Club"}],
		"players":[{"id":"p1","club_id":"c1","age":20,"position":"MC","current_ability":60,"potential":80}],
		"fixtures":[],"contracts":[]
	}
	assert(bool(schema.validate_world(world).ok))

func _test_geography() -> void:
	var geo = GeographyClass.new()
	var world := {}
	geo.add_region(world,"r1","ng","South",1.0,1.0)
	geo.add_city(world,"benin","r1","Benin City",6.3350,5.6037,1_700_000)
	geo.add_city(world,"lagos","r1","Lagos",6.5244,3.3792,15_000_000)
	assert(geo.distance_km(world,"benin","lagos") > 100.0)

func _test_save_migration() -> void:
	var store = SaveStoreClass.new()
	var migrated: Dictionary = store._migrate({"schema_version":2,"world":{},"history":[]})
	assert(not migrated.is_empty())
	assert(int(migrated.schema_version) == 3)
	assert((migrated.world as Dictionary).has("discipline"))
	assert((migrated.world as Dictionary).has("regions"))
	assert(store._migrate({"schema_version":999,"world":{},"history":[]}).is_empty())
