extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const LifecycleClass = preload("res://simulation/players/player_lifecycle.gd")
const MarketClass = preload("res://simulation/transfers/transfer_market.gd")
const CareerCycleClass = preload("res://application/career/career_cycle.gd")

var failures := 0
var checks := 0

func _init() -> void:
	print("[TEST] Football Dynasty Phase 4/5")
	_test_attributes_training_and_lifecycle()
	_test_transfer_ledger_and_loans()
	_test_career_cycle_integration()
	_test_fifty_year_population_health()
	_test_twenty_season_squad_soak()
	if failures == 0:
		print("[TEST] PHASE 4/5 PASS — %d checks" % checks)
		quit(0)
	else:
		push_error("[TEST] PHASE 4/5 FAIL — %d failures across %d checks" % [failures, checks])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[TEST] " + message)

func _test_attributes_training_and_lifecycle() -> void:
	var generator = WorldGeneratorClass.new()
	var lifecycle = LifecycleClass.new()
	var world: Dictionary = generator.create_world(45001, 1, 4, 25)
	var player: Dictionary = world.players[0]
	lifecycle.ensure_player_state(player, 45001)
	_expect(player.attributes.size() == 9, "Player must have nine core attributes")
	for value in player.attributes.values():
		_expect(int(value) >= 1 and int(value) <= 100, "Attributes must remain in 1..100")
	var before: int = int(player.current_ability)
	var gain: int = lifecycle.train_player(player, "passing", 1.0, 45002)
	_expect(int(player.current_ability) <= int(player.potential), "Training cannot exceed potential")
	_expect(int(player.current_ability) == before + gain, "Training gain must match CA change")
	var result: Dictionary = lifecycle.advance_year(world, 45003, 2)
	_expect(result.youth.size() == 8, "Two youth players per club must be generated")
	_expect(world.players.size() == 108, "Youth intake must be added to world population")
	for youth_id in result.youth:
		var youth: Dictionary = _find_player(world.players, String(youth_id))
		_expect(int(youth.age) == 16, "Youth intake age must be 16")
		_expect(youth.attributes.size() == 9, "Youth must receive core attributes")
	for active in world.players:
		if bool(active.get("retired", false)):
			continue
		_expect(int(active.get("injured_days", 0)) >= 0 and int(active.get("injured_days", 0)) <= 70, "Injury duration must be bounded")

func _test_transfer_ledger_and_loans() -> void:
	var generator = WorldGeneratorClass.new()
	var market = MarketClass.new()
	var world: Dictionary = generator.create_world(55001, 1, 4, 25)
	var player: Dictionary = world.players[0]
	var seller_id: String = String(player.club_id)
	var buyer: Dictionary = world.clubs[1] if String(world.clubs[1].id) != seller_id else world.clubs[2]
	var buyer_before: int = int(buyer.cash)
	var seller: Dictionary = _find_club(world.clubs, seller_id)
	var seller_before: int = int(seller.cash)
	var fee := 100_000
	var wage: int = market.recommended_wage(player)
	var error: Error = market.execute_transfer(world, String(player.id), String(buyer.id), fee, wage, 3, 2026, 55002)
	_expect(error == OK, "Affordable negotiated transfer must succeed")
	_expect(String(player.club_id) == String(buyer.id), "Transferred player must join buyer")
	_expect(int(buyer.cash) == buyer_before - fee, "Buyer cash must decrease by fee")
	_expect(int(seller.cash) == seller_before + fee, "Seller cash must increase by fee")
	var ledger_sum := 0
	for entry in world.ledger:
		ledger_sum += int(entry.amount)
	_expect(ledger_sum == 0, "Transfer fee ledger must balance to zero")
	var loan_player: Dictionary = world.players[30]
	var parent_id: String = String(loan_player.club_id)
	var borrower: Dictionary = world.clubs[3]
	if String(borrower.id) == parent_id:
		borrower = world.clubs[0]
	var loan_error: Error = market.execute_loan(world, String(loan_player.id), String(borrower.id), 10_000, 2026)
	_expect(loan_error == OK, "Affordable loan must succeed")
	_expect(String(loan_player.get("loan_parent_club_id", "")) == parent_id, "Loan must preserve parent club")
	_expect(market.return_expired_loans(world, 2027) == 1, "Expired loan must return exactly once")
	_expect(String(loan_player.club_id) == parent_id, "Loan player must return to parent club")

