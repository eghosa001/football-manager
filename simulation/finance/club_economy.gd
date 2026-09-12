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
		club["stadium"] = {}
	club.stadium["name"] = String(club.stadium.get("name", club.get("stadium_name", "%s Stadium" % String(club.get("name", "Club")))))
	club.stadium["capacity"] = int(club.stadium.get("capacity", club.get("stadium_capacity", 8_000 + reputation * 260)))
	club.stadium["condition"] = clampi(int(club.stadium.get("condition", 80)), 0, 100)
	club.stadium["expansion_potential"] = clampi(int(club.stadium.get("expansion_potential", 25 + reputation / 2)), 0, 100)
	club.stadium["ownership"] = String(club.stadium.get("ownership", "owned"))
	club.stadium["annual_rent"] = maxi(0, int(club.stadium.get("annual_rent", 0)))

	if not club.has("facilities"):
		club["facilities"] = {}
	club.facilities["training"] = clampi(int(club.facilities.get("training", club.get("training_facilities", 35 + reputation / 2))), 1, 100)
	club.facilities["youth_training"] = clampi(int(club.facilities.get("youth_training", club.facilities.get("youth", club.get("youth_facilities", 30 + reputation / 2)))), 1, 100)
	club.facilities["youth_recruitment"] = clampi(int(club.facilities.get("youth_recruitment", club.get("youth_recruitment", 35 + reputation / 3))), 1, 100)
	club.facilities["sports_science"] = clampi(int(club.facilities.get("sports_science", 25 + reputation / 2)), 1, 100)
	club.facilities["medical"] = clampi(int(club.facilities.get("medical", club.get("medical_facilities", 30 + reputation / 2))), 1, 100)
	club.facilities["scouting"] = clampi(int(club.facilities.get("scouting", 30 + reputation / 2)), 1, 100)
	# Compatibility aliases used by lifecycle/training/scouting services.
	club.facilities["youth"] = int(club.facilities.youth_training)
	club["training_facilities"] = int(club.facilities.training)
	club["youth_facilities"] = int(club.facilities.youth_training)
	club["youth_recruitment"] = int(club.facilities.youth_recruitment)
	club["medical_facilities"] = int(club.facilities.medical)
	club["scouting_facilities"] = int(club.facilities.scouting)
	club["sports_science"] = int(club.facilities.sports_science)

	if not club.has("supporters"):
		club["supporters"] = {}
	var supporter_size := int(club.supporters.get("size", club.supporters.get("core", 2_000 + reputation * 300)))
	club.supporters["size"] = maxi(500, supporter_size)
	club.supporters["core"] = int(club.supporters.size)
	club.supporters["loyalty"] = clampi(int(club.supporters.get("loyalty", 55 + reputation / 5)), 0, 100)
	club.supporters["patience"] = clampi(int(club.supporters.get("patience", 50)), 0, 100)
	club.supporters["passion"] = clampi(int(club.supporters.get("passion", 60)), 0, 100)
	club.supporters["expectation"] = clampi(int(club.supporters.get("expectation", reputation)), 0, 100)
	club.supporters["wealth"] = clampi(int(club.supporters.get("wealth", 45 + reputation / 4)), 0, 100)
	club.supporters["mood"] = clampi(int(club.supporters.get("mood", 65)), 0, 100)

	if not club.has("board"):
		club["board"] = {}
	club.board["patience"] = clampi(int(club.board.get("patience", 65)), 0, 100)
	club.board["ambition"] = clampi(int(club.board.get("ambition", 35 + reputation / 2)), 0, 100)
	club.board["confidence"] = clampi(int(club.board.get("confidence", 65)), 0, 100)
	club.board["financial_prudence"] = clampi(int(club.board.get("financial_prudence", 55)), 0, 100)
	club.board["youth_priority"] = clampi(int(club.board.get("youth_priority", 45 + int(club.facilities.youth_training) / 4)), 0, 100)
	club.board["style_priority"] = String(club.board.get("style_priority", "balanced"))
	if not club.board.has("objectives") or (club.board.objectives as Array).is_empty():
		club.board["objectives"] = _default_objectives(club, reputation)

