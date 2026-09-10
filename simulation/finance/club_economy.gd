class_name ClubEconomy
extends RefCounted

const LedgerClass = preload("res://simulation/finance/ledger.gd")

var _ledger = LedgerClass.new()

func ensure_world(world: Dictionary) -> void:
	_ledger.ensure(world)
	for club in world.clubs:
		ensure_club(club)

func ensure_club(club: Dictionary) -> void:
	var reputation: int = int(club.get("reputation", 50))
	if not club.has("stadium"):
		club["stadium"] = {"capacity": 8_000 + reputation * 260, "condition": 80}
	if not club.has("facilities"):
		club["facilities"] = {"training": clampi(35 + reputation / 2, 20, 90), "youth": clampi(30 + reputation / 2, 20, 90), "medical": clampi(30 + reputation / 2, 20, 90)}
	if not club.has("supporters"):
		club["supporters"] = {"core": 2_000 + reputation * 300, "mood": 65, "expectation": clampi(reputation, 30, 85)}
	if not club.has("board"):
		club["board"] = {"patience": 65, "ambition": clampi(35 + reputation / 2, 35, 80), "confidence": 65}
	club["ticket_price"] = int(club.get("ticket_price", 15 + reputation / 5))
	club["commercial_revenue"] = int(club.get("commercial_revenue", 750_000 + reputation * 35_000))
	club["debt"] = maxi(0, int(club.get("debt", 0)))
	club["financial_status"] = String(club.get("financial_status", "secure"))

func run_season_finances(world: Dictionary, season_year: int, competition_records: Array = []) -> Dictionary:
	ensure_world(world)
	var reports: Array = []
	for club in world.clubs:
		var club_id: String = String(club.id)
		var opening_cash: int = int(club.cash)
		var entry_start: int = world.ledger.size()
		var reputation: int = int(club.reputation)
		var sponsor: int = 4_000_000 + reputation * 100_000
		var commercial: int = int(club.commercial_revenue)
		var gate: int = _annual_gate_revenue(club)
		var prize: int = _prize_money(club_id, competition_records)
		var wages: int = _annual_wages(world, club_id)
		var operations: int = _operations_cost(club)
		_ledger.post(world, club_id, sponsor, "sponsorship", "sponsor-%s-%d" % [club_id, season_year], season_year)
		_ledger.post(world, club_id, commercial, "commercial", "commercial-%s-%d" % [club_id, season_year], season_year)
		_ledger.post(world, club_id, gate, "ticket_income", "tickets-%s-%d" % [club_id, season_year], season_year)
		if prize > 0:
			_ledger.post(world, club_id, prize, "prize_money", "prize-%s-%d" % [club_id, season_year], season_year)
		_ledger.post(world, club_id, -wages, "wages", "wages-%s-%d" % [club_id, season_year], season_year)
		_ledger.post(world, club_id, -operations, "operations", "operations-%s-%d" % [club_id, season_year], season_year)
		_apply_financial_safety(world, club, season_year)
		_refresh_budgets(club)
		_update_institutions(club)
		var movement := 0
		for i in range(entry_start, world.ledger.size()):
			if String(world.ledger[i].club_id) == club_id:
				movement += int(world.ledger[i].amount)
		reports.append({"club_id": club_id, "opening_cash": opening_cash, "closing_cash": int(club.cash), "ledger_movement": movement, "income": sponsor + commercial + gate + prize, "expenses": wages + operations, "financial_status": club.financial_status})
	return {"season_year": season_year, "clubs": reports}

func invest_in_facility(world: Dictionary, club_id: String, facility: String, season_year: int) -> Error:
	ensure_world(world)
	var club: Dictionary = _find_club(world.clubs, club_id)
	if club.is_empty() or not club.facilities.has(facility):
		return ERR_INVALID_PARAMETER
	var level: int = int(club.facilities[facility])
	if level >= 100:
		return ERR_ALREADY_EXISTS
	var cost: int = 100_000 + level * 15_000
	if int(club.cash) < cost:
		return ERR_UNAVAILABLE
	_ledger.post(world, club_id, -cost, "facility_investment", "facility-%s-%s-%d" % [club_id, facility, season_year], season_year)
	club.facilities[facility] = mini(100, level + 5)
	return OK

