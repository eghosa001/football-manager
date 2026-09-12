class_name TransferMarket
extends RefCounted

const LedgerClass = preload("res://simulation/finance/ledger.gd")
const SeededRngClass = preload("res://core/rng/seeded_rng.gd")
const DomainEventBusClass = preload("res://core/events/domain_event_bus.gd")

var _ledger = LedgerClass.new()
var _events = DomainEventBusClass.new()

func player_value(player: Dictionary, season_year: int) -> int:
	return estimated_value(player, {}, {}, season_year)

func estimated_value(player: Dictionary, seller: Dictionary = {}, buyer: Dictionary = {}, season_year: int = 0) -> int:
	if bool(player.get("retired", false)):
		return 0
	var ca: int = int(player.get("current_ability", 50))
	var upside: int = maxi(0, int(player.get("potential", ca)) - ca)
	var age: int = int(player.get("age", 24))
	var peak_factor: float = 1.0 if age <= 28 else maxf(0.35, 1.0 - float(age - 28) * 0.08)
	if age <= 20:
		peak_factor *= 1.18
	elif age <= 23:
		peak_factor *= 1.08
	var base := float(ca * ca * 700 + upside * 45_000) * peak_factor
	# Position scarcity: strikers and creative attackers cost more.
	var scarcity := 1.0
	match String(player.get("position", "MC")):
		"ST":
			scarcity = 1.22
		"AMC", "AMR", "AML":
			scarcity = 1.12
		"GK":
			scarcity = 0.88
		"DC", "DM":
			scarcity = 0.96
	# Form / morale: in-form players carry a premium.
	var form := clampf(float(player.get("form", 50)) / 50.0, 0.82, 1.25)
	var morale := lerpf(0.94, 1.06, clampf(float(player.get("morale", 50)) / 100.0, 0.0, 1.0))
	# Contract length: short contracts discount heavily.
	var contract_factor := 1.0
	if not seller.is_empty():
		var years_left := _contract_years_left(player, season_year)
		if years_left <= 0:
			contract_factor = 0.45
		elif years_left == 1:
			contract_factor = 0.68
		elif years_left == 2:
			contract_factor = 0.86
	# Reputation and club/league context.
	var rep_factor := lerpf(0.85, 1.30, clampf(float(player.get("reputation", ca)) / 100.0, 0.0, 1.0))
	var seller_factor := 1.0
	if not seller.is_empty():
		seller_factor = lerpf(0.92, 1.18, clampf(float(seller.get("reputation", 50)) / 100.0, 0.0, 1.0))
		if String(seller.get("financial_status", "secure")) == "insecure":
			seller_factor *= 0.88
	var buyer_factor := 1.0
	if not buyer.is_empty():
		buyer_factor = lerpf(0.97, 1.12, clampf(float(buyer.get("reputation", 50)) / 100.0, 0.0, 1.0))
	var trait_premium := 1.0 + float(player.get("traits", []).size()) * 0.02
	return maxi(5_000, int(base * scarcity * form * morale * contract_factor * rep_factor * seller_factor * buyer_factor * trait_premium))

func asking_price(player: Dictionary, seller: Dictionary, buyer: Dictionary, season_year: int, deadline_proximity: float = 0.0) -> int:
	var estimate := float(estimated_value(player, seller, buyer, season_year))
	var importance := clampf(float(player.get("squad_importance", 50)) / 100.0, 0.0, 1.0)
	var happiness := clampf(float(player.get("happiness", 60)) / 100.0, 0.0, 1.0)
	var seller_need := 1.0 + importance * 0.35 - (1.0 - happiness) * 0.18
	if not seller.is_empty() and String(seller.get("financial_status", "secure")) == "secure":
		seller_need *= 1.08
	var rivalry := 1.0
	if not seller.is_empty() and not buyer.is_empty() and _are_rivals(seller, buyer):
		rivalry = 1.28
	var deadline := 1.0 + clampf(deadline_proximity, 0.0, 1.0) * 0.22
	return maxi(5_000, int(estimate * seller_need * rivalry * deadline))

func _contract_years_left(player: Dictionary, season_year: int) -> int:
	var contracts: Array = player.get("contracts", [])
	if contracts.is_empty() and player.has("contract_end_year"):
		return maxi(0, int(player.get("contract_end_year", season_year)) - season_year)
	var best := 99
	for contract in contracts:
		best = mini(best, int(contract.get("end_year", season_year)) - season_year)
	return best if best != 99 else 2

