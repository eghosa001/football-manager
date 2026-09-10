extends SceneTree

const WorldGeneratorClass = preload("res://simulation/world/world_generator.gd")
const EconomyClass = preload("res://simulation/finance/club_economy.gd")
const TacticsClass = preload("res://simulation/tactics/tactics_manager.gd")
const TacticalMatchClass = preload("res://simulation/match/tactical_match_engine.gd")
const CareerCycleClass = preload("res://application/career/career_cycle.gd")

var failures := 0
var checks := 0

func _init() -> void:
	print("[TEST] Football Dynasty Phase 6/7")
	_test_institutional_finance_and_reconciliation()
	_test_hundred_year_economic_health()
	_test_manager_identity_and_lineup_policy()
	_test_tactical_styles_and_role_ratings()
	_test_career_cycle_economy_tactics()
	if failures == 0:
		print("[TEST] PHASE 6/7 PASS — %d checks" % checks)
		quit(0)
	else:
		push_error("[TEST] PHASE 6/7 FAIL — %d failures across %d checks" % [failures, checks])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[TEST] " + message)

func _test_institutional_finance_and_reconciliation() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(76001, 1, 4, 25)
	var economy = EconomyClass.new()
	economy.ensure_world(world)
	var openings := {}
	var starts := {}
	for club in world.clubs:
		openings[String(club.id)] = int(club.cash)
		starts[String(club.id)] = world.ledger.size()
		_expect(club.has("stadium") and club.has("facilities") and club.has("board") and club.has("supporters"), "Every club needs institutional state")
	var report: Dictionary = economy.run_season_finances(world, 2026, [])
	_expect(report.clubs.size() == 4, "Economy must report every club")
	for club in world.clubs:
		var id: String = String(club.id)
		_expect(economy.reconcile_club(world, id, int(openings[id]), int(starts[id])), "Club cash must reconcile exactly to ledger movement")
		_expect(int(club.cash) >= 0, "Financial safety must prevent negative cash")
		_expect(int(club.transfer_budget) >= 0 and int(club.wage_budget) > 0, "Budgets must remain non-negative")
		_expect(String(club.financial_status) in ["secure", "stable", "insecure"], "Financial status must be classified")
	var target: Dictionary = world.clubs[0]
	var old_level: int = int(target.facilities.training)
	if int(target.cash) > 2_000_000:
		var invest_error: Error = economy.invest_in_facility(world, String(target.id), "training", 2026)
		_expect(invest_error == OK, "Affordable facility investment must succeed")
		_expect(int(target.facilities.training) == mini(100, old_level + 5), "Facility investment must improve level")

func _test_hundred_year_economic_health() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(77001, 1, 4, 25)
	var economy = EconomyClass.new()
	economy.ensure_world(world)
	for year_offset in range(100):
		var year: int = 2026 + year_offset
		economy.run_season_finances(world, year, [])
		for club in world.clubs:
			_expect(int(club.cash) >= 0, "100-year economy cannot leave negative cash")
			_expect(int(club.debt) >= 0 and int(club.debt) < 2_000_000_000, "Debt must stay bounded")
			_expect(int(club.cash) < 2_000_000_000, "Cash must not run away beyond economic bound")
			_expect(int(club.supporters.core) >= 500 and int(club.supporters.core) < 2_000_000, "Supporter population must stay bounded")
	var insecure := 0
	for club in world.clubs:
		if String(club.financial_status) == "insecure":
			insecure += 1
	_expect(insecure < world.clubs.size(), "The simulation must not make every club financially insecure")
	for club in world.clubs:
		var expected := 5_000_000
		for entry in world.ledger:
			if String(entry.club_id) == String(club.id):
				expected += int(entry.amount)
		_expect(int(club.cash) == expected, "100-year cash must be fully explained by ledger entries")

func _test_manager_identity_and_lineup_policy() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(78001, 1, 4, 25)
	var tactics = TacticsClass.new()
	tactics.ensure_world(world, 78001)
	var manager_count := 0
	for staff_member in world.staff:
		if String(staff_member.role) == "manager":
			manager_count += 1
			_expect(staff_member.has("manager_profile"), "Managers need tactical identities")
			_expect(TacticsClass.FORMATIONS.has(String(staff_member.manager_profile.preferred_formation)), "Manager formation must be supported")
	_expect(manager_count == world.clubs.size(), "Every generated club must have one manager identity")
	for club in world.clubs:
		_expect(club.has("tactic"), "Every club needs an active tactic")
		var lineup: Array = tactics.select_lineup(world.players, String(club.id), club.tactic)
		_expect(lineup.size() == 11, "Tactical lineup policy must select eleven players")
		var unique := {}
		for player in lineup:
			unique[String(player.id)] = true
		_expect(unique.size() == 11, "Tactical lineup cannot duplicate players")

func _test_tactical_styles_and_role_ratings() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(79001, 1, 4, 25)
	var tactics = TacticsClass.new()
	var engine = TacticalMatchClass.new()
	for player in world.players:
		if not player.has("attributes"):
			player["attributes"] = {"technique": int(player.current_ability), "passing": int(player.current_ability), "pace": int(player.current_ability), "strength": int(player.current_ability), "finishing": int(player.current_ability)}
	var attacking: Dictionary = tactics.create_tactic("4-3-3", "positive", "high", "high")
	var cautious: Dictionary = tactics.create_tactic("4-2-3-1", "cautious", "low", "low")
	var balanced: Dictionary = tactics.create_tactic("4-4-2", "balanced", "standard", "standard")
	var styles := [attacking, cautious, balanced]
	var shot_totals := [0, 0, 0]
	var pass_totals := [0, 0, 0]
	var wins := [0, 0, 0]
	var home: Dictionary = world.clubs[0]
	var away: Dictionary = world.clubs[1]
	for style_index in range(styles.size()):
		for seed_offset in range(60):
			var result: Dictionary = engine.simulate_with_tactics(home, away, world.players, 79001 + style_index * 1000 + seed_offset, styles[style_index], balanced)
			shot_totals[style_index] += int(result.stats.home.shots)
			pass_totals[style_index] += int(result.stats.home.completed_passes)
			if int(result.home_goals) > int(result.away_goals):
				wins[style_index] += 1
			_expect(String(result.rating_policy) == "role_aware", "Tactical matches must use role-aware rating policy")
	_expect(shot_totals[0] > shot_totals[1], "Positive/high-tempo football must create more shots than cautious/low-tempo football")
	_expect(pass_totals[1] != pass_totals[0], "Controlled tactical styles must create statistically distinct passing output")
	for value in wins:
		_expect(int(value) > 0 and int(value) < 60, "No tested tactic may be a universal win or universal loss strategy")
	var before: float = float(attacking.familiarity)
	tactics.train_tactic({"tactic": attacking}, 10)
	_expect(float(attacking.familiarity) > before, "Tactical familiarity must improve through training")

func _test_career_cycle_economy_tactics() -> void:
	var world: Dictionary = WorldGeneratorClass.new().create_world(80001, 1, 4, 25)
	var history: Array = []
	var result: Dictionary = CareerCycleClass.new().complete_year(world, history, 80001)
	_expect(result.has("economy"), "Career cycle must close the financial year")
	_expect(result.economy.clubs.size() == world.clubs.size(), "Career economy must report every club")
	for club in world.clubs:
		_expect(club.has("tactic"), "Career cycle must retain club tactics")
		_expect(float(club.tactic.familiarity) >= 50.0, "Career cycle must train tactical familiarity")
		_expect(int(club.cash) >= 0, "Career economy must leave clubs solvent in cash terms")