func _default_objectives(club: Dictionary, reputation: int) -> Array:
	var league_target := maxi(1, 21 - int(round(float(reputation) / 5.0)))
	return [
		{"type": "league_position", "target": league_target, "weight": 1.0},
		{"type": "cup_performance", "target": "quarterfinal" if reputation >= 55 else "third_round", "weight": 0.6},
		{"type": "finance", "target": "break_even" if int(club.board.get("financial_prudence", 55)) >= 55 else "within_budget", "weight": 0.7},
		{"type": "youth_development", "target": 2 if int(club.facilities.get("youth_training", 50)) >= 60 else 1, "weight": 0.4 + float(club.board.get("youth_priority", 45)) / 250.0},
		{"type": "playing_style", "target": String(club.board.get("style_priority", "balanced")), "weight": 0.35},
	]

	club["ticket_price"] = int(club.get("ticket_price", 15 + reputation / 5))
	club["commercial_revenue"] = int(club.get("commercial_revenue", 750_000 + reputation * 35_000))
	club["debt"] = maxi(0, int(club.get("debt", 0)))
	club["financial_status"] = String(club.get("financial_status", "secure"))
	_ensure_sponsorships(club, reputation)

func sponsorship_deals(club: Dictionary) -> Array:
	return club.get("sponsorships", [])

func _ensure_sponsorships(club: Dictionary, reputation: int) -> void:
	if club.has("sponsorships") and club.sponsorships is Array and not club.sponsorships.is_empty():
		return
	var tier := _sponsor_tier(reputation)
	club["sponsorships"] = [
		{"id": "sponsor-%s-shirt" % String(club.get("id", "club")), "category": "shirt", "brand": _sponsor_brand(String(club.get("id", "")), 1), "annual_value": int(tier * 0.55), "years_total": 3, "years_remaining": 3, "tier": tier},
		{"id": "sponsor-%s-secondary" % String(club.get("id", "club")), "category": "secondary", "brand": _sponsor_brand(String(club.get("id", "")), 2), "annual_value": int(tier * 0.30), "years_total": 2, "years_remaining": 2, "tier": tier},
		{"id": "sponsor-%s-local" % String(club.get("id", "club")), "category": "local", "brand": _sponsor_brand(String(club.get("id", "")), 3), "annual_value": int(tier * 0.15), "years_total": 1, "years_remaining": 1, "tier": tier},
	]

func _sponsor_tier(reputation: int) -> int:
	return int(4_000_000 + reputation * 100_000)

func _sponsor_brand(club_id: String, slot: int) -> String:
	var pools := [
		["Orion Mobile", "Northgate Bank", "Vela Airways", "Kestrel Energy", "Bluefin Foods"],
		["Atlas Freight", "Meridian Insurance", "Cobalt Telecom", "Harbor Steel", "Lumen Health"],
		["City Bakery", "Riverside Motors", "Foundry Coffee", "Parkview Clinics", "Union Textiles"],
	]
	var pool: Array = pools[mini(slot - 1, pools.size() - 1)]
	return String(pool[abs(hash(club_id + str(slot))) % pool.size()])

func negotiate_sponsorships(world: Dictionary, club: Dictionary, season_year: int, performance: float) -> int:
	_ensure_sponsorships(club, int(club.get("reputation", 50)))
	var total := 0
	var reputation := int(club.get("reputation", 50))
	for deal in club.sponsorships:
		deal.years_remaining = int(deal.get("years_remaining", 1)) - 1
		total += int(deal.get("annual_value", 0))
		if int(deal.get("years_remaining", 0)) > 0:
			continue
		var growth := 1.0 + (performance - 0.5) * 0.55 + (float(reputation) - 50.0) / 220.0
		growth = clampf(growth, 0.72, 1.85)
		var base := float(_sponsor_tier(reputation))
		var share := 0.55 if String(deal.get("category", "")) == "shirt" else (0.30 if String(deal.get("category", "")) == "secondary" else 0.15)
		var renewed_value := maxi(60_000, int(base * share * growth))
		var duration := 3 if String(deal.get("category", "")) == "shirt" else (2 if String(deal.get("category", "")) == "secondary" else 1)
		deal.annual_value = renewed_value
		deal.years_total = duration
		deal.years_remaining = duration
		deal.brand = _sponsor_brand(String(club.get("id", "")) + str(season_year), 1 if String(deal.get("category", "")) == "shirt" else (2 if String(deal.get("category", "")) == "secondary" else 3))
		_events_emit(world, season_year, "SPONSORSHIP_RENEWED", {"club_id": String(club.get("id", "")), "category": String(deal.get("category", "")), "brand": String(deal.get("brand", "")), "annual_value": renewed_value, "years": duration})
	return total