func _are_rivals(seller: Dictionary, buyer: Dictionary) -> bool:
	var a := String(seller.get("id", ""))
	var b := String(buyer.get("id", ""))
	return String(seller.get("rival_club_id", "")) == b or String(buyer.get("rival_club_id", "")) == a

func recommended_wage(player: Dictionary) -> int:
	return clampi(int(player.current_ability) * int(player.current_ability) * 5, 500, 60_000)

func process_contracts(world: Dictionary, season_year: int, seed: int) -> Dictionary:
	_ledger.ensure(world)
	_events.ensure_world(world)
	var renewed: Array = []
	var released: Array = []
	for contract in world.contracts:
		if int(contract.end_year) > season_year:
			continue
		var player: Dictionary = _find_player(world.players, String(contract.player_id))
		if player.is_empty() or bool(player.get("retired", false)):
			continue
		var club: Dictionary = _find_club(world.clubs, String(contract.club_id))
		var wage: int = recommended_wage(player)
		if not club.is_empty() and int(player.current_ability) >= 45 and wage <= int(club.wage_budget):
			contract.start_year = season_year
			contract.end_year = season_year + 3
			contract.weekly_wage = wage
			renewed.append(String(player.id))
			_events.emit(world, "CONTRACT_SIGNED", {"player_id":String(player.id),"club_id":String(club.id),"start_year":season_year,"end_year":season_year+3,"weekly_wage":wage,"renewal":true}, "transfer_market")
		else:
			player.club_id = ""
			released.append(String(player.id))
	return {"renewed": renewed, "released": released}

func negotiate_contract(player: Dictionary, club: Dictionary, offered_wage: int, years: int, seed: int) -> bool:
	if years < 1 or years > 5:
		return false
	var target: int = recommended_wage(player)
	var tolerance: int = _rand_int(seed, _stable_key(String(player.id) + String(club.id)), 85, 110)
	return offered_wage * 100 >= target * tolerance and offered_wage <= int(club.get("wage_budget", 250_000))

func execute_transfer(world: Dictionary, player_id: String, buyer_id: String, fee: int, wage: int, years: int, season_year: int, seed: int, terms: Dictionary = {}) -> Error:
	_ledger.ensure(world)
	_events.ensure_world(world)
	var player: Dictionary = _find_player(world.players, player_id)
	var buyer: Dictionary = _find_club(world.clubs, buyer_id)
	if player.is_empty() or buyer.is_empty() or bool(player.get("retired", false)):
		return ERR_INVALID_PARAMETER
	var seller_id: String = String(player.get("club_id", ""))
	if seller_id == buyer_id:
		return ERR_ALREADY_EXISTS
	var instalments := clampi(int(terms.get("instalments", 1)), 1, 5)
	var sell_on := clampf(float(terms.get("sell_on_pct", 0.0)), 0.0, 0.30)
	var upfront := int(round(float(fee) / float(instalments)))
	if fee < 0 or int(buyer.transfer_budget) < upfront:
		return ERR_UNAVAILABLE
	if not negotiate_contract(player, buyer, wage, years, seed):
		return ERR_UNAUTHORIZED
	var reference := "transfer-%s-%d" % [player_id, season_year]
	_pay_sell_on_chain(world, player, seller_id, fee, season_year)
	_ledger.post(world, buyer_id, -upfront, "transfer_fee", reference, season_year)
	if seller_id != "":
		_ledger.post(world, seller_id, upfront, "transfer_fee", reference, season_year)
	if instalments > 1 and seller_id != "":
		_ledger.schedule_payable(world, buyer_id, seller_id, fee - upfront, instalments - 1, "transfer_instalment", reference, season_year + 1)
	# Agent fee + signing bonus move real money through the ledger, but only
	# when the deal terms explicitly include them. Plain fee-only transfers
	# (including legacy tests) keep exact fee accounting.
	var agent_fee := maxi(0, int(terms.get("agent_fee", 0)))
	if agent_fee == 0 and bool(terms.get("pay_agent_fee", false)):
		agent_fee = _agent_fee_for(player, buyer, fee, seed)
	if agent_fee > 0:
		_ledger.post(world, buyer_id, -agent_fee, "agent_fee", "agent-%s-%d" % [player_id, season_year], season_year)
	var signing_bonus := maxi(0, int(terms.get("signing_bonus", 0)))
	if signing_bonus > 0:
		_ledger.post(world, buyer_id, -signing_bonus, "signing_bonus", "signing-%s-%d" % [player_id, season_year], season_year)
	player.club_id = buyer_id
	player.erase("loan_parent_club_id")
	player.erase("loan_end_year")
	player["sell_on_pct"] = sell_on
	player["sell_on_beneficiary"] = seller_id
	_upsert_contract(world, player_id, buyer_id, season_year, season_year + years, wage, terms)
	_events.emit(world, "PLAYER_SIGNED", {"player_id": player_id, "buyer_id": buyer_id, "seller_id": seller_id, "fee": fee, "upfront": upfront, "instalments": instalments, "sell_on_pct": sell_on, "transfer_type": "permanent", "season_year": season_year}, "transfer_market")
	_events.emit(world, "CONTRACT_SIGNED", {"player_id": player_id, "club_id": buyer_id, "start_year": season_year, "end_year": season_year + years, "weekly_wage": wage, "renewal": false}, "transfer_market")
	return OK