func reconcile_club(world: Dictionary, club_id: String, opening_cash: int, ledger_start: int = 0) -> bool:
	var movement := 0
	for i in range(ledger_start, world.get("ledger", []).size()):
		var entry: Dictionary = world.ledger[i]
		if String(entry.club_id) == club_id:
			movement += int(entry.amount)
	var club: Dictionary = _find_club(world.clubs, club_id)
	return not club.is_empty() and int(club.cash) == opening_cash + movement

func _annual_gate_revenue(club: Dictionary) -> int:
	var capacity: int = int(club.stadium.capacity)
	var supporters: int = int(club.supporters.core)
	var reputation: int = int(club.reputation)
	var attendance: int = mini(capacity, int(supporters * (0.55 + reputation / 200.0)))
	return attendance * int(club.ticket_price) * 19

func _annual_wages(world: Dictionary, club_id: String) -> int:
	var weekly := 0
	for contract in world.get("contracts", []):
		if String(contract.get("club_id", "")) == club_id:
			weekly += int(contract.get("weekly_wage", 0))
	var contracted_staff := {}
	for contract in world.get("staff_contracts", []):
		if String(contract.get("club_id", "")) != club_id:
			continue
		weekly += int(contract.get("weekly_wage", 0))
		contracted_staff[String(contract.get("staff_id", ""))] = true
	# Backward-compatible fallback for old saves without staff contracts.
	for staff_member in world.get("staff", []):
		if String(staff_member.get("club_id", "")) == club_id and not contracted_staff.has(String(staff_member.get("id", ""))):
			weekly += 200 + int(staff_member.get("ability", 50)) * 12
	return weekly * 52

func _operations_cost(club: Dictionary) -> int:
	var stadium_cost: int = int(club.stadium.capacity) * 8
	var facility_total: int = int(club.facilities.training) + int(club.facilities.youth) + int(club.facilities.medical)
	return 180_000 + stadium_cost + facility_total * 2_500

func _prize_money(club_id: String, records: Array) -> int:
	for record in records:
		var position := 0
		for row in record.get("table", []):
			position += 1
			if String(row.club_id) == club_id:
				return maxi(50_000, 1_200_000 - (position - 1) * 55_000)
	return 100_000

func _apply_financial_safety(world: Dictionary, club: Dictionary, season_year: int) -> void:
	if int(club.cash) >= 0:
		return
	var deficit: int = -int(club.cash)
	var credit: int = deficit + 250_000
	club.debt = int(club.debt) + credit
	_ledger.post(world, String(club.id), credit, "credit_facility", "credit-%s-%d" % [String(club.id), season_year], season_year)

func _refresh_budgets(club: Dictionary) -> void:
	var available: int = maxi(0, int(club.cash) - int(club.debt) / 4)
	club.transfer_budget = int(available * 0.28)
	club.wage_budget = maxi(25_000, int(available * 0.012))
	var debt_ratio: float = float(club.debt) / maxf(float(club.cash + club.debt), 1.0)
	club.financial_status = "insecure" if debt_ratio > 0.65 else ("stable" if debt_ratio > 0.30 else "secure")

func _update_institutions(club: Dictionary) -> void:
	var status_penalty := -5 if String(club.financial_status) == "insecure" else (0 if String(club.financial_status) == "stable" else 2)
	club.board.confidence = clampi(int(club.board.confidence) + status_penalty, 0, 100)
	club.supporters.mood = clampi(int(club.supporters.mood) + status_penalty, 0, 100)
	var growth: int = maxi(0, int(club.reputation) - 45) * 8
	club.supporters.core = maxi(500, int(club.supporters.core) + growth)
	club.stadium.condition = clampi(int(club.stadium.condition) - 1, 40, 100)

func _find_club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if String(club.id) == club_id:
			return club
	return {}