func _events_emit(world: Dictionary, season_year: int, event_type: String, payload: Dictionary) -> void:
	if not world.has("domain_events"):
		world["domain_events"] = []
	world.domain_events.append({"type": event_type, "season_year": season_year, "payload": payload})

func run_season_finances(world: Dictionary, season_year: int, competition_records: Array = []) -> Dictionary:
	ensure_world(world)
	var reports: Array = []
	for club in world.clubs:
		var club_id: String = String(club.id)
		var opening_cash: int = int(club.cash)
		var entry_start: int = world.ledger.size()
		var performance := _record_performance(competition_records, club_id)
		var sponsor: int = negotiate_sponsorships(world, club, season_year, performance)
		var commercial: int = int(club.get("commercial_revenue", 750_000 + int(club.get("reputation", 50)) * 35_000))
		var broadcast: int = _broadcast_revenue(world, club, competition_records)
		var gate_report := _annual_gate_revenue(world, club)
		var gate: int = int(gate_report.revenue)
		var prize: int = _prize_money(club_id, competition_records)
		var wages: int = _annual_wages(world, club_id)
		var operations: int = _operations_cost(club)
		_ledger.post(world, club_id, sponsor, "sponsorship", "sponsor-%s-%d" % [club_id, season_year], season_year)
		_ledger.post(world, club_id, commercial, "commercial", "commercial-%s-%d" % [club_id, season_year], season_year)
		_ledger.post(world, club_id, broadcast, "broadcast", "broadcast-%s-%d" % [club_id, season_year], season_year)
		_ledger.post(world, club_id, gate, "ticket_income", "tickets-%s-%d" % [club_id, season_year], season_year)
		if prize > 0:
			_ledger.post(world, club_id, prize, "prize_money", "prize-%s-%d" % [club_id, season_year], season_year)
		_ledger.post(world, club_id, -wages, "wages", "wages-%s-%d" % [club_id, season_year], season_year)
		_ledger.post(world, club_id, -operations, "operations", "operations-%s-%d" % [club_id, season_year], season_year)
		if int(club.stadium.get("annual_rent", 0)) > 0:
			_ledger.post(world, club_id, -int(club.stadium.annual_rent), "stadium_rent", "rent-%s-%d" % [club_id, season_year], season_year)
		_apply_financial_safety(world, club, season_year)
		_refresh_budgets(club)
		_update_institutions(club, competition_records)
		var movement := 0
		for i in range(entry_start, world.ledger.size()):
			if String(world.ledger[i].club_id) == club_id:
				movement += int(world.ledger[i].amount)
		reports.append({"club_id": club_id, "opening_cash": opening_cash, "closing_cash": int(club.cash), "ledger_movement": movement, "income": sponsor + commercial + broadcast + gate + prize, "broadcast": broadcast, "corporate_revenue": int(gate_report.get("corporate_revenue", 0)), "standard_revenue": int(gate_report.get("standard_revenue", 0)), "expenses": wages + operations + int(club.stadium.get("annual_rent", 0)), "financial_status": club.financial_status, "average_attendance": int(gate_report.average_attendance), "attendance_rate": float(gate_report.attendance_rate)})
	return {"season_year": season_year, "clubs": reports}