func _pay_sell_on_chain(world: Dictionary, player: Dictionary, seller_id: String, fee: int, season_year: int) -> void:
	var beneficiary := String(player.get("sell_on_beneficiary", ""))
	var pct := float(player.get("sell_on_pct", 0.0))
	if beneficiary == "" or pct <= 0.0 or fee <= 0:
		return
	var due := int(round(float(fee) * pct))
	var reference := "sellon-%s-%d" % [String(player.get("id", "")), season_year]
	# Beneficiary is paid from the seller's proceeds; seller keeps the rest.
	_ledger.post(world, seller_id, -due, "sell_on_fee", reference, season_year)
	_ledger.post(world, beneficiary, due, "sell_on_fee", reference, season_year)
	_events.emit(world, "SELL_ON_PAID", {"player_id": String(player.get("id", "")), "beneficiary_id": beneficiary, "seller_id": seller_id, "fee": fee, "due": due, "season_year": season_year}, "transfer_market")

func _agent_fee_for(player: Dictionary, buyer: Dictionary, fee: int, seed: int) -> int:
	var greed := float(player.get("hidden_attributes", {}).get("greed", player.get("hidden_attributes", {}).get("ambition", 50)))
	var base := float(fee) * (0.03 + greed / 2500.0)
	# Agent who dislikes the buyer charges more; good relationship discounts.
	var agent: Dictionary = player.get("agent", {})
	var rel := float(agent.get("club_relationships", {}).get(String(buyer.get("id", "")), 0))
	base *= clampf(1.0 - rel / 400.0, 0.85, 1.25)
	return maxi(0, int(round(base)))

func execute_loan(world: Dictionary, player_id: String, borrower_id: String, fee: int, season_year: int, terms: Dictionary = {}) -> Error:
	_ledger.ensure(world)
	_events.ensure_world(world)
	var player: Dictionary = _find_player(world.players, player_id)
	var borrower: Dictionary = _find_club(world.clubs, borrower_id)
	if player.is_empty() or borrower.is_empty() or String(player.get("club_id", "")) == "":
		return ERR_INVALID_PARAMETER
	if int(borrower.transfer_budget) < fee:
		return ERR_UNAVAILABLE
	var parent_id: String = String(player.club_id)
	var reference := "loan-%s-%d" % [player_id, season_year]
	_ledger.post(world, borrower_id, -fee, "loan_fee", reference, season_year)
	_ledger.post(world, parent_id, fee, "loan_fee", reference, season_year)
	player.loan_parent_club_id = parent_id
	player.loan_end_year = season_year + 1
	player.loan_fee = fee
	player.loan_wage_contribution_pct = clampf(float(terms.get("wage_contribution_pct", 0.0)), 0.0, 1.0)
	player.loan_buy_option = maxi(0, int(terms.get("buy_option", 0)))
	player.loan_buy_obligation = bool(terms.get("buy_obligation", false))
	player.loan_appearances_start = int(player.get("career_appearances", 0))
	player.club_id = borrower_id
	_events.emit(world, "PLAYER_SIGNED", {"player_id":player_id,"buyer_id":borrower_id,"seller_id":parent_id,"fee":fee,"transfer_type":"loan","loan_end_year":season_year+1,"buy_option":int(player.loan_buy_option),"buy_obligation":bool(player.loan_buy_obligation)}, "transfer_market")
	return OK

