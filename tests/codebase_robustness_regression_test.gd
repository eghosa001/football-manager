extends SceneTree

const RegistrationServiceClass = preload("res://simulation/competitions/registration_service.gd")
const CareerCommandServiceClass = preload("res://application/career/career_command_service.gd")
const ClubEconomyServiceClass = preload("res://simulation/finance/club_economy_service.gd")
const LeagueSystemClass = preload("res://application/season/league_system.gd")

var failures := 0
var checks := 0

func _init() -> void:
	_test_borrowed_player_registration()
	_test_age_exemption_must_be_configured()
	_test_transfer_terms_are_executed()
	_test_transfer_completion_rechecks_window()
	_test_finance_defaults()
	_test_odd_sized_league_byes()
	if failures == 0:
		print("[TEST] CODEBASE ROBUSTNESS REGRESSION PASS: %d checks" % checks)
		quit(0)
		return
	push_error("[TEST] CODEBASE ROBUSTNESS REGRESSION FAIL: %d failures across %d checks" % [failures, checks])
	quit(1)

func _test_borrowed_player_registration() -> void:
	var service = RegistrationServiceClass.new()
	var player := {"id":"loan-p1","club_id":"borrower","country_id":"eng","age":24,"position":"MC","loan_parent_club_id":"parent","loan_end_year":2027,"retired":false,"injured_days":0}
	var world := {"players":[player],"registrations":{}}
	var competition := {"id":"league","country_id":"eng","registration_rules":{"max_squad":25,"max_loans":4}}
	var result: Dictionary = service.register_squad(world,"borrower",competition,["loan-p1"],2026)
	_require("loan-p1" in result.get("registered",[]), "active loanee must be registerable by the borrowing club")
	_require(result.get("rejected",[]).is_empty(), "valid borrowed player must not be rejected as on loan elsewhere")

func _test_age_exemption_must_be_configured() -> void:
	var service = RegistrationServiceClass.new()
	var players := [
		{"id":"p1","club_id":"club","country_id":"eng","age":25,"position":"GK","retired":false,"injured_days":0},
		{"id":"p2","club_id":"club","country_id":"eng","age":20,"position":"MC","retired":false,"injured_days":0},
	]
	var world := {"players":players,"registrations":{}}
	var strict := {"id":"strict","country_id":"eng","registration_rules":{"max_squad":1}}
	var strict_result: Dictionary = service.register_squad(world,"club",strict,["p1","p2"],2026)
	_require(strict_result.get("registered",[]).size() == 1, "U21 player must count toward cap when no exemption exists")
	_require(String(strict_result.get("rejected",[])[0].get("reason","")) == "squad_full", "non-exempt U21 rejection reason must be squad_full")
	var exempt := {"id":"exempt","country_id":"eng","registration_rules":{"max_squad":1,"u21_exempt":true}}
	var exempt_result: Dictionary = service.register_squad(world,"club",exempt,["p1","p2"],2026)
	_require(exempt_result.get("registered",[]).size() == 2, "configured U21 exemption must allow the extra young player")

func _test_transfer_terms_are_executed() -> void:
	var world := _transfer_world("2026-07-15")
	var command = CareerCommandServiceClass.new()
	var result: Dictionary = command.complete_transfer(world,"offer-1",100_000,1_000_000,3,71)
	_require(int(result.get("error",FAILED)) == OK, "accepted transfer must complete inside buyer window")
	_require(String(world.players[0].get("club_id","")) == "buyer", "completed transfer must move player to buyer")
	_require(world.get("payables",[]).size() == 1, "two-instalment deal must schedule one future payable")
	_require(int(world.payables[0].get("amount",0)) == 5_000_000, "future instalment must equal unpaid half of fee")
	_require(is_equal_approx(float(world.players[0].get("sell_on_pct",0.0)),0.10), "accepted sell-on percentage must persist on player")
	_require(String(world.players[0].get("sell_on_beneficiary","")) == "seller", "seller must remain beneficiary of negotiated sell-on")

func _test_transfer_completion_rechecks_window() -> void:
	var world := _transfer_world("2026-10-15")
	var result: Dictionary = CareerCommandServiceClass.new().complete_transfer(world,"offer-1",100_000,1_000_000,3,71)
	_require(int(result.get("error",OK)) == ERR_UNAVAILABLE, "accepted offer must not complete after buyer transfer window closes")
	_require(String(result.get("reason","")) == "transfer_window_closed", "closed-window completion must return explicit reason")
	_require(String(world.players[0].get("club_id","")) == "seller", "failed completion must not mutate player ownership")

func _test_finance_defaults() -> void:
	var club := {"id":"club","name":"Test Club","reputation":60,"cash":10_000_000}
	ClubEconomyServiceClass.new().ensure_club(club)
	_require(int(club.get("ticket_price",0)) > 0, "finance facade must initialize ticket price")
	_require(int(club.get("commercial_revenue",0)) > 0, "finance facade must initialize commercial revenue")
	_require(club.get("sponsorships",[]) is Array and not club.get("sponsorships",[]).is_empty(), "finance facade must initialize sponsorship portfolio")
	_require(club.has("debt") and club.has("financial_status"), "finance facade must initialize debt/status fields")

func _test_odd_sized_league_byes() -> void:
	var clubs := ["A","B","C","D","E"]
	var fixtures: Array = LeagueSystemClass.new()._round_robin("odd", clubs, 2026)
	_require(fixtures.size() == 20, "five-team double round-robin must create 20 fixtures")
	var counts := {}
	for fixture in fixtures:
		var home := String(fixture.get("home_club_id","")); var away := String(fixture.get("away_club_id",""))
		_require(home != "" and away != "" and home != away, "bye slot must never become a real fixture")
		counts[home] = int(counts.get(home,0)) + 1
		counts[away] = int(counts.get(away,0)) + 1
	for club_id in clubs:
		_require(int(counts.get(club_id,0)) == 8, "%s must play every opponent home and away" % club_id)

func _transfer_world(date_string: String) -> Dictionary:
	return {
		"date":date_string,
		"season_year":2026,
		"day_index":1,
		"countries":[{"id":"eng","name":"England"}],
		"clubs":[
			{"id":"seller","name":"Seller","country_id":"eng","cash":20_000_000,"transfer_budget":20_000_000,"wage_budget":500_000,"reputation":50},
			{"id":"buyer","name":"Buyer","country_id":"eng","cash":100_000_000,"transfer_budget":100_000_000,"wage_budget":1_000_000,"reputation":70},
		],
		"players":[{"id":"p","name":"Player","club_id":"seller","country_id":"eng","age":24,"position":"MC","current_ability":50,"potential":65,"morale":70,"happiness":70,"retired":false,"hidden_attributes":{"ambition":50,"loyalty":50}}],
		"contracts":[{"id":"contract-p","player_id":"p","club_id":"seller","start_year":2024,"end_year":2028,"weekly_wage":2_000}],
		"transfer_windows_by_country":{"eng":[{"start_month":6,"start_day":15,"end_month":9,"end_day":1}]},
		"transfer_windows":[{"start_month":6,"start_day":15,"end_month":9,"end_day":1}],
		"transfer_offers":[{"id":"offer-1","player_id":"p","buyer_id":"buyer","seller_id":"seller","fee":10_000_000,"clauses":{"fee":10_000_000,"instalments":2,"sell_on_pct":0.10,"sell_on_percentage":10},"status":"accepted"}],
		"ledger":[],"ledger_audit":[],"payables":[],"receivables":[],"inbox":[],"domain_events":[]
	}

func _require(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		return
	failures += 1
	push_error("[ROBUSTNESS] " + message)