func _broadcast_revenue(world: Dictionary, club: Dictionary, records: Array) -> int:
	# Broadcast pool splits into equal share + merit (league position) +
	# facility/reputation premium. Continental clubs earn an uplift.
	var league_size := 20
	var performance := _record_performance(records, String(club.get("id", "")))
	var league_rep := 50.0
	for competition in world.get("competitions", []):
		if String(competition.get("competition_type", "league")) != "league":
			continue
		if String(club.get("id", "")) in competition.get("club_ids", []):
			league_rep = float(competition.get("reputation", competition.get("league_reputation", 50)))
			league_size = maxi(8, competition.get("club_ids", []).size())
			break
	var pool := float(league_size) * (180_000 + league_rep * 22_000)
	var equal_share := pool / float(maxi(1, league_size))
	var merit := pool * 0.32 * performance / float(maxi(1, league_size)) * 2.0
	var premium := float(club.get("reputation", 50)) * 9_000 + float(club.facilities.get("scouting", 50)) * 1_200
	var continental := 0.0
	for record in records:
		if String(record.get("competition_type", "")) == "league":
			continue
		for row in record.get("table", []):
			if String(row.get("club_id", "")) == String(club.get("id", "")):
				continental = 420_000.0
				break
	return maxi(120_000, int(equal_share * 0.55 + merit + premium * 0.35 + continental))

func invest_in_facility(world: Dictionary, club_id: String, facility: String, season_year: int) -> Error:
	ensure_world(world)
	var club: Dictionary = _find_club(world.clubs, club_id)
	if club.is_empty():
		return ERR_INVALID_PARAMETER
	var normalized := "youth_training" if facility == "youth" else facility
	if not club.facilities.has(normalized):
		return ERR_INVALID_PARAMETER
	var level: int = int(club.facilities[normalized])
	if level >= 100:
		return ERR_ALREADY_EXISTS
	var cost: int = 100_000 + level * 15_000
	if int(club.cash) < cost:
		return ERR_UNAVAILABLE
	_ledger.post(world, club_id, -cost, "facility_investment", "facility-%s-%s-%d" % [club_id, normalized, season_year], season_year)
	club.facilities[normalized] = mini(100, level + 5)
	ensure_club(club)
	return OK

func reconcile_club(world: Dictionary, club_id: String, opening_cash: int, ledger_start: int = 0) -> bool:
	var movement := 0
	for i in range(ledger_start, world.get("ledger", []).size()):
		var entry: Dictionary = world.ledger[i]
		if String(entry.club_id) == club_id:
			movement += int(entry.amount)
	var club: Dictionary = _find_club(world.clubs, club_id)
	return not club.is_empty() and int(club.cash) == opening_cash + movement

func _annual_gate_revenue(world: Dictionary, club: Dictionary) -> Dictionary:
	var revenue := 0
	var corporate_revenue := 0
	var standard_revenue := 0
	var attendance_total := 0
	var matches := 0
	var capacity := int(club.stadium.capacity)
	var corporate := clampi(int(club.stadium.get("corporate_capacity", int(capacity * 0.03))), 0, capacity)
	var form := _season_form(world, String(club.id))
	for fixture in world.get("fixtures", []):
		if not bool(fixture.get("played", false)) or String(fixture.get("home_club_id", "")) != String(club.id):
			continue
		var opponent := _find_club(world.get("clubs", []), String(fixture.get("away_club_id", "")))
		var competition := _competition(world, String(fixture.get("competition_id", "")))
		var rivalry := _rivalry(world, String(club.id), String(opponent.get("id", "")))
		var split := _fixture_revenue_split(club, opponent, competition, rivalry, form, corporate)
		attendance_total += int(split.attendance)
		revenue += int(split.revenue)
		corporate_revenue += int(split.corporate_revenue)
		standard_revenue += int(split.standard_revenue)
		matches += 1
	if matches == 0:
		var split := _fixture_revenue_split(club, {}, {}, {}, 0.5, corporate)
		attendance_total = int(split.attendance) * 19
		revenue = int(split.revenue) * 19
		corporate_revenue = int(split.corporate_revenue) * 19
		standard_revenue = int(split.standard_revenue) * 19
		matches = 19
	return {"revenue": revenue, "corporate_revenue": corporate_revenue, "standard_revenue": standard_revenue, "average_attendance": int(round(float(attendance_total) / maxf(1.0, float(matches)))), "attendance_rate": snappedf(float(attendance_total) / maxf(1.0, float(matches * capacity)), 0.001)}