func _test_career_cycle_integration() -> void:
	var generator = WorldGeneratorClass.new()
	var cycle = CareerCycleClass.new()
	var world: Dictionary = generator.create_world(57501, 1, 4, 25)
	var history: Array = []
	var result: Dictionary = cycle.complete_year(world, history, 57501)
	_expect(int(result.season_year) == 2027, "Career cycle must roll into next season")
	_expect(history.size() == 1, "Career cycle must archive completed competition")
	_expect(result.lifecycle.youth.size() == 8, "Career cycle must run youth intake")
	_expect(world.players.size() >= 108, "Career cycle must retain and extend player population")
	for club in world.clubs:
		_expect(MarketClass.new().squad_is_viable(world, String(club.id), 18), "Career cycle must leave viable squads")

func _test_fifty_year_population_health() -> void:
	var generator = WorldGeneratorClass.new()
	var lifecycle = LifecycleClass.new()
	var market = MarketClass.new()
	var world: Dictionary = generator.create_world(61001, 1, 4, 25)
	for year_offset in range(50):
		var year: int = 2026 + year_offset
		world.season_year = year
		lifecycle.advance_year(world, 61001 + year_offset * 173, 2)
		market.process_contracts(world, year, 61001 + year_offset * 179)
		market.rebalance_ai_squads(world, year, 61001 + year_offset * 181, 18, 30)
	var active_count := 0
	var total_ca := 0
	var ids := {}
	for player in world.players:
		_expect(not ids.has(String(player.id)), "50-year population must preserve unique player IDs")
		ids[String(player.id)] = true
		if bool(player.get("retired", false)):
			continue
		active_count += 1
		total_ca += int(player.current_ability)
		_expect(int(player.age) >= 16 and int(player.age) <= 39, "Active player age must stay in viable bounds")
		_expect(int(player.current_ability) >= 1 and int(player.current_ability) <= 100, "CA must remain bounded over 50 years")
		_expect(int(player.potential) >= int(player.current_ability) or int(player.age) > 28, "Young active players cannot develop beyond potential")
		for value in player.attributes.values():
			_expect(int(value) >= 1 and int(value) <= 100, "Attributes must remain bounded over 50 years")
	_expect(active_count >= 72 and active_count <= 220, "50-year active population must remain healthy and bounded")
	var average_ca: float = float(total_ca) / maxf(float(active_count), 1.0)
	_expect(average_ca >= 25.0 and average_ca <= 80.0, "50-year average ability must remain plausible")
	_expect(world.staff.size() > 20, "Retired experienced players must feed staff population")
	for club in world.clubs:
		_expect(market.squad_is_viable(world, String(club.id), 18), "50-year clubs must remain positionally viable")

func _test_twenty_season_squad_soak() -> void:
	var generator = WorldGeneratorClass.new()
	var lifecycle = LifecycleClass.new()
	var market = MarketClass.new()
	var world: Dictionary = generator.create_world(65001, 1, 10, 25)
	for season_offset in range(20):
		var year: int = 2026 + season_offset
		world.season_year = year
		market.return_expired_loans(world, year)
		lifecycle.advance_year(world, 65001 + season_offset * 101, 2)
		market.process_contracts(world, year, 65001 + season_offset * 103)
		market.rebalance_ai_squads(world, year, 65001 + season_offset * 107, 20, 30)
		for club in world.clubs:
			_expect(int(club.get("cash", 0)) >= 0, "AI club cash cannot become negative in lifecycle/market soak")
			_expect(int(club.get("transfer_budget", 0)) >= 0, "AI club transfer budget cannot become negative")
			_expect(_active_squad_size(world.players, String(club.id)) >= 18, "AI club must retain viable squad depth")
			_expect(market.squad_is_viable(world, String(club.id), 18), "AI club must retain GK/DC/ST positional viability")
	_expect(world.players.size() > 250, "Long-save population must continue through youth intake")
	var ids := {}
	for player in world.players:
		_expect(not ids.has(String(player.id)), "Player IDs must remain unique over 20 seasons")
		ids[String(player.id)] = true

func _active_squad_size(players: Array, club_id: String) -> int:
	var count := 0
	for player in players:
		if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)):
			count += 1
	return count

func _find_player(players: Array, player_id: String) -> Dictionary:
	for player in players:
		if String(player.id) == player_id:
			return player
	return {}

func _find_club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if String(club.id) == club_id:
			return club
	return {}
