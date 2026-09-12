class_name FinanceLedger
extends RefCounted

const VALID_CATEGORIES := ["sponsorship", "commercial", "broadcast", "ticket_income", "ticket_corporate", "prize_money", "transfer_fee", "loan_fee", "transfer_instalment", "sell_on_fee", "agent_fee", "signing_bonus", "wages", "staff_wages", "bonuses", "operations", "facility_investment", "stadium_rent", "stadium_project", "scouting", "youth_system", "debt_service", "credit_facility", "tax"]

func ensure(world: Dictionary) -> void:
	if not world.has("ledger"):
		world["ledger"] = []
	if not world.has("ledger_audit"):
		world["ledger_audit"] = []
	if not world.has("payables"):
		world["payables"] = []
	if not world.has("receivables"):
		world["receivables"] = []
	for club in world.clubs:
		club["transfer_budget"] = int(club.get("transfer_budget", int(club.get("cash", 0))))
		club["wage_budget"] = int(club.get("wage_budget", 250_000))
		club["debt"] = maxi(0, int(club.get("debt", 0)))
		club["financial_status"] = String(club.get("financial_status", "secure"))

func post(world: Dictionary, club_id: String, amount: int, category: String, reference: String, season_year: int) -> void:
	ensure(world)
	if category not in VALID_CATEGORIES:
		category = "operations"
	# Duplicate-reference guard: same club/category/reference posts once.
	for entry in world.ledger:
		if String(entry.get("club_id", "")) == club_id and String(entry.get("reference", "")) == reference and String(entry.get("category", "")) == category:
			return
	var opening := 0
	var club: Dictionary = _find_club(world.clubs, club_id)
	opening = int(club.get("cash", 0))
	world.ledger.append({"club_id": club_id, "amount": amount, "category": category, "reference": reference, "season_year": season_year, "day_index": int(world.get("day_index", 0))})
	club.cash = int(club.cash) + amount
	club.transfer_budget = maxi(0, int(club.transfer_budget) + amount)
	_reconcile_status(world, club)
	world.ledger_audit.append({"club_id": club_id, "opening": opening, "closing": int(club.cash), "amount": amount, "category": category, "reference": reference, "season_year": season_year})
	if world.ledger_audit.size() > 2000:
		world.ledger_audit = world.ledger_audit.slice(world.ledger_audit.size() - 2000)

func schedule_payable(world: Dictionary, payer_id: String, payee_id: String, total: int, instalments: int, category: String, reference: String, season_year: int) -> Array:
	ensure(world)
	var plans: Array = []
	var per := int(round(float(total) / float(maxi(1, instalments))))
	for i in range(maxi(1, instalments)):
		var due_year := season_year + i
		var value := per if i < instalments - 1 else total - per * (instalments - 1)
		var row := {"payer_id": payer_id, "payee_id": payee_id, "amount": value, "category": category, "reference": "%s-%d" % [reference, i + 1], "due_year": due_year, "settled": false}
		world.payables.append(row)
		plans.append(row)
	return plans

func settle_due_payables(world: Dictionary, season_year: int) -> Dictionary:
	ensure(world)
	var settled := 0
	var value := 0
	for row in world.payables:
		if bool(row.get("settled", false)) or int(row.get("due_year", season_year)) > season_year:
			continue
		var payer := String(row.get("payer_id", ""))
		var payee := String(row.get("payee_id", ""))
		var amount := int(row.get("amount", 0))
		post(world, payer, -amount, String(row.get("category", "transfer_instalment")), String(row.get("reference", "")), season_year)
		if payee != "":
			post(world, payee, amount, String(row.get("category", "transfer_instalment")), String(row.get("reference", "")), season_year)
		row.settled = true
		settled += 1
		value += amount
	return {"settled": settled, "value": value}

func can_afford_wage(club: Dictionary, weekly_wage: int) -> bool:
	var annual := weekly_wage * 52
	var headroom := int(club.get("wage_budget", 0)) * 2 + maxi(0, int(club.get("cash", 0))) / 8
	return annual <= headroom + 250_000

func debt_ratio(club: Dictionary) -> float:
	return float(club.get("debt", 0)) / maxf(1.0, float(int(club.get("cash", 0)) + int(club.get("debt", 0))))

func _reconcile_status(world: Dictionary, club: Dictionary) -> void:
	var ratio := debt_ratio(club)
	var prior := String(club.get("financial_status", "secure"))
	var next := "insecure" if ratio > 0.65 or int(club.get("cash", 0)) < -500_000 else ("stable" if ratio > 0.30 else "secure")
	club.financial_status = next
	if prior != next:
		if not world.has("domain_events"):
			world["domain_events"] = []
		world.domain_events.append({"type": "FINANCIAL_STATUS_CHANGED", "payload": {"club_id": String(club.get("id", "")), "from": prior, "to": next, "cash": int(club.get("cash", 0)), "debt": int(club.get("debt", 0))}})

func balance(world: Dictionary, club_id: String) -> int:
	var total := 0
	for entry in world.get("ledger", []):
		if String(entry.club_id) == club_id:
			total += int(entry.amount)
	return total

func _find_club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if String(club.id) == club_id:
			return club
	assert(false, "Club not found: %s" % club_id)
	return {}