func _fixture_revenue_split(club: Dictionary, opponent: Dictionary, competition: Dictionary, rivalry: Dictionary, form: float, corporate: int) -> Dictionary:
	var attendance := _fixture_attendance(club, opponent, competition, rivalry, form)
	var corporate_sold := mini(corporate, int(round(float(attendance) * 0.06 + float(corporate) * 0.55)))
	var standard_sold := maxi(0, attendance - corporate_sold)
	var base_price := int(club.get("ticket_price", 20))
	var corporate_price := base_price * 4 + int(float(club.get("reputation", 50)) * 0.6)
	var standard_revenue := standard_sold * base_price
	var corporate_revenue := corporate_sold * corporate_price
	return {"attendance": attendance, "revenue": standard_revenue + corporate_revenue, "corporate_revenue": corporate_revenue, "standard_revenue": standard_revenue, "corporate_sold": corporate_sold, "standard_sold": standard_sold}

func _fixture_attendance(club: Dictionary, opponent: Dictionary, competition: Dictionary, rivalry: Dictionary, form: float) -> int:
	var supporters: Dictionary = club.get("supporters", {"size": 5000, "loyalty": 55, "passion": 60, "mood": 60, "wealth": 50})
	var base := float(supporters.get("size", supporters.get("core", 5000)))
	var loyalty := 0.72 + float(supporters.get("loyalty", 50)) / 250.0
	var passion := 0.82 + float(supporters.get("passion", 50)) / 300.0
	var mood := 0.80 + float(supporters.get("mood", 60)) / 300.0
	var form_factor := 0.82 + clampf(form, 0.0, 1.0) * 0.32
	var opponent_interest := 0.90 + float(opponent.get("reputation", 50)) / 500.0 if not opponent.is_empty() else 1.0
	var importance := 1.08 if bool(competition.get("continental", false)) or String(competition.get("competition_type", "league")) == "knockout" else 1.0
	var rivalry_factor := 1.0 + float(rivalry.get("intensity", 0)) / 500.0
	var price_expected := 10.0 + float(supporters.get("wealth", 50)) * 0.30
	var price_factor := clampf(1.10 - maxf(0.0, float(club.get("ticket_price", 20)) - price_expected) / 120.0, 0.65, 1.10)
	var capacity := int(club.get("stadium", {}).get("capacity", 10000))
	return clampi(int(round(base * loyalty * passion * mood * form_factor * opponent_interest * importance * rivalry_factor * price_factor)), 500, capacity)

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
	for staff_member in world.get("staff", []):
		if String(staff_member.get("club_id", "")) == club_id and not contracted_staff.has(String(staff_member.get("id", ""))):
			weekly += 200 + int(staff_member.get("ability", 50)) * 12
	return weekly * 52

func _operations_cost(club: Dictionary) -> int:
	var stadium_cost: int = int(club.get("stadium", {}).get("capacity", 10000)) * 8
	var facilities: Dictionary = club.get("facilities", {})
	var facility_total := 0
	for key in ["training", "youth_training", "youth_recruitment", "sports_science", "medical", "scouting"]:
		facility_total += int(facilities.get(key, 50))
	return 180_000 + stadium_cost + facility_total * 1_350

func _prize_money(club_id: String, records: Array) -> int:
	var total := 0
	for record in records:
		if String(record.get("competition_type","league")) == "knockout" and String(record.get("champion_club_id","")) == club_id:
			total += 1_000_000
		var position := 0
		for row in record.get("table", []):
			position += 1
			if String(row.club_id) == club_id:
				total += maxi(50_000, 1_200_000 - (position - 1) * 55_000)
	return total if total > 0 else 100_000

func _apply_financial_safety(world: Dictionary, club: Dictionary, season_year: int) -> void:
	_apply_wage_control(world, club, season_year)
	if int(club.get("cash", 0)) >= 0:
		_apply_debt_service(world, club, season_year)
		if int(club.get("cash", 0)) < 0:
			_top_up_to_buffer(world, club, season_year, 250_000)
		return
	var deficit: int = -int(club.get("cash", 0))
	var prudence := float(club.board.get("financial_prudence", 55)) / 100.0
	# Prudent boards inject less debt and cut budgets hard; reckless boards
	# borrow more and risk insolvency. Pre-fund this season's interest so the
	# credit always restores a non-negative buffer.
	var pending_interest := int(round(float(club.get("debt", 0)) * 0.055))
	var credit: int = deficit + pending_interest + int(lerpf(120_000, 320_000, 1.0 - prudence))
	club.debt = int(club.get("debt", 0)) + credit
	_ledger.post(world, String(club.id), credit, "credit_facility", "credit-%s-%d" % [String(club.id), season_year], season_year)
	_apply_debt_service(world, club, season_year)
	if int(club.get("cash", 0)) < 0:
		_top_up_to_buffer(world, club, season_year, 250_000)
	_apply_insolvency(world, club, season_year)