func settle_loan_terms(world: Dictionary, season_year: int, seed: int) -> Dictionary:
	_ledger.ensure(world)
	_events.ensure_world(world)
	var bought: Array = []
	var returned: Array = []
	var lapsed: Array = []
	for player in world.players:
		var parent_id := String(player.get("loan_parent_club_id", ""))
		if parent_id == "" or int(player.get("loan_end_year", 9999)) > season_year:
			continue
		var borrower_id := String(player.get("club_id", ""))
		var borrower := _find_club(world.clubs, borrower_id)
		var buy_option := int(player.get("loan_buy_option", 0))
		var obligation := bool(player.get("loan_buy_obligation", false))
		var apps := int(player.get("career_appearances", 0)) - int(player.get("loan_appearances_start", 0))
		var should_buy := false
		if buy_option > 0 and not borrower.is_empty():
			if obligation:
				should_buy = int(borrower.get("transfer_budget", 0)) >= buy_option
			else:
				should_buy = apps >= 12 and int(player.get("current_ability", 0)) >= 52 and int(borrower.get("transfer_budget", 0)) >= buy_option
		if should_buy:
			var reference := "loan-buy-%s-%d" % [String(player.get("id", "")), season_year]
			_ledger.post(world, borrower_id, -buy_option, "transfer_fee", reference, season_year)
			_ledger.post(world, parent_id, buy_option, "transfer_fee", reference, season_year)
			_upsert_contract(world, String(player.get("id", "")), borrower_id, season_year, season_year + 3, recommended_wage(player))
			_clear_loan_fields(player)
			bought.append({"player_id": String(player.get("id", "")), "buyer_id": borrower_id, "seller_id": parent_id, "fee": buy_option, "appearances": apps, "obligation": obligation})
			_events.emit(world, "PLAYER_SIGNED", {"player_id": String(player.get("id", "")), "buyer_id": borrower_id, "seller_id": parent_id, "fee": buy_option, "transfer_type": "loan_to_permanent", "season_year": season_year}, "transfer_market")
		elif obligation and buy_option > 0:
			lapsed.append({"player_id": String(player.get("id", "")), "buyer_id": borrower_id, "reason": "obligation_unaffordable"})
		else:
			returned.append(String(player.get("id", "")))
	return {"bought": bought, "returned_pending": returned, "lapsed_obligations": lapsed}

func _clear_loan_fields(player: Dictionary) -> void:
	for key in ["loan_parent_club_id", "loan_end_year", "loan_fee", "loan_wage_contribution_pct", "loan_buy_option", "loan_buy_obligation", "loan_appearances_start"]:
		player.erase(key)

func return_expired_loans(world: Dictionary, season_year: int) -> int:
	var count := 0
	for player in world.players:
		if int(player.get("loan_end_year", 9999)) <= season_year and String(player.get("loan_parent_club_id", "")) != "":
			player.club_id = String(player.loan_parent_club_id)
			player.erase("loan_parent_club_id")
			player.erase("loan_end_year")
			count += 1
	return count

func settle_payables(world: Dictionary, season_year: int) -> Dictionary:
	_ledger.ensure(world)
	return _ledger.settle_due_payables(world, season_year)

func rebalance_ai_squads(world: Dictionary, season_year: int, seed: int, min_squad: int = 20, max_squad: int = 30) -> Dictionary:
	_ledger.ensure(world)
	_events.ensure_world(world)
	var free_agents: Array = _free_agents(world.players)
	var signings := 0
	var releases := 0
	for club in world.clubs:
		var squad: Array = _squad(world.players, String(club.id))
		while squad.size() > max_squad:
			var weakest: Dictionary = _weakest_noncritical(squad)
			weakest.club_id = ""
			free_agents.append(weakest)
			squad.erase(weakest)
			releases += 1
		for required_position in ["GK", "DC", "ST"]:
			if _has_position(squad, required_position):
				continue
			var specialist: Dictionary = _best_available_position(free_agents, required_position)
			if specialist.is_empty():
				continue
			if _sign_free_agent(world, specialist, club, season_year):
				squad.append(specialist)
				free_agents.erase(specialist)
				signings += 1
		while squad.size() < min_squad and not free_agents.is_empty():
			var target: Dictionary = _best_fit(free_agents, squad)
			if _sign_free_agent(world, target, club, season_year):
				squad.append(target)
				signings += 1
			free_agents.erase(target)
	return {"signings": signings, "releases": releases, "free_agents": free_agents.size()}

func squad_is_viable(world: Dictionary, club_id: String, min_squad: int = 18) -> bool:
	var squad: Array = _squad(world.players, club_id)
	return squad.size() >= min_squad and _has_position(squad, "GK") and _has_position(squad, "DC") and _has_position(squad, "ST")

func _sign_free_agent(world: Dictionary, player: Dictionary, club: Dictionary, season_year: int) -> bool:
	var wage: int = recommended_wage(player)
	if wage > int(club.wage_budget):
		return false
	var previous_club := String(player.get("club_id", ""))
	player.club_id = String(club.id)
	_upsert_contract(world, String(player.id), String(club.id), season_year, season_year + 2, wage)
	_events.emit(world, "PLAYER_SIGNED", {"player_id":String(player.id),"buyer_id":String(club.id),"seller_id":previous_club,"fee":0,"transfer_type":"free_agent","season_year":season_year}, "transfer_market")
	_events.emit(world, "CONTRACT_SIGNED", {"player_id":String(player.id),"club_id":String(club.id),"start_year":season_year,"end_year":season_year+2,"weekly_wage":wage,"renewal":false}, "transfer_market")
	return true

func _free_agents(players: Array) -> Array:
	var result: Array = []
	for player in players:
		if not bool(player.get("retired", false)) and String(player.get("club_id", "")) == "":
			result.append(player)
	return result

func _has_position(squad: Array, position: String) -> bool:
	for player in squad:
		if String(player.position) == position:
			return true
	return false

func _best_available_position(free_agents: Array, position: String) -> Dictionary:
	var best: Dictionary = {}
	for player in free_agents:
		if String(player.position) != position:
			continue
		if best.is_empty() or int(player.current_ability) > int(best.current_ability):
			best = player
	return best

func _best_fit(free_agents: Array, squad: Array) -> Dictionary:
	var best: Dictionary = free_agents[0]
	var best_score := -99999
	for player in free_agents:
		var score: int = int(player.current_ability)
		if not _has_position(squad, String(player.position)):
			score += 25
		if score > best_score:
			best = player
			best_score = score
	return best

func _weakest_noncritical(squad: Array) -> Dictionary:
	var weakest: Dictionary = squad[0]
	for player in squad:
		var position: String = String(player.position)
		var count := 0
		for teammate in squad:
			if String(teammate.position) == position:
				count += 1
		if position in ["GK", "DC", "ST"] and count <= 1:
			continue
		if int(player.current_ability) < int(weakest.current_ability):
			weakest = player
	return weakest

func _squad(players: Array, club_id: String) -> Array:
	var result: Array = []
	for player in players:
		if String(player.get("club_id", "")) == club_id and not bool(player.get("retired", false)):
			result.append(player)
	return result

func _upsert_contract(world: Dictionary, player_id: String, club_id: String, start_year: int, end_year: int, wage: int, terms: Dictionary = {}) -> void:
	var clauses := {
		"signing_bonus": maxi(0, int(terms.get("signing_bonus", 0))),
		"release_clause": maxi(0, int(terms.get("release_clause", 0))),
		"extension_option": bool(terms.get("extension_option", false)),
		"promotion_rise_pct": clampf(float(terms.get("promotion_rise_pct", 0.0)), 0.0, 0.5),
		"relegation_drop_pct": clampf(float(terms.get("relegation_drop_pct", 0.0)), 0.0, 0.5),
		"squad_status": String(terms.get("squad_status", "squad")),
		"appearance_bonus": maxi(0, int(terms.get("appearance_bonus", 0))),
		"goal_bonus": maxi(0, int(terms.get("goal_bonus", 0))),
	}
	for contract in world.contracts:
		if String(contract.player_id) == player_id:
			contract.club_id = club_id
			contract.start_year = start_year
			contract.end_year = end_year
			contract.weekly_wage = wage
			for key in clauses.keys():
				contract[key] = clauses[key]
			return
	var row := {"id": "contract-" + player_id, "player_id": player_id, "club_id": club_id, "start_year": start_year, "end_year": end_year, "weekly_wage": wage}
	for key in clauses.keys():
		row[key] = clauses[key]
	world.contracts.append(row)

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

func _stable_key(text: String) -> int:
	var value := 23
	for character in text.to_utf8_buffer():
		value = posmod(value * 137 + int(character), 2_147_483_647)
	return value

func _rand_int(seed: int, key: int, min_value: int, max_value: int) -> int:
	return min_value + (SeededRngClass.value_for(seed, key) % (max_value - min_value + 1))