func _top_up_to_buffer(world: Dictionary, club: Dictionary, season_year: int, buffer: int) -> void:
	var shortfall: int = buffer - int(club.get("cash", 0))
	if shortfall <= 0:
		return
	club.debt = int(club.get("debt", 0)) + shortfall
	_ledger.post(world, String(club.id), shortfall, "credit_facility", "credit-topup-%s-%d" % [String(club.id), season_year], season_year)

func _apply_wage_control(world: Dictionary, club: Dictionary, season_year: int) -> void:
	var wages := _annual_wages(world, String(club.id))
	var income := float(maxi(1, int(club.get("commercial_revenue", 0)) + 4_000_000 + int(club.get("reputation", 50)) * 100_000))
	var ratio := float(wages) / income
	if ratio > 0.85:
		# Wage bill too high: board forces a transfer-budget freeze.
		club.transfer_budget = mini(int(club.get("transfer_budget", 0)), int(float(club.get("cash", 0)) * 0.10))
		club.board.confidence = clampi(int(club.board.get("confidence", 65)) - 4, 0, 100)

func _apply_debt_service(world: Dictionary, club: Dictionary, season_year: int) -> void:
	var debt := int(club.get("debt", 0))
	if debt <= 0:
		return
	var interest := mini(int(round(float(debt) * 0.055)), 750_000)
	_ledger.post(world, String(club.id), -interest, "debt_service", "interest-%s-%d" % [String(club.id), season_year], season_year)
	# Amortise 8% of principal when cash allows.
	if int(club.get("cash", 0)) > interest + 200_000:
		var amort := mini(debt, int(round(float(debt) * 0.08)))
		club.debt = debt - amort
		_ledger.post(world, String(club.id), -amort, "debt_service", "amort-%s-%d" % [String(club.id), season_year], season_year)

func _apply_insolvency(world: Dictionary, club: Dictionary, season_year: int) -> void:
	var debt := int(club.get("debt", 0))
	# Administration/restructuring keeps long-run debt bounded: write down
	# unsustainable debt instead of compounding interest forever.
	if debt > 30_000_000:
		var write_down := int(debt * 0.5)
		club.debt = debt - write_down
		_ledger.post(world, String(club.id), 0, "debt_service", "restructure-%s-%d" % [String(club.id), season_year], season_year)
		world.domain_events.append({"type": "CLUB_ADMINISTRATION", "payload": {"club_id": String(club.get("id", "")), "write_down": write_down, "season_year": season_year}}) if world.has("domain_events") else null
		debt = int(club.get("debt", 0))
	var ratio := float(debt) / maxf(1.0, float(int(club.get("cash", 0)) + debt))
	if ratio < 0.85 and int(club.get("cash", 0)) > -1_500_000:
		return
	club["insolvent"] = true
	club.financial_status = "insecure"
	club.transfer_budget = 0
	club.board.confidence = clampi(int(club.board.get("confidence", 60)) - 12, 0, 100)
	club.supporters.mood = clampi(int(club.supporters.get("mood", 60)) - 10, 0, 100)
	if not world.has("domain_events"):
		world["domain_events"] = []
	world.domain_events.append({"type": "CLUB_INSOLVENT", "payload": {"club_id": String(club.get("id", "")), "cash": int(club.get("cash", 0)), "debt": int(club.get("debt", 0)), "season_year": season_year}})

func _refresh_budgets(club: Dictionary) -> void:
	var available: int = maxi(0, int(club.cash) - int(club.debt) / 4)
	var prudence := float(club.board.get("financial_prudence",55))/100.0
	club.transfer_budget = int(available * lerpf(0.34,0.20,prudence))
	club.wage_budget = maxi(25_000, int(available * lerpf(0.014,0.010,prudence)))
	var debt_ratio: float = float(club.debt) / maxf(float(club.cash + club.debt), 1.0)
	club.financial_status = "insecure" if debt_ratio > 0.65 else ("stable" if debt_ratio > 0.30 else "secure")

func _update_institutions(club: Dictionary, records: Array) -> void:
	var status_penalty := -5 if String(club.financial_status) == "insecure" else (0 if String(club.financial_status) == "stable" else 2)
	var performance := _record_performance(records, String(club.id))
	var performance_delta := int(round((performance - 0.5) * 8.0))
	club.board.confidence = clampi(int(club.board.confidence) + status_penalty + performance_delta, 0, 100)
	_apply_supporter_reactions(club, performance, status_penalty, performance_delta)
	var expectation_gap := int(club.reputation) - int(club.supporters.expectation)
	club.supporters.expectation = clampi(int(club.supporters.expectation) + clampi(expectation_gap, -2, 2), 0, 100)
	var growth: int = int(round((float(club.reputation) - 45.0) * 8.0 + (performance - 0.5) * 600.0))
	club.supporters.size = maxi(500, int(club.supporters.size) + growth)
	club.supporters.core = int(club.supporters.size)
	club.stadium.condition = clampi(int(club.stadium.condition) - 1, 40, 100)

func _apply_supporter_reactions(club: Dictionary, performance: float, status_penalty: int, performance_delta: int) -> void:
	var mood_delta := status_penalty + performance_delta
	# Star-player sale hurts; marquee arrival lifts; derby defeat stings extra.
	var transfer_mood := clampi(int(club.get("transfer_mood", 0)), -6, 6)
	mood_delta += transfer_mood
	club["transfer_mood"] = 0
	var loyalty := float(club.supporters.get("loyalty", 55))
	var patience := float(club.supporters.get("patience", 50))
	# Patient loyal fans absorb bad seasons; impatient fans overreact.
	var absorption := lerpf(1.25, 0.70, clampf((loyalty * 0.6 + patience * 0.4) / 100.0, 0.0, 1.0))
	if mood_delta < 0:
		mood_delta = int(round(float(mood_delta) * absorption))
	else:
		mood_delta = int(round(float(mood_delta) * lerpf(0.8, 1.2, loyalty / 100.0)))
	club.supporters.mood = clampi(int(club.supporters.mood) + mood_delta, 0, 100)
	club.supporters.expectation = clampi(int(club.supporters.expectation) + (1 if performance > 0.72 else (-1 if performance < 0.30 else 0)), 0, 100)

func _season_form(world: Dictionary, club_id: String) -> float:
	var points := 0
	var games := 0
	for fixture in world.get("fixtures", []):
		if not bool(fixture.get("played",false)): continue
		var home := String(fixture.get("home_club_id",""))==club_id
		var away := String(fixture.get("away_club_id",""))==club_id
		if not home and not away: continue
		var gf:=int(fixture.get("home_goals",0)) if home else int(fixture.get("away_goals",0)); var ga:=int(fixture.get("away_goals",0)) if home else int(fixture.get("home_goals",0))
		points += 3 if gf>ga else (1 if gf==ga else 0); games += 1
	return float(points)/maxf(1.0,float(games*3))

func _record_performance(records: Array, club_id: String) -> float:
	for record in records:
		var table:Array=record.get("table",[])
		for i in range(table.size()):
			if String(table[i].get("club_id",""))==club_id: return 1.0-float(i)/maxf(1.0,float(table.size()-1))
	return 0.5

func _competition(world:Dictionary,id:String)->Dictionary:
	for competition in world.get("competitions",[]):
		if String(competition.get("id",""))==id: return competition
	return {}
func _rivalry(world:Dictionary,a:String,b:String)->Dictionary:
	for row in world.get("rivalries",[]):
		if (String(row.get("club_a",""))==a and String(row.get("club_b",""))==b) or (String(row.get("club_a",""))==b and String(row.get("club_b",""))==a): return row
	return {}
func _find_club(clubs: Array, club_id: String) -> Dictionary:
	for club in clubs:
		if String(club.id) == club_id:
			return club
	return {}
